// Supabase Edge Function: Serve static HTML pages from static_pages table
// Bypasses the Supabase gateway's Content-Type override by setting
// the response headers directly from the edge function.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const page = url.searchParams.get("page") || "index.html";

  // Pass through the hash fragment in the redirect if needed
  // (hash fragments don't reach the server, they stay client-side)

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data, error } = await supabase
    .from("static_pages")
    .select("content, content_type")
    .eq("path", page)
    .single();

  if (error || !data) {
    return new Response(
      "<!DOCTYPE html><html><head><title>404</title></head><body><h1>404 — Not Found</h1></body></html>",
      {
        status: 404,
        headers: { "Content-Type": "text/html; charset=utf-8" },
      },
    );
  }

  return new Response(data.content, {
    status: 200,
    headers: { "Content-Type": data.content_type },
  });
});
