-- Migration 4: Side Effects & Webhooks
-- Vault helper, URL decoding, Slack notifications via pg_net,
-- Slack signature verification, webhook receiver, pre-request hook,
-- and updated reducer with side-effect dispatch.

-- Vault helper: retrieve decrypted secrets
CREATE FUNCTION get_secret(secret_name text) RETURNS text AS $$
  SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = secret_name LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;

-- URL decoding helper for form-encoded Slack payloads.
-- Handles %XX hex sequences and + -> space conversion.
CREATE FUNCTION url_decode(input text) RETURNS text AS $$
DECLARE
  result text := input;
  hex_match text[];
BEGIN
  -- Replace + with space first
  result := replace(result, '+', ' ');
  -- Replace %XX hex sequences
  WHILE result ~ '%[0-9a-fA-F]{2}' LOOP
    hex_match := regexp_match(result, '%([0-9a-fA-F]{2})');
    result := regexp_replace(
      result,
      '%' || hex_match[1],
      chr(('x' || hex_match[1])::bit(8)::int),
      'i'
    );
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Side-effect dispatch via pg_net (async HTTP).
-- Called by the reducer after projection update.
CREATE FUNCTION dispatch_side_effects(
  req         capacity_requests,
  old_state   capacity_request_state,
  new_state   capacity_request_state,
  event_type  capacity_request_event_type
) RETURNS void AS $$
DECLARE
  slack_token text := get_secret('SLACK_BOT_TOKEN');
BEGIN
  -- Skip if no Slack channel configured
  IF req.slack_channel_id IS NULL THEN
    RETURN;
  END IF;

  CASE new_state
    WHEN 'UNDER_REVIEW' THEN
      IF old_state = 'SUBMITTED' THEN
        -- New request: post initial Slack message
        PERFORM net.http_post(
          url     := 'https://slack.com/api/chat.postMessage',
          headers := jsonb_build_object(
            'Content-Type',  'application/json',
            'Authorization', 'Bearer ' || slack_token
          ),
          body    := jsonb_build_object(
            'channel', req.slack_channel_id,
            'text',    format('New capacity request %s: %s x %s in %s. Awaiting commercial and technical review.',
                              req.id, req.quantity, req.requested_size, req.region),
            'metadata', jsonb_build_object('event_type', 'capacity_request', 'event_payload', jsonb_build_object('cr_id', req.id))
          )
        );
      ELSE
        -- Approval recorded; update thread
        PERFORM net.http_post(
          url     := 'https://slack.com/api/chat.postMessage',
          headers := jsonb_build_object(
            'Content-Type',  'application/json',
            'Authorization', 'Bearer ' || slack_token
          ),
          body    := jsonb_build_object(
            'channel', req.slack_channel_id,
            'thread_ts', req.slack_thread_ts,
            'text',    format('%s recorded for %s. Commercial: %s | Technical: %s',
                              event_type, req.id,
                              CASE WHEN req.commercial_approved_at IS NOT NULL THEN 'approved' ELSE 'pending' END,
                              CASE WHEN req.technical_approved_at IS NOT NULL THEN 'approved' ELSE 'pending' END)
          )
        );
      END IF;

    WHEN 'CUSTOMER_CONFIRMATION_REQUIRED' THEN
      PERFORM net.http_post(
        url     := 'https://slack.com/api/chat.postMessage',
        headers := jsonb_build_object(
          'Content-Type',  'application/json',
          'Authorization', 'Bearer ' || slack_token
        ),
        body    := jsonb_build_object(
          'channel', req.slack_channel_id,
          'thread_ts', req.slack_thread_ts,
          'text',    format('%s approved. Customer confirmation required by %s.',
                            req.id, req.next_deadline_at::date)
        )
      );

    WHEN 'REJECTED' THEN
      PERFORM net.http_post(
        url     := 'https://slack.com/api/chat.postMessage',
        headers := jsonb_build_object(
          'Content-Type',  'application/json',
          'Authorization', 'Bearer ' || slack_token
        ),
        body    := jsonb_build_object(
          'channel', req.slack_channel_id,
          'thread_ts', req.slack_thread_ts,
          'text',    format('%s has been rejected (%s).', req.id, event_type)
        )
      );

    WHEN 'PROVISIONING' THEN
      PERFORM net.http_post(
        url     := 'https://slack.com/api/chat.postMessage',
        headers := jsonb_build_object(
          'Content-Type',  'application/json',
          'Authorization', 'Bearer ' || slack_token
        ),
        body    := jsonb_build_object(
          'channel', req.slack_channel_id,
          'thread_ts', req.slack_thread_ts,
          'text',    format('%s confirmed by customer. Provisioning started.', req.id)
        )
      );

    WHEN 'COMPLETED', 'CANCELLED', 'EXPIRED', 'FAILED' THEN
      PERFORM net.http_post(
        url     := 'https://slack.com/api/chat.postMessage',
        headers := jsonb_build_object(
          'Content-Type',  'application/json',
          'Authorization', 'Bearer ' || slack_token
        ),
        body    := jsonb_build_object(
          'channel', req.slack_channel_id,
          'thread_ts', req.slack_thread_ts,
          'text',    format('%s -> %s.', req.id, new_state)
        )
      );

    ELSE NULL;
  END CASE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Slack HMAC-SHA256 signature verification
