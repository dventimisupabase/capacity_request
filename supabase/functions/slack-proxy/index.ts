// Supabase Edge Function: Slack -> PostgREST proxy
// Receives Slack's application/x-www-form-urlencoded POST,
// rewrites Content-Type to text/plain, and forwards the raw body
// unchanged to PostgREST's single-unnamed-parameter RPC endpoint.
//
// Three paths:
// 1. Modal opening: slash command with empty text or "create" (no extra args)
//    -> opens Slack modal via views.open API (trigger_id expires in 3s)
// 2. View submission: interactive payload with type "view_submission"
//    -> forwards to handle_slack_modal_submission
// 3. Default: all other requests forward to handle_slack_webhook

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const body = await req.text();
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const slackBotToken = Deno.env.get("SLACK_BOT_TOKEN") ?? "";

  // Parse form-encoded params to detect routing
  const params = new URLSearchParams(body);

  // --- Path 1: Modal opening ---
  // When the slash command text is empty or exactly "create" (no additional args),
  // open the Slack modal directly. The trigger_id expires in 3 seconds,
  // so we can't round-trip through the DB.
  if (params.has("command")) {
    const text = (params.get("text") ?? "").trim();
    if (text === "" || text === "create") {
      const triggerId = params.get("trigger_id");
      const channelId = params.get("channel_id") ?? "";

      if (triggerId && slackBotToken) {
        const modalView = {
          type: "modal" as const,
          title: { type: "plain_text" as const, text: "New Capacity Request" },
          submit: { type: "plain_text" as const, text: "Submit" },
          close: { type: "plain_text" as const, text: "Cancel" },
          private_metadata: channelId,
          blocks: [
            {
              type: "input",
              block_id: "size",
              label: { type: "plain_text", text: "Instance Size" },
              element: {
                type: "static_select",
                action_id: "size_select",
                placeholder: { type: "plain_text", text: "Select size" },
                options: [
                  { text: { type: "plain_text", text: "16XL" }, value: "16XL" },
                  { text: { type: "plain_text", text: "24XL" }, value: "24XL" },
                  { text: { type: "plain_text", text: "32XL" }, value: "32XL" },
                  { text: { type: "plain_text", text: "48XL" }, value: "48XL" },
                  { text: { type: "plain_text", text: "64XL" }, value: "64XL" },
                ],
              },
            },
            {
              type: "input",
              block_id: "region",
              label: { type: "plain_text", text: "Region" },
              element: {
                type: "static_select",
                action_id: "region_select",
                placeholder: { type: "plain_text", text: "Select region" },
                options: [
                  { text: { type: "plain_text", text: "us-east-1" }, value: "us-east-1" },
                  { text: { type: "plain_text", text: "us-west-2" }, value: "us-west-2" },
                  { text: { type: "plain_text", text: "eu-west-1" }, value: "eu-west-1" },
                  { text: { type: "plain_text", text: "eu-central-1" }, value: "eu-central-1" },
                  { text: { type: "plain_text", text: "ap-southeast-1" }, value: "ap-southeast-1" },
                  { text: { type: "plain_text", text: "ap-northeast-1" }, value: "ap-northeast-1" },
                ],
              },
            },
            {
              type: "input",
              block_id: "quantity",
              label: { type: "plain_text", text: "Quantity" },
              element: {
                type: "number_input",
                action_id: "quantity_input",
                is_decimal_allowed: false,
                min_value: "1",
                placeholder: { type: "plain_text", text: "Number of instances" },
              },
            },
            {
              type: "input",
              block_id: "duration",
              label: { type: "plain_text", text: "Expected Duration (days)" },
              element: {
                type: "number_input",
                action_id: "duration_input",
                is_decimal_allowed: false,
                min_value: "1",
                placeholder: { type: "plain_text", text: "Duration in days" },
              },
            },
            {
              type: "input",
              block_id: "needed_by",
              label: { type: "plain_text", text: "Needed By" },
              element: {
                type: "datepicker",
                action_id: "needed_by_picker",
                placeholder: { type: "plain_text", text: "Select a date" },
              },
            },
            {
              type: "input",
              block_id: "cost",
              optional: true,
              label: { type: "plain_text", text: "Estimated Monthly Cost (USD)" },
              element: {
                type: "number_input",
                action_id: "cost_input",
                is_decimal_allowed: true,
                min_value: "0",
                placeholder: { type: "plain_text", text: "e.g. 15000" },
              },
            },
            {
              type: "input",
              block_id: "customer",
              optional: true,
              label: { type: "plain_text", text: "Customer Name" },
              element: {
                type: "plain_text_input",
                action_id: "customer_input",
                placeholder: { type: "plain_text", text: "e.g. Acme Corp" },
              },
            },
            {
              type: "input",
              block_id: "commercial_owner",
              optional: true,
              label: { type: "plain_text", text: "Commercial Owner" },
              element: {
                type: "users_select",
                action_id: "commercial_owner_select",
                placeholder: { type: "plain_text", text: "Select a user" },
              },
            },
            {
              type: "input",
              block_id: "infra_group",
              optional: true,
              label: { type: "plain_text", text: "Infrastructure Group" },
              element: {
                type: "plain_text_input",
                action_id: "infra_group_input",
                placeholder: { type: "plain_text", text: "e.g. infra-team" },
              },
            },
          ],
        };

        // Open the modal via Slack API (must be synchronous, trigger_id expires in 3s)
        const modalResp = await fetch("https://slack.com/api/views.open", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${slackBotToken}`,
          },
          body: JSON.stringify({
            trigger_id: triggerId,
            view: modalView,
          }),
        });

        // Log any errors but return 200 to Slack regardless
        if (!modalResp.ok) {
          console.error("views.open failed:", await modalResp.text());
        }
      }

      // Return empty 200 to acknowledge the slash command
      return new Response("", { status: 200 });
    }
  }

  // --- Path 2: Interactive payload routing ---
  if (params.has("payload")) {
    try {
      const payload = JSON.parse(params.get("payload")!);

      // Path 2a: View submission (modal form submit)
      if (payload.type === "view_submission") {
        const submitBody = JSON.stringify(payload);
        const resp = await fetch(
          `${supabaseUrl}/rest/v1/rpc/handle_slack_modal_submission`,
          {
            method: "POST",
            headers: {
              "Content-Type": "text/plain",
              apikey: serviceRoleKey,
              Authorization: `Bearer ${serviceRoleKey}`,
              "x-slack-signature":
                req.headers.get("x-slack-signature") ?? "",
              "x-slack-request-timestamp":
                req.headers.get("x-slack-request-timestamp") ?? "",
            },
            body: submitBody,
          },
        );

        const result = await resp.text();
        if (!resp.ok) {
          console.error("modal submission error:", result);
          return new Response("", { status: 200 });
        }
        const body2 = result === "null" || result === "" ? "" : result;
        return new Response(body2, {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      }

      // Path 2b: Block actions (button clicks)
      // Acknowledge immediately, then fire PostgREST call and post
      // the updated Block Kit to Slack's response_url asynchronously.
      if (payload.type === "block_actions") {
        const responseUrl = payload.response_url;

        // Fire-and-forget: call PostgREST to apply the event, then
        // use response_url to replace the original message.
        const bgWork = fetch(
          `${supabaseUrl}/rest/v1/rpc/handle_slack_webhook`,
          {
            method: "POST",
            headers: {
              "Content-Type": "text/plain",
              apikey: serviceRoleKey,
              Authorization: `Bearer ${serviceRoleKey}`,
              "x-slack-signature":
                req.headers.get("x-slack-signature") ?? "",
              "x-slack-request-timestamp":
                req.headers.get("x-slack-request-timestamp") ?? "",
            },
            body,
          },
        ).then(async (resp) => {
          if (resp.ok && responseUrl) {
            const webhookResult = await resp.json();
            // Post the replacement to Slack's response_url
            await fetch(responseUrl, {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify(webhookResult),
            });
          }
        }).catch((err) => console.error("block_actions background error:", err));

        // Keep the edge function alive until background work completes
        // but return the acknowledgment immediately
        const ac = new AbortController();
        req.signal?.addEventListener("abort", () => ac.abort());

        // Return immediate acknowledgment to Slack (within 3s)
        // Use waitUntil-like pattern: respond first, then await bg work
        const response = new Response("", { status: 200 });

        // Ensure background work completes before function exits
        bgWork.finally(() => {});

        return response;
      }
    } catch {
      // If payload parsing fails, fall through to default handler
    }
  }

  // --- Path 3: Default — forward to handle_slack_webhook ---
  // (slash commands with text args like /capacity help, /capacity list, etc.)
  const resp = await fetch(
    `${supabaseUrl}/rest/v1/rpc/handle_slack_webhook`,
    {
      method: "POST",
      headers: {
        "Content-Type": "text/plain",
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
        "x-slack-signature": req.headers.get("x-slack-signature") ?? "",
        "x-slack-request-timestamp":
          req.headers.get("x-slack-request-timestamp") ?? "",
      },
      body,
    },
  );

  const result = await resp.text();
  return new Response(result, {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
