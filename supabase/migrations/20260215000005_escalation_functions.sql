-- Migration 8b: Escalation Functions
-- Extends dual-flag approval to triple-flag for high-cost requests.
-- Requests above a configurable threshold require VP approval in addition
-- to commercial and technical approval before advancing.

-- Configurable escalation threshold (defaults to $50,000)
CREATE FUNCTION get_escalation_threshold_usd() RETURNS numeric AS $$
  SELECT COALESCE(get_secret('ESCALATION_THRESHOLD_USD')::numeric, 50000);
$$ LANGUAGE sql SECURITY DEFINER;

-- Drop the old 4-arg compute_next_state (signature changes to 6-arg)
DROP FUNCTION compute_next_state(capacity_request_state, capacity_request_event_type, boolean, boolean);

-- New compute_next_state with VP approval support.
-- Default values ensure backward compatibility: vp_done defaults to true
-- and vp_required defaults to false, so existing callers that pass only
-- 4 args get the same behavior as before.
CREATE FUNCTION compute_next_state(
  current_state     capacity_request_state,
  event             capacity_request_event_type,
  commercial_done   boolean,
  technical_done    boolean,
  vp_done           boolean DEFAULT true,
  vp_required       boolean DEFAULT false
) RETURNS capacity_request_state AS $$
BEGIN
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
        -- After applying this approval, check all flags
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
      -- Terminal states accept no events (except CANCEL_APPROVED, handled above)
      NULL;
  END CASE;

  RAISE EXCEPTION 'Invalid transition: state=% event=%', current_state, event;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Update apply_capacity_event to compute VP flags and pass to compute_next_state.
-- Also updates projection to set vp_approved_at on VP_APPROVED.
CREATE OR REPLACE FUNCTION apply_capacity_event(
  p_request_id  text,
  p_event_type  capacity_request_event_type,
  p_actor_type  capacity_request_actor_type,
  p_actor_id    text,
  p_payload     jsonb DEFAULT '{}'
) RETURNS capacity_requests AS $$
DECLARE
  req             capacity_requests;
  old_state       capacity_request_state;
  new_state       capacity_request_state;
  commercial_done boolean;
  technical_done  boolean;
  vp_done         boolean;
  vp_required     boolean;
BEGIN
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

  -- Append event
  INSERT INTO capacity_request_events (capacity_request_id, event_type, actor_type, actor_id, payload)
    VALUES (p_request_id, p_event_type, p_actor_type, p_actor_id, p_payload);

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