CREATE FUNCTION verify_slack_signature(
  raw_body   text,
  timestamp_ text,
  signature  text
) RETURNS boolean AS $$
DECLARE
  signing_secret text;
  base_string    text;
  computed_sig   text;
BEGIN
  signing_secret := get_secret('SLACK_SIGNING_SECRET');
  base_string    := 'v0:' || timestamp_ || ':' || raw_body;
  computed_sig   := 'v0=' || encode(hmac(base_string, signing_secret, 'sha256'), 'hex');

  -- Compare via digest to avoid timing side-channels
  RETURN digest(computed_sig, 'sha256') = digest(signature, 'sha256');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Slack webhook receiver.
-- PostgREST routes POST /rpc/handle_slack_webhook with Content-Type: text/plain
-- to this function. The raw form-encoded body arrives as $1.
CREATE FUNCTION handle_slack_webhook(text) RETURNS json AS $$
DECLARE
  raw_body    text := $1;
  sig         text;
  ts          text;
  params      jsonb;
  payload     jsonb;
  action      text;
  user_id     text;
  channel_id  text;
  request_id  text;
  cmd_text    text;
  cmd_parts   text[];
  req         capacity_requests;
BEGIN
  -- Verify Slack request signature
  sig := current_setting('request.headers', true)::json->>'x-slack-signature';
  ts  := current_setting('request.headers', true)::json->>'x-slack-request-timestamp';

  IF NOT verify_slack_signature(raw_body, ts, sig) THEN
    RAISE EXCEPTION 'Invalid Slack signature';
  END IF;

  -- Parse form-encoded body into key-value pairs
  SELECT jsonb_object_agg(
    split_part(kv, '=', 1),
    url_decode(split_part(kv, '=', 2))
  ) INTO params
  FROM unnest(string_to_array(raw_body, '&')) AS kv;

  -- Route based on payload type
  IF params ? 'command' THEN
    user_id    := params->>'user_id';
    channel_id := params->>'channel_id';
    cmd_text   := trim(params->>'text');

    -- Parse: create <size> <region> <quantity> <duration_days> [customer_name]
    cmd_parts := string_to_array(cmd_text, ' ');

    IF cmd_parts[1] IS NULL OR cmd_parts[1] = '' THEN
      RETURN json_build_object(
        'response_type', 'ephemeral',
        'text', 'Usage: /capacity create <size> <region> <quantity> <duration_days> [customer_name]'
      );
    END IF;

    IF cmd_parts[1] = 'create' THEN
      -- Validate required arguments
      IF array_length(cmd_parts, 1) < 5 THEN
        RETURN json_build_object(
          'response_type', 'ephemeral',
          'text', 'Usage: /capacity create <size> <region> <quantity> <duration_days> [customer_name]'
            || E'\nExample: /capacity create 32XL us-east-1 2 90 Acme Corp'
        );
      END IF;

      req := create_capacity_request(
        p_requester_user_id         := user_id,
        p_commercial_owner_user_id  := NULL,
        p_infra_owner_group         := NULL,
        p_customer_ref              := jsonb_build_object(
          'name', CASE
            WHEN array_length(cmd_parts, 1) > 5
              THEN array_to_string(cmd_parts[6:], ' ')
            ELSE 'TBD'
          END
        ),
        p_requested_size            := cmd_parts[2],
        p_quantity                  := cmd_parts[4]::integer,
        p_region                    := cmd_parts[3],
        p_needed_by_date            := (current_date + (cmd_parts[5]::integer || ' days')::interval)::date,
        p_expected_duration_days    := cmd_parts[5]::integer,
        p_slack_channel_id          := channel_id
      );

      RETURN json_build_object(
        'response_type', 'in_channel',
        'text', format('Capacity request %s created: %s x %s in %s (%s days). State: %s',
                       req.id, req.quantity, req.requested_size, req.region,
                       req.expected_duration_days, req.state)
      );
    ELSE
      RETURN json_build_object(
        'response_type', 'ephemeral',
        'text', format('Unknown subcommand: %s. Try: /capacity create <size> <region> <quantity> <duration_days>', cmd_parts[1])
      );
    END IF;

  ELSIF params ? 'payload' THEN
    -- Interactive payload (button click)
    payload    := (params->>'payload')::jsonb;
    action     := payload->'actions'->0->>'action_id';
    user_id    := payload->'user'->>'id';
    request_id := payload->'actions'->0->>'value';

    -- Map action_id to event_type
    CASE action
      WHEN 'commercial_approve' THEN
        req := apply_capacity_event(request_id, 'COMMERCIAL_APPROVED', 'user', user_id);
      WHEN 'commercial_reject' THEN
        req := apply_capacity_event(request_id, 'COMMERCIAL_REJECTED', 'user', user_id);
      WHEN 'tech_approve' THEN
        req := apply_capacity_event(request_id, 'TECH_REVIEW_APPROVED', 'user', user_id);
      WHEN 'tech_reject' THEN
        req := apply_capacity_event(request_id, 'TECH_REVIEW_REJECTED', 'user', user_id);
      WHEN 'customer_confirm' THEN
        req := apply_capacity_event(request_id, 'CUSTOMER_CONFIRMED', 'user', user_id);
      WHEN 'customer_decline' THEN
        req := apply_capacity_event(request_id, 'CUSTOMER_DECLINED', 'user', user_id);
      WHEN 'cancel' THEN
        req := apply_capacity_event(request_id, 'CANCEL_APPROVED', 'user', user_id,
          json_build_object('reason', 'Cancelled via Slack')::jsonb);
      ELSE
        RETURN json_build_object('error', format('Unknown action: %s', action));
    END CASE;

    RETURN json_build_object('text', format('Event recorded for %s. New state: %s', request_id, req.state));
  END IF;

  RETURN json_build_object('error', 'Unknown payload type');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Pre-request hook: fast rejection of invalid Slack requests.
