-- Migration 7: Transactional Outbox
-- Replaces direct pg_net calls in dispatch_side_effects() with outbox inserts.
-- A pg_cron job polls the outbox and delivers via pg_net for at-least-once delivery.

-- Outbox table: stores side-effect intent for reliable delivery
CREATE TABLE capacity_request_outbox (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  capacity_request_id   text NOT NULL REFERENCES capacity_requests(id),
  event_id              uuid REFERENCES capacity_request_events(id),
  destination           text NOT NULL,
  payload               jsonb NOT NULL,
  created_at            timestamptz NOT NULL DEFAULT now(),
  delivered_at          timestamptz,
  attempts              integer NOT NULL DEFAULT 0,
  last_error            text,
  max_attempts          integer NOT NULL DEFAULT 5,
  pg_net_request_id     bigint
);

-- Partial index: efficiently find undelivered rows
CREATE INDEX idx_outbox_undelivered
  ON capacity_request_outbox (created_at)
  WHERE delivered_at IS NULL AND attempts < max_attempts;

-- RLS on outbox table
ALTER TABLE capacity_request_outbox ENABLE ROW LEVEL SECURITY;

-- Read-only for authenticated users (correlated to requests they can see)
CREATE POLICY outbox_read ON capacity_request_outbox
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM capacity_requests cr
      WHERE cr.id = capacity_request_outbox.capacity_request_id
    )
  );

-- Service role full access
CREATE POLICY outbox_service_all ON capacity_request_outbox
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Grant read to authenticated
GRANT SELECT ON capacity_request_outbox TO authenticated;

-- Helper: insert an outbox row
CREATE FUNCTION enqueue_outbox(
  p_capacity_request_id text,
  p_event_id            uuid,
  p_destination         text,
  p_payload             jsonb
) RETURNS uuid AS $$
DECLARE
  outbox_id uuid;
BEGIN
  INSERT INTO capacity_request_outbox (capacity_request_id, event_id, destination, payload)
  VALUES (p_capacity_request_id, p_event_id, p_destination, p_payload)
  RETURNING id INTO outbox_id;
  RETURN outbox_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Rewrite dispatch_side_effects to enqueue outbox rows instead of calling pg_net directly.
-- Secrets (SLACK_BOT_TOKEN) are NOT stored in the outbox; they're looked up at delivery time.
CREATE OR REPLACE FUNCTION dispatch_side_effects(
  req         capacity_requests,
  old_state   capacity_request_state,
  new_state   capacity_request_state,
  event_type  capacity_request_event_type
) RETURNS void AS $$
DECLARE
  slack_payload jsonb;
  latest_event_id uuid;
BEGIN
  -- Skip if no Slack channel configured
  IF req.slack_channel_id IS NULL THEN
    RETURN;
  END IF;

  -- Get the latest event ID for this request (the one just inserted)
  SELECT id INTO latest_event_id
  FROM capacity_request_events
  WHERE capacity_request_id = req.id
  ORDER BY created_at DESC
  LIMIT 1;

  CASE new_state
    WHEN 'UNDER_REVIEW' THEN
      IF old_state = 'SUBMITTED' THEN
        slack_payload := jsonb_build_object(
          'channel', req.slack_channel_id,
          'text',    format('New capacity request %s: %s x %s in %s. Awaiting commercial and technical review.',
                            req.id, req.quantity, req.requested_size, req.region),
          'metadata', jsonb_build_object('event_type', 'capacity_request', 'event_payload', jsonb_build_object('cr_id', req.id))
        );
      ELSE
        slack_payload := jsonb_build_object(
          'channel', req.slack_channel_id,
          'thread_ts', req.slack_thread_ts,
          'text',    format('%s recorded for %s. Commercial: %s | Technical: %s',
                            event_type, req.id,
                            CASE WHEN req.commercial_approved_at IS NOT NULL THEN 'approved' ELSE 'pending' END,
                            CASE WHEN req.technical_approved_at IS NOT NULL THEN 'approved' ELSE 'pending' END)
        );
      END IF;

    WHEN 'CUSTOMER_CONFIRMATION_REQUIRED' THEN
      slack_payload := jsonb_build_object(
        'channel', req.slack_channel_id,
        'thread_ts', req.slack_thread_ts,
        'text',    format('%s approved. Customer confirmation required by %s.',
                          req.id, req.next_deadline_at::date)
      );

    WHEN 'REJECTED' THEN
      slack_payload := jsonb_build_object(
        'channel', req.slack_channel_id,
        'thread_ts', req.slack_thread_ts,
        'text',    format('%s has been rejected (%s).', req.id, event_type)
      );

    WHEN 'PROVISIONING' THEN
      slack_payload := jsonb_build_object(
        'channel', req.slack_channel_id,
        'thread_ts', req.slack_thread_ts,
        'text',    format('%s confirmed by customer. Provisioning started.', req.id)
      );

    WHEN 'COMPLETED', 'CANCELLED', 'EXPIRED', 'FAILED' THEN
      slack_payload := jsonb_build_object(
        'channel', req.slack_channel_id,
        'thread_ts', req.slack_thread_ts,
        'text',    format('%s -> %s.', req.id, new_state)
      );

    ELSE NULL;
  END CASE;

  -- Enqueue to outbox if we built a payload
  IF slack_payload IS NOT NULL THEN
    PERFORM enqueue_outbox(req.id, latest_event_id, 'slack', slack_payload);
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Outbox processor: polls for undelivered messages and sends via pg_net.
-- Looks up SLACK_BOT_TOKEN at delivery time (not stored in outbox).
CREATE FUNCTION process_outbox() RETURNS void AS $$
DECLARE
  row record;
  slack_token text;
  request_id bigint;
BEGIN
  -- Look up token once per sweep
  slack_token := get_secret('SLACK_BOT_TOKEN');

  FOR row IN
    SELECT *
    FROM capacity_request_outbox
    WHERE delivered_at IS NULL
      AND attempts < max_attempts
    ORDER BY created_at
    FOR UPDATE SKIP LOCKED
  LOOP
    BEGIN
      IF row.destination = 'slack' AND slack_token IS NOT NULL THEN
        SELECT net.http_post(
          url     := 'https://slack.com/api/chat.postMessage',
          headers := jsonb_build_object(
            'Content-Type',  'application/json',
            'Authorization', 'Bearer ' || slack_token
          ),
          body    := row.payload
        ) INTO request_id;

        UPDATE capacity_request_outbox SET
          delivered_at = now(),
          attempts = attempts + 1,
          pg_net_request_id = request_id
        WHERE id = row.id;
      ELSE
        -- No token or unknown destination: increment attempts with error
        UPDATE capacity_request_outbox SET
          attempts = attempts + 1,
          last_error = CASE
            WHEN slack_token IS NULL THEN 'SLACK_BOT_TOKEN not configured'
            ELSE format('Unknown destination: %s', row.destination)
          END
        WHERE id = row.id;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      UPDATE capacity_request_outbox SET
        attempts = attempts + 1,
        last_error = SQLERRM
      WHERE id = row.id;
    END;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Schedule outbox processor every 30 seconds
SELECT cron.schedule(
  'process-outbox',
  '30 seconds',
  $$SELECT process_outbox()$$
);
