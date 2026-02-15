-- Migration: Suppress outbox for Slack interactive actions
-- When a button click triggers a state transition via handle_slack_webhook,
-- the response_url already sends the updated Block Kit. The outbox would
-- create a duplicate message. Use a session variable to suppress it.

-- Update dispatch_side_effects to check for suppression flag
CREATE OR REPLACE FUNCTION dispatch_side_effects(
  req         capacity_requests,
  old_state   capacity_request_state,
  new_state   capacity_request_state,
  event_type  capacity_request_event_type
) RETURNS void AS $$
DECLARE
  slack_payload jsonb;
  latest_event_id uuid;
BEGIN
  -- Skip if no Slack channel configured
  IF req.slack_channel_id IS NULL THEN
    RETURN;
  END IF;

  -- Skip if suppressed (e.g., during Slack interactive actions where
  -- the response_url already handles the message update)
  IF current_setting('app.suppress_outbox', true) = 'true' THEN
    RETURN;
  END IF;

  -- Get the latest event ID for this request (the one just inserted)
  SELECT id INTO latest_event_id
  FROM capacity_request_events
  WHERE capacity_request_id = req.id
  ORDER BY created_at DESC
  LIMIT 1;

  -- Build Block Kit payload
  slack_payload := build_block_kit_message(req, old_state, new_state, event_type);

  -- Enqueue to outbox if we built a payload
  IF slack_payload IS NOT NULL THEN
    PERFORM enqueue_outbox(req.id, latest_event_id, 'slack', slack_payload);
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update handle_slack_webhook to suppress outbox during interactive actions
CREATE OR REPLACE FUNCTION handle_slack_webhook(text) RETURNS json AS $$
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
  old_state   capacity_request_state;
  applied_event_type capacity_request_event_type;
  kit         jsonb;
  list_text   text;
  list_row    record;
  help_text   text;
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

  -- Help text used by help subcommand and empty input
  help_text := '*Available commands:*'
    || E'\n• `/capacity create <size> <region> <quantity> <duration_days> [customer]` — Create a request'
    || E'\n• `/capacity list` — List your recent requests'
    || E'\n• `/capacity view <id>` — View request details with actions'
    || E'\n• `/capacity help` — Show this help message'
    || E'\n\nOr just type `/capacity` with no arguments to open the creation form.';

  -- Route based on payload type
  IF params ? 'command' THEN
    user_id    := params->>'user_id';
    channel_id := params->>'channel_id';
    cmd_text   := trim(params->>'text');
    cmd_parts  := string_to_array(cmd_text, ' ');

    -- Empty input or 'help' -> help text
    IF cmd_parts[1] IS NULL OR cmd_parts[1] = '' OR cmd_parts[1] = 'help' THEN
      RETURN json_build_object(
        'response_type', 'ephemeral',
        'text', help_text
      );
    END IF;

    -- /capacity list
    IF cmd_parts[1] = 'list' THEN
      list_text := '*Your recent capacity requests:*' || E'\n';
      FOR list_row IN
        SELECT id, state, requested_size, quantity, region, created_at::date AS created_date
        FROM capacity_requests
        WHERE requester_user_id = user_id
        ORDER BY created_at DESC
        LIMIT 10
      LOOP
        list_text := list_text || format(E'\n`%s` | %s | %s x %s | %s | %s',
          list_row.id, list_row.state, list_row.quantity, list_row.requested_size,
          list_row.region, list_row.created_date);
      END LOOP;

      IF NOT FOUND THEN
        list_text := 'You have no capacity requests.';
      END IF;

      RETURN json_build_object(
        'response_type', 'ephemeral',
        'text', list_text
      );
    END IF;

    -- /capacity view <id>
    IF cmd_parts[1] = 'view' THEN
      IF cmd_parts[2] IS NULL OR cmd_parts[2] = '' THEN
        RETURN json_build_object(
          'response_type', 'ephemeral',
          'text', 'Usage: /capacity view <request_id>' || E'\nExample: /capacity view CR-2026-000001'
        );
      END IF;

      SELECT * INTO req FROM capacity_requests WHERE id = cmd_parts[2];

      IF req IS NULL THEN
        RETURN json_build_object(
          'response_type', 'ephemeral',
          'text', format('Request %s not found.', cmd_parts[2])
        );
      END IF;

      -- Build Block Kit with NULL event_type (view mode, no context line)
      kit := build_block_kit_message(req, req.state, req.state, NULL);

      IF kit IS NULL THEN
        RETURN json_build_object(
          'response_type', 'ephemeral',
          'text', format('%s — %s | %s x %s in %s', req.id, req.state,
                         req.quantity, req.requested_size, req.region)
        );
      END IF;

      RETURN json_build_object(
        'response_type', 'ephemeral',
        'text', format('Capacity Request %s', req.id),
        'blocks', kit->'blocks'
      );
    END IF;

    -- /capacity create <size> <region> <quantity> <duration_days> [customer_name]
    IF cmd_parts[1] = 'create' THEN
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
    END IF;

    -- Unknown subcommand -> help
    RETURN json_build_object(
      'response_type', 'ephemeral',
      'text', format('Unknown subcommand: %s', cmd_parts[1]) || E'\n\n' || help_text
    );

  ELSIF params ? 'payload' THEN
    -- Interactive payload (button click)
    payload    := (params->>'payload')::jsonb;
    action     := payload->'actions'->0->>'action_id';
    user_id    := payload->'user'->>'id';
    request_id := payload->'actions'->0->>'value';

    -- Capture old state for Block Kit response
    SELECT * INTO req FROM capacity_requests WHERE id = request_id;
    old_state := req.state;

    -- Suppress outbox for interactive actions (response_url handles the update)
    PERFORM set_config('app.suppress_outbox', 'true', true);

    -- Map action_id to event_type and apply
    CASE action
      WHEN 'commercial_approve' THEN
        applied_event_type := 'COMMERCIAL_APPROVED';
        req := apply_capacity_event(request_id, 'COMMERCIAL_APPROVED', 'user', user_id);
      WHEN 'commercial_reject' THEN
        applied_event_type := 'COMMERCIAL_REJECTED';
        req := apply_capacity_event(request_id, 'COMMERCIAL_REJECTED', 'user', user_id);
      WHEN 'tech_approve' THEN
        applied_event_type := 'TECH_REVIEW_APPROVED';
        req := apply_capacity_event(request_id, 'TECH_REVIEW_APPROVED', 'user', user_id);
      WHEN 'tech_reject' THEN
        applied_event_type := 'TECH_REVIEW_REJECTED';
        req := apply_capacity_event(request_id, 'TECH_REVIEW_REJECTED', 'user', user_id);
      WHEN 'customer_confirm' THEN
        applied_event_type := 'CUSTOMER_CONFIRMED';
        req := apply_capacity_event(request_id, 'CUSTOMER_CONFIRMED', 'user', user_id);
      WHEN 'customer_decline' THEN
        applied_event_type := 'CUSTOMER_DECLINED';
        req := apply_capacity_event(request_id, 'CUSTOMER_DECLINED', 'user', user_id);
      WHEN 'vp_approve' THEN
        applied_event_type := 'VP_APPROVED';
        req := apply_capacity_event(request_id, 'VP_APPROVED', 'user', user_id);
      WHEN 'vp_reject' THEN
        applied_event_type := 'VP_REJECTED';
        req := apply_capacity_event(request_id, 'VP_REJECTED', 'user', user_id);
      WHEN 'cancel' THEN
        applied_event_type := 'CANCEL_APPROVED';
        req := apply_capacity_event(request_id, 'CANCEL_APPROVED', 'user', user_id,
          json_build_object('reason', 'Cancelled via Slack')::jsonb);
      ELSE
        RETURN json_build_object('error', format('Unknown action: %s', action));
    END CASE;

    -- Clear suppression
    PERFORM set_config('app.suppress_outbox', '', true);

    -- Re-read request for updated state
    SELECT * INTO req FROM capacity_requests WHERE id = request_id;

    -- Build rich Block Kit response that replaces the original message
    kit := build_block_kit_message(req, old_state, req.state, applied_event_type, user_id);

    RETURN json_build_object(
      'replace_original', true,
      'text', format('%s updated to %s', request_id, req.state),
      'blocks', COALESCE(kit->'blocks', '[]'::jsonb)
    );
  END IF;

  RETURN json_build_object('error', 'Unknown payload type');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