-- Runs before the main function; has access to headers but not body.
CREATE FUNCTION check_request() RETURNS void AS $$
DECLARE
  headers json := current_setting('request.headers', true)::json;
  path    text := current_setting('request.path', true);
  ts      text;
BEGIN
  -- Only gate Slack webhook routes
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
END;
$$ LANGUAGE plpgsql;

-- Configure PostgREST pre-request hook.
-- On hosted Supabase, set via Dashboard: Settings > API > Pre-request function: check_request
-- For local dev, set on the authenticator role:
ALTER ROLE authenticator SET pgrst.db_pre_request = 'check_request';
NOTIFY pgrst, 'reload config';

-- Update apply_capacity_event to dispatch side effects after projection update.
CREATE OR REPLACE FUNCTION apply_capacity_event(
  p_request_id  text,
  p_event_type  capacity_request_event_type,
  p_actor_type  capacity_request_actor_type,
  p_actor_id    text,
  p_payload     jsonb DEFAULT '{}'
) RETURNS capacity_requests AS $$
DECLARE
  req             capacity_requests;
  old_state       capacity_request_state;
  new_state       capacity_request_state;
  commercial_done boolean;
  technical_done  boolean;
BEGIN
  -- Lock the row for the duration of this transaction
  SELECT * INTO STRICT req
    FROM capacity_requests
    WHERE id = p_request_id
    FOR UPDATE;

  -- Capture old state for side-effect dispatch
  old_state := req.state;

  -- Compute approval flags AFTER this event is applied
  commercial_done := req.commercial_approved_at IS NOT NULL
                     OR p_event_type = 'COMMERCIAL_APPROVED';
  technical_done  := req.technical_approved_at IS NOT NULL
                     OR p_event_type = 'TECH_REVIEW_APPROVED';

  -- Pure transition logic
  new_state := compute_next_state(req.state, p_event_type, commercial_done, technical_done);

  -- Append event
  INSERT INTO capacity_request_events (capacity_request_id, event_type, actor_type, actor_id, payload)
    VALUES (p_request_id, p_event_type, p_actor_type, p_actor_id, p_payload);

  -- Update projection with optimistic concurrency check
  UPDATE capacity_requests SET
    state                = new_state,
    version              = version + 1,
    updated_at           = now(),
    commercial_approved_at = CASE
      WHEN p_event_type = 'COMMERCIAL_APPROVED' THEN now()
      ELSE commercial_approved_at
    END,
    technical_approved_at = CASE
      WHEN p_event_type = 'TECH_REVIEW_APPROVED' THEN now()
      ELSE technical_approved_at
    END,
    next_deadline_at     = CASE
      WHEN new_state = 'CUSTOMER_CONFIRMATION_REQUIRED'
        THEN now() + (confirmation_ttl_days || ' days')::interval
      ELSE NULL
    END,
    cancellation_reason  = CASE
      WHEN p_event_type = 'CANCEL_APPROVED' THEN p_payload->>'reason'
      ELSE cancellation_reason
    END,
    cancellation_authorizer_user_id = CASE
      WHEN p_event_type = 'CANCEL_APPROVED' THEN p_actor_id
      ELSE cancellation_authorizer_user_id
    END
  WHERE id = p_request_id AND version = req.version
  RETURNING * INTO STRICT req;

  -- Dispatch side effects (async via pg_net, enqueued in this transaction)
  PERFORM dispatch_side_effects(req, old_state, new_state, p_event_type);

  RETURN req;
END;
$$ LANGUAGE plpgsql;
