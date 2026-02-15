-- Migration 3: Core Functions (no side effects)
-- Pure state transition logic and the reducer, testable without
-- Vault, pg_net, or any external dependencies.

-- Pure function: state transition table
-- Takes current state, event, and approval flags; returns next state.
CREATE FUNCTION compute_next_state(
  current_state     capacity_request_state,
  event             capacity_request_event_type,
  commercial_done   boolean,
  technical_done    boolean
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
      IF event IN ('COMMERCIAL_APPROVED', 'TECH_REVIEW_APPROVED') THEN
        -- After applying this approval, are both done?
        IF commercial_done AND technical_done THEN
          RETURN 'CUSTOMER_CONFIRMATION_REQUIRED';
        END IF;
        RETURN 'UNDER_REVIEW';
      END IF;
      IF event IN ('COMMERCIAL_REJECTED', 'TECH_REVIEW_REJECTED') THEN
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

-- Reducer: the single path for all state mutations.
-- Locks row, computes transition, inserts event, updates projection.
-- Side effects (dispatch_side_effects) will be added in migration 4.
CREATE FUNCTION apply_capacity_event(
  p_request_id  text,
  p_event_type  capacity_request_event_type,
  p_actor_type  capacity_request_actor_type,
  p_actor_id    text,
  p_payload     jsonb DEFAULT '{}'
) RETURNS capacity_requests AS $$
DECLARE
  req             capacity_requests;
  new_state       capacity_request_state;
  commercial_done boolean;
  technical_done  boolean;
BEGIN
  -- Lock the row for the duration of this transaction
  SELECT * INTO STRICT req
    FROM capacity_requests
    WHERE id = p_request_id
    FOR UPDATE;

  -- Compute approval flags AFTER this event is applied
  commercial_done := req.commercial_approved_at IS NOT NULL
                     OR p_event_type = 'COMMERCIAL_APPROVED';
  technical_done  := req.technical_approved_at IS NOT NULL
                     OR p_event_type = 'TECH_REVIEW_APPROVED';

  -- Pure transition logic
  new_state := compute_next_state(req.state, p_event_type, commercial_done, technical_done);

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

  RETURN req;
END;
$$ LANGUAGE plpgsql;

-- Create a new capacity request and apply the initial REQUEST_SUBMITTED event.
CREATE FUNCTION create_capacity_request(
  p_requester_user_id         text,
  p_commercial_owner_user_id  text,
  p_infra_owner_group         text,
  p_customer_ref              jsonb,
  p_requested_size            text,
  p_quantity                  integer,
  p_region                    text,
  p_needed_by_date            date,
  p_expected_duration_days    integer,
  p_estimated_monthly_cost_usd numeric DEFAULT NULL,
  p_confirmation_ttl_days     integer DEFAULT 7,
  p_slack_channel_id          text DEFAULT NULL
) RETURNS capacity_requests AS $$
DECLARE
  new_id  text;
  req     capacity_requests;
BEGIN
  new_id := next_capacity_request_id();

  INSERT INTO capacity_requests (
    id, state, requester_user_id, commercial_owner_user_id,
    infra_owner_group, customer_ref, requested_size, quantity,
    region, needed_by_date, expected_duration_days,
    estimated_monthly_cost_usd, confirmation_ttl_days,
    slack_channel_id
  ) VALUES (
    new_id, 'SUBMITTED', p_requester_user_id, p_commercial_owner_user_id,
    p_infra_owner_group, p_customer_ref, p_requested_size, p_quantity,
    p_region, p_needed_by_date, p_expected_duration_days,
    p_estimated_monthly_cost_usd, p_confirmation_ttl_days,
    p_slack_channel_id
  );

  -- Apply the initial event to transition SUBMITTED -> UNDER_REVIEW
  req := apply_capacity_event(new_id, 'REQUEST_SUBMITTED', 'user', p_requester_user_id, '{}');

  RETURN req;
END;
$$ LANGUAGE plpgsql;
