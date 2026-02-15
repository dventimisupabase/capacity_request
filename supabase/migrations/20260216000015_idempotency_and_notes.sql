-- Migration 15: Idempotency Keys + Notes
-- Adds idempotency_key and notes columns to capacity_request_events.
-- Updates apply_capacity_event() to support idempotent event application
-- and free-text notes on actions.

-- 1. Schema changes
ALTER TABLE capacity_request_events ADD COLUMN idempotency_key text UNIQUE;
ALTER TABLE capacity_request_events ADD COLUMN notes text;

-- 2. Recreate v_request_events view to include notes (not idempotency_key — that's internal)
-- Must DROP + CREATE because adding a column before an existing one isn't allowed by CREATE OR REPLACE.
DROP VIEW v_request_events;

CREATE VIEW v_request_events AS
SELECT
  e.id,
  e.capacity_request_id,
  e.event_type,
  e.actor_type,
  e.actor_id,
  e.payload,
  e.notes,
  e.created_at
FROM capacity_request_events e;

GRANT SELECT ON v_request_events TO anon, authenticated;

-- 3. Replace apply_capacity_event with new 7-arg signature
-- Must DROP first — adding default params would create an ambiguous overload.
DROP FUNCTION apply_capacity_event(text, capacity_request_event_type, capacity_request_actor_type, text, jsonb);

CREATE FUNCTION apply_capacity_event(
  p_request_id      text,
  p_event_type      capacity_request_event_type,
  p_actor_type      capacity_request_actor_type,
  p_actor_id        text,
  p_payload         jsonb DEFAULT '{}',
  p_idempotency_key text DEFAULT NULL,
  p_notes           text DEFAULT NULL
) RETURNS capacity_requests AS $$
DECLARE
  req             capacity_requests;
  existing_event  capacity_request_events;
  old_state       capacity_request_state;
  new_state       capacity_request_state;
  commercial_done boolean;
  technical_done  boolean;
  vp_done         boolean;
  vp_required     boolean;
BEGIN
  -- Idempotency check — done before the FOR UPDATE lock to avoid unnecessary contention
  IF p_idempotency_key IS NOT NULL THEN
    SELECT * INTO existing_event FROM capacity_request_events WHERE idempotency_key = p_idempotency_key;
    IF FOUND THEN
      SELECT * INTO STRICT req FROM capacity_requests WHERE id = existing_event.capacity_request_id;
      RETURN req;  -- no-op, return current state
    END IF;
  END IF;

  -- Lock the row for the duration of this transaction
  SELECT * INTO STRICT req
    FROM capacity_requests
    WHERE id = p_request_id
    FOR UPDATE;

  -- Capture old state for side-effect dispatch
  old_state := req.state;

  -- Compute approval flags AFTER this event is applied
  commercial_done := req.commercial_approved_at IS NOT NULL
                     OR p_event_type = 'COMMERCIAL_APPROVED';
  technical_done  := req.technical_approved_at IS NOT NULL
                     OR p_event_type = 'TECH_REVIEW_APPROVED';

  -- VP escalation flags
  vp_required := req.estimated_monthly_cost_usd IS NOT NULL
                 AND req.estimated_monthly_cost_usd >= get_escalation_threshold_usd();
  vp_done     := req.vp_approved_at IS NOT NULL
                 OR p_event_type = 'VP_APPROVED';

  -- Pure transition logic (now with VP flags)
  new_state := compute_next_state(req.state, p_event_type, commercial_done, technical_done, vp_done, vp_required);

  -- Append event (with new columns)
  INSERT INTO capacity_request_events (capacity_request_id, event_type, actor_type, actor_id, payload, idempotency_key, notes)
    VALUES (p_request_id, p_event_type, p_actor_type, p_actor_id, p_payload, p_idempotency_key, p_notes);

  -- Update projection with optimistic concurrency check
  UPDATE capacity_requests SET
    state                = new_state,
    version              = version + 1,
    updated_at           = now(),
    commercial_approved_at = CASE
      WHEN p_event_type = 'COMMERCIAL_APPROVED' THEN now()
      ELSE commercial_approved_at
    END,
    technical_approved_at = CASE
      WHEN p_event_type = 'TECH_REVIEW_APPROVED' THEN now()
      ELSE technical_approved_at
    END,
    vp_approved_at = CASE
      WHEN p_event_type = 'VP_APPROVED' THEN now()
      ELSE vp_approved_at
    END,
    next_deadline_at     = CASE
      WHEN new_state = 'CUSTOMER_CONFIRMATION_REQUIRED'
        THEN now() + (confirmation_ttl_days || ' days')::interval
      ELSE NULL
    END,
    cancellation_reason  = CASE
      WHEN p_event_type = 'CANCEL_APPROVED' THEN p_payload->>'reason'
      ELSE cancellation_reason
    END,
    cancellation_authorizer_user_id = CASE
      WHEN p_event_type = 'CANCEL_APPROVED' THEN p_actor_id
      ELSE cancellation_authorizer_user_id
    END
  WHERE id = p_request_id AND version = req.version
  RETURNING * INTO STRICT req;

  -- Dispatch side effects (async via outbox)
  PERFORM dispatch_side_effects(req, old_state, new_state, p_event_type);

  RETURN req;
END;
$$ LANGUAGE plpgsql;

-- 4. Re-grant execute permission (DROP removed the prior grant from migration 5)
GRANT EXECUTE ON FUNCTION apply_capacity_event TO authenticated;
