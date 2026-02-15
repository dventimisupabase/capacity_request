-- Add p_slack_channel_id parameter to create_capacity_request.
-- Replaces the existing function with an additional optional parameter.
CREATE OR REPLACE FUNCTION create_capacity_request(
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
