// Supabase Edge Function: Slack -> PostgREST proxy
// Receives Slack's application/x-www-form-urlencoded POST,
// rewrites Content-Type to text/plain, and forwards the raw body
// unchanged to PostgREST's single-unnamed-parameter RPC endpoint.

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const body = await req.text();
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const resp = await fetch(
    `${supabaseUrl}/rest/v1/rpc/handle_slack_webhook`,
    {
      method: "POST",
      headers: {
        "Content-Type": "text/plain",
        "apikey": serviceRoleKey,
        "Authorization": `Bearer ${serviceRoleKey}`,
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
