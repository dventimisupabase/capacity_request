-- Migration: Seed static_pages with transformed HTML content
-- All relative paths rewritten for PostgREST RPC serving via www?page=X
-- CSS inlined, config.js inlined with production credentials,
-- images point to Supabase Storage, inter-page links use www?page= format,
-- page-specific parameters use hash fragments (since PostgREST only passes
-- declared function params, not arbitrary query strings).

-- ============================================================
-- index.html
-- ============================================================
INSERT INTO static_pages (path, content) VALUES ('index.html', $html$<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>CapReq — Capacity Requests</title>
  <link rel="icon" type="image/png" href="https://oandzthkyemwojhebqwc.supabase.co/storage/v1/object/public/www/capreq-icon.png">
  <style>
/* Capacity Request — Ops Console
   Dark utilitarian aesthetic with amber accents */

@import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600;700&family=Outfit:wght@300;400;500;600;700&display=swap');

:root {
  --bg: #08080c;
  --surface: #111118;
  --surface-2: #1a1a24;
  --border: #2a2a3a;
  --border-light: #35354a;
  --text: #e8e8ed;
  --text-muted: #8888a0;
  --text-dim: #55556a;
  --accent: #f59e0b;
  --accent-dim: rgba(245, 158, 11, 0.15);
  --accent-glow: rgba(245, 158, 11, 0.3);
  --success: #22c55e;
  --success-dim: rgba(34, 197, 94, 0.12);
  --danger: #ef4444;
  --danger-dim: rgba(239, 68, 68, 0.12);
  --info: #38bdf8;
  --info-dim: rgba(56, 189, 248, 0.12);
  --warning: #eab308;
  --warning-dim: rgba(234, 179, 8, 0.12);
  --purple: #a78bfa;
  --purple-dim: rgba(167, 139, 250, 0.12);
  --mono: 'JetBrains Mono', 'SF Mono', 'Fira Code', monospace;
  --sans: 'Outfit', -apple-system, sans-serif;
  --radius: 8px;
  --radius-lg: 12px;
}

*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

body {
  font-family: var(--sans);
  background: var(--bg);
  color: var(--text);
  line-height: 1.6;
  min-height: 100vh;
  -webkit-font-smoothing: antialiased;
}

/* Noise texture overlay */
body::before {
  content: '';
  position: fixed;
  inset: 0;
  background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noise'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noise)' opacity='0.03'/%3E%3C/svg%3E");
  pointer-events: none;
  z-index: 0;
}

.shell {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 1.5rem;
  position: relative;
  z-index: 1;
}

/* --- Top Bar --- */

.topbar {
  display: flex;
  align-items: center;
  gap: 2rem;
  padding: 1rem 0;
  border-bottom: 1px solid var(--border);
  margin-bottom: 2rem;
}

.topbar-brand {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  margin-right: auto;
  text-decoration: none;
  color: var(--text);
}

.topbar-icon {
  width: 24px;
  height: 24px;
  border-radius: 4px;
}

.topbar-brand svg {
  width: 22px;
  height: 22px;
  color: var(--accent);
}

.topbar-brand span {
  font-family: var(--mono);
  font-weight: 700;
  font-size: 0.85rem;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.topbar-nav {
  display: flex;
  gap: 0.25rem;
}

.topbar-nav a {
  font-family: var(--mono);
  font-size: 0.78rem;
  font-weight: 500;
  color: var(--text-muted);
  text-decoration: none;
  padding: 0.4rem 0.75rem;
  border-radius: 6px;
  transition: all 0.2s;
  letter-spacing: 0.03em;
}

.topbar-nav a:hover {
  color: var(--text);
  background: var(--surface-2);
}

.topbar-nav a.active {
  color: var(--accent);
  background: var(--accent-dim);
}

.topbar-user {
  font-family: var(--mono);
  font-size: 0.75rem;
  color: var(--text-dim);
  padding: 0.35rem 0.6rem;
  border: 1px solid var(--border);
  border-radius: 6px;
}

/* --- Page Header --- */

.page-header {
  margin-bottom: 1.75rem;
}

.page-header h1 {
  font-family: var(--sans);
  font-size: 1.5rem;
  font-weight: 700;
  letter-spacing: -0.02em;
  color: var(--text);
}

.page-header h1 .mono {
  font-family: var(--mono);
  color: var(--accent);
  font-weight: 600;
}

.page-header p {
  color: var(--text-muted);
  font-size: 0.9rem;
  margin-top: 0.25rem;
}

/* --- Auth Card --- */

.auth-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  padding: 3rem;
  max-width: 440px;
  margin: 4rem auto;
  text-align: center;
}

.auth-logo {
  width: 64px;
  height: 64px;
  border-radius: 12px;
  margin-bottom: 1rem;
}

.auth-tagline {
  color: var(--text-dim) !important;
  font-size: 0.82rem !important;
  margin-bottom: 1.25rem !important;
}

.auth-card h2 {
  font-family: var(--sans);
  font-size: 1.25rem;
  font-weight: 600;
  margin-bottom: 0.5rem;
}

.auth-card p {
  color: var(--text-muted);
  font-size: 0.9rem;
  margin-bottom: 1.5rem;
}

.auth-card .input-group {
  display: flex;
  gap: 0.5rem;
}

.auth-card input[type="email"] {
  flex: 1;
  padding: 0.65rem 0.85rem;
  background: var(--surface-2);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  color: var(--text);
  font-family: var(--mono);
  font-size: 0.85rem;
  outline: none;
  transition: border-color 0.2s;
}

.auth-card input[type="email"]:focus {
  border-color: var(--accent);
  box-shadow: 0 0 0 3px var(--accent-dim);
}

.auth-card input[type="email"]::placeholder {
  color: var(--text-dim);
}

/* --- Cards & Panels --- */

.card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  overflow: hidden;
}

.card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.85rem 1.25rem;
  border-bottom: 1px solid var(--border);
  background: var(--surface-2);
}

.card-header h3 {
  font-family: var(--mono);
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  color: var(--text-muted);
}

.card-body {
  padding: 1.25rem;
}

/* --- Data Table --- */

.data-table {
  width: 100%;
  border-collapse: collapse;
}

.data-table th {
  font-family: var(--mono);
  font-size: 0.7rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  color: var(--text-dim);
  padding: 0.75rem 1rem;
  text-align: left;
  border-bottom: 1px solid var(--border);
  background: var(--surface-2);
  white-space: nowrap;
}

.data-table td {
  padding: 0.7rem 1rem;
  font-size: 0.875rem;
  border-bottom: 1px solid rgba(42, 42, 58, 0.5);
  transition: background 0.15s;
}

.data-table tbody tr {
  cursor: pointer;
  transition: background 0.15s;
}

.data-table tbody tr:hover td {
  background: var(--surface-2);
}

.data-table tbody tr:last-child td {
  border-bottom: none;
}

.data-table .col-id {
  font-family: var(--mono);
  font-weight: 500;
  font-size: 0.8rem;
  color: var(--accent);
}

.data-table .col-mono {
  font-family: var(--mono);
  font-size: 0.8rem;
}

.data-table .col-cost {
  font-family: var(--mono);
  font-size: 0.82rem;
  font-weight: 500;
}

.data-table .col-date {
  font-size: 0.8rem;
  color: var(--text-muted);
  white-space: nowrap;
}

.data-table .empty-row td {
  text-align: center;
  color: var(--text-dim);
  padding: 2.5rem 1rem;
}

/* --- State Badges --- */

.badge {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.25rem 0.6rem;
  border-radius: 100px;
  font-family: var(--mono);
  font-size: 0.68rem;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  white-space: nowrap;
}

.badge::before {
  content: '';
  width: 6px;
  height: 6px;
  border-radius: 50%;
  flex-shrink: 0;
}

