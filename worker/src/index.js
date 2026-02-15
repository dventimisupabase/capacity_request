// Cloudflare Worker: Slack -> PostgREST proxy
// Receives Slack's application/x-www-form-urlencoded POST,
// rewrites Content-Type to text/plain, and forwards the raw body
// unchanged to PostgREST's single-unnamed-parameter RPC endpoint.

export default {
  async fetch(request, env) {
    if (request.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    const body = await request.text();

    const resp = await fetch(env.POSTGREST_URL, {
      method: "POST",
      headers: {
        "Content-Type": "text/plain",
        "apikey": env.SUPABASE_ANON_KEY,
        "Authorization": `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
        "x-slack-signature": request.headers.get("x-slack-signature") || "",
        "x-slack-request-timestamp": request.headers.get("x-slack-request-timestamp") || "",
      },
      body,
    });

    // Return 200 OK immediately to Slack regardless of backend result.
    // Slack requires a response within 3 seconds.
    const result = await resp.text();
    return new Response(result, {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  },
};
