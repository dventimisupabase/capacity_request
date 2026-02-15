-- Migration 20: Approval Queue RPC
-- Returns pending actions for a given user, combining commercial review,
-- technical review, VP approval, and customer confirmation queues.

CREATE FUNCTION get_my_pending_actions(
  p_user_id    text,
  p_user_group text DEFAULT NULL
) RETURNS TABLE (
  request_id                text,
  state                     capacity_request_state,
  action_needed             text,
  requested_size            text,
  quantity                  integer,
  region                    text,
  estimated_monthly_cost_usd numeric,
  customer_ref              jsonb,
  needed_by_date            date,
  created_at                timestamptz,
  next_deadline_at          timestamptz,
  sla_status                text
) AS $$
BEGIN
  RETURN QUERY

  -- 1. Commercial review needed
  SELECT
    cr.id AS request_id,
    cr.state,
    'commercial_review'::text AS action_needed,
    cr.requested_size,
    cr.quantity,
    cr.region,
    cr.estimated_monthly_cost_usd,
    cr.customer_ref,
    cr.needed_by_date,
    cr.created_at,
    cr.next_deadline_at,
    CASE
      WHEN get_sla_threshold_hours(cr.state) IS NULL THEN NULL
      WHEN extract(epoch FROM now() - cr.updated_at) / 3600 >= get_sla_threshold_hours(cr.state) THEN 'breached'
      WHEN extract(epoch FROM now() - cr.updated_at) / 3600 >= get_sla_threshold_hours(cr.state) * 0.75 THEN 'at_risk'
      ELSE 'ok'
    END::text AS sla_status
  FROM capacity_requests cr
  WHERE cr.state = 'UNDER_REVIEW'
    AND cr.commercial_owner_user_id = p_user_id
    AND cr.commercial_approved_at IS NULL

  UNION ALL

  -- 2. Technical review needed (skipped if p_user_group is NULL)
  SELECT
    cr.id AS request_id,
    cr.state,
    'technical_review'::text AS action_needed,
    cr.requested_size,
    cr.quantity,
    cr.region,
    cr.estimated_monthly_cost_usd,
    cr.customer_ref,
    cr.needed_by_date,
    cr.created_at,
    cr.next_deadline_at,
    CASE
      WHEN get_sla_threshold_hours(cr.state) IS NULL THEN NULL
      WHEN extract(epoch FROM now() - cr.updated_at) / 3600 >= get_sla_threshold_hours(cr.state) THEN 'breached'
      WHEN extract(epoch FROM now() - cr.updated_at) / 3600 >= get_sla_threshold_hours(cr.state) * 0.75 THEN 'at_risk'
      ELSE 'ok'
    END::text AS sla_status
  FROM capacity_requests cr
  WHERE cr.state = 'UNDER_REVIEW'
    AND cr.infra_owner_group = p_user_group
    AND cr.technical_approved_at IS NULL
    AND p_user_group IS NOT NULL

  UNION ALL

  -- 3. VP approval needed (high-cost requests only)
  SELECT
    cr.id AS request_id,
    cr.state,
    'vp_approval'::text AS action_needed,
    cr.requested_size,
    cr.quantity,
    cr.region,
    cr.estimated_monthly_cost_usd,
    cr.customer_ref,
    cr.needed_by_date,
    cr.created_at,
    cr.next_deadline_at,
    CASE
      WHEN get_sla_threshold_hours(cr.state) IS NULL THEN NULL
      WHEN extract(epoch FROM now() - cr.updated_at) / 3600 >= get_sla_threshold_hours(cr.state) THEN 'breached'
      WHEN extract(epoch FROM now() - cr.updated_at) / 3600 >= get_sla_threshold_hours(cr.state) * 0.75 THEN 'at_risk'
      ELSE 'ok'
    END::text AS sla_status
  FROM capacity_requests cr
  WHERE cr.state = 'UNDER_REVIEW'
    AND cr.vp_approver_user_id = p_user_id
    AND cr.vp_approved_at IS NULL
    AND cr.estimated_monthly_cost_usd IS NOT NULL
    AND cr.estimated_monthly_cost_usd >= get_escalation_threshold_usd()

  UNION ALL

  -- 4. Customer confirmation needed
  SELECT
    cr.id AS request_id,
    cr.state,
    'customer_confirmation'::text AS action_needed,
    cr.requested_size,
    cr.quantity,
    cr.region,
    cr.estimated_monthly_cost_usd,
    cr.customer_ref,
    cr.needed_by_date,
    cr.created_at,
    cr.next_deadline_at,
    CASE
      WHEN get_sla_threshold_hours(cr.state) IS NULL THEN NULL
      WHEN extract(epoch FROM now() - cr.updated_at) / 3600 >= get_sla_threshold_hours(cr.state) THEN 'breached'
      WHEN extract(epoch FROM now() - cr.updated_at) / 3600 >= get_sla_threshold_hours(cr.state) * 0.75 THEN 'at_risk'
      ELSE 'ok'
    END::text AS sla_status
  FROM capacity_requests cr
  WHERE cr.state = 'CUSTOMER_CONFIRMATION_REQUIRED'
    AND cr.requester_user_id = p_user_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

GRANT EXECUTE ON FUNCTION get_my_pending_actions TO authenticated;
