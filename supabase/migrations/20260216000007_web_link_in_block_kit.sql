-- Migration: Add "View in Web" link button to Block Kit messages
-- Reads WEB_APP_BASE_URL from Vault. If not set, the button is omitted.

CREATE OR REPLACE FUNCTION build_block_kit_message(
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
  web_base_url text;
BEGIN
  IF req.slack_channel_id IS NULL THEN
    RETURN NULL;
  END IF;

  -- Read web app base URL from Vault (NULL if not configured)
  web_base_url := get_secret('WEB_APP_BASE_URL');

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

  -- Actions: contextual buttons based on new_state AND approval flags
  CASE new_state
    WHEN 'UNDER_REVIEW' THEN
      -- Only show Commercial buttons if not yet approved
      IF req.commercial_approved_at IS NULL THEN
        actions := actions || jsonb_build_array(
          jsonb_build_object('type', 'button', 'text', jsonb_build_object('type', 'plain_text', 'text', 'Commercial Approve'), 'action_id', 'commercial_approve', 'value', req.id, 'style', 'primary'),
          jsonb_build_object('type', 'button', 'text', jsonb_build_object('type', 'plain_text', 'text', 'Commercial Reject'),  'action_id', 'commercial_reject',  'value', req.id, 'style', 'danger')
        );
      END IF;

      -- Only show Tech buttons if not yet approved
      IF req.technical_approved_at IS NULL THEN
        actions := actions || jsonb_build_array(
          jsonb_build_object('type', 'button', 'text', jsonb_build_object('type', 'plain_text', 'text', 'Tech Approve'), 'action_id', 'tech_approve', 'value', req.id, 'style', 'primary'),
          jsonb_build_object('type', 'button', 'text', jsonb_build_object('type', 'plain_text', 'text', 'Tech Reject'),  'action_id', 'tech_reject',  'value', req.id, 'style', 'danger')
        );
      END IF;

      -- Only show VP buttons if escalation required and not yet approved
      IF vp_required AND req.vp_approved_at IS NULL THEN
        actions := actions || jsonb_build_array(
          jsonb_build_object('type', 'button', 'text', jsonb_build_object('type', 'plain_text', 'text', 'VP Approve'), 'action_id', 'vp_approve', 'value', req.id, 'style', 'primary'),
          jsonb_build_object('type', 'button', 'text', jsonb_build_object('type', 'plain_text', 'text', 'VP Reject'),  'action_id', 'vp_reject',  'value', req.id, 'style', 'danger')
        );
      END IF;

      -- Always show Cancel
      actions := actions || jsonb_build_array(
        jsonb_build_object('type', 'button', 'text', jsonb_build_object('type', 'plain_text', 'text', 'Cancel'), 'action_id', 'cancel', 'value', req.id)
      );

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

  -- Add "View in Web" URL button if web app URL is configured
  IF web_base_url IS NOT NULL AND web_base_url != '' THEN
    actions := actions || jsonb_build_array(
      jsonb_build_object(
        'type', 'button',
        'text', jsonb_build_object('type', 'plain_text', 'text', 'View in Web'),
        'url', format('%s/detail.html?id=%s', rtrim(web_base_url, '/'), req.id),
        'action_id', 'view_web'
      )
    );
  END IF;

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
