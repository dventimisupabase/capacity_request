-- Migration 5: Security & RLS
-- Row-Level Security policies and grants.
-- The projection table is writable only by the reducer (service role).
-- The events table is append-only via the reducer.

-- Enable RLS on both tables
ALTER TABLE capacity_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE capacity_request_events ENABLE ROW LEVEL SECURITY;

-- Revoke default write access from authenticated and anon roles.
-- Only the service role (used by SECURITY DEFINER functions) can write.
REVOKE INSERT, UPDATE, DELETE ON capacity_requests FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON capacity_request_events FROM authenticated, anon;

-- Grant read access so RLS policies can filter rows
GRANT SELECT ON capacity_requests TO authenticated;
GRANT SELECT ON capacity_request_events TO authenticated;

-- Grant execute on public API functions
GRANT EXECUTE ON FUNCTION create_capacity_request TO authenticated;
GRANT EXECUTE ON FUNCTION apply_capacity_event TO authenticated;
GRANT EXECUTE ON FUNCTION handle_slack_webhook TO authenticated;

-- RLS policies for capacity_requests
-- Requesters can read their own requests
CREATE POLICY requests_requester_read ON capacity_requests
  FOR SELECT
  TO authenticated
  USING (requester_user_id = current_setting('request.jwt.claims', true)::json->>'sub');

-- Commercial reviewers can read requests assigned to them
CREATE POLICY requests_commercial_read ON capacity_requests
  FOR SELECT
  TO authenticated
  USING (commercial_owner_user_id = current_setting('request.jwt.claims', true)::json->>'sub');

-- Infra reviewers can read requests assigned to their group
CREATE POLICY requests_infra_read ON capacity_requests
  FOR SELECT
  TO authenticated
  USING (infra_owner_group = current_setting('request.jwt.claims', true)::json->>'group');

-- Admins can read all requests (role claim = 'admin')
CREATE POLICY requests_admin_read ON capacity_requests
  FOR SELECT
  TO authenticated
  USING (current_setting('request.jwt.claims', true)::json->>'role' = 'admin');

-- Service role bypasses RLS (default Supabase behavior), but be explicit
CREATE POLICY requests_service_all ON capacity_requests
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- RLS policies for capacity_request_events
-- Users can read events for requests they can see (correlated subquery)
CREATE POLICY events_read ON capacity_request_events
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM capacity_requests cr
      WHERE cr.id = capacity_request_events.capacity_request_id
    )
  );

-- Service role can do everything on events
CREATE POLICY events_service_all ON capacity_request_events
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
