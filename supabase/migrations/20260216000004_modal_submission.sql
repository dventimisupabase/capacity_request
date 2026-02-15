-- Migration 15: Modal Submission Handler
-- Handles Slack view_submission payloads from the capacity request creation modal.
-- Also updates check_request() to gate the new endpoint.

CREATE FUNCTION handle_slack_modal_submission(text) RETURNS json AS $$
DECLARE
  raw_payload jsonb;
  vals        jsonb;
  user_id     text;
  channel_id  text;
  p_size      text;
  p_region    text;
  p_quantity  integer;
  p_duration  integer;
  p_needed_by date;
  p_cost      numeric;
  p_customer  text;
  p_commercial_owner text;
  p_infra_group text;
  errors      jsonb := '{}'::jsonb;
  req         capacity_requests;
BEGIN
  raw_payload := $1::jsonb;
  user_id     := raw_payload->'user'->>'id';
  channel_id  := raw_payload->'view'->>'private_metadata';
  vals        := raw_payload->'view'->'state'->'values';

  -- Extract form values from Slack's nested structure
  -- Required fields
  p_size := vals->'size'->'size_select'->'selected_option'->>'value';
  p_region := vals->'region'->'region_select'->'selected_option'->>'value';

  -- Numeric inputs
  BEGIN
    p_quantity := (vals->'quantity'->'quantity_input'->>'value')::integer;
  EXCEPTION WHEN OTHERS THEN
    p_quantity := NULL;
  END;

  BEGIN
    p_duration := (vals->'duration'->'duration_input'->>'value')::integer;
  EXCEPTION WHEN OTHERS THEN
    p_duration := NULL;
  END;

  -- Date picker
  BEGIN
    p_needed_by := (vals->'needed_by'->'needed_by_picker'->>'selected_date')::date;
  EXCEPTION WHEN OTHERS THEN
    p_needed_by := NULL;
  END;

  -- Optional fields
  BEGIN
    p_cost := (vals->'cost'->'cost_input'->>'value')::numeric;
  EXCEPTION WHEN OTHERS THEN
    p_cost := NULL;
  END;

  p_customer := vals->'customer'->'customer_input'->>'value';
  p_commercial_owner := vals->'commercial_owner'->'commercial_owner_select'->>'selected_user';
  p_infra_group := vals->'infra_group'->'infra_group_input'->>'value';

  -- Validate required fields
  IF p_size IS NULL THEN
    errors := errors || jsonb_build_object('size', 'Size is required');
  END IF;
  IF p_region IS NULL THEN
    errors := errors || jsonb_build_object('region', 'Region is required');
  END IF;
  IF p_quantity IS NULL THEN
    errors := errors || jsonb_build_object('quantity', 'Quantity is required');
  END IF;
  IF p_duration IS NULL THEN
    errors := errors || jsonb_build_object('duration', 'Duration is required');
  END IF;
  IF p_needed_by IS NULL THEN
    errors := errors || jsonb_build_object('needed_by', 'Needed-by date is required');
  END IF;

  -- Return errors to Slack if validation fails
  IF errors != '{}'::jsonb THEN
    RETURN json_build_object(
      'response_action', 'errors',
      'errors', errors
    );
  END IF;

  -- Create the capacity request
  req := create_capacity_request(
    p_requester_user_id         := user_id,
    p_commercial_owner_user_id  := p_commercial_owner,
    p_infra_owner_group         := p_infra_group,
    p_customer_ref              := jsonb_build_object('name', COALESCE(p_customer, 'TBD')),
    p_requested_size            := p_size,
    p_quantity                  := p_quantity,
    p_region                    := p_region,
    p_needed_by_date            := p_needed_by,
    p_expected_duration_days    := p_duration,
    p_estimated_monthly_cost_usd := p_cost,
    p_slack_channel_id          := channel_id
  );

  -- Return NULL to close the modal (Slack interprets empty 200 as success)
  -- The Block Kit notification posts to the channel via the normal outbox flow.
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute to authenticated and service_role
GRANT EXECUTE ON FUNCTION handle_slack_modal_submission TO authenticated, service_role;

-- Update check_request to gate the modal submission endpoint
CREATE OR REPLACE FUNCTION check_request() RETURNS void AS $$
DECLARE
  headers json := current_setting('request.headers', true)::json;
  path    text := current_setting('request.path', true);
  ts      text;
BEGIN
  -- Gate Slack webhook route
  IF path = '/rpc/handle_slack_webhook' THEN
    IF headers->>'x-slack-signature' IS NULL
       OR headers->>'x-slack-request-timestamp' IS NULL THEN
      RAISE EXCEPTION 'Missing Slack signature headers'
        USING HINT = 'Provide X-Slack-Signature and X-Slack-Request-Timestamp';
    END IF;

    ts := headers->>'x-slack-request-timestamp';
    IF abs(extract(epoch FROM now()) - ts::bigint) > 300 THEN
      RAISE EXCEPTION 'Slack request timestamp too old'
        USING HINT = 'Possible replay attack';
    END IF;
  END IF;

  -- Gate modal submission route (same Slack signature validation)
  IF path = '/rpc/handle_slack_modal_submission' THEN
    IF headers->>'x-slack-signature' IS NULL
       OR headers->>'x-slack-request-timestamp' IS NULL THEN
      RAISE EXCEPTION 'Missing Slack signature headers'
        USING HINT = 'Provide X-Slack-Signature and X-Slack-Request-Timestamp';
    END IF;

    ts := headers->>'x-slack-request-timestamp';
    IF abs(extract(epoch FROM now()) - ts::bigint) > 300 THEN
      RAISE EXCEPTION 'Slack request timestamp too old'
        USING HINT = 'Possible replay attack';
    END IF;
  END IF;

  -- Gate provisioning webhook route
  IF path = '/rpc/handle_provisioning_webhook' THEN
    IF headers->>'x-provisioning-api-key' IS NULL THEN
      RAISE EXCEPTION 'Missing provisioning API key header'
        USING HINT = 'Provide X-Provisioning-API-Key';
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;
