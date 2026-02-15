-- Create a detail view with all fields needed by the web detail page.
-- Views bypass RLS (they run as the view owner), so authenticated users
-- can see all requests through this view.
CREATE VIEW v_request_detail AS
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

GRANT SELECT ON v_request_detail TO anon, authenticated;

-- Also grant anon access to v_request_summary (dashboard works without login)
GRANT SELECT ON v_request_summary TO anon;

-- Create a view for events so the detail page can load the timeline
CREATE VIEW v_request_events AS
SELECT
  e.id,
  e.capacity_request_id,
  e.event_type,
  e.actor_type,
  e.actor_id,
  e.payload,
  e.created_at
FROM capacity_request_events e;

GRANT SELECT ON v_request_events TO anon, authenticated;
