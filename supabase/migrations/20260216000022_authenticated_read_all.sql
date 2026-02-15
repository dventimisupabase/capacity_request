-- Migration 22: Allow all authenticated users to read all requests and events.
-- The existing RLS policies restrict reads to specific roles (requester, commercial
-- owner, infra group, admin). With security_invoker views from migration 16, this
-- means the web UI (ops console) can't show requests to general authenticated users.
-- This migration adds a permissive policy so any signed-in user can see everything,
-- which is the correct behavior for an internal ops console.

-- All authenticated users can read all capacity requests
CREATE POLICY requests_authenticated_read_all ON capacity_requests
  FOR SELECT
  TO authenticated
  USING (true);

-- All authenticated users can read all events
CREATE POLICY events_authenticated_read_all ON capacity_request_events
  FOR SELECT
  TO authenticated
  USING (true);
