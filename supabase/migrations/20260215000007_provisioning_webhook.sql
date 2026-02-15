-- Migration 10: Provisioning Webhook
-- External provisioning systems POST status updates via this RPC.
-- Auth via API key in X-Provisioning-API-Key header, validated against Vault.
-- Mirrors handle_slack_webhook pattern: receives raw text body via PostgREST.

-- Verify the provisioning API key from the request header against Vault.
-- Uses constant-time digest comparison to avoid timing side-channels.
CREATE FUNCTION verify_provisioning_api_key() RETURNS boolean AS $$
DECLARE
  provided_key text;
  stored_key   text;
BEGIN
  provided_key := current_setting('request.headers', true)::json->>'x-provisioning-api-key';

  IF provided_key IS NULL OR provided_key = '' THEN
    RETURN false;
  END IF;

  stored_key := get_secret('PROVISIONING_WEBHOOK_SECRET');

  IF stored_key IS NULL THEN
    RETURN false;
  END IF;

  -- Constant-time comparison via digest
  RETURN digest(provided_key, 'sha256') = digest(stored_key, 'sha256');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Provisioning webhook receiver.
-- PostgREST routes POST /rpc/handle_provisioning_webhook with Content-Type: text/plain
-- to this function. The raw JSON body arrives as $1.
--
-- Expected body:
--   {"request_id": "CR-2026-000003", "status": "complete", "details": {...}}
--
-- Returns JSON:
--   Success: {"status": "ok", "request_id": "...", "new_state": "..."}
--   Error:   {"status": "error", "message": "..."}
--   Auth failures raise exceptions (HTTP 400 via PostgREST).
CREATE FUNCTION handle_provisioning_webhook(text) RETURNS json AS $$
DECLARE
  raw_body    text := $1;
  body        jsonb;
  v_request_id text;
  v_status    text;
  v_details   jsonb;
  v_event_type capacity_request_event_type;
  req         capacity_requests;
BEGIN
  -- Verify API key (auth failures raise exception -> HTTP 400)
  IF NOT verify_provisioning_api_key() THEN
    RAISE EXCEPTION 'Invalid provisioning API key';
  END IF;

  -- Parse JSON body
  BEGIN
    body := raw_body::jsonb;
  EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('status', 'error', 'message', 'Invalid JSON body');
  END;

  -- Extract fields
  v_request_id := body->>'request_id';
  v_status     := body->>'status';
  v_details    := COALESCE(body->'details', '{}'::jsonb);

  -- Validate request_id
  IF v_request_id IS NULL OR v_request_id = '' THEN
    RETURN json_build_object('status', 'error', 'message', 'Missing request_id');
  END IF;

  -- Map status to event type
  CASE v_status
    WHEN 'complete' THEN v_event_type := 'PROVISIONING_COMPLETE';
    WHEN 'failed'   THEN v_event_type := 'PROVISIONING_FAILED';
    ELSE
      RETURN json_build_object('status', 'error', 'message',
        format('Unknown status: %s. Expected "complete" or "failed".', v_status));
  END CASE;

  -- Look up the request
  SELECT * INTO req FROM capacity_requests WHERE id = v_request_id;
  IF NOT FOUND THEN
    RETURN json_build_object('status', 'error', 'message',
      format('Request %s not found', v_request_id));
  END IF;

  -- Validate state
  IF req.state != 'PROVISIONING' THEN
    RETURN json_build_object('status', 'error', 'message',
      format('Request %s is not in PROVISIONING state (current: %s)', v_request_id, req.state));
  END IF;

  -- Apply the event
  req := apply_capacity_event(
    v_request_id,
    v_event_type,
    'system',
    'provisioning_webhook',
    v_details
  );

  RETURN json_build_object(
    'status', 'ok',
    'request_id', req.id,
    'new_state', req.state
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grants: allow authenticated and service_role to call the webhook
GRANT EXECUTE ON FUNCTION handle_provisioning_webhook(text) TO authenticated, service_role;
