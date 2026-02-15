-- Migration 14: Workflow Visualization & Operator Guidance
-- Adds text-based workflow pipeline to Slack Block Kit messages
-- and contextual operator guidance per state.

-- ============================================================
-- build_workflow_mrkdwn: text-based pipeline for Slack mrkdwn
-- ============================================================
CREATE FUNCTION build_workflow_mrkdwn(
  req       capacity_requests,
  new_state capacity_request_state
) RETURNS text AS $$
DECLARE
  stages     text[] := ARRAY['SUBMITTED', 'UNDER_REVIEW', 'CUSTOMER_CONFIRMATION_REQUIRED', 'PROVISIONING', 'COMPLETED'];
  labels     text[] := ARRAY['Submitted', 'Under Review', 'Confirming', 'Provisioning', 'Completed'];
  terminal   text[] := ARRAY['REJECTED', 'CANCELLED', 'EXPIRED', 'FAILED'];
  pipeline   text := '';
  i          int;
  current_idx int := 0;
  is_terminal boolean := false;
  terminal_from int := 0;
  emoji      text;
  vp_required boolean;
  sub_lines  text := '';
BEGIN
  -- Find current stage index
  FOR i IN 1..array_length(stages, 1) LOOP
    IF stages[i] = new_state::text THEN
      current_idx := i;
    END IF;
  END LOOP;

  -- Check if terminal
  is_terminal := new_state::text = ANY(terminal);

  -- For terminal states, determine which stage they branched from
  IF new_state = 'REJECTED' THEN
    terminal_from := 2; -- UNDER_REVIEW
  ELSIF new_state = 'EXPIRED' THEN
    terminal_from := 3; -- CUSTOMER_CONFIRMATION_REQUIRED
  ELSIF new_state = 'FAILED' THEN
    terminal_from := 4; -- PROVISIONING
  ELSIF new_state = 'CANCELLED' THEN
    -- Determine based on approval state
    IF req.commercial_approved_at IS NOT NULL AND req.technical_approved_at IS NOT NULL THEN
      terminal_from := 3;
    ELSIF req.commercial_approved_at IS NOT NULL OR req.technical_approved_at IS NOT NULL THEN
      terminal_from := 2;
    ELSE
      terminal_from := 1;
    END IF;
  END IF;

  -- Build pipeline string
  FOR i IN 1..array_length(stages, 1) LOOP
    IF NOT is_terminal THEN
      IF i < current_idx THEN
        emoji := E'\u2705'; -- completed
      ELSIF i = current_idx THEN
        emoji := E'\U0001F536'; -- active (orange diamond)
      ELSE
        emoji := E'\u2B1C'; -- future (white square)
      END IF;
    ELSE
      IF i < terminal_from THEN
        emoji := E'\u2705'; -- completed
      ELSIF i = terminal_from THEN
        emoji := E'\u274C'; -- failed/stopped
      ELSE
        emoji := E'\u2B1C'; -- future (never reached)
      END IF;
    END IF;

    IF i > 1 THEN
      pipeline := pipeline || E' \u2192 ';
    END IF;
    pipeline := pipeline || emoji || ' ' || labels[i];
  END LOOP;

  -- Add terminal state label if applicable
  IF is_terminal THEN
    pipeline := pipeline || E'\n' || E'\u274C' || ' *' || replace(new_state::text, '_', ' ') || '*';
  END IF;

  -- Add approval sub-bullets for UNDER_REVIEW
  IF new_state = 'UNDER_REVIEW' OR (is_terminal AND terminal_from >= 2) THEN
    sub_lines := E'\n';
    IF req.commercial_approved_at IS NOT NULL THEN
      sub_lines := sub_lines || E'\n    \u251C \u2705 Commercial Approved';
    ELSE
      sub_lines := sub_lines || E'\n    \u251C \u23F3 Commercial Pending';
    END IF;

    IF req.technical_approved_at IS NOT NULL THEN
      sub_lines := sub_lines || E'\n    \u251C \u2705 Technical Approved';
    ELSE
      sub_lines := sub_lines || E'\n    \u251C \u23F3 Technical Pending';
    END IF;

    vp_required := req.estimated_monthly_cost_usd IS NOT NULL
                   AND req.estimated_monthly_cost_usd >= get_escalation_threshold_usd();
    IF vp_required THEN
      IF req.vp_approved_at IS NOT NULL THEN
        sub_lines := sub_lines || E'\n    \u2514 \u2705 VP Approved';
      ELSE
        sub_lines := sub_lines || E'\n    \u2514 \u23F3 VP Pending';
      END IF;
    END IF;

    pipeline := pipeline || sub_lines;
  END IF;

  RETURN pipeline;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================
