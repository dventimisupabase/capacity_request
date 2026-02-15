-- Migration 16: Tighten View RLS + Signed Confirmation Token
-- Recreates all views with security_invoker = true (Postgres 15+).
-- Removes anon grants — dashboard now requires sign-in.
-- Adds signed HMAC token functions for anon confirmation access.

-- ============================================================
-- Part 1: Recreate all views with security_invoker = true
-- ============================================================

-- Drop views in dependency order (detail/events first, then observability)
DROP VIEW IF EXISTS v_request_events;
DROP VIEW IF EXISTS v_request_detail;
DROP VIEW IF EXISTS v_request_summary;
DROP VIEW IF EXISTS v_time_in_state;
DROP VIEW IF EXISTS v_approval_latency;
DROP VIEW IF EXISTS v_provisioning_duration;
DROP VIEW IF EXISTS v_terminal_state_counts;

-- v_request_events (from migration 15, includes notes column)
CREATE VIEW v_request_events WITH (security_invoker = true) AS
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

GRANT SELECT ON v_request_events TO authenticated;

-- v_request_detail (from migration 13)
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
  cr.next_deadline_at,
  cr.version,
  cr.created_at,
  cr.updated_at,
  cr.slack_channel_id,
  cr.slack_thread_ts
FROM capacity_requests cr;

GRANT SELECT ON v_request_detail TO authenticated;

-- v_request_summary (from migration 9, uses get_escalation_threshold_usd())
CREATE VIEW v_request_summary WITH (security_invoker = true) AS
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

GRANT SELECT ON v_request_summary TO authenticated;

-- v_time_in_state (from migration 9)
CREATE VIEW v_time_in_state WITH (security_invoker = true) AS
SELECT
  capacity_request_id,
  event_type,
  created_at AS entered_at,
  lead(created_at) OVER w AS exited_at,
  lead(created_at) OVER w - created_at AS duration
FROM capacity_request_events
WINDOW w AS (PARTITION BY capacity_request_id ORDER BY created_at);

GRANT SELECT ON v_time_in_state TO authenticated;

-- v_approval_latency (from migration 9)
CREATE VIEW v_approval_latency WITH (security_invoker = true) AS
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

GRANT SELECT ON v_approval_latency TO authenticated;

-- v_provisioning_duration (from migration 9)
CREATE VIEW v_provisioning_duration WITH (security_invoker = true) AS
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

GRANT SELECT ON v_provisioning_duration TO authenticated;

-- v_terminal_state_counts (from migration 9)
CREATE VIEW v_terminal_state_counts WITH (security_invoker = true) AS
SELECT
  state,
  count(*) AS request_count
FROM capacity_requests
WHERE state IN ('COMPLETED', 'REJECTED', 'CANCELLED', 'EXPIRED', 'FAILED')
GROUP BY state;

GRANT SELECT ON v_terminal_state_counts TO authenticated;

-- ============================================================
-- Part 2: Signed token functions for anon confirmation
-- ============================================================

-- generate_confirmation_token: creates an HMAC-signed token for a request
-- Called by service_role (side-effect dispatch) to embed in confirmation URLs.
CREATE FUNCTION generate_confirmation_token(
  p_request_id  text,
  p_expires_at  timestamptz
) RETURNS text AS $$
DECLARE
  secret text;
  payload text;
BEGIN
  secret := get_secret('CONFIRMATION_TOKEN_SECRET');
  IF secret IS NULL THEN
    RAISE EXCEPTION 'CONFIRMATION_TOKEN_SECRET not configured in Vault';
  END IF;

  payload := p_request_id || '|' || extract(epoch FROM p_expires_at)::bigint::text;
  RETURN encode(hmac(payload, secret, 'sha256'), 'hex');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION generate_confirmation_token TO service_role;

-- get_confirmation_request: validates token and returns request data for confirm page.
-- SECURITY DEFINER to bypass RLS and read Vault.
CREATE FUNCTION get_confirmation_request(
  p_request_id  text,
  p_token       text,
  p_expires_at  bigint
) RETURNS jsonb AS $$
DECLARE
  secret text;
  payload text;
  expected_token text;
  req capacity_requests;
BEGIN
  -- Check expiry
  IF p_expires_at < extract(epoch FROM now())::bigint THEN
    RAISE EXCEPTION 'Confirmation token has expired';
  END IF;

  -- Validate HMAC
  secret := get_secret('CONFIRMATION_TOKEN_SECRET');
  IF secret IS NULL THEN
    RAISE EXCEPTION 'CONFIRMATION_TOKEN_SECRET not configured in Vault';
  END IF;

  payload := p_request_id || '|' || p_expires_at::text;
  expected_token := encode(hmac(payload, secret, 'sha256'), 'hex');

  IF p_token != expected_token THEN
    RAISE EXCEPTION 'Invalid confirmation token';
  END IF;

  -- Fetch request
  SELECT * INTO req FROM capacity_requests WHERE id = p_request_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Request % not found', p_request_id;
  END IF;

  -- Return only fields needed by confirm.html
  RETURN jsonb_build_object(
    'id', req.id,
    'state', req.state,
    'requested_size', req.requested_size,
    'region', req.region,
    'quantity', req.quantity,
    'estimated_monthly_cost_usd', req.estimated_monthly_cost_usd,
    'needed_by_date', req.needed_by_date,
    'next_deadline_at', req.next_deadline_at,
    'customer_ref', req.customer_ref
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_confirmation_request TO anon, authenticated;