.badge-SUBMITTED          { background: #1e1e2e; color: #8888a0; }
.badge-SUBMITTED::before  { background: #8888a0; }

.badge-UNDER_REVIEW       { background: var(--info-dim); color: var(--info); }
.badge-UNDER_REVIEW::before { background: var(--info); }

.badge-CUSTOMER_CONFIRMATION_REQUIRED { background: var(--warning-dim); color: var(--warning); }
.badge-CUSTOMER_CONFIRMATION_REQUIRED::before { background: var(--warning); }

.badge-PROVISIONING       { background: var(--purple-dim); color: var(--purple); }
.badge-PROVISIONING::before { background: var(--purple); }

.badge-COMPLETED          { background: var(--success-dim); color: var(--success); }
.badge-COMPLETED::before  { background: var(--success); }

.badge-REJECTED           { background: var(--danger-dim); color: var(--danger); }
.badge-REJECTED::before   { background: var(--danger); }

.badge-CANCELLED          { background: #1e1e2e; color: #8888a0; }
.badge-CANCELLED::before  { background: #666; }

.badge-EXPIRED            { background: var(--danger-dim); color: #f87171; }
.badge-EXPIRED::before    { background: #f87171; }

.badge-FAILED             { background: var(--danger-dim); color: var(--danger); }
.badge-FAILED::before     { background: var(--danger); }

/* --- Buttons --- */

.btn {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.55rem 1rem;
  border: 1px solid transparent;
  border-radius: var(--radius);
  font-family: var(--sans);
  font-size: 0.85rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  text-decoration: none;
  white-space: nowrap;
}

.btn:active { transform: scale(0.97); }

.btn-primary {
  background: var(--accent);
  color: #000;
  border-color: var(--accent);
}
.btn-primary:hover {
  background: #d97706;
  box-shadow: 0 0 20px var(--accent-dim);
}

.btn-success {
  background: var(--success-dim);
  color: var(--success);
  border-color: rgba(34, 197, 94, 0.25);
}
.btn-success:hover {
  background: rgba(34, 197, 94, 0.2);
  border-color: var(--success);
}

.btn-danger {
  background: var(--danger-dim);
  color: var(--danger);
  border-color: rgba(239, 68, 68, 0.25);
}
.btn-danger:hover {
  background: rgba(239, 68, 68, 0.2);
  border-color: var(--danger);
}

.btn-ghost {
  background: transparent;
  color: var(--text-muted);
  border-color: var(--border);
}
.btn-ghost:hover {
  color: var(--text);
  border-color: var(--border-light);
  background: var(--surface-2);
}

.btn:disabled {
  opacity: 0.4;
  cursor: not-allowed;
  transform: none;
}

.actions {
  display: flex;
  gap: 0.5rem;
  flex-wrap: wrap;
  margin-top: 1.25rem;
}

/* --- Detail Grid --- */

.detail-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0;
}

.detail-item {
  padding: 0.75rem 1.25rem;
  border-bottom: 1px solid rgba(42, 42, 58, 0.5);
}

.detail-item:nth-child(odd) {
  border-right: 1px solid rgba(42, 42, 58, 0.5);
}

.detail-label {
  font-family: var(--mono);
  font-size: 0.68rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--text-dim);
  margin-bottom: 0.2rem;
}

.detail-value {
  font-size: 0.9rem;
  font-weight: 500;
}

.detail-value.mono {
  font-family: var(--mono);
  font-size: 0.85rem;
}

/* --- Timeline --- */

.timeline {
  list-style: none;
  position: relative;
  padding-left: 2rem;
}

.timeline::before {
  content: '';
  position: absolute;
  left: 7px;
  top: 8px;
  bottom: 8px;
  width: 2px;
  background: var(--border);
}

.timeline li {
  position: relative;
  padding-bottom: 1.25rem;
}

.timeline li:last-child { padding-bottom: 0; }

.timeline li::before {
  content: '';
  position: absolute;
  left: -2rem + 3px;
  left: calc(-2rem + 3px);
  top: 6px;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: var(--surface);
  border: 2px solid var(--accent);
  box-shadow: 0 0 8px var(--accent-dim);
}

.event-type {
  font-family: var(--mono);
  font-weight: 600;
  font-size: 0.82rem;
  color: var(--text);
}

.event-meta {
  font-size: 0.78rem;
  color: var(--text-dim);
}

.event-payload {
  margin-top: 0.35rem;
  font-family: var(--mono);
  font-size: 0.75rem;
  color: var(--text-muted);
  background: var(--surface-2);
  padding: 0.3rem 0.5rem;
  border-radius: 4px;
  display: inline-block;
}

/* --- Forms --- */

.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0 1.5rem;
}

.form-group {
  margin-bottom: 1.25rem;
}

.form-group.full {
  grid-column: 1 / -1;
}

.form-group label {
  display: block;
  font-family: var(--mono);
  font-size: 0.72rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--text-muted);
  margin-bottom: 0.4rem;
}

.form-group input,
.form-group select {
  width: 100%;
  padding: 0.6rem 0.85rem;
  background: var(--surface-2);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  color: var(--text);
  font-family: var(--sans);
  font-size: 0.9rem;
  outline: none;
  transition: border-color 0.2s, box-shadow 0.2s;
  -webkit-appearance: none;
}

.form-group select {
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='8' fill='none'%3E%3Cpath d='M1 1.5l5 5 5-5' stroke='%238888a0' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 0.85rem center;
  padding-right: 2.5rem;
}

.form-group input:focus,
.form-group select:focus {
  border-color: var(--accent);
  box-shadow: 0 0 0 3px var(--accent-dim);
}

.form-group input::placeholder {
  color: var(--text-dim);
}

/* --- Messages --- */

.msg {
  padding: 0.75rem 1rem;
  border-radius: var(--radius);
  font-size: 0.875rem;
  margin-bottom: 1rem;
  border: 1px solid transparent;
}

.msg-error {
  background: var(--danger-dim);
  color: #f87171;
  border-color: rgba(239, 68, 68, 0.2);
}

.msg-success {
  background: var(--success-dim);
  color: #4ade80;
  border-color: rgba(34, 197, 94, 0.2);
}

.msg-info {
  background: var(--info-dim);
  color: var(--info);
  border-color: rgba(56, 189, 248, 0.2);
}

.msg a {
  color: inherit;
  font-weight: 600;
}

/* --- Section Dividers --- */

.section-label {
  font-family: var(--mono);
  font-size: 0.7rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.12em;
  color: var(--text-dim);
  margin-bottom: 0.85rem;
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.section-label::after {
  content: '';
  flex: 1;
  height: 1px;
  background: var(--border);
}

/* --- Stat Pills (confirm page) --- */

.stat-row {
  display: flex;
  gap: 1rem;
  flex-wrap: wrap;
  margin-bottom: 1.5rem;
}

.stat {
  flex: 1;
  min-width: 120px;
  padding: 1rem 1.25rem;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
}

.stat-label {
  font-family: var(--mono);
  font-size: 0.68rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--text-dim);
  margin-bottom: 0.3rem;
}

.stat-value {
  font-size: 1.1rem;
  font-weight: 600;
}

.stat-value.mono {
  font-family: var(--mono);
}

/* --- Footer --- */

.app-footer {
  margin-top: 2.5rem;
  padding: 1.25rem 0;
  border-top: 1px solid var(--border);
  text-align: center;
}

.app-footer p {
  color: var(--text-dim);
  font-size: 0.8rem;
  max-width: 600px;
  margin: 0 auto;
  line-height: 1.6;
}

.app-footer code {
  font-family: var(--mono);
  font-size: 0.75rem;
  color: var(--accent);
  background: var(--accent-dim);
  padding: 0.15rem 0.4rem;
  border-radius: 4px;
}

/* --- Utilities --- */

.hidden { display: none !important; }

.mt-1 { margin-top: 0.5rem; }
.mt-2 { margin-top: 1rem; }
.mt-3 { margin-top: 1.5rem; }
.mb-2 { margin-bottom: 1rem; }
.mb-3 { margin-bottom: 1.5rem; }

/* --- Animations --- */

@keyframes fadeIn {
  from { opacity: 0; transform: translateY(8px); }
  to   { opacity: 1; transform: translateY(0); }
}

.fade-in {
  animation: fadeIn 0.35s ease-out both;
}

.fade-in-1 { animation-delay: 0.05s; }
.fade-in-2 { animation-delay: 0.1s; }
.fade-in-3 { animation-delay: 0.15s; }
.fade-in-4 { animation-delay: 0.2s; }

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}

.loading { animation: pulse 1.5s ease-in-out infinite; color: var(--text-dim); }
  </style>
</head>
<body>
  <div class="shell">
    <header class="topbar">
      <a href="www?page=index.html" class="topbar-brand">
        <img src="https://oandzthkyemwojhebqwc.supabase.co/storage/v1/object/public/www/capreq-icon.png" alt="CapReq" class="topbar-icon">
        <span>CapReq</span>
      </a>
      <nav class="topbar-nav">
        <a href="www?page=index.html" class="active">Dashboard</a>
        <a href="www?page=new.html">New Request</a>
      </nav>
      <span class="topbar-user" id="user-info"></span>
    </header>

    <div id="auth" class="auth-card">
      <img src="https://oandzthkyemwojhebqwc.supabase.co/storage/v1/object/public/www/capreq-icon.png" alt="CapReq" class="auth-logo">
      <h2>CapReq</h2>
      <p class="auth-tagline">Manage infrastructure capacity requests with approvals</p>
      <p>Enter your email to sign in.</p>
      <div class="input-group">
        <input type="email" id="email" placeholder="you@example.com">
        <button class="btn btn-primary" onclick="signIn()">Send Link</button>
      </div>
      <p id="auth-msg" class="hidden mt-2"></p>
    </div>

    <div id="app" class="hidden">
      <div class="page-header fade-in">
        <h1>Dashboard</h1>
        <p>Manage infrastructure capacity requests with approvals</p>
      </div>

      <div id="msg"></div>

      <div class="card fade-in fade-in-1">
        <div class="card-header">
          <h3>Requests</h3>
          <a href="www?page=new.html" class="btn btn-primary" style="padding:0.35rem 0.75rem;font-size:0.78rem;">+ New</a>
        </div>
        <table class="data-table">
          <thead>
            <tr>
              <th>ID</th>
              <th>State</th>
              <th>Region</th>
              <th>Size</th>
              <th>Qty</th>
              <th>Est. Cost</th>
              <th>Created</th>
              <th>Updated</th>
            </tr>
          </thead>
          <tbody id="requests-body">
            <tr class="empty-row"><td colspan="8" class="loading">Loading requests...</td></tr>
          </tbody>
        </table>
      </div>

      <footer class="app-footer fade-in fade-in-3">
        <p>Create requests via <code>/capacity</code> in Slack or the web form. Track them through commercial review, technical review, optional VP escalation, customer confirmation, and provisioning.</p>
      </footer>
    </div>
  </div>

  <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js"></script>
  <script>
    const SUPABASE_URL = 'https://oandzthkyemwojhebqwc.supabase.co';
    const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9hbmR6dGhreWVtd29qaGVicXdjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzExMDgwNzUsImV4cCI6MjA4NjY4NDA3NX0.v7hwYm4a-b1aiWj04cCQY2WT9v08FEqvioFU3BG7nus';
  </script>
  <script>
    const sb = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

    async function init() {
      try {
        if (SUPABASE_ANON_KEY.includes('secret')) {
          showApp({ email: 'local-dev' });
          return;
        }
        const { data: { session } } = await sb.auth.getSession();
        if (session) showApp(session.user);
        sb.auth.onAuthStateChange((_event, session) => {
          if (session) showApp(session.user);
        });
      } catch (e) {
        console.error('init error:', e);
        showApp({ email: 'fallback' });
      }
    }

    async function signIn() {
      const email = document.getElementById('email').value.trim();
      if (!email) return;
      const { error } = await sb.auth.signInWithOtp({ email });
      const msg = document.getElementById('auth-msg');
      msg.classList.remove('hidden');
      msg.className = error ? 'msg msg-error mt-2' : 'msg msg-success mt-2';
      msg.textContent = error ? error.message : 'Check your email for the magic link.';
    }

    async function showApp(user) {
      document.getElementById('auth').classList.add('hidden');
      document.getElementById('app').classList.remove('hidden');
      document.getElementById('user-info').textContent = user.email;
      await loadRequests();
    }

    async function loadRequests() {
      const { data, error } = await sb.from('v_request_summary')
        .select('*')
        .order('created_at', { ascending: false });

      const tbody = document.getElementById('requests-body');
      if (error) {
        tbody.innerHTML = `<tr class="empty-row"><td colspan="8" class="msg-error">${error.message}</td></tr>`;
        return;
      }
      if (!data || data.length === 0) {
        tbody.innerHTML = '<tr class="empty-row"><td colspan="8">No requests found.</td></tr>';
        return;
      }
      tbody.innerHTML = data.map(r => `
        <tr onclick="location.href='www?page=detail.html#id=${encodeURIComponent(r.id)}'">
          <td class="col-id">${esc(r.id)}</td>
          <td><span class="badge badge-${r.state}">${fmtState(r.state)}</span></td>
          <td class="col-mono">${esc(r.region)}</td>
          <td class="col-mono">${esc(r.requested_size)}</td>
          <td>${r.quantity}</td>
          <td class="col-cost">${r.estimated_monthly_cost_usd != null ? '$' + Number(r.estimated_monthly_cost_usd).toLocaleString() : '<span style="color:var(--text-dim)">\u2014</span>'}</td>
          <td class="col-date">${fmtDate(r.created_at)}</td>
          <td class="col-date">${fmtDate(r.updated_at)}</td>
        </tr>
      `).join('');
    }

    function esc(s) {
      if (s == null) return '';
      const d = document.createElement('div');
      d.textContent = s;
      return d.innerHTML;
    }

    function fmtDate(iso) {
      if (!iso) return '\u2014';
      return new Date(iso).toLocaleDateString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
    }

    function fmtState(s) {
      return (s || '').replace(/_/g, ' ');
    }

    init();
  </script>
</body>
</html>$html$);

