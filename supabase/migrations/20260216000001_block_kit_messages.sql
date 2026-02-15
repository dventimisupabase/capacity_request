-- Migration 12: Block Kit Messages + VP Actions + Rich Button Responses
-- Centralizes Slack message formatting into build_block_kit_message(),
-- adds VP approve/reject interactive actions, rewrites dispatch_side_effects()
-- to use Block Kit, and makes button click responses replace the original message.

-- Pure function: builds a complete Slack Block Kit payload for a capacity request.
-- Returns NULL if no Slack channel is configured.
CREATE FUNCTION build_block_kit_message(
  req         capacity_requests,
  old_state   capacity_request_state,
  new_state   capacity_request_state,
  event_type  capacity_request_event_type,
  p_actor_id  text DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
  blocks       jsonb := '[]'::jsonb;
  actions      jsonb := '[]'::jsonb;
  fields       jsonb := '[]'::jsonb;
  detail_lines text[];
  context_text text;
  fallback     text;
  vp_required  boolean;
  result       jsonb;
BEGIN
  IF req.slack_channel_id IS NULL THEN
    RETURN NULL;
  END IF;

  -- Header block
  blocks := blocks || jsonb_build_array(jsonb_build_object(
    'type', 'header',
    'text', jsonb_build_object(
      'type', 'plain_text',
      'text', format('Capacity Request %s', req.id)
    )
  ));

  -- Fields section: State, Size, Region, Quantity, Duration, Est. Cost
  fields := jsonb_build_array(
    jsonb_build_object('type', 'mrkdwn', 'text', format('*State:* %s', new_state)),
    jsonb_build_object('type', 'mrkdwn', 'text', format('*Size:* %s', COALESCE(req.requested_size, 'N/A'))),
    jsonb_build_object('type', 'mrkdwn', 'text', format('*Region:* %s', COALESCE(req.region, 'N/A'))),
    jsonb_build_object('type', 'mrkdwn', 'text', format('*Quantity:* %s', COALESCE(req.quantity::text, 'N/A'))),
    jsonb_build_object('type', 'mrkdwn', 'text', format('*Duration:* %s days', COALESCE(req.expected_duration_days::text, 'N/A'))),
    jsonb_build_object('type', 'mrkdwn', 'text', format('*Est. Cost:* $%s/mo', COALESCE(req.estimated_monthly_cost_usd::text, 'N/A')))
  );

  blocks := blocks || jsonb_build_array(jsonb_build_object(
    'type', 'section',
    'fields', fields
  ));

  -- Detail section: Customer, Needed By, approval statuses
  detail_lines := ARRAY[
    format('*Customer:* %s', COALESCE(req.customer_ref->>'name', 'TBD')),
    format('*Needed By:* %s', COALESCE(req.needed_by_date::text, 'N/A')),
    format('*Commercial:* %s', CASE WHEN req.commercial_approved_at IS NOT NULL THEN 'Approved' ELSE 'Pending' END),
    format('*Technical:* %s', CASE WHEN req.technical_approved_at IS NOT NULL THEN 'Approved' ELSE 'Pending' END)
  ];

  -- VP status if escalated
  vp_required := req.estimated_monthly_cost_usd IS NOT NULL
                 AND req.estimated_monthly_cost_usd >= get_escalation_threshold_usd();
  IF vp_required THEN
    detail_lines := detail_lines || format('*VP Approval:* %s',
      CASE WHEN req.vp_approved_at IS NOT NULL THEN 'Approved' ELSE 'Required — Pending' END);
  END IF;

  blocks := blocks || jsonb_build_array(jsonb_build_object(
    'type', 'section',
    'text', jsonb_build_object(
      'type', 'mrkdwn',
      'text', array_to_string(detail_lines, E'\n')
    )
  ));

  -- Context block: who acted and when (omitted when event_type is NULL, i.e. /capacity view)
  IF event_type IS NOT NULL THEN
    context_text := format('%s by %s at %s',
      event_type,
      COALESCE(p_actor_id, 'system'),
      to_char(now(), 'YYYY-MM-DD HH24:MI:SS TZ')
    );
    blocks := blocks || jsonb_build_array(jsonb_build_object(
      'type', 'context',
      'elements', jsonb_build_array(jsonb_build_object(
        'type', 'mrkdwn',
        'text', context_text
      ))
    ));
  END IF;

  -- Divider
  blocks := blocks || jsonb_build_array(jsonb_build_object('type', 'divider'));

  -- Actions: contextual buttons based on new_state
  CASE new_state
    WHEN 'UNDER_REVIEW' THEN
      actions := jsonb_build_array(
        jsonb_build_object('type', 'button', 'text', jsonb_build_object('type', 'plain_text', 'text', 'Commercial Approve'), 'action_id', 'commercial_approve', 'value', req.id, 'style', 'primary'),
        jsonb_build_object('type', 'button', 'text', jsonb_build_object('type', 'plain_text', 'text', 'Commercial Reject'),  'action_id', 'commercial_reject',  'value', req.id, 'style', 'danger'),
        jsonb_build_object('type', 'button', 'text', jsonb_build_object('type', 'plain_text', 'text', 'Tech Approve'),       'action_id', 'tech_approve',       'value', req.id, 'style', 'primary'),
        jsonb_build_object('type', 'button', 'text', jsonb_build_object('type', 'plain_text', 'text', 'Tech Reject'),        'action_id', 'tech_reject',        'value', req.id, 'style', 'danger'),
        jsonb_build_object('type', 'button', 'text', jsonb_build_object('type', 'plain_text', 'text', 'Cancel'),             'action_id', 'cancel',             'value', req.id)
      );
      -- Add VP buttons if escalation required
      IF vp_required THEN
        actions := actions || jsonb_build_array(
          jsonb_build_object('type', 'button', 'text', jsonb_build_object('type', 'plain_text', 'text', 'VP Approve'), 'action_id', 'vp_approve', 'value', req.id, 'style', 'primary'),
          jsonb_build_object('type', 'button', 'text', jsonb_build_object('type', 'plain_text', 'text', 'VP Reject'),  'action_id', 'vp_reject',  'value', req.id, 'style', 'danger')
        );
      END IF;

    WHEN 'CUSTOMER_CONFIRMATION_REQUIRED' THEN
      actions := jsonb_build_array(
        jsonb_build_object('type', 'button', 'text', jsonb_build_object('type', 'plain_text', 'text', 'Confirm'),  'action_id', 'customer_confirm', 'value', req.id, 'style', 'primary'),
        jsonb_build_object('type', 'button', 'text', jsonb_build_object('type', 'plain_text', 'text', 'Decline'),  'action_id', 'customer_decline', 'value', req.id, 'style', 'danger'),
        jsonb_build_object('type', 'button', 'text', jsonb_build_object('type', 'plain_text', 'text', 'Cancel'),   'action_id', 'cancel',           'value', req.id)
      );

    WHEN 'PROVISIONING' THEN
      actions := jsonb_build_array(
        jsonb_build_object('type', 'button', 'text', jsonb_build_object('type', 'plain_text', 'text', 'Cancel'), 'action_id', 'cancel', 'value', req.id)
      );

    ELSE
      -- Terminal states or SUBMITTED: no actions
      actions := '[]'::jsonb;
  END CASE;

  -- Append actions block only if there are actions
  IF jsonb_array_length(actions) > 0 THEN
    blocks := blocks || jsonb_build_array(jsonb_build_object(
      'type', 'actions',
      'elements', actions
    ));
  END IF;

  -- Fallback text for notifications
  fallback := format('Capacity Request %s — %s', req.id, new_state);

  -- Build final result
  result := jsonb_build_object(
    'channel', req.slack_channel_id,
    'text', fallback,
    'blocks', blocks
  );

  -- Add thread_ts if available
  IF req.slack_thread_ts IS NOT NULL THEN
    result := result || jsonb_build_object('thread_ts', req.slack_thread_ts);
  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql STABLE;

-- Rewrite dispatch_side_effects to use build_block_kit_message
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

-- Update handle_slack_webhook to add VP actions and rich button responses
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

    -- Capture old state for Block Kit response
    SELECT * INTO req FROM capacity_requests WHERE id = request_id;
    old_state := req.state;

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