-- get_operator_guidance: contextual help text per state
-- ============================================================
CREATE FUNCTION get_operator_guidance(
  req       capacity_requests,
  state     capacity_request_state
) RETURNS text AS $$
DECLARE
  vp_required  boolean;
  comm_done    boolean := req.commercial_approved_at IS NOT NULL;
  tech_done    boolean := req.technical_approved_at IS NOT NULL;
  vp_done      boolean := req.vp_approved_at IS NOT NULL;
  guidance     text;
BEGIN
  vp_required := req.estimated_monthly_cost_usd IS NOT NULL
                 AND req.estimated_monthly_cost_usd >= get_escalation_threshold_usd();

  CASE state
    WHEN 'SUBMITTED' THEN
      guidance := 'This request was just created and is being routed for review.';

    WHEN 'UNDER_REVIEW' THEN
      IF NOT comm_done AND NOT tech_done THEN
        guidance := 'Awaiting commercial and technical review. Commercial owner and infra team should review and approve or reject.';
      ELSIF comm_done AND NOT tech_done THEN
        guidance := 'Commercial review complete. Awaiting technical review from the infrastructure team.';
      ELSIF NOT comm_done AND tech_done THEN
        guidance := 'Technical review complete. Awaiting commercial review from the commercial owner.';
      ELSIF comm_done AND tech_done AND vp_required AND NOT vp_done THEN
        guidance := format('Commercial and technical reviews approved. Awaiting VP approval due to cost exceeding escalation threshold ($%s/mo).', req.estimated_monthly_cost_usd);
      ELSE
        guidance := 'All reviews in progress.';
      END IF;

    WHEN 'CUSTOMER_CONFIRMATION_REQUIRED' THEN
      guidance := 'All approvals received. Customer must confirm they still need this capacity.';
      IF req.next_deadline_at IS NOT NULL THEN
        guidance := guidance || format(' Deadline: %s.', to_char(req.next_deadline_at, 'YYYY-MM-DD HH24:MI TZ'));
      END IF;
      guidance := guidance || ' After that, the request will automatically expire.';

    WHEN 'PROVISIONING' THEN
      guidance := 'Customer confirmed. An operator should now provision the requested infrastructure in Admin Studio (or your provisioning system). When done, call the provisioning webhook with status "complete" or "failed".';

    WHEN 'COMPLETED' THEN
      guidance := 'This request has been fulfilled. Infrastructure has been provisioned.';

    WHEN 'REJECTED' THEN
      guidance := 'This request was rejected during review.';

    WHEN 'CANCELLED' THEN
      guidance := 'This request was cancelled.';
      IF req.cancellation_reason IS NOT NULL THEN
        guidance := guidance || format(' Reason: %s', req.cancellation_reason);
      END IF;

    WHEN 'EXPIRED' THEN
      guidance := 'Customer did not confirm within the deadline. This request has expired.';

    WHEN 'FAILED' THEN
      guidance := 'Provisioning failed. Review the error details and consider creating a new request.';

    ELSE
      guidance := NULL;
  END CASE;

  RETURN guidance;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================
-- Updated build_block_kit_message: adds workflow pipeline + guidance
-- ============================================================
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
  pipeline_text text;
  guidance_text text;
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

  -- Workflow pipeline visualization
  pipeline_text := build_workflow_mrkdwn(req, new_state);
  IF pipeline_text IS NOT NULL THEN
    blocks := blocks || jsonb_build_array(jsonb_build_object(
      'type', 'section',
      'text', jsonb_build_object(
        'type', 'mrkdwn',
        'text', pipeline_text
      )
    ));
  END IF;

  -- Operator guidance
  guidance_text := get_operator_guidance(req, new_state);
  IF guidance_text IS NOT NULL THEN
    blocks := blocks || jsonb_build_array(jsonb_build_object(
      'type', 'context',
      'elements', jsonb_build_array(jsonb_build_object(
        'type', 'mrkdwn',
        'text', E'\U0001F4CB ' || guidance_text
      ))
    ));
  END IF;

  -- Divider between pipeline/guidance and details
  blocks := blocks || jsonb_build_array(jsonb_build_object('type', 'divider'));

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
