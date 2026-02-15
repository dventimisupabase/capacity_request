-- Update handle_slack_webhook to parse slash commands and create requests.
-- Format: /capacity create <size> <region> <quantity> <duration_days> [customer_name]
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
