-- Drop the old create_capacity_request overload (without p_slack_channel_id).
-- Migration 20260215000001 used CREATE OR REPLACE with a new parameter, which
-- created a second overload rather than replacing the original from migration 3.
-- This is a no-op on fresh databases (supabase db reset) but fixes deployed ones.
DROP FUNCTION IF EXISTS create_capacity_request(text, text, text, jsonb, text, integer, text, date, integer, numeric, integer);