-- ============================================================
-- detail.html
-- ============================================================
INSERT INTO static_pages (path, content) VALUES ('detail.html', $html$<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>CapReq — Request Detail</title>
  <link rel="icon" type="image/png" href="https://oandzthkyemwojhebqwc.supabase.co/storage/v1/object/public/www/capreq-icon.png">
  <style>
/* Capacity Request — Ops Console
   Dark utilitarian aesthetic with amber accents */

@import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600;700&family=Outfit:wght@300;400;500;600;700&display=swap');

:root {
  --bg: #08080c;
  --surface: #111118;
  --surface-2: #1a1a24;
  --border: #2a2a3a;
  --border-light: #35354a;
  --text: #e8e8ed;
  --text-muted: #8888a0;
  --text-dim: #55556a;
  --accent: #f59e0b;
  --accent-dim: rgba(245, 158, 11, 0.15);
  --accent-glow: rgba(245, 158, 11, 0.3);
  --success: #22c55e;
  --success-dim: rgba(34, 197, 94, 0.12);
  --danger: #ef4444;
  --danger-dim: rgba(239, 68, 68, 0.12);
  --info: #38bdf8;
  --info-dim: rgba(56, 189, 248, 0.12);
  --warning: #eab308;
  --warning-dim: rgba(234, 179, 8, 0.12);
  --purple: #a78bfa;
  --purple-dim: rgba(167, 139, 250, 0.12);
  --mono: 'JetBrains Mono', 'SF Mono', 'Fira Code', monospace;
  --sans: 'Outfit', -apple-system, sans-serif;
  --radius: 8px;
  --radius-lg: 12px;
}

*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

body {
  font-family: var(--sans);
  background: var(--bg);
  color: var(--text);
  line-height: 1.6;
  min-height: 100vh;
  -webkit-font-smoothing: antialiased;
}

body::before {
  content: '';
  position: fixed;
  inset: 0;
  background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noise'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noise)' opacity='0.03'/%3E%3C/svg%3E");
  pointer-events: none;
  z-index: 0;
}

.shell { max-width: 1200px; margin: 0 auto; padding: 0 1.5rem; position: relative; z-index: 1; }
.topbar { display: flex; align-items: center; gap: 2rem; padding: 1rem 0; border-bottom: 1px solid var(--border); margin-bottom: 2rem; }
.topbar-brand { display: flex; align-items: center; gap: 0.6rem; margin-right: auto; text-decoration: none; color: var(--text); }
.topbar-icon { width: 24px; height: 24px; border-radius: 4px; }
.topbar-brand svg { width: 22px; height: 22px; color: var(--accent); }
.topbar-brand span { font-family: var(--mono); font-weight: 700; font-size: 0.85rem; letter-spacing: 0.08em; text-transform: uppercase; }
.topbar-nav { display: flex; gap: 0.25rem; }
.topbar-nav a { font-family: var(--mono); font-size: 0.78rem; font-weight: 500; color: var(--text-muted); text-decoration: none; padding: 0.4rem 0.75rem; border-radius: 6px; transition: all 0.2s; letter-spacing: 0.03em; }
.topbar-nav a:hover { color: var(--text); background: var(--surface-2); }
.topbar-nav a.active { color: var(--accent); background: var(--accent-dim); }
.topbar-user { font-family: var(--mono); font-size: 0.75rem; color: var(--text-dim); padding: 0.35rem 0.6rem; border: 1px solid var(--border); border-radius: 6px; }
.page-header { margin-bottom: 1.75rem; }
.page-header h1 { font-family: var(--sans); font-size: 1.5rem; font-weight: 700; letter-spacing: -0.02em; color: var(--text); }
.page-header h1 .mono { font-family: var(--mono); color: var(--accent); font-weight: 600; }
.page-header p { color: var(--text-muted); font-size: 0.9rem; margin-top: 0.25rem; }
.auth-card { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius-lg); padding: 3rem; max-width: 440px; margin: 4rem auto; text-align: center; }
.auth-logo { width: 64px; height: 64px; border-radius: 12px; margin-bottom: 1rem; }
.auth-tagline { color: var(--text-dim) !important; font-size: 0.82rem !important; margin-bottom: 1.25rem !important; }
.auth-card h2 { font-family: var(--sans); font-size: 1.25rem; font-weight: 600; margin-bottom: 0.5rem; }
.auth-card p { color: var(--text-muted); font-size: 0.9rem; margin-bottom: 1.5rem; }
.auth-card .input-group { display: flex; gap: 0.5rem; }
.auth-card input[type="email"] { flex: 1; padding: 0.65rem 0.85rem; background: var(--surface-2); border: 1px solid var(--border); border-radius: var(--radius); color: var(--text); font-family: var(--mono); font-size: 0.85rem; outline: none; transition: border-color 0.2s; }
.auth-card input[type="email"]:focus { border-color: var(--accent); box-shadow: 0 0 0 3px var(--accent-dim); }
.auth-card input[type="email"]::placeholder { color: var(--text-dim); }
.card { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius-lg); overflow: hidden; }
.card-header { display: flex; align-items: center; justify-content: space-between; padding: 0.85rem 1.25rem; border-bottom: 1px solid var(--border); background: var(--surface-2); }
.card-header h3 { font-family: var(--mono); font-size: 0.75rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.1em; color: var(--text-muted); }
.card-body { padding: 1.25rem; }
.data-table { width: 100%; border-collapse: collapse; }
.data-table th { font-family: var(--mono); font-size: 0.7rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.1em; color: var(--text-dim); padding: 0.75rem 1rem; text-align: left; border-bottom: 1px solid var(--border); background: var(--surface-2); white-space: nowrap; }
.data-table td { padding: 0.7rem 1rem; font-size: 0.875rem; border-bottom: 1px solid rgba(42, 42, 58, 0.5); transition: background 0.15s; }
.data-table tbody tr { cursor: pointer; transition: background 0.15s; }
.data-table tbody tr:hover td { background: var(--surface-2); }
.data-table tbody tr:last-child td { border-bottom: none; }
.data-table .col-id { font-family: var(--mono); font-weight: 500; font-size: 0.8rem; color: var(--accent); }
.data-table .col-mono { font-family: var(--mono); font-size: 0.8rem; }
.data-table .col-cost { font-family: var(--mono); font-size: 0.82rem; font-weight: 500; }
.data-table .col-date { font-size: 0.8rem; color: var(--text-muted); white-space: nowrap; }
.data-table .empty-row td { text-align: center; color: var(--text-dim); padding: 2.5rem 1rem; }
.badge { display: inline-flex; align-items: center; gap: 0.35rem; padding: 0.25rem 0.6rem; border-radius: 100px; font-family: var(--mono); font-size: 0.68rem; font-weight: 600; letter-spacing: 0.04em; text-transform: uppercase; white-space: nowrap; }
.badge::before { content: ''; width: 6px; height: 6px; border-radius: 50%; flex-shrink: 0; }
.badge-SUBMITTED { background: #1e1e2e; color: #8888a0; }
.badge-SUBMITTED::before { background: #8888a0; }
.badge-UNDER_REVIEW { background: var(--info-dim); color: var(--info); }
.badge-UNDER_REVIEW::before { background: var(--info); }
.badge-CUSTOMER_CONFIRMATION_REQUIRED { background: var(--warning-dim); color: var(--warning); }
.badge-CUSTOMER_CONFIRMATION_REQUIRED::before { background: var(--warning); }
.badge-PROVISIONING { background: var(--purple-dim); color: var(--purple); }
.badge-PROVISIONING::before { background: var(--purple); }
.badge-COMPLETED { background: var(--success-dim); color: var(--success); }
.badge-COMPLETED::before { background: var(--success); }
.badge-REJECTED { background: var(--danger-dim); color: var(--danger); }
.badge-REJECTED::before { background: var(--danger); }
.badge-CANCELLED { background: #1e1e2e; color: #8888a0; }
.badge-CANCELLED::before { background: #666; }
.badge-EXPIRED { background: var(--danger-dim); color: #f87171; }
.badge-EXPIRED::before { background: #f87171; }
.badge-FAILED { background: var(--danger-dim); color: var(--danger); }
.badge-FAILED::before { background: var(--danger); }
.btn { display: inline-flex; align-items: center; gap: 0.4rem; padding: 0.55rem 1rem; border: 1px solid transparent; border-radius: var(--radius); font-family: var(--sans); font-size: 0.85rem; font-weight: 600; cursor: pointer; transition: all 0.2s; text-decoration: none; white-space: nowrap; }
.btn:active { transform: scale(0.97); }
.btn-primary { background: var(--accent); color: #000; border-color: var(--accent); }
.btn-primary:hover { background: #d97706; box-shadow: 0 0 20px var(--accent-dim); }
.btn-success { background: var(--success-dim); color: var(--success); border-color: rgba(34, 197, 94, 0.25); }
.btn-success:hover { background: rgba(34, 197, 94, 0.2); border-color: var(--success); }
.btn-danger { background: var(--danger-dim); color: var(--danger); border-color: rgba(239, 68, 68, 0.25); }
.btn-danger:hover { background: rgba(239, 68, 68, 0.2); border-color: var(--danger); }
.btn-ghost { background: transparent; color: var(--text-muted); border-color: var(--border); }
.btn-ghost:hover { color: var(--text); border-color: var(--border-light); background: var(--surface-2); }
.btn:disabled { opacity: 0.4; cursor: not-allowed; transform: none; }
.actions { display: flex; gap: 0.5rem; flex-wrap: wrap; margin-top: 1.25rem; }
.detail-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 0; }
.detail-item { padding: 0.75rem 1.25rem; border-bottom: 1px solid rgba(42, 42, 58, 0.5); }
.detail-item:nth-child(odd) { border-right: 1px solid rgba(42, 42, 58, 0.5); }
.detail-label { font-family: var(--mono); font-size: 0.68rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.08em; color: var(--text-dim); margin-bottom: 0.2rem; }
.detail-value { font-size: 0.9rem; font-weight: 500; }
.detail-value.mono { font-family: var(--mono); font-size: 0.85rem; }
.timeline { list-style: none; position: relative; padding-left: 2rem; }
.timeline::before { content: ''; position: absolute; left: 7px; top: 8px; bottom: 8px; width: 2px; background: var(--border); }
.timeline li { position: relative; padding-bottom: 1.25rem; }
.timeline li:last-child { padding-bottom: 0; }
.timeline li::before { content: ''; position: absolute; left: -2rem + 3px; left: calc(-2rem + 3px); top: 6px; width: 10px; height: 10px; border-radius: 50%; background: var(--surface); border: 2px solid var(--accent); box-shadow: 0 0 8px var(--accent-dim); }
.event-type { font-family: var(--mono); font-weight: 600; font-size: 0.82rem; color: var(--text); }
.event-meta { font-size: 0.78rem; color: var(--text-dim); }
.event-payload { margin-top: 0.35rem; font-family: var(--mono); font-size: 0.75rem; color: var(--text-muted); background: var(--surface-2); padding: 0.3rem 0.5rem; border-radius: 4px; display: inline-block; }
.section-label { font-family: var(--mono); font-size: 0.7rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.12em; color: var(--text-dim); margin-bottom: 0.85rem; display: flex; align-items: center; gap: 0.75rem; }
.section-label::after { content: ''; flex: 1; height: 1px; background: var(--border); }
.msg { padding: 0.75rem 1rem; border-radius: var(--radius); font-size: 0.875rem; margin-bottom: 1rem; border: 1px solid transparent; }
.msg-error { background: var(--danger-dim); color: #f87171; border-color: rgba(239, 68, 68, 0.2); }
.msg-success { background: var(--success-dim); color: #4ade80; border-color: rgba(34, 197, 94, 0.2); }
.msg-info { background: var(--info-dim); color: var(--info); border-color: rgba(56, 189, 248, 0.2); }
.msg a { color: inherit; font-weight: 600; }
.hidden { display: none !important; }
.mt-1 { margin-top: 0.5rem; }
.mt-2 { margin-top: 1rem; }
.mt-3 { margin-top: 1.5rem; }
.mb-2 { margin-bottom: 1rem; }
.mb-3 { margin-bottom: 1.5rem; }
@keyframes fadeIn { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }
.fade-in { animation: fadeIn 0.35s ease-out both; }
.fade-in-1 { animation-delay: 0.05s; }
.fade-in-2 { animation-delay: 0.1s; }
.fade-in-3 { animation-delay: 0.15s; }
.fade-in-4 { animation-delay: 0.2s; }
@keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.5; } }
.loading { animation: pulse 1.5s ease-in-out infinite; color: var(--text-dim); }
  </style>
</head>
<body>
  <div class="shell">
    <header class="topbar">
      <a href="www?page=index.html" class="topbar-brand">
        <img src="https://oandzthkyemwojhebqwc.supabase.co/storage/v1/object/public/www/capreq-icon.png" alt="CapReq" class="topbar-icon">
        <span>CapReq</span>
      </a>
      <nav class="topbar-nav">
        <a href="www?page=index.html">Dashboard</a>
        <a href="www?page=new.html">New Request</a>
      </nav>
      <span class="topbar-user" id="user-info"></span>
    </header>

    <div id="auth" class="auth-card">
      <img src="https://oandzthkyemwojhebqwc.supabase.co/storage/v1/object/public/www/capreq-icon.png" alt="CapReq" class="auth-logo">
      <h2>CapReq</h2>
      <p class="auth-tagline">Manage infrastructure capacity requests with approvals</p>
      <p>Sign in to view request details.</p>
      <div class="input-group">
        <input type="email" id="email" placeholder="you@example.com">
        <button class="btn btn-primary" onclick="signIn()">Send Link</button>
      </div>
      <p id="auth-msg" class="hidden mt-2"></p>
    </div>

    <div id="app" class="hidden">
      <div class="page-header fade-in">
        <h1>Request <span class="mono" id="req-id"></span></h1>
      </div>

      <div id="msg"></div>

      <!-- Request fields -->
      <div class="card fade-in fade-in-1 mb-3">
        <div class="card-header">
          <h3>Details</h3>
          <span id="state-badge"></span>
        </div>
        <div class="card-body">
          <div class="detail-grid" id="detail-grid">
            <div class="detail-item" style="grid-column:1/-1"><span class="loading">Loading...</span></div>
          </div>
        </div>
      </div>

      <!-- Action buttons -->
      <div class="actions fade-in fade-in-2" id="actions"></div>

      <!-- Events timeline -->
      <div class="fade-in fade-in-3 mt-3">
        <div class="section-label">Event Log</div>
        <ul class="timeline" id="timeline">
          <li class="loading">Loading events...</li>
        </ul>
      </div>
    </div>
  </div>

  <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js"></script>
  <script>
    const SUPABASE_URL = 'https://oandzthkyemwojhebqwc.supabase.co';
    const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9hbmR6dGhreWVtd29qaGVicXdjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzExMDgwNzUsImV4cCI6MjA4NjY4NDA3NX0.v7hwYm4a-b1aiWj04cCQY2WT9v08FEqvioFU3BG7nus';
  </script>
  <script>
    const sb = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

    // Read request ID from hash fragment: www?page=detail.html#id=CR-xxx
    const hashParams = new URLSearchParams(location.hash.substring(1));
    const requestId = hashParams.get('id');

    async function init() {
      if (!requestId) { document.body.innerHTML = '<div class="shell"><div class="msg msg-error mt-3">No request ID provided.</div></div>'; return; }
      document.getElementById('req-id').textContent = requestId;

      try {
        if (SUPABASE_ANON_KEY.includes('secret')) {
          showApp({ email: 'local-dev', id: 'local-dev' });
          return;
        }
        const { data: { session } } = await sb.auth.getSession();
        if (session) showApp(session.user);
        sb.auth.onAuthStateChange((_event, session) => {
          if (session) showApp(session.user);
        });
      } catch (e) {
        console.error('init error:', e);
        showApp({ email: 'fallback', id: 'fallback' });
      }
    }

    async function signIn() {
      const email = document.getElementById('email').value.trim();
      if (!email) return;
      const { error } = await sb.auth.signInWithOtp({ email });
      const msg = document.getElementById('auth-msg');
      msg.classList.remove('hidden');
      msg.className = error ? 'msg msg-error mt-2' : 'msg msg-success mt-2';
      msg.textContent = error ? error.message : 'Check your email for the magic link.';
    }

    async function showApp(user) {
      document.getElementById('auth').classList.add('hidden');
      document.getElementById('app').classList.remove('hidden');
      document.getElementById('user-info').textContent = user.email;
      window._userId = user.id || user.email;
      await loadDetail();
    }

    async function loadDetail() {
      const [reqResult, eventsResult] = await Promise.all([
        sb.from('capacity_requests').select('*').eq('id', requestId).single(),
        sb.from('capacity_request_events').select('*').eq('capacity_request_id', requestId).order('created_at', { ascending: true })
      ]);

      if (reqResult.error) {
        document.getElementById('msg').innerHTML = `<div class="msg msg-error">${reqResult.error.message}</div>`;
        return;
      }

      const r = reqResult.data;

      // State badge in card header
      document.getElementById('state-badge').innerHTML = `<span class="badge badge-${r.state}">${fmtState(r.state)}</span>`;

      const grid = document.getElementById('detail-grid');
      grid.innerHTML = `
        <div class="detail-item"><div class="detail-label">Region</div><div class="detail-value mono">${esc(r.region)}</div></div>
        <div class="detail-item"><div class="detail-label">Size</div><div class="detail-value mono">${esc(r.requested_size)}</div></div>
        <div class="detail-item"><div class="detail-label">Quantity</div><div class="detail-value">${r.quantity}</div></div>
        <div class="detail-item"><div class="detail-label">Est. Cost</div><div class="detail-value mono">${r.estimated_monthly_cost_usd != null ? '$' + Number(r.estimated_monthly_cost_usd).toLocaleString() : '\u2014'}</div></div>
        <div class="detail-item"><div class="detail-label">Needed By</div><div class="detail-value">${r.needed_by_date || '\u2014'}</div></div>
        <div class="detail-item"><div class="detail-label">Duration</div><div class="detail-value">${r.expected_duration_days ? r.expected_duration_days + ' days' : '\u2014'}</div></div>
        <div class="detail-item"><div class="detail-label">Customer</div><div class="detail-value">${r.customer_ref ? esc(r.customer_ref.name || JSON.stringify(r.customer_ref)) : '\u2014'}</div></div>
        <div class="detail-item"><div class="detail-label">Requester</div><div class="detail-value mono">${esc(r.requester_user_id)}</div></div>
        <div class="detail-item"><div class="detail-label">Commercial</div><div class="detail-value mono">${esc(r.commercial_owner_user_id) || '\u2014'}</div></div>
        <div class="detail-item"><div class="detail-label">Infra Group</div><div class="detail-value mono">${esc(r.infra_owner_group) || '\u2014'}</div></div>
        <div class="detail-item"><div class="detail-label">Created</div><div class="detail-value">${fmtDate(r.created_at)}</div></div>
        <div class="detail-item"><div class="detail-label">Updated</div><div class="detail-value">${fmtDate(r.updated_at)}</div></div>
        <div class="detail-item"><div class="detail-label">Deadline</div><div class="detail-value">${r.next_deadline_at ? fmtDate(r.next_deadline_at) : '\u2014'}</div></div>
        <div class="detail-item"><div class="detail-label">Version</div><div class="detail-value mono">${r.version}</div></div>
      `;

      // Action buttons
      const acts = document.getElementById('actions');
      acts.innerHTML = '';
      const state = r.state;

      if (state === 'UNDER_REVIEW') {
        acts.innerHTML = `
          <button class="btn btn-success" onclick="applyEvent('COMMERCIAL_APPROVED')">Commercial Approve</button>
          <button class="btn btn-danger"  onclick="applyEvent('COMMERCIAL_REJECTED')">Commercial Reject</button>
          <button class="btn btn-success" onclick="applyEvent('TECH_REVIEW_APPROVED')">Tech Approve</button>
          <button class="btn btn-danger"  onclick="applyEvent('TECH_REVIEW_REJECTED')">Tech Reject</button>
          <button class="btn btn-success" onclick="applyEvent('VP_APPROVED')">VP Approve</button>
          <button class="btn btn-danger"  onclick="applyEvent('VP_REJECTED')">VP Reject</button>
        `;
      }
      if (state === 'CUSTOMER_CONFIRMATION_REQUIRED') {
        acts.innerHTML = `
          <button class="btn btn-success" onclick="applyEvent('CUSTOMER_CONFIRMED')">Confirm</button>
          <button class="btn btn-danger"  onclick="applyEvent('CUSTOMER_DECLINED')">Decline</button>
        `;
      }
      if (!['COMPLETED', 'REJECTED', 'CANCELLED', 'EXPIRED', 'FAILED'].includes(state)) {
        acts.innerHTML += `<button class="btn btn-ghost" onclick="cancelRequest()">Cancel Request</button>`;
      }

      // Events timeline
      const tl = document.getElementById('timeline');
      if (eventsResult.error || !eventsResult.data.length) {
        tl.innerHTML = '<li>No events found.</li>';
      } else {
        tl.innerHTML = eventsResult.data.map(e => `
          <li>
            <span class="event-type">${fmtState(e.event_type)}</span>
            <span class="event-meta"> \u2014 ${e.actor_type}:${esc(e.actor_id)} at ${fmtDate(e.created_at)}</span>
            ${e.payload && Object.keys(e.payload).length ? '<div class="event-payload">' + esc(JSON.stringify(e.payload)) + '</div>' : ''}
          </li>
        `).join('');
      }
    }

    async function applyEvent(eventType, payload) {
      const msgEl = document.getElementById('msg');
      msgEl.innerHTML = '';
      const actorId = window._userId || 'web-user';
      const { data, error } = await sb.rpc('apply_capacity_event', {
        p_request_id: requestId,
        p_event_type: eventType,
        p_actor_type: 'user',
        p_actor_id: actorId,
        p_payload: payload || {}
      });
      if (error) {
        msgEl.innerHTML = `<div class="msg msg-error">${error.message}</div>`;
      } else {
        msgEl.innerHTML = `<div class="msg msg-success">Event ${fmtState(eventType)} applied.</div>`;
        await loadDetail();
      }
    }

    async function cancelRequest() {
      const reason = prompt('Cancellation reason (optional):');
      if (reason === null) return;
      await applyEvent('CANCEL_APPROVED', { reason: reason || 'Cancelled via web UI' });
    }

    function esc(s) {
      if (s == null) return '';
      const d = document.createElement('div');
      d.textContent = String(s);
      return d.innerHTML;
    }

    function fmtDate(iso) {
      if (!iso) return '\u2014';
      return new Date(iso).toLocaleDateString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
    }

    function fmtState(s) {
      return (s || '').replace(/_/g, ' ');
    }

    init();
  </script>
</body>
</html>$html$);

-- ============================================================
-- new.html
-- ============================================================
INSERT INTO static_pages (path, content) VALUES ('new.html', $html$<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>CapReq — New Request</title>
  <link rel="icon" type="image/png" href="https://oandzthkyemwojhebqwc.supabase.co/storage/v1/object/public/www/capreq-icon.png">
  <style>
/* Capacity Request — Ops Console
   Dark utilitarian aesthetic with amber accents */

@import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600;700&family=Outfit:wght@300;400;500;600;700&display=swap');

:root {
  --bg: #08080c;
  --surface: #111118;
  --surface-2: #1a1a24;
  --border: #2a2a3a;
  --border-light: #35354a;
  --text: #e8e8ed;
  --text-muted: #8888a0;
  --text-dim: #55556a;
  --accent: #f59e0b;
  --accent-dim: rgba(245, 158, 11, 0.15);
  --accent-glow: rgba(245, 158, 11, 0.3);
  --success: #22c55e;
  --success-dim: rgba(34, 197, 94, 0.12);
  --danger: #ef4444;
  --danger-dim: rgba(239, 68, 68, 0.12);
  --info: #38bdf8;
  --info-dim: rgba(56, 189, 248, 0.12);
  --warning: #eab308;
  --warning-dim: rgba(234, 179, 8, 0.12);
  --purple: #a78bfa;
  --purple-dim: rgba(167, 139, 250, 0.12);
  --mono: 'JetBrains Mono', 'SF Mono', 'Fira Code', monospace;
  --sans: 'Outfit', -apple-system, sans-serif;
  --radius: 8px;
  --radius-lg: 12px;
}

*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

body {
  font-family: var(--sans);
  background: var(--bg);
  color: var(--text);
  line-height: 1.6;
  min-height: 100vh;
  -webkit-font-smoothing: antialiased;
}

body::before {
  content: '';
  position: fixed;
  inset: 0;
  background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noise'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noise)' opacity='0.03'/%3E%3C/svg%3E");
  pointer-events: none;
  z-index: 0;
}

.shell { max-width: 1200px; margin: 0 auto; padding: 0 1.5rem; position: relative; z-index: 1; }
.topbar { display: flex; align-items: center; gap: 2rem; padding: 1rem 0; border-bottom: 1px solid var(--border); margin-bottom: 2rem; }
.topbar-brand { display: flex; align-items: center; gap: 0.6rem; margin-right: auto; text-decoration: none; color: var(--text); }
.topbar-icon { width: 24px; height: 24px; border-radius: 4px; }
.topbar-brand svg { width: 22px; height: 22px; color: var(--accent); }
.topbar-brand span { font-family: var(--mono); font-weight: 700; font-size: 0.85rem; letter-spacing: 0.08em; text-transform: uppercase; }
.topbar-nav { display: flex; gap: 0.25rem; }
.topbar-nav a { font-family: var(--mono); font-size: 0.78rem; font-weight: 500; color: var(--text-muted); text-decoration: none; padding: 0.4rem 0.75rem; border-radius: 6px; transition: all 0.2s; letter-spacing: 0.03em; }
.topbar-nav a:hover { color: var(--text); background: var(--surface-2); }
.topbar-nav a.active { color: var(--accent); background: var(--accent-dim); }
.topbar-user { font-family: var(--mono); font-size: 0.75rem; color: var(--text-dim); padding: 0.35rem 0.6rem; border: 1px solid var(--border); border-radius: 6px; }
.page-header { margin-bottom: 1.75rem; }
.page-header h1 { font-family: var(--sans); font-size: 1.5rem; font-weight: 700; letter-spacing: -0.02em; color: var(--text); }
.page-header h1 .mono { font-family: var(--mono); color: var(--accent); font-weight: 600; }
.page-header p { color: var(--text-muted); font-size: 0.9rem; margin-top: 0.25rem; }
.auth-card { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius-lg); padding: 3rem; max-width: 440px; margin: 4rem auto; text-align: center; }
.auth-logo { width: 64px; height: 64px; border-radius: 12px; margin-bottom: 1rem; }
.auth-tagline { color: var(--text-dim) !important; font-size: 0.82rem !important; margin-bottom: 1.25rem !important; }
.auth-card h2 { font-family: var(--sans); font-size: 1.25rem; font-weight: 600; margin-bottom: 0.5rem; }
.auth-card p { color: var(--text-muted); font-size: 0.9rem; margin-bottom: 1.5rem; }
.auth-card .input-group { display: flex; gap: 0.5rem; }
.auth-card input[type="email"] { flex: 1; padding: 0.65rem 0.85rem; background: var(--surface-2); border: 1px solid var(--border); border-radius: var(--radius); color: var(--text); font-family: var(--mono); font-size: 0.85rem; outline: none; transition: border-color 0.2s; }
.auth-card input[type="email"]:focus { border-color: var(--accent); box-shadow: 0 0 0 3px var(--accent-dim); }
.auth-card input[type="email"]::placeholder { color: var(--text-dim); }
.card { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius-lg); overflow: hidden; }
.card-header { display: flex; align-items: center; justify-content: space-between; padding: 0.85rem 1.25rem; border-bottom: 1px solid var(--border); background: var(--surface-2); }
.card-header h3 { font-family: var(--mono); font-size: 0.75rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.1em; color: var(--text-muted); }
.card-body { padding: 1.25rem; }
.btn { display: inline-flex; align-items: center; gap: 0.4rem; padding: 0.55rem 1rem; border: 1px solid transparent; border-radius: var(--radius); font-family: var(--sans); font-size: 0.85rem; font-weight: 600; cursor: pointer; transition: all 0.2s; text-decoration: none; white-space: nowrap; }
.btn:active { transform: scale(0.97); }
.btn-primary { background: var(--accent); color: #000; border-color: var(--accent); }
.btn-primary:hover { background: #d97706; box-shadow: 0 0 20px var(--accent-dim); }
.btn-ghost { background: transparent; color: var(--text-muted); border-color: var(--border); }
.btn-ghost:hover { color: var(--text); border-color: var(--border-light); background: var(--surface-2); }
.btn:disabled { opacity: 0.4; cursor: not-allowed; transform: none; }
.actions { display: flex; gap: 0.5rem; flex-wrap: wrap; margin-top: 1.25rem; }
.form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 0 1.5rem; }
.form-group { margin-bottom: 1.25rem; }
.form-group.full { grid-column: 1 / -1; }
.form-group label { display: block; font-family: var(--mono); font-size: 0.72rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.08em; color: var(--text-muted); margin-bottom: 0.4rem; }
.form-group input, .form-group select { width: 100%; padding: 0.6rem 0.85rem; background: var(--surface-2); border: 1px solid var(--border); border-radius: var(--radius); color: var(--text); font-family: var(--sans); font-size: 0.9rem; outline: none; transition: border-color 0.2s, box-shadow 0.2s; -webkit-appearance: none; }
.form-group select { background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='8' fill='none'%3E%3Cpath d='M1 1.5l5 5 5-5' stroke='%238888a0' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E"); background-repeat: no-repeat; background-position: right 0.85rem center; padding-right: 2.5rem; }
.form-group input:focus, .form-group select:focus { border-color: var(--accent); box-shadow: 0 0 0 3px var(--accent-dim); }
.form-group input::placeholder { color: var(--text-dim); }
.msg { padding: 0.75rem 1rem; border-radius: var(--radius); font-size: 0.875rem; margin-bottom: 1rem; border: 1px solid transparent; }
.msg-error { background: var(--danger-dim); color: #f87171; border-color: rgba(239, 68, 68, 0.2); }
.msg-success { background: var(--success-dim); color: #4ade80; border-color: rgba(34, 197, 94, 0.2); }
.msg a { color: inherit; font-weight: 600; }
.hidden { display: none !important; }
.mt-1 { margin-top: 0.5rem; }
.mt-2 { margin-top: 1rem; }
.mt-3 { margin-top: 1.5rem; }
.mb-2 { margin-bottom: 1rem; }
.mb-3 { margin-bottom: 1.5rem; }
@keyframes fadeIn { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }
.fade-in { animation: fadeIn 0.35s ease-out both; }
.fade-in-1 { animation-delay: 0.05s; }
.fade-in-2 { animation-delay: 0.1s; }
.fade-in-3 { animation-delay: 0.15s; }
@keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.5; } }
.loading { animation: pulse 1.5s ease-in-out infinite; color: var(--text-dim); }
  </style>
</head>
<body>
  <div class="shell">
    <header class="topbar">
      <a href="www?page=index.html" class="topbar-brand">
        <img src="https://oandzthkyemwojhebqwc.supabase.co/storage/v1/object/public/www/capreq-icon.png" alt="CapReq" class="topbar-icon">
        <span>CapReq</span>
      </a>
      <nav class="topbar-nav">
        <a href="www?page=index.html">Dashboard</a>
        <a href="www?page=new.html" class="active">New Request</a>
      </nav>
      <span class="topbar-user" id="user-info"></span>
    </header>

    <div id="auth" class="auth-card">
      <img src="https://oandzthkyemwojhebqwc.supabase.co/storage/v1/object/public/www/capreq-icon.png" alt="CapReq" class="auth-logo">
      <h2>CapReq</h2>
      <p class="auth-tagline">Manage infrastructure capacity requests with approvals</p>
      <p>Sign in to submit a capacity request.</p>
      <div class="input-group">
        <input type="email" id="email" placeholder="you@example.com">
        <button class="btn btn-primary" onclick="signIn()">Send Link</button>
      </div>
      <p id="auth-msg" class="hidden mt-2"></p>
    </div>

    <div id="app" class="hidden">
      <div class="page-header fade-in">
        <h1>New Request</h1>
        <p>Submit a capacity provisioning request</p>
      </div>

      <div id="msg"></div>

      <div class="card fade-in fade-in-1">
        <div class="card-header">
          <h3>Request Details</h3>
        </div>
        <div class="card-body">
          <form id="request-form" onsubmit="submitForm(event)">
            <div class="form-grid">
              <div class="form-group">
                <label for="size">Instance Size</label>
                <select id="size" required>
                  <option value="">Select size...</option>
                  <option value="8XL">8XL</option>
                  <option value="16XL">16XL</option>
                  <option value="24XL">24XL</option>
                  <option value="32XL">32XL</option>
                  <option value="48XL">48XL</option>
                </select>
              </div>
              <div class="form-group">
                <label for="region">Region</label>
                <select id="region" required>
                  <option value="">Select region...</option>
                  <option value="us-east-1">us-east-1</option>
                  <option value="us-east-2">us-east-2</option>
                  <option value="us-west-1">us-west-1</option>
                  <option value="us-west-2">us-west-2</option>
                  <option value="eu-west-1">eu-west-1</option>
                  <option value="eu-west-2">eu-west-2</option>
                  <option value="eu-central-1">eu-central-1</option>
                  <option value="ap-southeast-1">ap-southeast-1</option>
                  <option value="ap-northeast-1">ap-northeast-1</option>
                </select>
              </div>

              <div class="form-group">
                <label for="quantity">Quantity</label>
                <input type="number" id="quantity" min="1" max="100" value="1" required>
              </div>
              <div class="form-group">
                <label for="duration">Duration (days)</label>
                <input type="number" id="duration" min="1" max="365" required>
              </div>

              <div class="form-group">
                <label for="needed_by">Needed By Date</label>
                <input type="date" id="needed_by" required>
              </div>
              <div class="form-group">
                <label for="cost">Est. Monthly Cost (USD)</label>
                <input type="number" id="cost" min="0" step="0.01" placeholder="e.g. 50000">
              </div>

              <div class="form-group full">
                <label for="customer_name">Customer Name</label>
                <input type="text" id="customer_name" required placeholder="e.g. Acme Corp">
              </div>

              <div class="form-group">
                <label for="commercial_owner">Commercial Owner</label>
                <input type="text" id="commercial_owner" placeholder="User ID or email">
              </div>
              <div class="form-group">
                <label for="infra_group">Infra Group</label>
                <input type="text" id="infra_group" placeholder="e.g. infra-team">
              </div>
            </div>

            <div class="actions mt-1">
              <button type="submit" class="btn btn-primary">Submit Request</button>
              <a href="www?page=index.html" class="btn btn-ghost">Cancel</a>
            </div>
          </form>
        </div>
      </div>
    </div>
  </div>

  <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js"></script>
  <script>
    const SUPABASE_URL = 'https://oandzthkyemwojhebqwc.supabase.co';
    const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9hbmR6dGhreWVtd29qaGVicXdjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzExMDgwNzUsImV4cCI6MjA4NjY4NDA3NX0.v7hwYm4a-b1aiWj04cCQY2WT9v08FEqvioFU3BG7nus';
  </script>
  <script>
    const sb = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

    async function init() {
      try {
        if (SUPABASE_ANON_KEY.includes('secret')) {
          showApp({ email: 'local-dev', id: 'local-dev' });
          return;
        }
        const { data: { session } } = await sb.auth.getSession();
        if (session) showApp(session.user);
        sb.auth.onAuthStateChange((_event, session) => {
          if (session) showApp(session.user);
        });
      } catch (e) {
        console.error('init error:', e);
        showApp({ email: 'fallback', id: 'fallback' });
      }
    }

    async function signIn() {
      const email = document.getElementById('email').value.trim();
      if (!email) return;
      const { error } = await sb.auth.signInWithOtp({ email });
      const msg = document.getElementById('auth-msg');
      msg.classList.remove('hidden');
      msg.className = error ? 'msg msg-error mt-2' : 'msg msg-success mt-2';
      msg.textContent = error ? error.message : 'Check your email for the magic link.';
    }

    function showApp(user) {
      document.getElementById('auth').classList.add('hidden');
      document.getElementById('app').classList.remove('hidden');
      document.getElementById('user-info').textContent = user.email;
      window._userId = user.id || user.email;
    }

    async function submitForm(e) {
      e.preventDefault();
      const msgEl = document.getElementById('msg');
      msgEl.innerHTML = '';

      const userId = window._userId || 'web-user';
      const cost = document.getElementById('cost').value;

      const { data, error } = await sb.rpc('create_capacity_request', {
        p_requester_user_id: userId,
        p_commercial_owner_user_id: document.getElementById('commercial_owner').value || null,
        p_infra_owner_group: document.getElementById('infra_group').value || null,
        p_customer_ref: { name: document.getElementById('customer_name').value },
        p_requested_size: document.getElementById('size').value,
        p_quantity: parseInt(document.getElementById('quantity').value),
        p_region: document.getElementById('region').value,
        p_needed_by_date: document.getElementById('needed_by').value,
        p_expected_duration_days: parseInt(document.getElementById('duration').value),
        p_estimated_monthly_cost_usd: cost ? parseFloat(cost) : null
      });

      if (error) {
        msgEl.innerHTML = `<div class="msg msg-error">${error.message}</div>`;
        return;
      }

      const newId = data.id || (data[0] && data[0].id) || data;
      if (typeof newId === 'string' && newId.startsWith('CR-')) {
        location.href = `www?page=detail.html#id=${encodeURIComponent(newId)}`;
      } else {
        msgEl.innerHTML = `<div class="msg msg-success">Request created. <a href="www?page=index.html">Back to dashboard</a></div>`;
      }
    }

    init();
  </script>
</body>
</html>$html$);

-- ============================================================
-- confirm.html
-- ============================================================
INSERT INTO static_pages (path, content) VALUES ('confirm.html', $html$<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>CapReq — Confirm Request</title>
  <link rel="icon" type="image/png" href="https://oandzthkyemwojhebqwc.supabase.co/storage/v1/object/public/www/capreq-icon.png">
  <style>
/* Capacity Request — Ops Console
   Dark utilitarian aesthetic with amber accents */

@import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600;700&family=Outfit:wght@300;400;500;600;700&display=swap');

:root {
  --bg: #08080c;
  --surface: #111118;
  --surface-2: #1a1a24;
  --border: #2a2a3a;
  --border-light: #35354a;
  --text: #e8e8ed;
  --text-muted: #8888a0;
  --text-dim: #55556a;
  --accent: #f59e0b;
  --accent-dim: rgba(245, 158, 11, 0.15);
  --accent-glow: rgba(245, 158, 11, 0.3);
  --success: #22c55e;
  --success-dim: rgba(34, 197, 94, 0.12);
  --danger: #ef4444;
  --danger-dim: rgba(239, 68, 68, 0.12);
  --info: #38bdf8;
  --info-dim: rgba(56, 189, 248, 0.12);
  --warning: #eab308;
  --warning-dim: rgba(234, 179, 8, 0.12);
  --purple: #a78bfa;
  --purple-dim: rgba(167, 139, 250, 0.12);
  --mono: 'JetBrains Mono', 'SF Mono', 'Fira Code', monospace;
  --sans: 'Outfit', -apple-system, sans-serif;
  --radius: 8px;
  --radius-lg: 12px;
}

*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

body {
  font-family: var(--sans);
  background: var(--bg);
  color: var(--text);
  line-height: 1.6;
  min-height: 100vh;
  -webkit-font-smoothing: antialiased;
}

body::before {
  content: '';
  position: fixed;
  inset: 0;
  background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noise'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noise)' opacity='0.03'/%3E%3C/svg%3E");
  pointer-events: none;
  z-index: 0;
}

.shell { max-width: 1200px; margin: 0 auto; padding: 0 1.5rem; position: relative; z-index: 1; }
.topbar { display: flex; align-items: center; gap: 2rem; padding: 1rem 0; border-bottom: 1px solid var(--border); margin-bottom: 2rem; }
.topbar-brand { display: flex; align-items: center; gap: 0.6rem; margin-right: auto; text-decoration: none; color: var(--text); }
.topbar-icon { width: 24px; height: 24px; border-radius: 4px; }
.topbar-brand svg { width: 22px; height: 22px; color: var(--accent); }
.topbar-brand span { font-family: var(--mono); font-weight: 700; font-size: 0.85rem; letter-spacing: 0.08em; text-transform: uppercase; }
.topbar-nav { display: flex; gap: 0.25rem; }
.topbar-nav a { font-family: var(--mono); font-size: 0.78rem; font-weight: 500; color: var(--text-muted); text-decoration: none; padding: 0.4rem 0.75rem; border-radius: 6px; transition: all 0.2s; letter-spacing: 0.03em; }
.topbar-nav a:hover { color: var(--text); background: var(--surface-2); }
.topbar-nav a.active { color: var(--accent); background: var(--accent-dim); }
.topbar-user { font-family: var(--mono); font-size: 0.75rem; color: var(--text-dim); padding: 0.35rem 0.6rem; border: 1px solid var(--border); border-radius: 6px; }
.page-header { margin-bottom: 1.75rem; }
.page-header h1 { font-family: var(--sans); font-size: 1.5rem; font-weight: 700; letter-spacing: -0.02em; color: var(--text); }
.page-header p { color: var(--text-muted); font-size: 0.9rem; margin-top: 0.25rem; }
.auth-card { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius-lg); padding: 3rem; max-width: 440px; margin: 4rem auto; text-align: center; }
.auth-logo { width: 64px; height: 64px; border-radius: 12px; margin-bottom: 1rem; }
.auth-tagline { color: var(--text-dim) !important; font-size: 0.82rem !important; margin-bottom: 1.25rem !important; }
.auth-card h2 { font-family: var(--sans); font-size: 1.25rem; font-weight: 600; margin-bottom: 0.5rem; }
.auth-card p { color: var(--text-muted); font-size: 0.9rem; margin-bottom: 1.5rem; }
.auth-card .input-group { display: flex; gap: 0.5rem; }
.auth-card input[type="email"] { flex: 1; padding: 0.65rem 0.85rem; background: var(--surface-2); border: 1px solid var(--border); border-radius: var(--radius); color: var(--text); font-family: var(--mono); font-size: 0.85rem; outline: none; transition: border-color 0.2s; }
.auth-card input[type="email"]:focus { border-color: var(--accent); box-shadow: 0 0 0 3px var(--accent-dim); }
.auth-card input[type="email"]::placeholder { color: var(--text-dim); }
.card { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius-lg); overflow: hidden; }
.card-header { display: flex; align-items: center; justify-content: space-between; padding: 0.85rem 1.25rem; border-bottom: 1px solid var(--border); background: var(--surface-2); }
.card-header h3 { font-family: var(--mono); font-size: 0.75rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.1em; color: var(--text-muted); }
.card-body { padding: 1.25rem; }
.badge { display: inline-flex; align-items: center; gap: 0.35rem; padding: 0.25rem 0.6rem; border-radius: 100px; font-family: var(--mono); font-size: 0.68rem; font-weight: 600; letter-spacing: 0.04em; text-transform: uppercase; white-space: nowrap; }
.badge::before { content: ''; width: 6px; height: 6px; border-radius: 50%; flex-shrink: 0; }
.badge-SUBMITTED { background: #1e1e2e; color: #8888a0; }
.badge-SUBMITTED::before { background: #8888a0; }
.badge-UNDER_REVIEW { background: var(--info-dim); color: var(--info); }
.badge-UNDER_REVIEW::before { background: var(--info); }
.badge-CUSTOMER_CONFIRMATION_REQUIRED { background: var(--warning-dim); color: var(--warning); }
.badge-CUSTOMER_CONFIRMATION_REQUIRED::before { background: var(--warning); }
.badge-PROVISIONING { background: var(--purple-dim); color: var(--purple); }
.badge-PROVISIONING::before { background: var(--purple); }
.badge-COMPLETED { background: var(--success-dim); color: var(--success); }
.badge-COMPLETED::before { background: var(--success); }
.badge-REJECTED { background: var(--danger-dim); color: var(--danger); }
.badge-REJECTED::before { background: var(--danger); }
.badge-CANCELLED { background: #1e1e2e; color: #8888a0; }
.badge-CANCELLED::before { background: #666; }
.badge-EXPIRED { background: var(--danger-dim); color: #f87171; }
.badge-EXPIRED::before { background: #f87171; }
.badge-FAILED { background: var(--danger-dim); color: var(--danger); }
.badge-FAILED::before { background: var(--danger); }
.btn { display: inline-flex; align-items: center; gap: 0.4rem; padding: 0.55rem 1rem; border: 1px solid transparent; border-radius: var(--radius); font-family: var(--sans); font-size: 0.85rem; font-weight: 600; cursor: pointer; transition: all 0.2s; text-decoration: none; white-space: nowrap; }
.btn:active { transform: scale(0.97); }
.btn-primary { background: var(--accent); color: #000; border-color: var(--accent); }
.btn-primary:hover { background: #d97706; box-shadow: 0 0 20px var(--accent-dim); }
.btn-success { background: var(--success-dim); color: var(--success); border-color: rgba(34, 197, 94, 0.25); }
.btn-success:hover { background: rgba(34, 197, 94, 0.2); border-color: var(--success); }
.btn-danger { background: var(--danger-dim); color: var(--danger); border-color: rgba(239, 68, 68, 0.25); }
.btn-danger:hover { background: rgba(239, 68, 68, 0.2); border-color: var(--danger); }
.btn-ghost { background: transparent; color: var(--text-muted); border-color: var(--border); }
.btn-ghost:hover { color: var(--text); border-color: var(--border-light); background: var(--surface-2); }
.btn:disabled { opacity: 0.4; cursor: not-allowed; transform: none; }
.actions { display: flex; gap: 0.5rem; flex-wrap: wrap; margin-top: 1.25rem; }
.stat-row { display: flex; gap: 1rem; flex-wrap: wrap; margin-bottom: 1.5rem; }
.stat { flex: 1; min-width: 120px; padding: 1rem 1.25rem; background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius); }
.stat-label { font-family: var(--mono); font-size: 0.68rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.08em; color: var(--text-dim); margin-bottom: 0.3rem; }
.stat-value { font-size: 1.1rem; font-weight: 600; }
.stat-value.mono { font-family: var(--mono); }
.msg { padding: 0.75rem 1rem; border-radius: var(--radius); font-size: 0.875rem; margin-bottom: 1rem; border: 1px solid transparent; }
.msg-error { background: var(--danger-dim); color: #f87171; border-color: rgba(239, 68, 68, 0.2); }
.msg-success { background: var(--success-dim); color: #4ade80; border-color: rgba(34, 197, 94, 0.2); }
.msg-info { background: var(--info-dim); color: var(--info); border-color: rgba(56, 189, 248, 0.2); }
.msg a { color: inherit; font-weight: 600; }
.hidden { display: none !important; }
.mt-1 { margin-top: 0.5rem; }
.mt-2 { margin-top: 1rem; }
.mt-3 { margin-top: 1.5rem; }
.mb-2 { margin-bottom: 1rem; }
.mb-3 { margin-bottom: 1.5rem; }
@keyframes fadeIn { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }
.fade-in { animation: fadeIn 0.35s ease-out both; }
.fade-in-1 { animation-delay: 0.05s; }
.fade-in-2 { animation-delay: 0.1s; }
.fade-in-3 { animation-delay: 0.15s; }
@keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.5; } }
.loading { animation: pulse 1.5s ease-in-out infinite; color: var(--text-dim); }
  </style>
</head>
<body>
  <div class="shell">
    <header class="topbar">
      <a href="www?page=index.html" class="topbar-brand">
        <img src="https://oandzthkyemwojhebqwc.supabase.co/storage/v1/object/public/www/capreq-icon.png" alt="CapReq" class="topbar-icon">
        <span>CapReq</span>
      </a>
      <nav class="topbar-nav">
        <a href="www?page=index.html">Dashboard</a>
        <a href="www?page=new.html">New Request</a>
      </nav>
      <span class="topbar-user" id="user-info"></span>
    </header>

    <div id="auth" class="auth-card">
      <img src="https://oandzthkyemwojhebqwc.supabase.co/storage/v1/object/public/www/capreq-icon.png" alt="CapReq" class="auth-logo">
      <h2>CapReq</h2>
      <p class="auth-tagline">Manage infrastructure capacity requests with approvals</p>
      <p>Sign in to confirm or decline this request.</p>
      <div class="input-group">
        <input type="email" id="email" placeholder="you@example.com">
        <button class="btn btn-primary" onclick="signIn()">Send Link</button>
      </div>
      <p id="auth-msg" class="hidden mt-2"></p>
    </div>

    <div id="app" class="hidden">
      <div class="page-header fade-in">
        <h1>Customer Confirmation</h1>
        <p>Review and confirm the capacity request below</p>
      </div>

      <div id="msg"></div>

      <div class="card fade-in fade-in-1 mb-3">
        <div class="card-header">
          <h3>Request Summary</h3>
          <span id="state-badge"></span>
        </div>
        <div class="card-body">
          <div class="stat-row" id="stat-row">
            <div class="stat"><div class="stat-label">Loading</div><div class="stat-value loading">...</div></div>
          </div>
        </div>
      </div>

      <div class="actions fade-in fade-in-2" id="actions"></div>
    </div>
  </div>

  <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js"></script>
  <script>
    const SUPABASE_URL = 'https://oandzthkyemwojhebqwc.supabase.co';
    const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9hbmR6dGhreWVtd29qaGVicXdjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzExMDgwNzUsImV4cCI6MjA4NjY4NDA3NX0.v7hwYm4a-b1aiWj04cCQY2WT9v08FEqvioFU3BG7nus';
  </script>
  <script>
    const sb = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

    // Read request ID from hash fragment: www?page=confirm.html#id=CR-xxx
    const hashParams = new URLSearchParams(location.hash.substring(1));
    const requestId = hashParams.get('id');

    async function init() {
      if (!requestId) { document.body.innerHTML = '<div class="shell"><div class="msg msg-error mt-3">No request ID provided.</div></div>'; return; }

      try {
        if (SUPABASE_ANON_KEY.includes('secret')) {
          showApp({ email: 'local-dev', id: 'local-dev' });
          return;
        }
        const { data: { session } } = await sb.auth.getSession();
        if (session) showApp(session.user);
        sb.auth.onAuthStateChange((_event, session) => {
          if (session) showApp(session.user);
        });
      } catch (e) {
        console.error('init error:', e);
        showApp({ email: 'fallback', id: 'fallback' });
      }
    }

    async function signIn() {
      const email = document.getElementById('email').value.trim();
      if (!email) return;
      const { error } = await sb.auth.signInWithOtp({ email });
      const msg = document.getElementById('auth-msg');
      msg.classList.remove('hidden');
      msg.className = error ? 'msg msg-error mt-2' : 'msg msg-success mt-2';
      msg.textContent = error ? error.message : 'Check your email for the magic link.';
    }

    async function showApp(user) {
      document.getElementById('auth').classList.add('hidden');
      document.getElementById('app').classList.remove('hidden');
      document.getElementById('user-info').textContent = user.email;
      window._userId = user.id || user.email;
      await loadSummary();
    }

    async function loadSummary() {
      const { data: r, error } = await sb.from('capacity_requests')
        .select('*')
        .eq('id', requestId)
        .single();

      if (error) {
        document.getElementById('msg').innerHTML = `<div class="msg msg-error">${error.message}</div>`;
        return;
      }

      document.getElementById('state-badge').innerHTML = `<span class="badge badge-${r.state}">${fmtState(r.state)}</span>`;

      document.getElementById('stat-row').innerHTML = `
        <div class="stat">
          <div class="stat-label">Request ID</div>
          <div class="stat-value mono">${esc(r.id)}</div>
        </div>
        <div class="stat">
          <div class="stat-label">Size</div>
          <div class="stat-value mono">${esc(r.requested_size)}</div>
        </div>
        <div class="stat">
          <div class="stat-label">Region</div>
          <div class="stat-value mono">${esc(r.region)}</div>
        </div>
        <div class="stat">
          <div class="stat-label">Quantity</div>
          <div class="stat-value">${r.quantity}</div>
        </div>
        <div class="stat">
          <div class="stat-label">Est. Cost</div>
          <div class="stat-value mono">${r.estimated_monthly_cost_usd != null ? '$' + Number(r.estimated_monthly_cost_usd).toLocaleString() : '\u2014'}</div>
        </div>
        <div class="stat">
          <div class="stat-label">Needed By</div>
          <div class="stat-value">${r.needed_by_date || '\u2014'}</div>
        </div>
        <div class="stat">
          <div class="stat-label">Deadline</div>
          <div class="stat-value">${r.next_deadline_at ? fmtDate(r.next_deadline_at) : '\u2014'}</div>
        </div>
      `;

      const acts = document.getElementById('actions');
      if (r.state === 'CUSTOMER_CONFIRMATION_REQUIRED') {
        acts.innerHTML = `
          <button class="btn btn-success" onclick="respond('CUSTOMER_CONFIRMED')">Confirm</button>
          <button class="btn btn-danger"  onclick="respond('CUSTOMER_DECLINED')">Decline</button>
        `;
      } else {
        acts.innerHTML = `<div class="msg msg-info">This request is in state <strong>${fmtState(r.state)}</strong> and cannot be confirmed or declined.</div>`;
      }
    }

    async function respond(eventType) {
      const msgEl = document.getElementById('msg');
      msgEl.innerHTML = '';
      const actorId = window._userId || 'web-user';

      const { data, error } = await sb.rpc('apply_capacity_event', {
        p_request_id: requestId,
        p_event_type: eventType,
        p_actor_type: 'user',
        p_actor_id: actorId,
        p_payload: {}
      });
      if (error) {
        msgEl.innerHTML = `<div class="msg msg-error">${error.message}</div>`;
      } else {
        const label = eventType === 'CUSTOMER_CONFIRMED' ? 'confirmed' : 'declined';
        msgEl.innerHTML = `<div class="msg msg-success">Request ${label}. <a href="www?page=detail.html#id=${encodeURIComponent(requestId)}">View details</a></div>`;
        document.getElementById('actions').innerHTML = '';
        await loadSummary();
      }
    }

    function esc(s) {
      if (s == null) return '';
      const d = document.createElement('div');
      d.textContent = String(s);
      return d.innerHTML;
    }

    function fmtDate(iso) {
      if (!iso) return '\u2014';
      return new Date(iso).toLocaleDateString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
    }

    function fmtState(s) {
      return (s || '').replace(/_/g, ' ');
    }

    init();
  </script>
</body>
</html>$html$);
