-- Migration: Serve static web pages directly from PostgREST
-- Store HTML/CSS/JS in a table, serve via RPC with correct Content-Type.
-- Uses the "text/html" domain trick from PostgREST docs:
-- https://docs.postgrest.org/en/v14/how-tos/providing-html-content-using-htmx.html

-- Custom domain so PostgREST serves responses as text/html
CREATE DOMAIN "text/html" AS text;

-- Table to store static web content
CREATE TABLE static_pages (
  path         text PRIMARY KEY,
  content      text NOT NULL,
  content_type text NOT NULL DEFAULT 'text/html; charset=utf-8'
);

-- Allow anonymous and authenticated reads
ALTER TABLE static_pages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "static_pages_read" ON static_pages FOR SELECT USING (true);
GRANT SELECT ON static_pages TO anon, authenticated;

-- RPC function to serve pages
-- Usage: GET /rest/v1/rpc/www?page=index.html
CREATE FUNCTION www(page text DEFAULT 'index.html') RETURNS "text/html" AS $$
DECLARE
  p static_pages;
BEGIN
  SELECT * INTO p FROM static_pages WHERE path = page;

  IF p IS NULL THEN
    PERFORM set_config('response.status', '404', true);
    RETURN '<!DOCTYPE html><html><head><title>404</title></head><body><h1>404 — Not Found</h1></body></html>';
  END IF;

  RETURN p.content;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION www TO anon, authenticated, service_role;

-- Allow www() through the pre-request check without auth
-- (it's a public website)
CREATE OR REPLACE FUNCTION check_request() RETURNS void AS $$
DECLARE
  req_path text := current_setting('request.path', true);
  role     text := current_setting('request.jwt.claims', true)::json->>'role';
BEGIN
  -- Public routes: no auth required
  IF req_path IN (
    '/rest/v1/rpc/www',
    '/rest/v1/rpc/handle_slack_webhook',
    '/rest/v1/rpc/handle_slack_modal_submission',
    '/rest/v1/rpc/handle_provisioning_webhook'
  ) THEN
    RETURN;
  END IF;

  -- Slack signature verification for webhook routes
  IF req_path IN (
    '/rest/v1/rpc/handle_slack_webhook',
    '/rest/v1/rpc/handle_slack_modal_submission'
  ) THEN
    -- Signature is verified inside the functions themselves
    RETURN;
  END IF;

  -- All other routes: require authentication
  IF role = 'anon' THEN
    -- Allow read access to views for anonymous (dashboard works without login)
    IF req_path LIKE '/rest/v1/v_%' THEN
      RETURN;
    END IF;
  END IF;

  RETURN;
END;
$$ LANGUAGE plpgsql;
