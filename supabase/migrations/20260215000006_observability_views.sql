-- Migration 9: Observability Views
-- SQL views for time-in-state, approval latency, request summary,
-- provisioning duration, and terminal state counts.

-- v_time_in_state: duration between consecutive events per request
CREATE VIEW v_time_in_state AS
SELECT
  capacity_request_id,
  event_type,
  created_at AS entered_at,
  lead(created_at) OVER w AS exited_at,
  lead(created_at) OVER w - created_at AS duration
FROM capacity_request_events
WINDOW w AS (PARTITION BY capacity_request_id ORDER BY created_at);

-- v_approval_latency: time from UNDER_REVIEW entry to each approval
CREATE VIEW v_approval_latency AS
SELECT
  cr.id AS capacity_request_id,
  submitted.created_at AS review_started_at,
  commercial.created_at AS commercial_approved_at,
  technical.created_at AS technical_approved_at,
  vp.created_at AS vp_approved_at,
  commercial.created_at - submitted.created_at AS commercial_latency,
  technical.created_at - submitted.created_at AS technical_latency,
  vp.created_at - submitted.created_at AS vp_latency,
  GREATEST(
    COALESCE(commercial.created_at, submitted.created_at),
    COALESCE(technical.created_at, submitted.created_at),
    COALESCE(vp.created_at, submitted.created_at)
  ) - submitted.created_at AS total_approval_latency
FROM capacity_requests cr
JOIN capacity_request_events submitted
  ON submitted.capacity_request_id = cr.id
  AND submitted.event_type = 'REQUEST_SUBMITTED'
LEFT JOIN capacity_request_events commercial
  ON commercial.capacity_request_id = cr.id
  AND commercial.event_type = 'COMMERCIAL_APPROVED'
LEFT JOIN capacity_request_events technical
  ON technical.capacity_request_id = cr.id
  AND technical.event_type = 'TECH_REVIEW_APPROVED'
LEFT JOIN capacity_request_events vp
  ON vp.capacity_request_id = cr.id
  AND vp.event_type = 'VP_APPROVED';

-- v_request_summary: one row per request with key metrics
CREATE VIEW v_request_summary AS
SELECT
  cr.id,
  cr.state,
  cr.created_at,
  cr.updated_at,
  cr.estimated_monthly_cost_usd,
  cr.region,
  cr.requested_size,
  cr.quantity,
  (SELECT count(*) FROM capacity_request_events e WHERE e.capacity_request_id = cr.id) AS total_events,
  now() - cr.created_at AS time_since_creation,
  cr.commercial_approved_at - cr.created_at AS commercial_approval_latency,
  cr.technical_approved_at - cr.created_at AS technical_approval_latency,
  cr.estimated_monthly_cost_usd IS NOT NULL
    AND cr.estimated_monthly_cost_usd >= get_escalation_threshold_usd() AS escalation_required,
  cr.vp_approved_at IS NOT NULL AS vp_approved,
  cr.vp_approved_at - cr.created_at AS vp_approval_latency,
  cr.state IN ('COMPLETED', 'REJECTED', 'CANCELLED', 'EXPIRED', 'FAILED') AS is_terminal,
  cr.updated_at - cr.created_at AS total_duration
FROM capacity_requests cr;

-- v_provisioning_duration: time from PROVISIONING entry to terminal
CREATE VIEW v_provisioning_duration AS
SELECT
  cr.id AS capacity_request_id,
  confirmed.created_at AS provisioning_started_at,
  terminal.created_at AS provisioning_ended_at,
  terminal.event_type AS terminal_event,
  terminal.created_at - confirmed.created_at AS provisioning_duration
FROM capacity_requests cr
JOIN capacity_request_events confirmed
  ON confirmed.capacity_request_id = cr.id
  AND confirmed.event_type = 'CUSTOMER_CONFIRMED'
LEFT JOIN capacity_request_events terminal
  ON terminal.capacity_request_id = cr.id
  AND terminal.event_type IN ('PROVISIONING_COMPLETE', 'PROVISIONING_FAILED');

-- v_terminal_state_counts: aggregated counts by terminal state
CREATE VIEW v_terminal_state_counts AS
SELECT
  state,
  count(*) AS request_count
FROM capacity_requests
WHERE state IN ('COMPLETED', 'REJECTED', 'CANCELLED', 'EXPIRED', 'FAILED')
GROUP BY state;

-- Grant SELECT on all views to authenticated
GRANT SELECT ON v_time_in_state TO authenticated;
GRANT SELECT ON v_approval_latency TO authenticated;
GRANT SELECT ON v_request_summary TO authenticated;
GRANT SELECT ON v_provisioning_duration TO authenticated;
GRANT SELECT ON v_terminal_state_counts TO authenticated;
