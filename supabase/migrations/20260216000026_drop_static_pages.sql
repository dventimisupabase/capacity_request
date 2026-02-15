-- Migration: Remove static pages infrastructure
--
-- The web UI is served entirely from Vercel (capreq.vercel.app).
-- The Supabase-hosted static pages (static_pages table + www RPC function)
-- were a parallel copy that nothing links to. Remove them.

DROP FUNCTION IF EXISTS www(text);
DROP TABLE IF EXISTS static_pages;
