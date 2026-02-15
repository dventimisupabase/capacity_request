-- Migration 17: Confirmation Reminder Logic
-- Adds CONFIRMATION_REMINDER_SENT event type, updates compute_next_state
-- to handle it as a no-op, adds reminder-specific Slack message in
-- dispatch_side_effects, and adds reminder sweep to timer function.

-- 1. Add enum value
ALTER TYPE capacity_request_event_type ADD VALUE 'CONFIRMATION_REMINDER_SENT';

-- 2. Update compute_next_state — handle no-op reminder event
-- Must DROP + CREATE (same 6-arg signature, adding a new code path).
DROP FUNCTION compute_next_state(capacity_request_state, capacity_request_event_type, boolean, boolean, boolean, boolean);

CREATE FUNCTION compute_next_state(
  current_state     capacity_request_state,
  event             capacity_request_event_type,
  commercial_done   boolean,
  technical_done    boolean,
  vp_done           boolean DEFAULT true,
  vp_required       boolean DEFAULT false
) RETURNS capacity_request_state AS $$
BEGIN
  -- CONFIRMATION_REMINDER_SENT is a no-op event (no state change)
  IF event = 'CONFIRMATION_REMINDER_SENT' THEN
    IF current_state != 'CUSTOMER_CONFIRMATION_REQUIRED' THEN
      RAISE EXCEPTION 'CONFIRMATION_REMINDER_SENT only valid in CUSTOMER_CONFIRMATION_REQUIRED, got %', current_state;
    END IF;
    RETURN current_state;
  END IF;

  -- CANCEL_APPROVED from any non-terminal state
  IF event = 'CANCEL_APPROVED' THEN
    IF current_state IN ('COMPLETED', 'REJECTED', 'CANCELLED', 'EXPIRED', 'FAILED') THEN
      RAISE EXCEPTION 'Cannot cancel a request in terminal state %', current_state;
    END IF;
    RETURN 'CANCELLED';
  END IF;

  CASE current_state
    WHEN 'SUBMITTED' THEN
      IF event = 'REQUEST_SUBMITTED' THEN RETURN 'UNDER_REVIEW'; END IF;

    WHEN 'UNDER_REVIEW' THEN
      IF event IN ('COMMERCIAL_APPROVED', 'TECH_REVIEW_APPROVED', 'VP_APPROVED') THEN
        IF commercial_done AND technical_done AND (NOT vp_required OR vp_done) THEN
          RETURN 'CUSTOMER_CONFIRMATION_REQUIRED';
        END IF;
        RETURN 'UNDER_REVIEW';
      END IF;
      IF event IN ('COMMERCIAL_REJECTED', 'TECH_REVIEW_REJECTED', 'VP_REJECTED') THEN
        RETURN 'REJECTED';
      END IF;

    WHEN 'CUSTOMER_CONFIRMATION_REQUIRED' THEN
      IF event = 'CUSTOMER_CONFIRMED' THEN RETURN 'PROVISIONING'; END IF;
      IF event = 'CUSTOMER_DECLINED' THEN RETURN 'CANCELLED'; END IF;
      IF event = 'CUSTOMER_CONFIRMATION_TIMEOUT' THEN RETURN 'EXPIRED'; END IF;

    WHEN 'PROVISIONING' THEN
      IF event = 'PROVISIONING_COMPLETE' THEN RETURN 'COMPLETED'; END IF;
      IF event = 'PROVISIONING_FAILED' THEN RETURN 'FAILED'; END IF;

    ELSE
      NULL;
  END CASE;

  RAISE EXCEPTION 'Invalid transition: state=% event=%', current_state, event;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 3. Update dispatch_side_effects — add reminder-specific Slack message
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

  -- Skip if suppressed (e.g., during Slack interactive actions)
  IF current_setting('app.suppress_outbox', true) = 'true' THEN
    RETURN;
  END IF;

  -- Get the latest event ID for this request (the one just inserted)
  SELECT id INTO latest_event_id
  FROM capacity_request_events
  WHERE capacity_request_id = req.id
  ORDER BY created_at DESC
  LIMIT 1;

  -- Reminder gets a simple text message instead of full Block Kit
  IF event_type = 'CONFIRMATION_REMINDER_SENT' THEN
    slack_payload := jsonb_build_object(
      'channel', req.slack_channel_id,
      'text', format('Reminder: %s is awaiting customer confirmation. Deadline: %s.',
                      req.id, COALESCE(req.next_deadline_at::date::text, 'N/A'))
    );
    IF req.slack_thread_ts IS NOT NULL THEN
      slack_payload := slack_payload || jsonb_build_object('thread_ts', req.slack_thread_ts);
    END IF;
    PERFORM enqueue_outbox(req.id, latest_event_id, 'slack', slack_payload);
    RETURN;
  END IF;

  -- Build Block Kit payload for all other events
  slack_payload := build_block_kit_message(req, old_state, new_state, event_type);

  IF slack_payload IS NOT NULL THEN
    PERFORM enqueue_outbox(req.id, latest_event_id, 'slack', slack_payload);
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Update run_capacity_request_timers — add reminder sweep
CREATE OR REPLACE FUNCTION run_capacity_request_timers() RETURNS void AS $$
DECLARE
  expired RECORD;
  reminder RECORD;
BEGIN
  -- Existing: expire overdue deadlines
  FOR expired IN
    SELECT id FROM capacity_requests
    WHERE next_deadline_at IS NOT NULL
      AND next_deadline_at <= now()
      AND state NOT IN ('COMPLETED', 'REJECTED', 'CANCELLED', 'EXPIRED', 'FAILED')
    FOR UPDATE SKIP LOCKED
  LOOP
    PERFORM apply_capacity_event(
      expired.id,
      'CUSTOMER_CONFIRMATION_TIMEOUT',
      'cron',
      'pg_cron_timer',
      '{}'
    );
  END LOOP;

  -- New: send confirmation reminders at 50% of deadline elapsed
  FOR reminder IN
    SELECT cr.id
    FROM capacity_requests cr
    WHERE cr.state = 'CUSTOMER_CONFIRMATION_REQUIRED'
      AND cr.next_deadline_at IS NOT NULL
      AND cr.next_deadline_at > now()
      AND now() > cr.updated_at + (cr.next_deadline_at - cr.updated_at) / 2
      AND NOT EXISTS (
        SELECT 1 FROM capacity_request_events e
        WHERE e.capacity_request_id = cr.id
          AND e.event_type = 'CONFIRMATION_REMINDER_SENT'
      )
    FOR UPDATE SKIP LOCKED
  LOOP
    PERFORM apply_capacity_event(
      reminder.id,
      'CONFIRMATION_REMINDER_SENT',
      'cron',
      'pg_cron_timer',
      '{}'
    );
  END LOOP;
END;
$$ LANGUAGE plpgsql;
