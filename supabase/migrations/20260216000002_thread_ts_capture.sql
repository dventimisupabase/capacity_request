-- Migration 13: Thread TS Capture
-- Captures slack_thread_ts from the Slack API response after the initial message
-- is delivered. Runs on a 30-second cron cadence to read pg_net HTTP responses.

CREATE FUNCTION capture_thread_timestamps() RETURNS void AS $$
DECLARE
  row record;
  response_body jsonb;
  ts_value text;
BEGIN
  -- Find outbox rows that:
  -- 1. Were delivered (delivered_at IS NOT NULL)
  -- 2. Belong to requests with no slack_thread_ts yet
  -- 3. Were the initial message (payload has no thread_ts key)
  -- 4. Have a pg_net_request_id we can look up
  FOR row IN
    SELECT o.id AS outbox_id,
           o.pg_net_request_id,
           o.capacity_request_id
    FROM capacity_request_outbox o
    JOIN capacity_requests cr ON cr.id = o.capacity_request_id
    WHERE o.delivered_at IS NOT NULL
      AND cr.slack_thread_ts IS NULL
      AND NOT (o.payload ? 'thread_ts')
      AND o.pg_net_request_id IS NOT NULL
  LOOP
    BEGIN
      -- Look up the HTTP response from pg_net
      SELECT (body::jsonb) INTO response_body
      FROM net._http_response
      WHERE id = row.pg_net_request_id;

      IF response_body IS NULL THEN
        CONTINUE;  -- Response not yet available
      END IF;

      -- Extract ts from Slack's response: {"ok": true, "ts": "1234567890.123456", ...}
      ts_value := response_body->>'ts';

      IF ts_value IS NOT NULL THEN
        UPDATE capacity_requests
        SET slack_thread_ts = ts_value
        WHERE id = row.capacity_request_id
          AND slack_thread_ts IS NULL;  -- Idempotent
      END IF;

    EXCEPTION WHEN OTHERS THEN
      -- Log but don't fail the whole sweep
      RAISE WARNING 'capture_thread_timestamps: error for outbox % : %', row.outbox_id, SQLERRM;
    END;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Schedule thread TS capture every 30 seconds
SELECT cron.schedule(
  'capture-thread-ts',
  '30 seconds',
  $$SELECT capture_thread_timestamps()$$
);
