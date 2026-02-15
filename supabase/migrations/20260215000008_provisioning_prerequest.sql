-- Migration 11: Update Pre-Request Hook for Provisioning Webhook
-- Adds an IF block for /rpc/handle_provisioning_webhook that requires
-- the X-Provisioning-API-Key header. Existing Slack path unchanged.

CREATE OR REPLACE FUNCTION check_request() RETURNS void AS $$
DECLARE
  headers json := current_setting('request.headers', true)::json;
  path    text := current_setting('request.path', true);
  ts      text;
BEGIN
  -- Gate Slack webhook route
  IF path = '/rpc/handle_slack_webhook' THEN
    -- Require signature headers
    IF headers->>'x-slack-signature' IS NULL
       OR headers->>'x-slack-request-timestamp' IS NULL THEN
      RAISE EXCEPTION 'Missing Slack signature headers'
        USING HINT = 'Provide X-Slack-Signature and X-Slack-Request-Timestamp';
    END IF;

    -- Replay protection: reject if timestamp is > 5 minutes old
    ts := headers->>'x-slack-request-timestamp';
    IF abs(extract(epoch FROM now()) - ts::bigint) > 300 THEN
      RAISE EXCEPTION 'Slack request timestamp too old'
        USING HINT = 'Possible replay attack';
    END IF;
  END IF;

  -- Gate provisioning webhook route
  IF path = '/rpc/handle_provisioning_webhook' THEN
    IF headers->>'x-provisioning-api-key' IS NULL THEN
      RAISE EXCEPTION 'Missing provisioning API key header'
        USING HINT = 'Provide X-Provisioning-API-Key';
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;
