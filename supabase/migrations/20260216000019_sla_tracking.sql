-- Migration 19: SLA Tracking Views
-- Adds get_sla_threshold_hours() helper and v_sla_status view for
-- monitoring SLA compliance of active capacity requests.

-- 1. SLA threshold helper (configurable via Vault, with sensible defaults)
CREATE FUNCTION get_sla_threshold_hours(p_state capacity_request_state) RETURNS numeric AS $$
BEGIN
  CASE p_state
    WHEN 'UNDER_REVIEW' THEN
      RETURN COALESCE(get_secret('SLA_UNDER_REVIEW_HOURS')::numeric, 48);
    WHEN 'CUSTOMER_CONFIRMATION_REQUIRED' THEN
      RETURN COALESCE(get_secret('SLA_CONFIRMATION_HOURS')::numeric, 72);
    WHEN 'PROVISIONING' THEN
      RETURN COALESCE(get_secret('SLA_PROVISIONING_HOURS')::numeric, 24);
    ELSE
      RETURN NULL;
  END CASE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- 2. v_sla_status view — shows SLA compliance for active requests
CREATE VIEW v_sla_status WITH (security_invoker = true) AS
SELECT
  cr.id,
  cr.state,
  cr.updated_at AS state_entered_at,
  now() - cr.updated_at AS time_in_current_state,
  get_sla_threshold_hours(cr.state) AS sla_threshold_hours,
  CASE
    WHEN get_sla_threshold_hours(cr.state) IS NULL THEN NULL
    WHEN extract(epoch FROM now() - cr.updated_at) / 3600 >= get_sla_threshold_hours(cr.state) THEN 'breached'
    WHEN extract(epoch FROM now() - cr.updated_at) / 3600 >= get_sla_threshold_hours(cr.state) * 0.75 THEN 'at_risk'
    ELSE 'ok'
  END::text AS sla_status,
  cr.region,
  cr.requested_size,
  cr.quantity,
  cr.estimated_monthly_cost_usd,
  cr.requester_user_id,
  cr.commercial_owner_user_id,
  cr.infra_owner_group,
  cr.vp_approver_user_id
FROM capacity_requests cr
WHERE cr.state NOT IN ('COMPLETED', 'REJECTED', 'CANCELLED', 'EXPIRED', 'FAILED');

GRANT SELECT ON v_sla_status TO authenticated;
