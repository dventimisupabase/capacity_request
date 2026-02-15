// Supabase Edge Function: Provisioning System -> PostgREST proxy
// Receives JSON POST from external provisioning system,
// rewrites Content-Type to text/plain, and forwards the raw body
// to PostgREST's single-unnamed-parameter RPC endpoint.
// Passes X-Provisioning-API-Key header through for auth.

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const body = await req.text();
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const resp = await fetch(
    `${supabaseUrl}/rest/v1/rpc/handle_provisioning_webhook`,
    {
      method: "POST",
      headers: {
        "Content-Type": "text/plain",
        "apikey": serviceRoleKey,
        "Authorization": `Bearer ${serviceRoleKey}`,
        "x-provisioning-api-key":
          req.headers.get("x-provisioning-api-key") ?? "",
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
