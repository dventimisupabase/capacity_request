-- Migration 18: Slack DM Dispatch + VP Approver Column
-- Adds vp_approver_user_id column, RLS policy for VP approver reads,
-- updates create_capacity_request with 13th param, creates enqueue_slack_dm
-- helper, and updates dispatch_side_effects with DM dispatch at key transitions.

-- 1. Add vp_approver_user_id column
ALTER TABLE capacity_requests ADD COLUMN vp_approver_user_id text;

-- 2. RLS policy for VP approver
CREATE POLICY requests_vp_approver_read ON capacity_requests
  FOR SELECT TO authenticated
  USING (vp_approver_user_id = current_setting('request.jwt.claims', true)::json->>'sub');

-- 3. Update create_capacity_request — add 13th param (vp_approver_user_id)
-- Must DROP + CREATE (adding a DEFAULT param would create ambiguous overload).
DROP FUNCTION create_capacity_request(text, text, text, jsonb, text, integer, text, date, integer, numeric, integer, text);

CREATE FUNCTION create_capacity_request(
  p_requester_user_id          text,
  p_commercial_owner_user_id   text,
  p_infra_owner_group          text,
  p_customer_ref               jsonb,
  p_requested_size             text,
  p_quantity                   integer,
  p_region                     text,
  p_needed_by_date             date,
  p_expected_duration_days     integer,
  p_estimated_monthly_cost_usd numeric DEFAULT NULL,
  p_confirmation_ttl_days      integer DEFAULT 7,
  p_slack_channel_id           text DEFAULT NULL,
  p_vp_approver_user_id        text DEFAULT NULL
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
    slack_channel_id, vp_approver_user_id
  ) VALUES (
    new_id, 'SUBMITTED', p_requester_user_id, p_commercial_owner_user_id,
    p_infra_owner_group, p_customer_ref, p_requested_size, p_quantity,
    p_region, p_needed_by_date, p_expected_duration_days,
    p_estimated_monthly_cost_usd, p_confirmation_ttl_days,
    p_slack_channel_id, p_vp_approver_user_id
  );

  -- Apply the initial event to transition SUBMITTED -> UNDER_REVIEW
  req := apply_capacity_event(new_id, 'REQUEST_SUBMITTED', 'user', p_requester_user_id, '{}');

  RETURN req;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION create_capacity_request TO authenticated;

-- 4. Create enqueue_slack_dm helper
CREATE FUNCTION enqueue_slack_dm(
  p_capacity_request_id text,
  p_event_id            uuid,
  p_slack_user_id       text,
  p_message_text        text
) RETURNS uuid AS $$
BEGIN
  -- No-op if no user ID provided
  IF p_slack_user_id IS NULL OR p_slack_user_id = '' THEN
    RETURN NULL;
  END IF;

  -- Slack chat.postMessage with a user ID as channel sends a DM
  RETURN enqueue_outbox(
    p_capacity_request_id,
    p_event_id,
    'slack',
    jsonb_build_object('channel', p_slack_user_id, 'text', p_message_text)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Update dispatch_side_effects — add DM dispatch at key transitions
-- Now runs even without slack_channel_id (DMs use individual user IDs).
-- Channel messages are gated on slack_channel_id, DMs on individual user IDs.
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

  -- === DM dispatch at key transitions ===

  -- SUBMITTED -> UNDER_REVIEW: DM commercial owner
  IF old_state = 'SUBMITTED' AND new_state = 'UNDER_REVIEW' THEN
    PERFORM enqueue_slack_dm(
      req.id, latest_event_id,
      req.commercial_owner_user_id,
      format('New capacity request %s needs your commercial review. Size: %s x %s in %s.',
             req.id, req.quantity, req.requested_size, req.region)
    );
  END IF;

  -- VP escalation needed: DM vp_approver when commercial + tech done but VP pending
  IF new_state = 'UNDER_REVIEW'
     AND event_type IN ('COMMERCIAL_APPROVED', 'TECH_REVIEW_APPROVED')
     AND req.commercial_approved_at IS NOT NULL
     AND req.technical_approved_at IS NOT NULL
     AND req.vp_approved_at IS NULL
     AND req.estimated_monthly_cost_usd IS NOT NULL
     AND req.estimated_monthly_cost_usd >= get_escalation_threshold_usd()
  THEN
    PERFORM enqueue_slack_dm(
      req.id, latest_event_id,
      req.vp_approver_user_id,
      format('Capacity request %s ($%s/mo) requires your VP approval. Size: %s x %s in %s.',
             req.id, req.estimated_monthly_cost_usd, req.quantity, req.requested_size, req.region)
    );
  END IF;

  -- -> CUSTOMER_CONFIRMATION_REQUIRED: DM requester
  IF new_state = 'CUSTOMER_CONFIRMATION_REQUIRED' AND old_state != 'CUSTOMER_CONFIRMATION_REQUIRED' THEN
    PERFORM enqueue_slack_dm(
      req.id, latest_event_id,
      req.requester_user_id,
      format('All approvals received for %s. Please confirm or decline by %s.',
             req.id, COALESCE(req.next_deadline_at::date::text, 'N/A'))
    );
  END IF;

  -- CONFIRMATION_REMINDER_SENT: DM requester with reminder
  IF event_type = 'CONFIRMATION_REMINDER_SENT' THEN
    PERFORM enqueue_slack_dm(
      req.id, latest_event_id,
      req.requester_user_id,
      format('Reminder: %s needs your confirmation by %s.',
             req.id, COALESCE(req.next_deadline_at::date::text, 'N/A'))
    );
  END IF;

  -- === Channel message dispatch (only if slack_channel_id is set) ===
  IF req.slack_channel_id IS NULL THEN
    RETURN;
  END IF;

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

-- 6. Recreate v_request_detail — add vp_approver_user_id
DROP VIEW IF EXISTS v_request_detail;

CREATE VIEW v_request_detail WITH (security_invoker = true) AS
SELECT
  cr.id,
  cr.state,
  cr.region,
  cr.requested_size,
  cr.quantity,
  cr.estimated_monthly_cost_usd,
  cr.needed_by_date,
  cr.expected_duration_days,
  cr.customer_ref,
  cr.requester_user_id,
  cr.commercial_owner_user_id,
  cr.infra_owner_group,
  cr.commercial_approved_at,
  cr.technical_approved_at,
  cr.vp_approved_at,
  cr.vp_approver_user_id,
  cr.next_deadline_at,
  cr.version,
  cr.created_at,
  cr.updated_at,
  cr.slack_channel_id,
  cr.slack_thread_ts
FROM capacity_requests cr;

GRANT SELECT ON v_request_detail TO authenticated;
