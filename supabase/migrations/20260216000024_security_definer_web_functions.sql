-- Migration: Add SECURITY DEFINER to web-facing RPC functions
--
-- apply_capacity_event and create_capacity_request are called from the web UI
-- via the authenticated role. Without SECURITY DEFINER they run as the calling
-- user, who lacks direct INSERT/UPDATE on capacity_requests (by design — RLS
-- blocks writes for the authenticated role). Adding SECURITY DEFINER lets these
-- functions execute with the owner's (postgres) privileges, matching the pattern
-- used by all other write-path functions (slash commands, webhooks, outbox).

ALTER FUNCTION apply_capacity_event(text, capacity_request_event_type, capacity_request_actor_type, text, jsonb, text, text)
  SECURITY DEFINER;

ALTER FUNCTION create_capacity_request(text, text, text, jsonb, text, integer, text, date, integer, numeric, integer, text, text)
  SECURITY DEFINER;
