-- Migration: Update static_pages with Phase 6b UI changes
-- Updates all existing pages and adds queue.html + analytics.html
-- Transformations: CSS inlined, config.js inlined, image URLs rewritten,
-- inter-page links use www?page= format, params use hash fragments.

DELETE FROM static_pages;

-- ============================================================
-- index.html
-- ============================================================
INSERT INTO static_pages (path, content) VALUES ('index.html', $page$<!DOCTYPE html>
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

/* ─── Top Bar ──────────────────────────────────── */

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
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-family: var(--mono);
  font-size: 0.75rem;
  color: var(--text-dim);
  padding: 0.35rem 0.6rem;
  border: 1px solid var(--border);
  border-radius: 6px;
}

.topbar-signout {
  color: var(--text-dim);
  cursor: pointer;
  opacity: 0.6;
  transition: opacity 0.2s, color 0.2s;
  background: none;
  border: none;
  font-family: var(--mono);
  font-size: 0.7rem;
  padding: 0;
}

.topbar-signout:hover {
  opacity: 1;
  color: var(--danger);
}

/* ─── Page Header ──────────────────────────────── */

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

/* ─── Auth Card ────────────────────────────────── */

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

/* ─── Cards & Panels ──────────────────────────── */

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

/* ─── Data Table ───────────────────────────────── */

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

/* ─── State Badges ─────────────────────────────── */

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

/* ─── Buttons ──────────────────────────────────── */

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

.btn-slack {
  width: 100%;
  justify-content: center;
  gap: 0.6rem;
  font-size: 0.9rem;
  padding: 0.7rem 1.25rem;
}

.btn-slack svg {
  width: 20px;
  height: 20px;
  flex-shrink: 0;
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

/* ─── Detail Grid ──────────────────────────────── */

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

/* ─── Timeline ─────────────────────────────────── */

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

/* ─── Forms ────────────────────────────────────── */

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

/* ─── Messages ─────────────────────────────────── */

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

/* ─── Section Dividers ─────────────────────────── */

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

/* ─── Stat Pills (confirm page) ────────────────── */

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

/* ─── Footer ──────────────────────────────────── */

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

/* ─── Utilities ────────────────────────────────── */

.hidden { display: none !important; }

.mt-1 { margin-top: 0.5rem; }
.mt-2 { margin-top: 1rem; }
.mt-3 { margin-top: 1.5rem; }
.mb-2 { margin-bottom: 1rem; }
.mb-3 { margin-bottom: 1.5rem; }

/* ─── Animations ───────────────────────────────── */

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

/* ─── Workflow Stepper ────────────────────────── */

.stepper {
  display: flex;
  align-items: flex-start;
  gap: 0;
  overflow-x: auto;
  padding: 1rem 0.5rem 0.5rem;
}

.stepper-stage {
  display: flex;
  flex-direction: column;
  align-items: center;
  position: relative;
  flex: 1;
  min-width: 0;
}

.stepper-row {
  display: flex;
  align-items: center;
  width: 100%;
}

.stepper-connector {
  flex: 1;
  height: 2px;
  background: var(--border);
  min-width: 8px;
}

.stepper-connector.completed {
  background: var(--success);
}

.stepper-connector.invisible {
  visibility: hidden;
}

.stepper-node {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  font-size: 0.7rem;
  font-weight: 700;
  border: 2px solid var(--border);
  background: var(--surface);
  color: var(--text-dim);
  transition: all 0.3s;
}

.stepper-node.completed {
  border-color: var(--success);
  background: var(--success-dim);
  color: var(--success);
}

.stepper-node.active {
  border-color: var(--accent);
  background: var(--accent-dim);
  color: var(--accent);
  box-shadow: 0 0 12px var(--accent-glow), 0 0 24px rgba(245, 158, 11, 0.1);
  animation: stepperPulse 2s ease-in-out infinite;
}

.stepper-node.failed {
  border-color: var(--danger);
  background: var(--danger-dim);
  color: var(--danger);
}

.stepper-label {
  margin-top: 0.4rem;
  font-family: var(--mono);
  font-size: 0.62rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--text-dim);
  text-align: center;
  white-space: nowrap;
}

.stepper-label.completed { color: var(--success); }
.stepper-label.active    { color: var(--accent); }
.stepper-label.failed    { color: var(--danger); }

@keyframes stepperPulse {
  0%, 100% { box-shadow: 0 0 12px var(--accent-glow), 0 0 24px rgba(245, 158, 11, 0.1); }
  50%      { box-shadow: 0 0 18px var(--accent-glow), 0 0 36px rgba(245, 158, 11, 0.2); }
}

/* Approval sub-checks shown below stepper for UNDER_REVIEW */
.approval-checks {
  display: flex;
  gap: 1.25rem;
  flex-wrap: wrap;
  padding: 0.75rem 0 0;
  margin-top: 0.75rem;
  border-top: 1px solid var(--border);
}

.approval-check {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  font-family: var(--mono);
  font-size: 0.72rem;
  font-weight: 500;
  color: var(--text-muted);
}

.approval-check .check-icon {
  width: 16px;
  height: 16px;
  border-radius: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.6rem;
  font-weight: 700;
}

.approval-check .check-icon.done {
  background: var(--success-dim);
  color: var(--success);
  border: 1px solid rgba(34, 197, 94, 0.3);
}

.approval-check .check-icon.pending {
  background: var(--surface-2);
  color: var(--text-dim);
  border: 1px solid var(--border);
}

/* Operator guidance banner */
.guidance-banner {
  padding: 0.75rem 1rem;
  border-radius: var(--radius);
  font-size: 0.85rem;
  line-height: 1.5;
  margin-bottom: 1rem;
  border: 1px solid transparent;
}

.guidance-info {
  background: var(--info-dim);
  color: var(--info);
  border-color: rgba(56, 189, 248, 0.2);
}

.guidance-success {
  background: var(--success-dim);
  color: #4ade80;
  border-color: rgba(34, 197, 94, 0.2);
}

.guidance-error {
  background: var(--danger-dim);
  color: #f87171;
  border-color: rgba(239, 68, 68, 0.2);
}

.guidance-muted {
  background: #1e1e2e;
  color: #8888a0;
  border-color: rgba(42, 42, 58, 0.5);
}

/* ─── Filter Bar ──────────────────────────────── */

.filter-bar {
  display: flex;
  gap: 0.75rem;
  align-items: flex-end;
  flex-wrap: wrap;
  padding: 0.85rem 1.25rem;
  border-bottom: 1px solid var(--border);
  background: var(--surface-2);
}

.filter-group {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.filter-group label {
  font-family: var(--mono);
  font-size: 0.68rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--text-dim);
}

.filter-group select,
.filter-group input {
  padding: 0.4rem 0.65rem;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  color: var(--text);
  font-family: var(--sans);
  font-size: 0.82rem;
  outline: none;
  transition: border-color 0.2s, box-shadow 0.2s;
  -webkit-appearance: none;
}

.filter-group select {
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='8' fill='none'%3E%3Cpath d='M1 1.5l5 5 5-5' stroke='%238888a0' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 0.65rem center;
  padding-right: 2rem;
}

.filter-group select:focus,
.filter-group input:focus {
  border-color: var(--accent);
  box-shadow: 0 0 0 3px var(--accent-dim);
}

.filter-group input::placeholder {
  color: var(--text-dim);
}

.filter-actions {
  display: flex;
  align-items: flex-end;
}

.filter-actions .btn {
  padding: 0.4rem 0.65rem;
  font-size: 0.78rem;
}

/* ─── Age Indicators ──────────────────────────── */

.age-green td:first-child { border-left: 3px solid var(--success); }
.age-amber td:first-child { border-left: 3px solid var(--warning); }
.age-red td:first-child   { border-left: 3px solid var(--danger); }

/* ─── Event Notes in Timeline ─────────────────── */

.event-notes {
  margin-top: 0.35rem;
  font-size: 0.8rem;
  font-style: italic;
  color: var(--text-muted);
  background: var(--surface-2);
  padding: 0.35rem 0.6rem;
  border-radius: 4px;
  border-left: 3px solid var(--warning);
}

/* ─── Queue Page ──────────────────────────────── */

.queue-table {
  width: 100%;
  border-collapse: collapse;
}

.queue-table th {
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

.queue-table td {
  padding: 0.7rem 1rem;
  font-size: 0.875rem;
  border-bottom: 1px solid rgba(42, 42, 58, 0.5);
}

.queue-table tbody tr:last-child td {
  border-bottom: none;
}

.queue-actions {
  display: flex;
  gap: 0.35rem;
}

.queue-actions .btn {
  padding: 0.3rem 0.6rem;
  font-size: 0.75rem;
}

.badge-count {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 18px;
  height: 18px;
  padding: 0 5px;
  border-radius: 100px;
  font-family: var(--mono);
  font-size: 0.65rem;
  font-weight: 700;
  background: var(--accent);
  color: #000;
}

.empty-state {
  text-align: center;
  padding: 3rem 1rem;
  color: var(--text-dim);
}

.empty-state svg {
  width: 48px;
  height: 48px;
  margin-bottom: 1rem;
  opacity: 0.3;
}

.empty-state p {
  font-size: 0.9rem;
}

/* ─── Nav Badge ───────────────────────────────── */

.nav-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 16px;
  height: 16px;
  padding: 0 4px;
  border-radius: 100px;
  font-family: var(--mono);
  font-size: 0.6rem;
  font-weight: 700;
  background: var(--accent);
  color: #000;
  margin-left: 0.25rem;
  vertical-align: middle;
}

.nav-badge:empty { display: none; }

/* ─── Analytics Page ──────────────────────────── */

.chart-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.25rem;
}

.chart-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  overflow: hidden;
}

.chart-card .card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.85rem 1.25rem;
  border-bottom: 1px solid var(--border);
  background: var(--surface-2);
}

.chart-card .card-header h3 {
  font-family: var(--mono);
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  color: var(--text-muted);
}

.chart-card .card-body {
  padding: 1.25rem;
  height: 280px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.chart-card canvas {
  width: 100% !important;
  height: 100% !important;
}

/* ─── Textarea ────────────────────────────────── */

.form-group textarea {
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
  resize: vertical;
}

.form-group textarea:focus {
  border-color: var(--accent);
  box-shadow: 0 0 0 3px var(--accent-dim);
}

.form-group textarea::placeholder {
  color: var(--text-dim);
}

/* ─── SLA Badges ──────────────────────────────── */

.sla-ok      { color: var(--success); }
.sla-at_risk { color: var(--warning); }
.sla-breached { color: var(--danger); }

/* ─── Responsive ──────────────────────────────── */

@media (max-width: 768px) {
  .shell {
    padding: 0 0.75rem;
  }

  .topbar {
    flex-wrap: wrap;
  }

  .topbar-brand {
    margin-right: auto;
  }

  .topbar-nav {
    order: 3;
    width: 100%;
    overflow-x: auto;
    padding-top: 0.5rem;
  }

  .form-grid,
  .detail-grid {
    grid-template-columns: 1fr;
  }

  .detail-item:nth-child(odd) {
    border-right: none;
  }

  .data-table,
  .queue-table {
    display: block;
    overflow-x: auto;
  }

  .stat-row {
    flex-wrap: wrap;
  }

  .stat-row .stat {
    min-width: calc(50% - 0.5rem);
    flex: 0 0 calc(50% - 0.5rem);
  }

  .chart-grid {
    grid-template-columns: 1fr;
  }

  .filter-bar {
    flex-direction: column;
    align-items: stretch;
  }

  .filter-group {
    width: 100%;
  }

  .filter-group select,
  .filter-group input {
    width: 100%;
  }

  .auth-card {
    margin: 2rem 0.5rem;
    padding: 2rem 1.5rem;
  }
}

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
        <a href="www?page=queue.html">Queue <span class="nav-badge" id="queue-badge"></span></a>
        <a href="www?page=analytics.html">Analytics</a>
      </nav>
      <span class="topbar-user"><span id="user-info"></span><button class="topbar-signout" onclick="signOut()" title="Sign out">Sign out</button></span>
    </header>

    <div id="auth" class="auth-card">
      <img src="https://oandzthkyemwojhebqwc.supabase.co/storage/v1/object/public/www/capreq-icon.png" alt="CapReq" class="auth-logo">
      <h2>CapReq</h2>
      <p class="auth-tagline">Manage infrastructure capacity requests with approvals</p>
      <p>Sign in with your Slack workspace account.</p>
      <button class="btn btn-primary btn-slack" onclick="signInWithSlack()">
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor"><path d="M5.042 15.165a2.528 2.528 0 0 1-2.52 2.523A2.528 2.528 0 0 1 0 15.165a2.527 2.527 0 0 1 2.522-2.52h2.52v2.52zm1.271 0a2.527 2.527 0 0 1 2.521-2.52 2.527 2.527 0 0 1 2.521 2.52v6.313A2.528 2.528 0 0 1 8.834 24a2.528 2.528 0 0 1-2.521-2.522v-6.313zM8.834 5.042a2.528 2.528 0 0 1-2.521-2.52A2.528 2.528 0 0 1 8.834 0a2.528 2.528 0 0 1 2.521 2.522v2.52H8.834zm0 1.271a2.528 2.528 0 0 1 2.521 2.521 2.528 2.528 0 0 1-2.521 2.521H2.522A2.528 2.528 0 0 1 0 8.834a2.528 2.528 0 0 1 2.522-2.521h6.312zM18.956 8.834a2.528 2.528 0 0 1 2.522-2.521A2.528 2.528 0 0 1 24 8.834a2.528 2.528 0 0 1-2.522 2.521h-2.522V8.834zm-1.27 0a2.528 2.528 0 0 1-2.523 2.521 2.527 2.527 0 0 1-2.52-2.521V2.522A2.527 2.527 0 0 1 15.163 0a2.528 2.528 0 0 1 2.523 2.522v6.312zM15.163 18.956a2.528 2.528 0 0 1 2.523 2.522A2.528 2.528 0 0 1 15.163 24a2.527 2.527 0 0 1-2.52-2.522v-2.522h2.52zm0-1.27a2.527 2.527 0 0 1-2.52-2.523 2.527 2.527 0 0 1 2.52-2.52h6.315A2.528 2.528 0 0 1 24 15.165a2.528 2.528 0 0 1-2.522 2.523h-6.315z"/></svg>
        Sign in with Slack
      </button>
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
        <div class="filter-bar">
          <div class="filter-group">
            <label for="filter-state">State</label>
            <select id="filter-state">
              <option value="">All</option>
              <option value="SUBMITTED">Submitted</option>
              <option value="UNDER_REVIEW">Under Review</option>
              <option value="CUSTOMER_CONFIRMATION_REQUIRED">Customer Confirmation</option>
              <option value="PROVISIONING">Provisioning</option>
              <option value="COMPLETED">Completed</option>
              <option value="REJECTED">Rejected</option>
              <option value="CANCELLED">Cancelled</option>
              <option value="EXPIRED">Expired</option>
              <option value="FAILED">Failed</option>
            </select>
          </div>
          <div class="filter-group">
            <label for="filter-region">Region</label>
            <select id="filter-region">
              <option value="">All</option>
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
          <div class="filter-group">
            <label for="filter-search">Search</label>
            <input type="text" id="filter-search" placeholder="ID or customer...">
          </div>
          <div class="filter-group">
            <label for="filter-range">Date Range</label>
            <select id="filter-range">
              <option value="">All time</option>
              <option value="7">Last 7 days</option>
              <option value="30">Last 30 days</option>
              <option value="90">Last 90 days</option>
            </select>
          </div>
          <div class="filter-actions">
            <button class="btn btn-ghost" onclick="clearFilters()">Clear</button>
          </div>
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
    let allRequests = [];
    const TERMINAL_STATES = ['COMPLETED', 'REJECTED', 'CANCELLED', 'EXPIRED', 'FAILED'];

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

    async function signInWithSlack() {
      const { data, error } = await sb.auth.signInWithOAuth({
        provider: 'slack_oidc',
        options: { redirectTo: window.location.href }
      });
      if (error) {
        const msg = document.getElementById('auth-msg');
        msg.classList.remove('hidden');
        msg.className = 'msg msg-error mt-2';
        msg.textContent = error.message;
      }
    }

    async function signOut() {
      await sb.auth.signOut();
      location.reload();
    }

    function getSlackUserId(user) {
      if (user.user_metadata?.provider_id) return user.user_metadata.provider_id;
      const slack = user.identities?.find(i => i.provider === 'slack_oidc');
      if (slack?.identity_data?.provider_id) return slack.identity_data.provider_id;
      if (user.user_metadata?.sub) return user.user_metadata.sub;
      return user.id || user.email;
    }

    async function showApp(user) {
      document.getElementById('auth').classList.add('hidden');
      document.getElementById('app').classList.remove('hidden');
      const displayName = user.user_metadata?.name || user.user_metadata?.full_name || user.email;
      document.getElementById('user-info').textContent = displayName;
      window._userId = getSlackUserId(user);
      initFilters();
      await loadRequests();
      loadQueueBadge();
    }

    function initFilters() {
      const p = new URLSearchParams(location.hash.substring(1));
      if (p.get('state')) document.getElementById('filter-state').value = p.get('state');
      if (p.get('region')) document.getElementById('filter-region').value = p.get('region');
      if (p.get('q')) document.getElementById('filter-search').value = p.get('q');
      if (p.get('range')) document.getElementById('filter-range').value = p.get('range');

      document.getElementById('filter-state').addEventListener('change', applyFilters);
      document.getElementById('filter-region').addEventListener('change', applyFilters);
      document.getElementById('filter-search').addEventListener('input', applyFilters);
      document.getElementById('filter-range').addEventListener('change', applyFilters);
    }

    function applyFilters() {
      const state = document.getElementById('filter-state').value;
      const region = document.getElementById('filter-region').value;
      const q = document.getElementById('filter-search').value.trim().toLowerCase();
      const range = document.getElementById('filter-range').value;

      const p = new URLSearchParams();
      if (state) p.set('state', state);
      if (region) p.set('region', region);
      if (q) p.set('q', q);
      if (range) p.set('range', range);
      const qs = p.toString();
      history.replaceState(null, '', location.pathname + location.search + (qs ? '#' + qs : ''));

      renderRequests(filterRequests(state, region, q, range));
    }

    function filterRequests(state, region, q, range) {
      let filtered = allRequests;
      if (state) filtered = filtered.filter(r => r.state === state);
      if (region) filtered = filtered.filter(r => r.region === region);
      if (q) {
        filtered = filtered.filter(r => {
          const id = (r.id || '').toLowerCase();
          const name = (r.customer_ref && r.customer_ref.name ? r.customer_ref.name : '').toLowerCase();
          return id.includes(q) || name.includes(q);
        });
      }
      if (range) {
        const cutoff = new Date();
        cutoff.setDate(cutoff.getDate() - parseInt(range));
        filtered = filtered.filter(r => new Date(r.created_at) >= cutoff);
      }
      return filtered;
    }

    function clearFilters() {
      document.getElementById('filter-state').value = '';
      document.getElementById('filter-region').value = '';
      document.getElementById('filter-search').value = '';
      document.getElementById('filter-range').value = '';
      history.replaceState(null, '', location.pathname + location.search);
      renderRequests(allRequests);
    }

    function getAgeClass(r) {
      if (TERMINAL_STATES.includes(r.state)) return '';
      const hours = (Date.now() - new Date(r.created_at).getTime()) / 3600000;
      if (hours < 24) return 'age-green';
      if (hours < 72) return 'age-amber';
      return 'age-red';
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
      allRequests = data || [];
      applyFilters();
    }

    function renderRequests(data) {
      const tbody = document.getElementById('requests-body');
      if (!data || data.length === 0) {
        tbody.innerHTML = '<tr class="empty-row"><td colspan="8">No requests found.</td></tr>';
        return;
      }
      tbody.innerHTML = data.map(r => `
        <tr class="${getAgeClass(r)}" onclick="location.href='www?page=detail.html#id=${encodeURIComponent(r.id)}'">
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

    async function loadQueueBadge() {
      try {
        const userId = window._userId || 'web-user';
        const { data, error } = await sb.rpc('get_my_pending_actions', { p_user_id: userId });
        if (!error && data && data.length > 0) {
          document.getElementById('queue-badge').textContent = data.length;
        }
      } catch (e) {
        // Queue badge is non-critical
      }
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
</html>
$page$);

-- ============================================================
-- detail.html
-- ============================================================
INSERT INTO static_pages (path, content) VALUES ('detail.html', $page$<!DOCTYPE html>
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

/* ─── Top Bar ──────────────────────────────────── */

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
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-family: var(--mono);
  font-size: 0.75rem;
  color: var(--text-dim);
  padding: 0.35rem 0.6rem;
  border: 1px solid var(--border);
  border-radius: 6px;
}

.topbar-signout {
  color: var(--text-dim);
  cursor: pointer;
  opacity: 0.6;
  transition: opacity 0.2s, color 0.2s;
  background: none;
  border: none;
  font-family: var(--mono);
  font-size: 0.7rem;
  padding: 0;
}

.topbar-signout:hover {
  opacity: 1;
  color: var(--danger);
}

/* ─── Page Header ──────────────────────────────── */

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

/* ─── Auth Card ────────────────────────────────── */

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

/* ─── Cards & Panels ──────────────────────────── */

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

/* ─── Data Table ───────────────────────────────── */

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

/* ─── State Badges ─────────────────────────────── */

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

/* ─── Buttons ──────────────────────────────────── */

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

.btn-slack {
  width: 100%;
  justify-content: center;
  gap: 0.6rem;
  font-size: 0.9rem;
  padding: 0.7rem 1.25rem;
}

.btn-slack svg {
  width: 20px;
  height: 20px;
  flex-shrink: 0;
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

/* ─── Detail Grid ──────────────────────────────── */

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

/* ─── Timeline ─────────────────────────────────── */

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

/* ─── Forms ────────────────────────────────────── */

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

/* ─── Messages ─────────────────────────────────── */

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

/* ─── Section Dividers ─────────────────────────── */

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

/* ─── Stat Pills (confirm page) ────────────────── */

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

/* ─── Footer ──────────────────────────────────── */

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

/* ─── Utilities ────────────────────────────────── */

.hidden { display: none !important; }

.mt-1 { margin-top: 0.5rem; }
.mt-2 { margin-top: 1rem; }
.mt-3 { margin-top: 1.5rem; }
.mb-2 { margin-bottom: 1rem; }
.mb-3 { margin-bottom: 1.5rem; }

/* ─── Animations ───────────────────────────────── */

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

/* ─── Workflow Stepper ────────────────────────── */

.stepper {
  display: flex;
  align-items: flex-start;
  gap: 0;
  overflow-x: auto;
  padding: 1rem 0.5rem 0.5rem;
}

.stepper-stage {
  display: flex;
  flex-direction: column;
  align-items: center;
  position: relative;
  flex: 1;
  min-width: 0;
}

.stepper-row {
  display: flex;
  align-items: center;
  width: 100%;
}

.stepper-connector {
  flex: 1;
  height: 2px;
  background: var(--border);
  min-width: 8px;
}

.stepper-connector.completed {
  background: var(--success);
}

.stepper-connector.invisible {
  visibility: hidden;
}

.stepper-node {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  font-size: 0.7rem;
  font-weight: 700;
  border: 2px solid var(--border);
  background: var(--surface);
  color: var(--text-dim);
  transition: all 0.3s;
}

.stepper-node.completed {
  border-color: var(--success);
  background: var(--success-dim);
  color: var(--success);
}

.stepper-node.active {
  border-color: var(--accent);
  background: var(--accent-dim);
  color: var(--accent);
  box-shadow: 0 0 12px var(--accent-glow), 0 0 24px rgba(245, 158, 11, 0.1);
  animation: stepperPulse 2s ease-in-out infinite;
}

.stepper-node.failed {
  border-color: var(--danger);
  background: var(--danger-dim);
  color: var(--danger);
}

.stepper-label {
  margin-top: 0.4rem;
  font-family: var(--mono);
  font-size: 0.62rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--text-dim);
  text-align: center;
  white-space: nowrap;
}

.stepper-label.completed { color: var(--success); }
.stepper-label.active    { color: var(--accent); }
.stepper-label.failed    { color: var(--danger); }

@keyframes stepperPulse {
  0%, 100% { box-shadow: 0 0 12px var(--accent-glow), 0 0 24px rgba(245, 158, 11, 0.1); }
  50%      { box-shadow: 0 0 18px var(--accent-glow), 0 0 36px rgba(245, 158, 11, 0.2); }
}

/* Approval sub-checks shown below stepper for UNDER_REVIEW */
.approval-checks {
  display: flex;
  gap: 1.25rem;
  flex-wrap: wrap;
  padding: 0.75rem 0 0;
  margin-top: 0.75rem;
  border-top: 1px solid var(--border);
}

.approval-check {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  font-family: var(--mono);
  font-size: 0.72rem;
  font-weight: 500;
  color: var(--text-muted);
}

.approval-check .check-icon {
  width: 16px;
  height: 16px;
  border-radius: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.6rem;
  font-weight: 700;
}

.approval-check .check-icon.done {
  background: var(--success-dim);
  color: var(--success);
  border: 1px solid rgba(34, 197, 94, 0.3);
}

.approval-check .check-icon.pending {
  background: var(--surface-2);
  color: var(--text-dim);
  border: 1px solid var(--border);
}

/* Operator guidance banner */
.guidance-banner {
  padding: 0.75rem 1rem;
  border-radius: var(--radius);
  font-size: 0.85rem;
  line-height: 1.5;
  margin-bottom: 1rem;
  border: 1px solid transparent;
}

.guidance-info {
  background: var(--info-dim);
  color: var(--info);
  border-color: rgba(56, 189, 248, 0.2);
}

.guidance-success {
  background: var(--success-dim);
  color: #4ade80;
  border-color: rgba(34, 197, 94, 0.2);
}

.guidance-error {
  background: var(--danger-dim);
  color: #f87171;
  border-color: rgba(239, 68, 68, 0.2);
}

.guidance-muted {
  background: #1e1e2e;
  color: #8888a0;
  border-color: rgba(42, 42, 58, 0.5);
}

/* ─── Filter Bar ──────────────────────────────── */

.filter-bar {
  display: flex;
  gap: 0.75rem;
  align-items: flex-end;
  flex-wrap: wrap;
  padding: 0.85rem 1.25rem;
  border-bottom: 1px solid var(--border);
  background: var(--surface-2);
}

.filter-group {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.filter-group label {
  font-family: var(--mono);
  font-size: 0.68rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--text-dim);
}

.filter-group select,
.filter-group input {
  padding: 0.4rem 0.65rem;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  color: var(--text);
  font-family: var(--sans);
  font-size: 0.82rem;
  outline: none;
  transition: border-color 0.2s, box-shadow 0.2s;
  -webkit-appearance: none;
}

.filter-group select {
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='8' fill='none'%3E%3Cpath d='M1 1.5l5 5 5-5' stroke='%238888a0' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 0.65rem center;
  padding-right: 2rem;
}

.filter-group select:focus,
.filter-group input:focus {
  border-color: var(--accent);
  box-shadow: 0 0 0 3px var(--accent-dim);
}

.filter-group input::placeholder {
  color: var(--text-dim);
}

.filter-actions {
  display: flex;
  align-items: flex-end;
}

.filter-actions .btn {
  padding: 0.4rem 0.65rem;
  font-size: 0.78rem;
}

/* ─── Age Indicators ──────────────────────────── */

.age-green td:first-child { border-left: 3px solid var(--success); }
.age-amber td:first-child { border-left: 3px solid var(--warning); }
.age-red td:first-child   { border-left: 3px solid var(--danger); }

/* ─── Event Notes in Timeline ─────────────────── */

.event-notes {
  margin-top: 0.35rem;
  font-size: 0.8rem;
  font-style: italic;
  color: var(--text-muted);
  background: var(--surface-2);
  padding: 0.35rem 0.6rem;
  border-radius: 4px;
  border-left: 3px solid var(--warning);
}

/* ─── Queue Page ──────────────────────────────── */

.queue-table {
  width: 100%;
  border-collapse: collapse;
}

.queue-table th {
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

.queue-table td {
  padding: 0.7rem 1rem;
  font-size: 0.875rem;
  border-bottom: 1px solid rgba(42, 42, 58, 0.5);
}

.queue-table tbody tr:last-child td {
  border-bottom: none;
}

.queue-actions {
  display: flex;
  gap: 0.35rem;
}

.queue-actions .btn {
  padding: 0.3rem 0.6rem;
  font-size: 0.75rem;
}

.badge-count {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 18px;
  height: 18px;
  padding: 0 5px;
  border-radius: 100px;
  font-family: var(--mono);
  font-size: 0.65rem;
  font-weight: 700;
  background: var(--accent);
  color: #000;
}

.empty-state {
  text-align: center;
  padding: 3rem 1rem;
  color: var(--text-dim);
}

.empty-state svg {
  width: 48px;
  height: 48px;
  margin-bottom: 1rem;
  opacity: 0.3;
}

.empty-state p {
  font-size: 0.9rem;
}

/* ─── Nav Badge ───────────────────────────────── */

.nav-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 16px;
  height: 16px;
  padding: 0 4px;
  border-radius: 100px;
  font-family: var(--mono);
  font-size: 0.6rem;
  font-weight: 700;
  background: var(--accent);
  color: #000;
  margin-left: 0.25rem;
  vertical-align: middle;
}

.nav-badge:empty { display: none; }

/* ─── Analytics Page ──────────────────────────── */

.chart-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.25rem;
}

.chart-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  overflow: hidden;
}

.chart-card .card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.85rem 1.25rem;
  border-bottom: 1px solid var(--border);
  background: var(--surface-2);
}

.chart-card .card-header h3 {
  font-family: var(--mono);
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  color: var(--text-muted);
}

.chart-card .card-body {
  padding: 1.25rem;
  height: 280px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.chart-card canvas {
  width: 100% !important;
  height: 100% !important;
}

/* ─── Textarea ────────────────────────────────── */

.form-group textarea {
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
  resize: vertical;
}

.form-group textarea:focus {
  border-color: var(--accent);
  box-shadow: 0 0 0 3px var(--accent-dim);
}

.form-group textarea::placeholder {
  color: var(--text-dim);
}

/* ─── SLA Badges ──────────────────────────────── */

.sla-ok      { color: var(--success); }
.sla-at_risk { color: var(--warning); }
.sla-breached { color: var(--danger); }

/* ─── Responsive ──────────────────────────────── */

@media (max-width: 768px) {
  .shell {
    padding: 0 0.75rem;
  }

  .topbar {
    flex-wrap: wrap;
  }

  .topbar-brand {
    margin-right: auto;
  }

  .topbar-nav {
    order: 3;
    width: 100%;
    overflow-x: auto;
    padding-top: 0.5rem;
  }

  .form-grid,
  .detail-grid {
    grid-template-columns: 1fr;
  }

  .detail-item:nth-child(odd) {
    border-right: none;
  }

  .data-table,
  .queue-table {
    display: block;
    overflow-x: auto;
  }

  .stat-row {
    flex-wrap: wrap;
  }

  .stat-row .stat {
    min-width: calc(50% - 0.5rem);
    flex: 0 0 calc(50% - 0.5rem);
  }

  .chart-grid {
    grid-template-columns: 1fr;
  }

  .filter-bar {
    flex-direction: column;
    align-items: stretch;
  }

  .filter-group {
    width: 100%;
  }

  .filter-group select,
  .filter-group input {
    width: 100%;
  }

  .auth-card {
    margin: 2rem 0.5rem;
    padding: 2rem 1.5rem;
  }
}

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
        <a href="www?page=queue.html">Queue <span class="nav-badge" id="queue-badge"></span></a>
        <a href="www?page=analytics.html">Analytics</a>
      </nav>
      <span class="topbar-user"><span id="user-info"></span><button class="topbar-signout" onclick="signOut()" title="Sign out">Sign out</button></span>
    </header>

    <div id="auth" class="auth-card">
      <img src="https://oandzthkyemwojhebqwc.supabase.co/storage/v1/object/public/www/capreq-icon.png" alt="CapReq" class="auth-logo">
      <h2>CapReq</h2>
      <p class="auth-tagline">Manage infrastructure capacity requests with approvals</p>
      <p>Sign in with your Slack workspace account.</p>
      <button class="btn btn-primary btn-slack" onclick="signInWithSlack()">
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor"><path d="M5.042 15.165a2.528 2.528 0 0 1-2.52 2.523A2.528 2.528 0 0 1 0 15.165a2.527 2.527 0 0 1 2.522-2.52h2.52v2.52zm1.271 0a2.527 2.527 0 0 1 2.521-2.52 2.527 2.527 0 0 1 2.521 2.52v6.313A2.528 2.528 0 0 1 8.834 24a2.528 2.528 0 0 1-2.521-2.522v-6.313zM8.834 5.042a2.528 2.528 0 0 1-2.521-2.52A2.528 2.528 0 0 1 8.834 0a2.528 2.528 0 0 1 2.521 2.522v2.52H8.834zm0 1.271a2.528 2.528 0 0 1 2.521 2.521 2.528 2.528 0 0 1-2.521 2.521H2.522A2.528 2.528 0 0 1 0 8.834a2.528 2.528 0 0 1 2.522-2.521h6.312zM18.956 8.834a2.528 2.528 0 0 1 2.522-2.521A2.528 2.528 0 0 1 24 8.834a2.528 2.528 0 0 1-2.522 2.521h-2.522V8.834zm-1.27 0a2.528 2.528 0 0 1-2.523 2.521 2.527 2.527 0 0 1-2.52-2.521V2.522A2.527 2.527 0 0 1 15.163 0a2.528 2.528 0 0 1 2.523 2.522v6.312zM15.163 18.956a2.528 2.528 0 0 1 2.523 2.522A2.528 2.528 0 0 1 15.163 24a2.527 2.527 0 0 1-2.52-2.522v-2.522h2.52zm0-1.27a2.527 2.527 0 0 1-2.52-2.523 2.527 2.527 0 0 1 2.52-2.52h6.315A2.528 2.528 0 0 1 24 15.165a2.528 2.528 0 0 1-2.522 2.523h-6.315z"/></svg>
        Sign in with Slack
      </button>
      <p id="auth-msg" class="hidden mt-2"></p>
    </div>

    <div id="app" class="hidden">
      <div class="page-header fade-in">
        <h1>Request <span class="mono" id="req-id"></span></h1>
      </div>

      <div id="msg"></div>

      <!-- Workflow stepper -->
      <div class="card fade-in fade-in-1 mb-3" id="stepper-card">
        <div class="card-header">
          <h3>Workflow</h3>
        </div>
        <div class="card-body">
          <div id="workflow-stepper"></div>
          <div id="approval-checks"></div>
        </div>
      </div>

      <!-- Operator guidance -->
      <div id="guidance" class="fade-in fade-in-1"></div>

      <!-- Request fields -->
      <div class="card fade-in fade-in-2 mb-3">
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

      <!-- Notes for actions -->
      <div class="form-group full fade-in fade-in-3" id="notes-group" style="margin-top:1rem;display:none;">
        <label for="action-notes">Notes (optional)</label>
        <textarea id="action-notes" rows="3" placeholder="Add a note about your decision..."></textarea>
      </div>

      <!-- Action buttons -->
      <div class="actions fade-in fade-in-3" id="actions"></div>

      <!-- Events timeline -->
      <div class="fade-in fade-in-4 mt-3">
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
    const params = new URLSearchParams(location.hash.substring(1));
    const requestId = params.get('id');

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

    async function signInWithSlack() {
      const { data, error } = await sb.auth.signInWithOAuth({
        provider: 'slack_oidc',
        options: { redirectTo: window.location.href }
      });
      if (error) {
        const msg = document.getElementById('auth-msg');
        msg.classList.remove('hidden');
        msg.className = 'msg msg-error mt-2';
        msg.textContent = error.message;
      }
    }

    async function signOut() {
      await sb.auth.signOut();
      location.reload();
    }

    function getSlackUserId(user) {
      if (user.user_metadata?.provider_id) return user.user_metadata.provider_id;
      const slack = user.identities?.find(i => i.provider === 'slack_oidc');
      if (slack?.identity_data?.provider_id) return slack.identity_data.provider_id;
      if (user.user_metadata?.sub) return user.user_metadata.sub;
      return user.id || user.email;
    }

    async function showApp(user) {
      document.getElementById('auth').classList.add('hidden');
      document.getElementById('app').classList.remove('hidden');
      const displayName = user.user_metadata?.name || user.user_metadata?.full_name || user.email;
      document.getElementById('user-info').textContent = displayName;
      window._userId = getSlackUserId(user);
      await loadDetail();
    }

    async function loadDetail() {
      const [reqResult, eventsResult] = await Promise.all([
        sb.from('v_request_detail').select('*').eq('id', requestId).single(),
        sb.from('v_request_events').select('*').eq('capacity_request_id', requestId).order('created_at', { ascending: true })
      ]);

      if (reqResult.error) {
        document.getElementById('msg').innerHTML = `<div class="msg msg-error">${reqResult.error.message}</div>`;
        return;
      }

      const r = reqResult.data;

      // Workflow stepper
      renderStepper(r);

      // Operator guidance
      const guidance = getGuidance(r);
      const guidanceEl = document.getElementById('guidance');
      if (guidance) {
        guidanceEl.innerHTML = `<div class="guidance-banner ${guidance.style}">${esc(guidance.text)}</div>`;
      } else {
        guidanceEl.innerHTML = '';
      }

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
        <div class="detail-item"><div class="detail-label">VP Approver</div><div class="detail-value mono">${esc(r.vp_approver_user_id) || '\u2014'}</div></div>
        <div class="detail-item"><div class="detail-label">Deadline</div><div class="detail-value">${r.next_deadline_at ? fmtDate(r.next_deadline_at) : '\u2014'}</div></div>
        <div class="detail-item"><div class="detail-label">Version</div><div class="detail-value mono">${r.version}</div></div>
      `;

      // Action buttons & notes textarea
      const acts = document.getElementById('actions');
      acts.innerHTML = '';
      const state = r.state;
      const hasActions = !['COMPLETED', 'REJECTED', 'CANCELLED', 'EXPIRED', 'FAILED'].includes(state);
      document.getElementById('notes-group').style.display = hasActions ? '' : 'none';

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
      if (hasActions) {
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
            ${e.notes ? '<div class="event-notes">' + esc(e.notes) + '</div>' : ''}
          </li>
        `).join('');
      }
    }

    async function applyEvent(eventType, payload) {
      const msgEl = document.getElementById('msg');
      msgEl.innerHTML = '';
      const actorId = window._userId || 'web-user';
      const notesEl = document.getElementById('action-notes');
      const notes = notesEl ? notesEl.value.trim() : '';
      const rpcParams = {
        p_request_id: requestId,
        p_event_type: eventType,
        p_actor_type: 'user',
        p_actor_id: actorId,
        p_payload: payload || {}
      };
      if (notes) rpcParams.p_notes = notes;
      const { data, error } = await sb.rpc('apply_capacity_event', rpcParams);
      if (error) {
        msgEl.innerHTML = `<div class="msg msg-error">${error.message}</div>`;
      } else {
        if (notesEl) notesEl.value = '';
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

    function renderStepper(r) {
      const stages = [
        { key: 'SUBMITTED', label: 'Submitted' },
        { key: 'UNDER_REVIEW', label: 'Under Review' },
        { key: 'CUSTOMER_CONFIRMATION_REQUIRED', label: 'Confirming' },
        { key: 'PROVISIONING', label: 'Provisioning' },
        { key: 'COMPLETED', label: 'Completed' }
      ];
      const terminal = { REJECTED: 'Rejected', CANCELLED: 'Cancelled', EXPIRED: 'Expired', FAILED: 'Failed' };
      const stageOrder = stages.map(s => s.key);
      const state = r.state;
      const isTerminal = state in terminal;

      // Find which stage we branched from for terminal states
      let terminalFrom = -1;
      if (state === 'REJECTED') terminalFrom = stageOrder.indexOf('UNDER_REVIEW');
      else if (state === 'EXPIRED' || state === 'CANCELLED') terminalFrom = stageOrder.indexOf('CUSTOMER_CONFIRMATION_REQUIRED');
      else if (state === 'FAILED') terminalFrom = stageOrder.indexOf('PROVISIONING');

      // For CANCELLED, it could be from any active stage — check what makes sense
      if (state === 'CANCELLED') {
        // Use the last known active stage based on approval flags
        if (r.commercial_approved_at && r.technical_approved_at) terminalFrom = stageOrder.indexOf('CUSTOMER_CONFIRMATION_REQUIRED');
        else if (r.commercial_approved_at || r.technical_approved_at) terminalFrom = stageOrder.indexOf('UNDER_REVIEW');
        else terminalFrom = stageOrder.indexOf('SUBMITTED');
      }

      const currentIdx = stageOrder.indexOf(state);

      let html = '<div class="stepper">';
      stages.forEach((stage, i) => {
        let nodeClass = 'stepper-node';
        let labelClass = 'stepper-label';

        if (!isTerminal) {
          if (i < currentIdx) { nodeClass += ' completed'; labelClass += ' completed'; }
          else if (i === currentIdx) { nodeClass += ' active'; labelClass += ' active'; }
        } else {
          // Terminal: everything up to terminalFrom is completed, terminalFrom itself is failed
          if (i < terminalFrom) { nodeClass += ' completed'; labelClass += ' completed'; }
          else if (i === terminalFrom) { nodeClass += ' failed'; labelClass += ' failed'; }
        }

        // Leading connector (skip for first)
        const connClass = i === 0 ? 'invisible' :
          (!isTerminal && i <= currentIdx) || (isTerminal && i <= terminalFrom) ? 'completed' : '';

        html += '<div class="stepper-stage">';
        html += '<div class="stepper-row">';
        html += `<div class="stepper-connector ${connClass}"></div>`;

        // Node icon
        let icon = i + 1;
        if (nodeClass.includes('completed')) icon = '\u2713';
        else if (nodeClass.includes('active')) icon = '\u25CF';
        else if (nodeClass.includes('failed')) icon = '\u2717';

        html += `<div class="${nodeClass}">${icon}</div>`;

        // Trailing connector (skip for last)
        const trailClass = i === stages.length - 1 ? 'invisible' :
          (!isTerminal && i < currentIdx) || (isTerminal && i < terminalFrom) ? 'completed' : '';
        html += `<div class="stepper-connector ${trailClass}"></div>`;

        html += '</div>'; // stepper-row
        html += `<div class="${labelClass}">${stage.label}</div>`;
        html += '</div>'; // stepper-stage
      });
      html += '</div>';

      // Terminal state indicator below
      if (isTerminal) {
        html += `<div style="text-align:center;margin-top:0.5rem;"><span class="badge badge-${state}">${terminal[state]}</span></div>`;
      }

      document.getElementById('workflow-stepper').innerHTML = html;

      // Approval sub-checks for UNDER_REVIEW
      const checksEl = document.getElementById('approval-checks');
      if (state === 'UNDER_REVIEW' || (isTerminal && terminalFrom >= stageOrder.indexOf('UNDER_REVIEW'))) {
        const vpRequired = r.estimated_monthly_cost_usd != null && r.estimated_monthly_cost_usd >= 50000;
        let checks = '';
        checks += apprCheck('Commercial', r.commercial_approved_at);
        checks += apprCheck('Technical', r.technical_approved_at);
        if (vpRequired) checks += apprCheck('VP', r.vp_approved_at);
        checksEl.innerHTML = '<div class="approval-checks">' + checks + '</div>';
      } else {
        checksEl.innerHTML = '';
      }
    }

    function apprCheck(label, ts) {
      const done = ts != null;
      return `<div class="approval-check"><span class="check-icon ${done ? 'done' : 'pending'}">${done ? '\u2713' : '\u00B7'}</span>${label} ${done ? 'Approved' : 'Pending'}</div>`;
    }

    function getGuidance(r) {
      const state = r.state;
      const vpRequired = r.estimated_monthly_cost_usd != null && r.estimated_monthly_cost_usd >= 50000;
      const commDone = r.commercial_approved_at != null;
      const techDone = r.technical_approved_at != null;
      const vpDone = r.vp_approved_at != null;

      switch (state) {
        case 'SUBMITTED':
          return { text: 'This request was just created and is being routed for review.', style: 'guidance-info' };
        case 'UNDER_REVIEW':
          if (!commDone && !techDone)
            return { text: 'Awaiting commercial and technical review. Commercial owner and infra team should review and approve or reject.', style: 'guidance-info' };
          if (commDone && !techDone)
            return { text: 'Commercial review complete. Awaiting technical review from the infrastructure team.', style: 'guidance-info' };
          if (!commDone && techDone)
            return { text: 'Technical review complete. Awaiting commercial review from the commercial owner.', style: 'guidance-info' };
          if (commDone && techDone && vpRequired && !vpDone)
            return { text: `Commercial and technical reviews approved. Awaiting VP approval due to cost exceeding escalation threshold ($${Number(r.estimated_monthly_cost_usd).toLocaleString()}/mo).`, style: 'guidance-info' };
          return { text: 'All reviews in progress.', style: 'guidance-info' };
        case 'CUSTOMER_CONFIRMATION_REQUIRED':
          return { text: `All approvals received. Customer must confirm they still need this capacity.${r.next_deadline_at ? ' Deadline: ' + fmtDate(r.next_deadline_at) + '.' : ''} After that, the request will automatically expire.`, style: 'guidance-info' };
        case 'PROVISIONING':
          return { text: 'Customer confirmed. An operator should now provision the requested infrastructure in Admin Studio (or your provisioning system). When done, call the provisioning webhook with status "complete" or "failed".', style: 'guidance-info' };
        case 'COMPLETED':
          return { text: 'This request has been fulfilled. Infrastructure has been provisioned.', style: 'guidance-success' };
        case 'REJECTED':
          return { text: 'This request was rejected during review.', style: 'guidance-error' };
        case 'CANCELLED':
          return { text: 'This request was cancelled.', style: 'guidance-muted' };
        case 'EXPIRED':
          return { text: 'Customer did not confirm within the deadline. This request has expired.', style: 'guidance-error' };
        case 'FAILED':
          return { text: 'Provisioning failed. Review the error details and consider creating a new request.', style: 'guidance-error' };
        default:
          return null;
      }
    }

    init();
  </script>
</body>
</html>
$page$);

-- ============================================================
-- new.html
-- ============================================================
INSERT INTO static_pages (path, content) VALUES ('new.html', $page$<!DOCTYPE html>
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

/* ─── Top Bar ──────────────────────────────────── */

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
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-family: var(--mono);
  font-size: 0.75rem;
  color: var(--text-dim);
  padding: 0.35rem 0.6rem;
  border: 1px solid var(--border);
  border-radius: 6px;
}

.topbar-signout {
  color: var(--text-dim);
  cursor: pointer;
  opacity: 0.6;
  transition: opacity 0.2s, color 0.2s;
  background: none;
  border: none;
  font-family: var(--mono);
  font-size: 0.7rem;
  padding: 0;
}

.topbar-signout:hover {
  opacity: 1;
  color: var(--danger);
}

/* ─── Page Header ──────────────────────────────── */

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

/* ─── Auth Card ────────────────────────────────── */

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

/* ─── Cards & Panels ──────────────────────────── */

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

/* ─── Data Table ───────────────────────────────── */

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

/* ─── State Badges ─────────────────────────────── */

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

/* ─── Buttons ──────────────────────────────────── */

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

.btn-slack {
  width: 100%;
  justify-content: center;
  gap: 0.6rem;
  font-size: 0.9rem;
  padding: 0.7rem 1.25rem;
}

.btn-slack svg {
  width: 20px;
  height: 20px;
  flex-shrink: 0;
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

/* ─── Detail Grid ──────────────────────────────── */

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

/* ─── Timeline ─────────────────────────────────── */

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

/* ─── Forms ────────────────────────────────────── */

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

/* ─── Messages ─────────────────────────────────── */

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

/* ─── Section Dividers ─────────────────────────── */

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

/* ─── Stat Pills (confirm page) ────────────────── */

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

/* ─── Footer ──────────────────────────────────── */

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

/* ─── Utilities ────────────────────────────────── */

.hidden { display: none !important; }

.mt-1 { margin-top: 0.5rem; }
.mt-2 { margin-top: 1rem; }
.mt-3 { margin-top: 1.5rem; }
.mb-2 { margin-bottom: 1rem; }
.mb-3 { margin-bottom: 1.5rem; }

/* ─── Animations ───────────────────────────────── */

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

/* ─── Workflow Stepper ────────────────────────── */

.stepper {
  display: flex;
  align-items: flex-start;
  gap: 0;
  overflow-x: auto;
  padding: 1rem 0.5rem 0.5rem;
}

.stepper-stage {
  display: flex;
  flex-direction: column;
  align-items: center;
  position: relative;
  flex: 1;
  min-width: 0;
}

.stepper-row {
  display: flex;
  align-items: center;
  width: 100%;
}

.stepper-connector {
  flex: 1;
  height: 2px;
  background: var(--border);
  min-width: 8px;
}

.stepper-connector.completed {
  background: var(--success);
}

.stepper-connector.invisible {
  visibility: hidden;
}

.stepper-node {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  font-size: 0.7rem;
  font-weight: 700;
  border: 2px solid var(--border);
  background: var(--surface);
  color: var(--text-dim);
  transition: all 0.3s;
}

.stepper-node.completed {
  border-color: var(--success);
  background: var(--success-dim);
  color: var(--success);
}

.stepper-node.active {
  border-color: var(--accent);
  background: var(--accent-dim);
  color: var(--accent);
  box-shadow: 0 0 12px var(--accent-glow), 0 0 24px rgba(245, 158, 11, 0.1);
  animation: stepperPulse 2s ease-in-out infinite;
}

.stepper-node.failed {
  border-color: var(--danger);
  background: var(--danger-dim);
  color: var(--danger);
}

.stepper-label {
  margin-top: 0.4rem;
  font-family: var(--mono);
  font-size: 0.62rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--text-dim);
  text-align: center;
  white-space: nowrap;
}

.stepper-label.completed { color: var(--success); }
.stepper-label.active    { color: var(--accent); }
.stepper-label.failed    { color: var(--danger); }

@keyframes stepperPulse {
  0%, 100% { box-shadow: 0 0 12px var(--accent-glow), 0 0 24px rgba(245, 158, 11, 0.1); }
  50%      { box-shadow: 0 0 18px var(--accent-glow), 0 0 36px rgba(245, 158, 11, 0.2); }
}

/* Approval sub-checks shown below stepper for UNDER_REVIEW */
.approval-checks {
  display: flex;
  gap: 1.25rem;
  flex-wrap: wrap;
  padding: 0.75rem 0 0;
  margin-top: 0.75rem;
  border-top: 1px solid var(--border);
}

.approval-check {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  font-family: var(--mono);
  font-size: 0.72rem;
  font-weight: 500;
  color: var(--text-muted);
}

.approval-check .check-icon {
  width: 16px;
  height: 16px;
  border-radius: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.6rem;
  font-weight: 700;
}

.approval-check .check-icon.done {
  background: var(--success-dim);
  color: var(--success);
  border: 1px solid rgba(34, 197, 94, 0.3);
}

.approval-check .check-icon.pending {
  background: var(--surface-2);
  color: var(--text-dim);
  border: 1px solid var(--border);
}

/* Operator guidance banner */
.guidance-banner {
  padding: 0.75rem 1rem;
  border-radius: var(--radius);
  font-size: 0.85rem;
  line-height: 1.5;
  margin-bottom: 1rem;
  border: 1px solid transparent;
}

.guidance-info {
  background: var(--info-dim);
  color: var(--info);
  border-color: rgba(56, 189, 248, 0.2);
}

.guidance-success {
  background: var(--success-dim);
  color: #4ade80;
  border-color: rgba(34, 197, 94, 0.2);
}

.guidance-error {
  background: var(--danger-dim);
  color: #f87171;
  border-color: rgba(239, 68, 68, 0.2);
}

.guidance-muted {
  background: #1e1e2e;
  color: #8888a0;
  border-color: rgba(42, 42, 58, 0.5);
}

/* ─── Filter Bar ──────────────────────────────── */

.filter-bar {
  display: flex;
  gap: 0.75rem;
  align-items: flex-end;
  flex-wrap: wrap;
  padding: 0.85rem 1.25rem;
  border-bottom: 1px solid var(--border);
  background: var(--surface-2);
}

.filter-group {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.filter-group label {
  font-family: var(--mono);
  font-size: 0.68rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--text-dim);
}

.filter-group select,
.filter-group input {
  padding: 0.4rem 0.65rem;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  color: var(--text);
  font-family: var(--sans);
  font-size: 0.82rem;
  outline: none;
  transition: border-color 0.2s, box-shadow 0.2s;
  -webkit-appearance: none;
}

.filter-group select {
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='8' fill='none'%3E%3Cpath d='M1 1.5l5 5 5-5' stroke='%238888a0' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 0.65rem center;
  padding-right: 2rem;
}

.filter-group select:focus,
.filter-group input:focus {
  border-color: var(--accent);
  box-shadow: 0 0 0 3px var(--accent-dim);
}

.filter-group input::placeholder {
  color: var(--text-dim);
}

.filter-actions {
  display: flex;
  align-items: flex-end;
}

.filter-actions .btn {
  padding: 0.4rem 0.65rem;
  font-size: 0.78rem;
}

/* ─── Age Indicators ──────────────────────────── */

.age-green td:first-child { border-left: 3px solid var(--success); }
.age-amber td:first-child { border-left: 3px solid var(--warning); }
.age-red td:first-child   { border-left: 3px solid var(--danger); }

/* ─── Event Notes in Timeline ─────────────────── */

.event-notes {
  margin-top: 0.35rem;
  font-size: 0.8rem;
  font-style: italic;
  color: var(--text-muted);
  background: var(--surface-2);
  padding: 0.35rem 0.6rem;
  border-radius: 4px;
  border-left: 3px solid var(--warning);
}

/* ─── Queue Page ──────────────────────────────── */

.queue-table {
  width: 100%;
  border-collapse: collapse;
}

.queue-table th {
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

.queue-table td {
  padding: 0.7rem 1rem;
  font-size: 0.875rem;
  border-bottom: 1px solid rgba(42, 42, 58, 0.5);
}

.queue-table tbody tr:last-child td {
  border-bottom: none;
}

.queue-actions {
  display: flex;
  gap: 0.35rem;
}

.queue-actions .btn {
  padding: 0.3rem 0.6rem;
  font-size: 0.75rem;
}

.badge-count {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 18px;
  height: 18px;
  padding: 0 5px;
  border-radius: 100px;
  font-family: var(--mono);
  font-size: 0.65rem;
  font-weight: 700;
  background: var(--accent);
  color: #000;
}

.empty-state {
  text-align: center;
  padding: 3rem 1rem;
  color: var(--text-dim);
}

.empty-state svg {
  width: 48px;
  height: 48px;
  margin-bottom: 1rem;
  opacity: 0.3;
}

.empty-state p {
  font-size: 0.9rem;
}

/* ─── Nav Badge ───────────────────────────────── */

.nav-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 16px;
  height: 16px;
  padding: 0 4px;
  border-radius: 100px;
  font-family: var(--mono);
  font-size: 0.6rem;
  font-weight: 700;
  background: var(--accent);
  color: #000;
  margin-left: 0.25rem;
  vertical-align: middle;
}

.nav-badge:empty { display: none; }

/* ─── Analytics Page ──────────────────────────── */

.chart-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.25rem;
}

.chart-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  overflow: hidden;
}

.chart-card .card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.85rem 1.25rem;
  border-bottom: 1px solid var(--border);
  background: var(--surface-2);
}

.chart-card .card-header h3 {
  font-family: var(--mono);
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  color: var(--text-muted);
}

.chart-card .card-body {
  padding: 1.25rem;
  height: 280px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.chart-card canvas {
  width: 100% !important;
  height: 100% !important;
}

/* ─── Textarea ────────────────────────────────── */

.form-group textarea {
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
  resize: vertical;
}

.form-group textarea:focus {
  border-color: var(--accent);
  box-shadow: 0 0 0 3px var(--accent-dim);
}

.form-group textarea::placeholder {
  color: var(--text-dim);
}

/* ─── SLA Badges ──────────────────────────────── */

.sla-ok      { color: var(--success); }
.sla-at_risk { color: var(--warning); }
.sla-breached { color: var(--danger); }

/* ─── Responsive ──────────────────────────────── */

@media (max-width: 768px) {
  .shell {
    padding: 0 0.75rem;
  }

  .topbar {
    flex-wrap: wrap;
  }

  .topbar-brand {
    margin-right: auto;
  }

  .topbar-nav {
    order: 3;
    width: 100%;
    overflow-x: auto;
    padding-top: 0.5rem;
  }

  .form-grid,
  .detail-grid {
    grid-template-columns: 1fr;
  }

  .detail-item:nth-child(odd) {
    border-right: none;
  }

  .data-table,
  .queue-table {
    display: block;
    overflow-x: auto;
  }

  .stat-row {
    flex-wrap: wrap;
  }

  .stat-row .stat {
    min-width: calc(50% - 0.5rem);
    flex: 0 0 calc(50% - 0.5rem);
  }

  .chart-grid {
    grid-template-columns: 1fr;
  }

  .filter-bar {
    flex-direction: column;
    align-items: stretch;
  }

  .filter-group {
    width: 100%;
  }

  .filter-group select,
  .filter-group input {
    width: 100%;
  }

  .auth-card {
    margin: 2rem 0.5rem;
    padding: 2rem 1.5rem;
  }
}

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
        <a href="www?page=queue.html">Queue <span class="nav-badge" id="queue-badge"></span></a>
        <a href="www?page=analytics.html">Analytics</a>
      </nav>
      <span class="topbar-user"><span id="user-info"></span><button class="topbar-signout" onclick="signOut()" title="Sign out">Sign out</button></span>
    </header>

    <div id="auth" class="auth-card">
      <img src="https://oandzthkyemwojhebqwc.supabase.co/storage/v1/object/public/www/capreq-icon.png" alt="CapReq" class="auth-logo">
      <h2>CapReq</h2>
      <p class="auth-tagline">Manage infrastructure capacity requests with approvals</p>
      <p>Sign in with your Slack workspace account.</p>
      <button class="btn btn-primary btn-slack" onclick="signInWithSlack()">
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor"><path d="M5.042 15.165a2.528 2.528 0 0 1-2.52 2.523A2.528 2.528 0 0 1 0 15.165a2.527 2.527 0 0 1 2.522-2.52h2.52v2.52zm1.271 0a2.527 2.527 0 0 1 2.521-2.52 2.527 2.527 0 0 1 2.521 2.52v6.313A2.528 2.528 0 0 1 8.834 24a2.528 2.528 0 0 1-2.521-2.522v-6.313zM8.834 5.042a2.528 2.528 0 0 1-2.521-2.52A2.528 2.528 0 0 1 8.834 0a2.528 2.528 0 0 1 2.521 2.522v2.52H8.834zm0 1.271a2.528 2.528 0 0 1 2.521 2.521 2.528 2.528 0 0 1-2.521 2.521H2.522A2.528 2.528 0 0 1 0 8.834a2.528 2.528 0 0 1 2.522-2.521h6.312zM18.956 8.834a2.528 2.528 0 0 1 2.522-2.521A2.528 2.528 0 0 1 24 8.834a2.528 2.528 0 0 1-2.522 2.521h-2.522V8.834zm-1.27 0a2.528 2.528 0 0 1-2.523 2.521 2.527 2.527 0 0 1-2.52-2.521V2.522A2.527 2.527 0 0 1 15.163 0a2.528 2.528 0 0 1 2.523 2.522v6.312zM15.163 18.956a2.528 2.528 0 0 1 2.523 2.522A2.528 2.528 0 0 1 15.163 24a2.527 2.527 0 0 1-2.52-2.522v-2.522h2.52zm0-1.27a2.527 2.527 0 0 1-2.52-2.523 2.527 2.527 0 0 1 2.52-2.52h6.315A2.528 2.528 0 0 1 24 15.165a2.528 2.528 0 0 1-2.522 2.523h-6.315z"/></svg>
        Sign in with Slack
      </button>
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

              <div class="form-group full">
                <label for="vp_approver">VP Approver</label>
                <input type="text" id="vp_approver" placeholder="User ID (optional, for cost escalation)">
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

    async function signInWithSlack() {
      const { data, error } = await sb.auth.signInWithOAuth({
        provider: 'slack_oidc',
        options: { redirectTo: window.location.href }
      });
      if (error) {
        const msg = document.getElementById('auth-msg');
        msg.classList.remove('hidden');
        msg.className = 'msg msg-error mt-2';
        msg.textContent = error.message;
      }
    }

    async function signOut() {
      await sb.auth.signOut();
      location.reload();
    }

    function getSlackUserId(user) {
      if (user.user_metadata?.provider_id) return user.user_metadata.provider_id;
      const slack = user.identities?.find(i => i.provider === 'slack_oidc');
      if (slack?.identity_data?.provider_id) return slack.identity_data.provider_id;
      if (user.user_metadata?.sub) return user.user_metadata.sub;
      return user.id || user.email;
    }

    function showApp(user) {
      document.getElementById('auth').classList.add('hidden');
      document.getElementById('app').classList.remove('hidden');
      const displayName = user.user_metadata?.name || user.user_metadata?.full_name || user.email;
      document.getElementById('user-info').textContent = displayName;
      window._userId = getSlackUserId(user);
    }

    async function submitForm(e) {
      e.preventDefault();
      const msgEl = document.getElementById('msg');
      msgEl.innerHTML = '';

      const userId = window._userId || 'web-user';
      const cost = document.getElementById('cost').value;

      const vpApprover = document.getElementById('vp_approver').value.trim();
      const rpcParams = {
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
      };
      if (vpApprover) rpcParams.p_vp_approver_user_id = vpApprover;
      const { data, error } = await sb.rpc('create_capacity_request', rpcParams);

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
</html>
$page$);

-- ============================================================
-- confirm.html
-- ============================================================
INSERT INTO static_pages (path, content) VALUES ('confirm.html', $page$<!DOCTYPE html>
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

/* ─── Top Bar ──────────────────────────────────── */

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
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-family: var(--mono);
  font-size: 0.75rem;
  color: var(--text-dim);
  padding: 0.35rem 0.6rem;
  border: 1px solid var(--border);
  border-radius: 6px;
}

.topbar-signout {
  color: var(--text-dim);
  cursor: pointer;
  opacity: 0.6;
  transition: opacity 0.2s, color 0.2s;
  background: none;
  border: none;
  font-family: var(--mono);
  font-size: 0.7rem;
  padding: 0;
}

.topbar-signout:hover {
  opacity: 1;
  color: var(--danger);
}

/* ─── Page Header ──────────────────────────────── */

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

/* ─── Auth Card ────────────────────────────────── */

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

/* ─── Cards & Panels ──────────────────────────── */

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

/* ─── Data Table ───────────────────────────────── */

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

/* ─── State Badges ─────────────────────────────── */

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

/* ─── Buttons ──────────────────────────────────── */

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

.btn-slack {
  width: 100%;
  justify-content: center;
  gap: 0.6rem;
  font-size: 0.9rem;
  padding: 0.7rem 1.25rem;
}

.btn-slack svg {
  width: 20px;
  height: 20px;
  flex-shrink: 0;
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

/* ─── Detail Grid ──────────────────────────────── */

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

/* ─── Timeline ─────────────────────────────────── */

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

/* ─── Forms ────────────────────────────────────── */

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

/* ─── Messages ─────────────────────────────────── */

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

/* ─── Section Dividers ─────────────────────────── */

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

/* ─── Stat Pills (confirm page) ────────────────── */

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

/* ─── Footer ──────────────────────────────────── */

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

/* ─── Utilities ────────────────────────────────── */

.hidden { display: none !important; }

.mt-1 { margin-top: 0.5rem; }
.mt-2 { margin-top: 1rem; }
.mt-3 { margin-top: 1.5rem; }
.mb-2 { margin-bottom: 1rem; }
.mb-3 { margin-bottom: 1.5rem; }

/* ─── Animations ───────────────────────────────── */

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

/* ─── Workflow Stepper ────────────────────────── */

.stepper {
  display: flex;
  align-items: flex-start;
  gap: 0;
  overflow-x: auto;
  padding: 1rem 0.5rem 0.5rem;
}

.stepper-stage {
  display: flex;
  flex-direction: column;
  align-items: center;
  position: relative;
  flex: 1;
  min-width: 0;
}

.stepper-row {
  display: flex;
  align-items: center;
  width: 100%;
}

.stepper-connector {
  flex: 1;
  height: 2px;
  background: var(--border);
  min-width: 8px;
}

.stepper-connector.completed {
  background: var(--success);
}

.stepper-connector.invisible {
  visibility: hidden;
}

.stepper-node {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  font-size: 0.7rem;
  font-weight: 700;
  border: 2px solid var(--border);
  background: var(--surface);
  color: var(--text-dim);
  transition: all 0.3s;
}

.stepper-node.completed {
  border-color: var(--success);
  background: var(--success-dim);
  color: var(--success);
}

.stepper-node.active {
  border-color: var(--accent);
  background: var(--accent-dim);
  color: var(--accent);
  box-shadow: 0 0 12px var(--accent-glow), 0 0 24px rgba(245, 158, 11, 0.1);
  animation: stepperPulse 2s ease-in-out infinite;
}

.stepper-node.failed {
  border-color: var(--danger);
  background: var(--danger-dim);
  color: var(--danger);
}

.stepper-label {
  margin-top: 0.4rem;
  font-family: var(--mono);
  font-size: 0.62rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--text-dim);
  text-align: center;
  white-space: nowrap;
}

.stepper-label.completed { color: var(--success); }
.stepper-label.active    { color: var(--accent); }
.stepper-label.failed    { color: var(--danger); }

@keyframes stepperPulse {
  0%, 100% { box-shadow: 0 0 12px var(--accent-glow), 0 0 24px rgba(245, 158, 11, 0.1); }
  50%      { box-shadow: 0 0 18px var(--accent-glow), 0 0 36px rgba(245, 158, 11, 0.2); }
}

/* Approval sub-checks shown below stepper for UNDER_REVIEW */
.approval-checks {
  display: flex;
  gap: 1.25rem;
  flex-wrap: wrap;
  padding: 0.75rem 0 0;
  margin-top: 0.75rem;
  border-top: 1px solid var(--border);
}

.approval-check {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  font-family: var(--mono);
  font-size: 0.72rem;
  font-weight: 500;
  color: var(--text-muted);
}

.approval-check .check-icon {
  width: 16px;
  height: 16px;
  border-radius: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.6rem;
  font-weight: 700;
}

.approval-check .check-icon.done {
  background: var(--success-dim);
  color: var(--success);
  border: 1px solid rgba(34, 197, 94, 0.3);
}

.approval-check .check-icon.pending {
  background: var(--surface-2);
  color: var(--text-dim);
  border: 1px solid var(--border);
}

/* Operator guidance banner */
.guidance-banner {
  padding: 0.75rem 1rem;
  border-radius: var(--radius);
  font-size: 0.85rem;
  line-height: 1.5;
  margin-bottom: 1rem;
  border: 1px solid transparent;
}

.guidance-info {
  background: var(--info-dim);
  color: var(--info);
  border-color: rgba(56, 189, 248, 0.2);
}

.guidance-success {
  background: var(--success-dim);
  color: #4ade80;
  border-color: rgba(34, 197, 94, 0.2);
}

.guidance-error {
  background: var(--danger-dim);
  color: #f87171;
  border-color: rgba(239, 68, 68, 0.2);
}

.guidance-muted {
  background: #1e1e2e;
  color: #8888a0;
  border-color: rgba(42, 42, 58, 0.5);
}

/* ─── Filter Bar ──────────────────────────────── */

.filter-bar {
  display: flex;
  gap: 0.75rem;
  align-items: flex-end;
  flex-wrap: wrap;
  padding: 0.85rem 1.25rem;
  border-bottom: 1px solid var(--border);
  background: var(--surface-2);
}

.filter-group {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.filter-group label {
  font-family: var(--mono);
  font-size: 0.68rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--text-dim);
}

.filter-group select,
.filter-group input {
  padding: 0.4rem 0.65rem;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  color: var(--text);
  font-family: var(--sans);
  font-size: 0.82rem;
  outline: none;
  transition: border-color 0.2s, box-shadow 0.2s;
  -webkit-appearance: none;
}

.filter-group select {
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='8' fill='none'%3E%3Cpath d='M1 1.5l5 5 5-5' stroke='%238888a0' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 0.65rem center;
  padding-right: 2rem;
}

.filter-group select:focus,
.filter-group input:focus {
  border-color: var(--accent);
  box-shadow: 0 0 0 3px var(--accent-dim);
}

.filter-group input::placeholder {
  color: var(--text-dim);
}

.filter-actions {
  display: flex;
  align-items: flex-end;
}

.filter-actions .btn {
  padding: 0.4rem 0.65rem;
  font-size: 0.78rem;
}

/* ─── Age Indicators ──────────────────────────── */

.age-green td:first-child { border-left: 3px solid var(--success); }
.age-amber td:first-child { border-left: 3px solid var(--warning); }
.age-red td:first-child   { border-left: 3px solid var(--danger); }

/* ─── Event Notes in Timeline ─────────────────── */

.event-notes {
  margin-top: 0.35rem;
  font-size: 0.8rem;
  font-style: italic;
  color: var(--text-muted);
  background: var(--surface-2);
  padding: 0.35rem 0.6rem;
  border-radius: 4px;
  border-left: 3px solid var(--warning);
}

/* ─── Queue Page ──────────────────────────────── */

.queue-table {
  width: 100%;
  border-collapse: collapse;
}

.queue-table th {
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

.queue-table td {
  padding: 0.7rem 1rem;
  font-size: 0.875rem;
  border-bottom: 1px solid rgba(42, 42, 58, 0.5);
}

.queue-table tbody tr:last-child td {
  border-bottom: none;
}

.queue-actions {
  display: flex;
  gap: 0.35rem;
}

.queue-actions .btn {
  padding: 0.3rem 0.6rem;
  font-size: 0.75rem;
}

.badge-count {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 18px;
  height: 18px;
  padding: 0 5px;
  border-radius: 100px;
  font-family: var(--mono);
  font-size: 0.65rem;
  font-weight: 700;
  background: var(--accent);
  color: #000;
}

.empty-state {
  text-align: center;
  padding: 3rem 1rem;
  color: var(--text-dim);
}

.empty-state svg {
  width: 48px;
  height: 48px;
  margin-bottom: 1rem;
  opacity: 0.3;
}

.empty-state p {
  font-size: 0.9rem;
}

/* ─── Nav Badge ───────────────────────────────── */

.nav-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 16px;
  height: 16px;
  padding: 0 4px;
  border-radius: 100px;
  font-family: var(--mono);
  font-size: 0.6rem;
  font-weight: 700;
  background: var(--accent);
  color: #000;
  margin-left: 0.25rem;
  vertical-align: middle;
}

.nav-badge:empty { display: none; }

/* ─── Analytics Page ──────────────────────────── */

.chart-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.25rem;
}

.chart-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  overflow: hidden;
}

.chart-card .card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.85rem 1.25rem;
  border-bottom: 1px solid var(--border);
  background: var(--surface-2);
}

.chart-card .card-header h3 {
  font-family: var(--mono);
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  color: var(--text-muted);
}

.chart-card .card-body {
  padding: 1.25rem;
  height: 280px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.chart-card canvas {
  width: 100% !important;
  height: 100% !important;
}

/* ─── Textarea ────────────────────────────────── */

.form-group textarea {
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
  resize: vertical;
}

.form-group textarea:focus {
  border-color: var(--accent);
  box-shadow: 0 0 0 3px var(--accent-dim);
}

.form-group textarea::placeholder {
  color: var(--text-dim);
}

/* ─── SLA Badges ──────────────────────────────── */

.sla-ok      { color: var(--success); }
.sla-at_risk { color: var(--warning); }
.sla-breached { color: var(--danger); }

/* ─── Responsive ──────────────────────────────── */

@media (max-width: 768px) {
  .shell {
    padding: 0 0.75rem;
  }

  .topbar {
    flex-wrap: wrap;
  }

  .topbar-brand {
    margin-right: auto;
  }

  .topbar-nav {
    order: 3;
    width: 100%;
    overflow-x: auto;
    padding-top: 0.5rem;
  }

  .form-grid,
  .detail-grid {
    grid-template-columns: 1fr;
  }

  .detail-item:nth-child(odd) {
    border-right: none;
  }

  .data-table,
  .queue-table {
    display: block;
    overflow-x: auto;
  }

  .stat-row {
    flex-wrap: wrap;
  }

  .stat-row .stat {
    min-width: calc(50% - 0.5rem);
    flex: 0 0 calc(50% - 0.5rem);
  }

  .chart-grid {
    grid-template-columns: 1fr;
  }

  .filter-bar {
    flex-direction: column;
    align-items: stretch;
  }

  .filter-group {
    width: 100%;
  }

  .filter-group select,
  .filter-group input {
    width: 100%;
  }

  .auth-card {
    margin: 2rem 0.5rem;
    padding: 2rem 1.5rem;
  }
}

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
        <a href="www?page=queue.html">Queue <span class="nav-badge" id="queue-badge"></span></a>
        <a href="www?page=analytics.html">Analytics</a>
      </nav>
      <span class="topbar-user"><span id="user-info"></span><button class="topbar-signout" onclick="signOut()" title="Sign out">Sign out</button></span>
    </header>

    <div id="auth" class="auth-card">
      <img src="https://oandzthkyemwojhebqwc.supabase.co/storage/v1/object/public/www/capreq-icon.png" alt="CapReq" class="auth-logo">
      <h2>CapReq</h2>
      <p class="auth-tagline">Manage infrastructure capacity requests with approvals</p>
      <p>Sign in with your Slack workspace account.</p>
      <button class="btn btn-primary btn-slack" onclick="signInWithSlack()">
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor"><path d="M5.042 15.165a2.528 2.528 0 0 1-2.52 2.523A2.528 2.528 0 0 1 0 15.165a2.527 2.527 0 0 1 2.522-2.52h2.52v2.52zm1.271 0a2.527 2.527 0 0 1 2.521-2.52 2.527 2.527 0 0 1 2.521 2.52v6.313A2.528 2.528 0 0 1 8.834 24a2.528 2.528 0 0 1-2.521-2.522v-6.313zM8.834 5.042a2.528 2.528 0 0 1-2.521-2.52A2.528 2.528 0 0 1 8.834 0a2.528 2.528 0 0 1 2.521 2.522v2.52H8.834zm0 1.271a2.528 2.528 0 0 1 2.521 2.521 2.528 2.528 0 0 1-2.521 2.521H2.522A2.528 2.528 0 0 1 0 8.834a2.528 2.528 0 0 1 2.522-2.521h6.312zM18.956 8.834a2.528 2.528 0 0 1 2.522-2.521A2.528 2.528 0 0 1 24 8.834a2.528 2.528 0 0 1-2.522 2.521h-2.522V8.834zm-1.27 0a2.528 2.528 0 0 1-2.523 2.521 2.527 2.527 0 0 1-2.52-2.521V2.522A2.527 2.527 0 0 1 15.163 0a2.528 2.528 0 0 1 2.523 2.522v6.312zM15.163 18.956a2.528 2.528 0 0 1 2.523 2.522A2.528 2.528 0 0 1 15.163 24a2.527 2.527 0 0 1-2.52-2.522v-2.522h2.52zm0-1.27a2.527 2.527 0 0 1-2.52-2.523 2.527 2.527 0 0 1 2.52-2.52h6.315A2.528 2.528 0 0 1 24 15.165a2.528 2.528 0 0 1-2.522 2.523h-6.315z"/></svg>
        Sign in with Slack
      </button>
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

      <div class="form-group full fade-in fade-in-2" id="notes-group" style="margin-top:1rem;display:none;">
        <label for="notes">Notes (optional)</label>
        <textarea id="notes" rows="3" placeholder="Add a note about your decision..."></textarea>
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
    const params = new URLSearchParams(location.hash.substring(1));
    const requestId = params.get('id');

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

    async function signInWithSlack() {
      const { data, error } = await sb.auth.signInWithOAuth({
        provider: 'slack_oidc',
        options: { redirectTo: window.location.href }
      });
      if (error) {
        const msg = document.getElementById('auth-msg');
        msg.classList.remove('hidden');
        msg.className = 'msg msg-error mt-2';
        msg.textContent = error.message;
      }
    }

    async function signOut() {
      await sb.auth.signOut();
      location.reload();
    }

    function getSlackUserId(user) {
      if (user.user_metadata?.provider_id) return user.user_metadata.provider_id;
      const slack = user.identities?.find(i => i.provider === 'slack_oidc');
      if (slack?.identity_data?.provider_id) return slack.identity_data.provider_id;
      if (user.user_metadata?.sub) return user.user_metadata.sub;
      return user.id || user.email;
    }

    async function showApp(user) {
      document.getElementById('auth').classList.add('hidden');
      document.getElementById('app').classList.remove('hidden');
      const displayName = user.user_metadata?.name || user.user_metadata?.full_name || user.email;
      document.getElementById('user-info').textContent = displayName;
      window._userId = getSlackUserId(user);
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
      const notesGroup = document.getElementById('notes-group');
      if (r.state === 'CUSTOMER_CONFIRMATION_REQUIRED') {
        notesGroup.style.display = '';
        acts.innerHTML = `
          <button class="btn btn-success" onclick="respond('CUSTOMER_CONFIRMED')">Confirm</button>
          <button class="btn btn-danger"  onclick="respond('CUSTOMER_DECLINED')">Decline</button>
        `;
      } else {
        notesGroup.style.display = 'none';
        acts.innerHTML = `<div class="msg msg-info">This request is in state <strong>${fmtState(r.state)}</strong> and cannot be confirmed or declined.</div>`;
      }
    }

    async function respond(eventType) {
      const msgEl = document.getElementById('msg');
      msgEl.innerHTML = '';
      const actorId = window._userId || 'web-user';
      const notesEl = document.getElementById('notes');
      const notes = notesEl ? notesEl.value.trim() : '';

      const rpcParams = {
        p_request_id: requestId,
        p_event_type: eventType,
        p_actor_type: 'user',
        p_actor_id: actorId,
        p_payload: {}
      };
      if (notes) rpcParams.p_notes = notes;
      const { data, error } = await sb.rpc('apply_capacity_event', rpcParams);
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
</html>
$page$);

-- ============================================================
-- queue.html
-- ============================================================
INSERT INTO static_pages (path, content) VALUES ('queue.html', $page$<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>CapReq — Approval Queue</title>
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

/* ─── Top Bar ──────────────────────────────────── */

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
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-family: var(--mono);
  font-size: 0.75rem;
  color: var(--text-dim);
  padding: 0.35rem 0.6rem;
  border: 1px solid var(--border);
  border-radius: 6px;
}

.topbar-signout {
  color: var(--text-dim);
  cursor: pointer;
  opacity: 0.6;
  transition: opacity 0.2s, color 0.2s;
  background: none;
  border: none;
  font-family: var(--mono);
  font-size: 0.7rem;
  padding: 0;
}

.topbar-signout:hover {
  opacity: 1;
  color: var(--danger);
}

/* ─── Page Header ──────────────────────────────── */

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

/* ─── Auth Card ────────────────────────────────── */

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

/* ─── Cards & Panels ──────────────────────────── */

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

/* ─── Data Table ───────────────────────────────── */

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

/* ─── State Badges ─────────────────────────────── */

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

/* ─── Buttons ──────────────────────────────────── */

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

.btn-slack {
  width: 100%;
  justify-content: center;
  gap: 0.6rem;
  font-size: 0.9rem;
  padding: 0.7rem 1.25rem;
}

.btn-slack svg {
  width: 20px;
  height: 20px;
  flex-shrink: 0;
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

/* ─── Detail Grid ──────────────────────────────── */

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

/* ─── Timeline ─────────────────────────────────── */

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

/* ─── Forms ────────────────────────────────────── */

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

/* ─── Messages ─────────────────────────────────── */

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

/* ─── Section Dividers ─────────────────────────── */

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

/* ─── Stat Pills (confirm page) ────────────────── */

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

/* ─── Footer ──────────────────────────────────── */

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

/* ─── Utilities ────────────────────────────────── */

.hidden { display: none !important; }

.mt-1 { margin-top: 0.5rem; }
.mt-2 { margin-top: 1rem; }
.mt-3 { margin-top: 1.5rem; }
.mb-2 { margin-bottom: 1rem; }
.mb-3 { margin-bottom: 1.5rem; }

/* ─── Animations ───────────────────────────────── */

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

/* ─── Workflow Stepper ────────────────────────── */

.stepper {
  display: flex;
  align-items: flex-start;
  gap: 0;
  overflow-x: auto;
  padding: 1rem 0.5rem 0.5rem;
}

.stepper-stage {
  display: flex;
  flex-direction: column;
  align-items: center;
  position: relative;
  flex: 1;
  min-width: 0;
}

.stepper-row {
  display: flex;
  align-items: center;
  width: 100%;
}

.stepper-connector {
  flex: 1;
  height: 2px;
  background: var(--border);
  min-width: 8px;
}

.stepper-connector.completed {
  background: var(--success);
}

.stepper-connector.invisible {
  visibility: hidden;
}

.stepper-node {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  font-size: 0.7rem;
  font-weight: 700;
  border: 2px solid var(--border);
  background: var(--surface);
  color: var(--text-dim);
  transition: all 0.3s;
}

.stepper-node.completed {
  border-color: var(--success);
  background: var(--success-dim);
  color: var(--success);
}

.stepper-node.active {
  border-color: var(--accent);
  background: var(--accent-dim);
  color: var(--accent);
  box-shadow: 0 0 12px var(--accent-glow), 0 0 24px rgba(245, 158, 11, 0.1);
  animation: stepperPulse 2s ease-in-out infinite;
}

.stepper-node.failed {
  border-color: var(--danger);
  background: var(--danger-dim);
  color: var(--danger);
}

.stepper-label {
  margin-top: 0.4rem;
  font-family: var(--mono);
  font-size: 0.62rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--text-dim);
  text-align: center;
  white-space: nowrap;
}

.stepper-label.completed { color: var(--success); }
.stepper-label.active    { color: var(--accent); }
.stepper-label.failed    { color: var(--danger); }

@keyframes stepperPulse {
  0%, 100% { box-shadow: 0 0 12px var(--accent-glow), 0 0 24px rgba(245, 158, 11, 0.1); }
  50%      { box-shadow: 0 0 18px var(--accent-glow), 0 0 36px rgba(245, 158, 11, 0.2); }
}

/* Approval sub-checks shown below stepper for UNDER_REVIEW */
.approval-checks {
  display: flex;
  gap: 1.25rem;
  flex-wrap: wrap;
  padding: 0.75rem 0 0;
  margin-top: 0.75rem;
  border-top: 1px solid var(--border);
}

.approval-check {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  font-family: var(--mono);
  font-size: 0.72rem;
  font-weight: 500;
  color: var(--text-muted);
}

.approval-check .check-icon {
  width: 16px;
  height: 16px;
  border-radius: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.6rem;
  font-weight: 700;
}

.approval-check .check-icon.done {
  background: var(--success-dim);
  color: var(--success);
  border: 1px solid rgba(34, 197, 94, 0.3);
}

.approval-check .check-icon.pending {
  background: var(--surface-2);
  color: var(--text-dim);
  border: 1px solid var(--border);
}

/* Operator guidance banner */
.guidance-banner {
  padding: 0.75rem 1rem;
  border-radius: var(--radius);
  font-size: 0.85rem;
  line-height: 1.5;
  margin-bottom: 1rem;
  border: 1px solid transparent;
}

.guidance-info {
  background: var(--info-dim);
  color: var(--info);
  border-color: rgba(56, 189, 248, 0.2);
}

.guidance-success {
  background: var(--success-dim);
  color: #4ade80;
  border-color: rgba(34, 197, 94, 0.2);
}

.guidance-error {
  background: var(--danger-dim);
  color: #f87171;
  border-color: rgba(239, 68, 68, 0.2);
}

.guidance-muted {
  background: #1e1e2e;
  color: #8888a0;
  border-color: rgba(42, 42, 58, 0.5);
}

/* ─── Filter Bar ──────────────────────────────── */

.filter-bar {
  display: flex;
  gap: 0.75rem;
  align-items: flex-end;
  flex-wrap: wrap;
  padding: 0.85rem 1.25rem;
  border-bottom: 1px solid var(--border);
  background: var(--surface-2);
}

.filter-group {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.filter-group label {
  font-family: var(--mono);
  font-size: 0.68rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--text-dim);
}

.filter-group select,
.filter-group input {
  padding: 0.4rem 0.65rem;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  color: var(--text);
  font-family: var(--sans);
  font-size: 0.82rem;
  outline: none;
  transition: border-color 0.2s, box-shadow 0.2s;
  -webkit-appearance: none;
}

.filter-group select {
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='8' fill='none'%3E%3Cpath d='M1 1.5l5 5 5-5' stroke='%238888a0' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 0.65rem center;
  padding-right: 2rem;
}

.filter-group select:focus,
.filter-group input:focus {
  border-color: var(--accent);
  box-shadow: 0 0 0 3px var(--accent-dim);
}

.filter-group input::placeholder {
  color: var(--text-dim);
}

.filter-actions {
  display: flex;
  align-items: flex-end;
}

.filter-actions .btn {
  padding: 0.4rem 0.65rem;
  font-size: 0.78rem;
}

/* ─── Age Indicators ──────────────────────────── */

.age-green td:first-child { border-left: 3px solid var(--success); }
.age-amber td:first-child { border-left: 3px solid var(--warning); }
.age-red td:first-child   { border-left: 3px solid var(--danger); }

/* ─── Event Notes in Timeline ─────────────────── */

.event-notes {
  margin-top: 0.35rem;
  font-size: 0.8rem;
  font-style: italic;
  color: var(--text-muted);
  background: var(--surface-2);
  padding: 0.35rem 0.6rem;
  border-radius: 4px;
  border-left: 3px solid var(--warning);
}

/* ─── Queue Page ──────────────────────────────── */

.queue-table {
  width: 100%;
  border-collapse: collapse;
}

.queue-table th {
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

.queue-table td {
  padding: 0.7rem 1rem;
  font-size: 0.875rem;
  border-bottom: 1px solid rgba(42, 42, 58, 0.5);
}

.queue-table tbody tr:last-child td {
  border-bottom: none;
}

.queue-actions {
  display: flex;
  gap: 0.35rem;
}

.queue-actions .btn {
  padding: 0.3rem 0.6rem;
  font-size: 0.75rem;
}

.badge-count {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 18px;
  height: 18px;
  padding: 0 5px;
  border-radius: 100px;
  font-family: var(--mono);
  font-size: 0.65rem;
  font-weight: 700;
  background: var(--accent);
  color: #000;
}

.empty-state {
  text-align: center;
  padding: 3rem 1rem;
  color: var(--text-dim);
}

.empty-state svg {
  width: 48px;
  height: 48px;
  margin-bottom: 1rem;
  opacity: 0.3;
}

.empty-state p {
  font-size: 0.9rem;
}

/* ─── Nav Badge ───────────────────────────────── */

.nav-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 16px;
  height: 16px;
  padding: 0 4px;
  border-radius: 100px;
  font-family: var(--mono);
  font-size: 0.6rem;
  font-weight: 700;
  background: var(--accent);
  color: #000;
  margin-left: 0.25rem;
  vertical-align: middle;
}

.nav-badge:empty { display: none; }

/* ─── Analytics Page ──────────────────────────── */

.chart-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.25rem;
}

.chart-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  overflow: hidden;
}

.chart-card .card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.85rem 1.25rem;
  border-bottom: 1px solid var(--border);
  background: var(--surface-2);
}

.chart-card .card-header h3 {
  font-family: var(--mono);
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  color: var(--text-muted);
}

.chart-card .card-body {
  padding: 1.25rem;
  height: 280px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.chart-card canvas {
  width: 100% !important;
  height: 100% !important;
}

/* ─── Textarea ────────────────────────────────── */

.form-group textarea {
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
  resize: vertical;
}

.form-group textarea:focus {
  border-color: var(--accent);
  box-shadow: 0 0 0 3px var(--accent-dim);
}

.form-group textarea::placeholder {
  color: var(--text-dim);
}

/* ─── SLA Badges ──────────────────────────────── */

.sla-ok      { color: var(--success); }
.sla-at_risk { color: var(--warning); }
.sla-breached { color: var(--danger); }

/* ─── Responsive ──────────────────────────────── */

@media (max-width: 768px) {
  .shell {
    padding: 0 0.75rem;
  }

  .topbar {
    flex-wrap: wrap;
  }

  .topbar-brand {
    margin-right: auto;
  }

  .topbar-nav {
    order: 3;
    width: 100%;
    overflow-x: auto;
    padding-top: 0.5rem;
  }

  .form-grid,
  .detail-grid {
    grid-template-columns: 1fr;
  }

  .detail-item:nth-child(odd) {
    border-right: none;
  }

  .data-table,
  .queue-table {
    display: block;
    overflow-x: auto;
  }

  .stat-row {
    flex-wrap: wrap;
  }

  .stat-row .stat {
    min-width: calc(50% - 0.5rem);
    flex: 0 0 calc(50% - 0.5rem);
  }

  .chart-grid {
    grid-template-columns: 1fr;
  }

  .filter-bar {
    flex-direction: column;
    align-items: stretch;
  }

  .filter-group {
    width: 100%;
  }

  .filter-group select,
  .filter-group input {
    width: 100%;
  }

  .auth-card {
    margin: 2rem 0.5rem;
    padding: 2rem 1.5rem;
  }
}

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
        <a href="www?page=queue.html" class="active">Queue <span class="nav-badge" id="queue-badge"></span></a>
        <a href="www?page=analytics.html">Analytics</a>
      </nav>
      <span class="topbar-user"><span id="user-info"></span><button class="topbar-signout" onclick="signOut()" title="Sign out">Sign out</button></span>
    </header>

    <div id="auth" class="auth-card">
      <img src="https://oandzthkyemwojhebqwc.supabase.co/storage/v1/object/public/www/capreq-icon.png" alt="CapReq" class="auth-logo">
      <h2>CapReq</h2>
      <p class="auth-tagline">Manage infrastructure capacity requests with approvals</p>
      <p>Sign in with your Slack workspace account.</p>
      <button class="btn btn-primary btn-slack" onclick="signInWithSlack()">
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor"><path d="M5.042 15.165a2.528 2.528 0 0 1-2.52 2.523A2.528 2.528 0 0 1 0 15.165a2.527 2.527 0 0 1 2.522-2.52h2.52v2.52zm1.271 0a2.527 2.527 0 0 1 2.521-2.52 2.527 2.527 0 0 1 2.521 2.52v6.313A2.528 2.528 0 0 1 8.834 24a2.528 2.528 0 0 1-2.521-2.522v-6.313zM8.834 5.042a2.528 2.528 0 0 1-2.521-2.52A2.528 2.528 0 0 1 8.834 0a2.528 2.528 0 0 1 2.521 2.522v2.52H8.834zm0 1.271a2.528 2.528 0 0 1 2.521 2.521 2.528 2.528 0 0 1-2.521 2.521H2.522A2.528 2.528 0 0 1 0 8.834a2.528 2.528 0 0 1 2.522-2.521h6.312zM18.956 8.834a2.528 2.528 0 0 1 2.522-2.521A2.528 2.528 0 0 1 24 8.834a2.528 2.528 0 0 1-2.522 2.521h-2.522V8.834zm-1.27 0a2.528 2.528 0 0 1-2.523 2.521 2.527 2.527 0 0 1-2.52-2.521V2.522A2.527 2.527 0 0 1 15.163 0a2.528 2.528 0 0 1 2.523 2.522v6.312zM15.163 18.956a2.528 2.528 0 0 1 2.523 2.522A2.528 2.528 0 0 1 15.163 24a2.527 2.527 0 0 1-2.52-2.522v-2.522h2.52zm0-1.27a2.527 2.527 0 0 1-2.52-2.523 2.527 2.527 0 0 1 2.52-2.52h6.315A2.528 2.528 0 0 1 24 15.165a2.528 2.528 0 0 1-2.522 2.523h-6.315z"/></svg>
        Sign in with Slack
      </button>
      <p id="auth-msg" class="hidden mt-2"></p>
    </div>

    <div id="app" class="hidden">
      <div class="page-header fade-in">
        <h1>Approval Queue</h1>
        <p>Actions pending your review</p>
      </div>

      <div id="msg"></div>

      <div class="card fade-in fade-in-1">
        <div class="card-header">
          <h3>Pending Actions</h3>
        </div>
        <div id="queue-content">
          <table class="queue-table">
            <thead>
              <tr>
                <th>Request ID</th>
                <th>Action Needed</th>
                <th>Size</th>
                <th>Qty</th>
                <th>Region</th>
                <th>Cost</th>
                <th>Needed By</th>
                <th>SLA</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody id="queue-body">
              <tr><td colspan="9" class="loading" style="text-align:center;padding:2rem;">Loading queue...</td></tr>
            </tbody>
          </table>
        </div>
      </div>

      <footer class="app-footer fade-in fade-in-3">
        <p>Approve or reject pending actions from your queue. Actions are assigned based on your role and ownership of each request.</p>
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

    const actionMap = {
      commercial_review:     { approve: 'COMMERCIAL_APPROVED',  reject: 'COMMERCIAL_REJECTED',  label: 'Commercial Review' },
      technical_review:      { approve: 'TECH_REVIEW_APPROVED', reject: 'TECH_REVIEW_REJECTED', label: 'Technical Review' },
      vp_approval:           { approve: 'VP_APPROVED',          reject: 'VP_REJECTED',          label: 'VP Approval' },
      customer_confirmation: { approve: 'CUSTOMER_CONFIRMED',   reject: 'CUSTOMER_DECLINED',    label: 'Customer Confirmation' }
    };

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

    async function signInWithSlack() {
      const { data, error } = await sb.auth.signInWithOAuth({
        provider: 'slack_oidc',
        options: { redirectTo: window.location.href }
      });
      if (error) {
        const msg = document.getElementById('auth-msg');
        msg.classList.remove('hidden');
        msg.className = 'msg msg-error mt-2';
        msg.textContent = error.message;
      }
    }

    async function signOut() {
      await sb.auth.signOut();
      location.reload();
    }

    function getSlackUserId(user) {
      if (user.user_metadata?.provider_id) return user.user_metadata.provider_id;
      const slack = user.identities?.find(i => i.provider === 'slack_oidc');
      if (slack?.identity_data?.provider_id) return slack.identity_data.provider_id;
      if (user.user_metadata?.sub) return user.user_metadata.sub;
      return user.id || user.email;
    }

    async function showApp(user) {
      document.getElementById('auth').classList.add('hidden');
      document.getElementById('app').classList.remove('hidden');
      const displayName = user.user_metadata?.name || user.user_metadata?.full_name || user.email;
      document.getElementById('user-info').textContent = displayName;
      window._userId = getSlackUserId(user);
      await loadQueue();
    }

    async function loadQueue() {
      const userId = window._userId || 'web-user';
      const { data, error } = await sb.rpc('get_my_pending_actions', { p_user_id: userId });

      const tbody = document.getElementById('queue-body');
      const badge = document.getElementById('queue-badge');

      if (error) {
        tbody.innerHTML = `<tr><td colspan="9" style="text-align:center;padding:2rem;" class="msg-error">${error.message}</td></tr>`;
        return;
      }

      if (!data || data.length === 0) {
        badge.textContent = '';
        document.getElementById('queue-content').innerHTML = `
          <div class="empty-state">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <p>No pending actions &mdash; you're all caught up!</p>
          </div>`;
        return;
      }

      badge.textContent = data.length;

      tbody.innerHTML = data.map((item, idx) => {
        const action = actionMap[item.action_needed] || { approve: null, reject: null, label: item.action_needed };
        const slaClass = item.sla_status ? 'sla-' + item.sla_status : '';
        const slaLabel = item.sla_status ? item.sla_status.replace(/_/g, ' ') : '\u2014';
        return `
          <tr>
            <td class="col-id" style="cursor:pointer" onclick="location.href='www?page=detail.html#id=${encodeURIComponent(item.request_id)}'">
              ${esc(item.request_id)}
            </td>
            <td>${esc(action.label)}</td>
            <td class="col-mono">${esc(item.requested_size)}</td>
            <td>${item.quantity}</td>
            <td class="col-mono">${esc(item.region)}</td>
            <td class="col-cost">${item.estimated_monthly_cost_usd != null ? '$' + Number(item.estimated_monthly_cost_usd).toLocaleString() : '\u2014'}</td>
            <td class="col-date">${item.needed_by_date || '\u2014'}</td>
            <td><span class="${slaClass}" style="font-weight:600;font-size:0.8rem;text-transform:uppercase;font-family:var(--mono)">${slaLabel}</span></td>
            <td class="queue-actions">
              ${action.approve ? `<button class="btn btn-success" onclick="doAction('${esc(item.request_id)}','${action.approve}',this)">Approve</button>` : ''}
              ${action.reject ? `<button class="btn btn-danger" onclick="doAction('${esc(item.request_id)}','${action.reject}',this)">Reject</button>` : ''}
            </td>
          </tr>`;
      }).join('');
    }

    async function doAction(requestId, eventType, btn) {
      const msgEl = document.getElementById('msg');
      msgEl.innerHTML = '';
      btn.disabled = true;

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
        btn.disabled = false;
      } else {
        msgEl.innerHTML = `<div class="msg msg-success">Action applied to ${esc(requestId)}.</div>`;
        await loadQueue();
      }
    }

    function esc(s) {
      if (s == null) return '';
      const d = document.createElement('div');
      d.textContent = String(s);
      return d.innerHTML;
    }

    function fmtState(s) {
      return (s || '').replace(/_/g, ' ');
    }

    init();
  </script>
</body>
</html>
$page$);

-- ============================================================
-- analytics.html
-- ============================================================
INSERT INTO static_pages (path, content) VALUES ('analytics.html', $page$<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>CapReq — Analytics</title>
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

/* ─── Top Bar ──────────────────────────────────── */

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
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-family: var(--mono);
  font-size: 0.75rem;
  color: var(--text-dim);
  padding: 0.35rem 0.6rem;
  border: 1px solid var(--border);
  border-radius: 6px;
}

.topbar-signout {
  color: var(--text-dim);
  cursor: pointer;
  opacity: 0.6;
  transition: opacity 0.2s, color 0.2s;
  background: none;
  border: none;
  font-family: var(--mono);
  font-size: 0.7rem;
  padding: 0;
}

.topbar-signout:hover {
  opacity: 1;
  color: var(--danger);
}

/* ─── Page Header ──────────────────────────────── */

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

/* ─── Auth Card ────────────────────────────────── */

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

/* ─── Cards & Panels ──────────────────────────── */

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

/* ─── Data Table ───────────────────────────────── */

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

/* ─── State Badges ─────────────────────────────── */

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

/* ─── Buttons ──────────────────────────────────── */

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

.btn-slack {
  width: 100%;
  justify-content: center;
  gap: 0.6rem;
  font-size: 0.9rem;
  padding: 0.7rem 1.25rem;
}

.btn-slack svg {
  width: 20px;
  height: 20px;
  flex-shrink: 0;
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

/* ─── Detail Grid ──────────────────────────────── */

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

/* ─── Timeline ─────────────────────────────────── */

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

/* ─── Forms ────────────────────────────────────── */

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

/* ─── Messages ─────────────────────────────────── */

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

/* ─── Section Dividers ─────────────────────────── */

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

/* ─── Stat Pills (confirm page) ────────────────── */

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

/* ─── Footer ──────────────────────────────────── */

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

/* ─── Utilities ────────────────────────────────── */

.hidden { display: none !important; }

.mt-1 { margin-top: 0.5rem; }
.mt-2 { margin-top: 1rem; }
.mt-3 { margin-top: 1.5rem; }
.mb-2 { margin-bottom: 1rem; }
.mb-3 { margin-bottom: 1.5rem; }

/* ─── Animations ───────────────────────────────── */

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

/* ─── Workflow Stepper ────────────────────────── */

.stepper {
  display: flex;
  align-items: flex-start;
  gap: 0;
  overflow-x: auto;
  padding: 1rem 0.5rem 0.5rem;
}

.stepper-stage {
  display: flex;
  flex-direction: column;
  align-items: center;
  position: relative;
  flex: 1;
  min-width: 0;
}

.stepper-row {
  display: flex;
  align-items: center;
  width: 100%;
}

.stepper-connector {
  flex: 1;
  height: 2px;
  background: var(--border);
  min-width: 8px;
}

.stepper-connector.completed {
  background: var(--success);
}

.stepper-connector.invisible {
  visibility: hidden;
}

.stepper-node {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  font-size: 0.7rem;
  font-weight: 700;
  border: 2px solid var(--border);
  background: var(--surface);
  color: var(--text-dim);
  transition: all 0.3s;
}

.stepper-node.completed {
  border-color: var(--success);
  background: var(--success-dim);
  color: var(--success);
}

.stepper-node.active {
  border-color: var(--accent);
  background: var(--accent-dim);
  color: var(--accent);
  box-shadow: 0 0 12px var(--accent-glow), 0 0 24px rgba(245, 158, 11, 0.1);
  animation: stepperPulse 2s ease-in-out infinite;
}

.stepper-node.failed {
  border-color: var(--danger);
  background: var(--danger-dim);
  color: var(--danger);
}

.stepper-label {
  margin-top: 0.4rem;
  font-family: var(--mono);
  font-size: 0.62rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--text-dim);
  text-align: center;
  white-space: nowrap;
}

.stepper-label.completed { color: var(--success); }
.stepper-label.active    { color: var(--accent); }
.stepper-label.failed    { color: var(--danger); }

@keyframes stepperPulse {
  0%, 100% { box-shadow: 0 0 12px var(--accent-glow), 0 0 24px rgba(245, 158, 11, 0.1); }
  50%      { box-shadow: 0 0 18px var(--accent-glow), 0 0 36px rgba(245, 158, 11, 0.2); }
}

/* Approval sub-checks shown below stepper for UNDER_REVIEW */
.approval-checks {
  display: flex;
  gap: 1.25rem;
  flex-wrap: wrap;
  padding: 0.75rem 0 0;
  margin-top: 0.75rem;
  border-top: 1px solid var(--border);
}

.approval-check {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  font-family: var(--mono);
  font-size: 0.72rem;
  font-weight: 500;
  color: var(--text-muted);
}

.approval-check .check-icon {
  width: 16px;
  height: 16px;
  border-radius: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.6rem;
  font-weight: 700;
}

.approval-check .check-icon.done {
  background: var(--success-dim);
  color: var(--success);
  border: 1px solid rgba(34, 197, 94, 0.3);
}

.approval-check .check-icon.pending {
  background: var(--surface-2);
  color: var(--text-dim);
  border: 1px solid var(--border);
}

/* Operator guidance banner */
.guidance-banner {
  padding: 0.75rem 1rem;
  border-radius: var(--radius);
  font-size: 0.85rem;
  line-height: 1.5;
  margin-bottom: 1rem;
  border: 1px solid transparent;
}

.guidance-info {
  background: var(--info-dim);
  color: var(--info);
  border-color: rgba(56, 189, 248, 0.2);
}

.guidance-success {
  background: var(--success-dim);
  color: #4ade80;
  border-color: rgba(34, 197, 94, 0.2);
}

.guidance-error {
  background: var(--danger-dim);
  color: #f87171;
  border-color: rgba(239, 68, 68, 0.2);
}

.guidance-muted {
  background: #1e1e2e;
  color: #8888a0;
  border-color: rgba(42, 42, 58, 0.5);
}

/* ─── Filter Bar ──────────────────────────────── */

.filter-bar {
  display: flex;
  gap: 0.75rem;
  align-items: flex-end;
  flex-wrap: wrap;
  padding: 0.85rem 1.25rem;
  border-bottom: 1px solid var(--border);
  background: var(--surface-2);
}

.filter-group {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.filter-group label {
  font-family: var(--mono);
  font-size: 0.68rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--text-dim);
}

.filter-group select,
.filter-group input {
  padding: 0.4rem 0.65rem;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  color: var(--text);
  font-family: var(--sans);
  font-size: 0.82rem;
  outline: none;
  transition: border-color 0.2s, box-shadow 0.2s;
  -webkit-appearance: none;
}

.filter-group select {
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='8' fill='none'%3E%3Cpath d='M1 1.5l5 5 5-5' stroke='%238888a0' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 0.65rem center;
  padding-right: 2rem;
}

.filter-group select:focus,
.filter-group input:focus {
  border-color: var(--accent);
  box-shadow: 0 0 0 3px var(--accent-dim);
}

.filter-group input::placeholder {
  color: var(--text-dim);
}

.filter-actions {
  display: flex;
  align-items: flex-end;
}

.filter-actions .btn {
  padding: 0.4rem 0.65rem;
  font-size: 0.78rem;
}

/* ─── Age Indicators ──────────────────────────── */

.age-green td:first-child { border-left: 3px solid var(--success); }
.age-amber td:first-child { border-left: 3px solid var(--warning); }
.age-red td:first-child   { border-left: 3px solid var(--danger); }

/* ─── Event Notes in Timeline ─────────────────── */

.event-notes {
  margin-top: 0.35rem;
  font-size: 0.8rem;
  font-style: italic;
  color: var(--text-muted);
  background: var(--surface-2);
  padding: 0.35rem 0.6rem;
  border-radius: 4px;
  border-left: 3px solid var(--warning);
}

/* ─── Queue Page ──────────────────────────────── */

.queue-table {
  width: 100%;
  border-collapse: collapse;
}

.queue-table th {
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

.queue-table td {
  padding: 0.7rem 1rem;
  font-size: 0.875rem;
  border-bottom: 1px solid rgba(42, 42, 58, 0.5);
}

.queue-table tbody tr:last-child td {
  border-bottom: none;
}

.queue-actions {
  display: flex;
  gap: 0.35rem;
}

.queue-actions .btn {
  padding: 0.3rem 0.6rem;
  font-size: 0.75rem;
}

.badge-count {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 18px;
  height: 18px;
  padding: 0 5px;
  border-radius: 100px;
  font-family: var(--mono);
  font-size: 0.65rem;
  font-weight: 700;
  background: var(--accent);
  color: #000;
}

.empty-state {
  text-align: center;
  padding: 3rem 1rem;
  color: var(--text-dim);
}

.empty-state svg {
  width: 48px;
  height: 48px;
  margin-bottom: 1rem;
  opacity: 0.3;
}

.empty-state p {
  font-size: 0.9rem;
}

/* ─── Nav Badge ───────────────────────────────── */

.nav-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 16px;
  height: 16px;
  padding: 0 4px;
  border-radius: 100px;
  font-family: var(--mono);
  font-size: 0.6rem;
  font-weight: 700;
  background: var(--accent);
  color: #000;
  margin-left: 0.25rem;
  vertical-align: middle;
}

.nav-badge:empty { display: none; }

/* ─── Analytics Page ──────────────────────────── */

.chart-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.25rem;
}

.chart-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  overflow: hidden;
}

.chart-card .card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.85rem 1.25rem;
  border-bottom: 1px solid var(--border);
  background: var(--surface-2);
}

.chart-card .card-header h3 {
  font-family: var(--mono);
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  color: var(--text-muted);
}

.chart-card .card-body {
  padding: 1.25rem;
  height: 280px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.chart-card canvas {
  width: 100% !important;
  height: 100% !important;
}

/* ─── Textarea ────────────────────────────────── */

.form-group textarea {
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
  resize: vertical;
}

.form-group textarea:focus {
  border-color: var(--accent);
  box-shadow: 0 0 0 3px var(--accent-dim);
}

.form-group textarea::placeholder {
  color: var(--text-dim);
}

/* ─── SLA Badges ──────────────────────────────── */

.sla-ok      { color: var(--success); }
.sla-at_risk { color: var(--warning); }
.sla-breached { color: var(--danger); }

/* ─── Responsive ──────────────────────────────── */

@media (max-width: 768px) {
  .shell {
    padding: 0 0.75rem;
  }

  .topbar {
    flex-wrap: wrap;
  }

  .topbar-brand {
    margin-right: auto;
  }

  .topbar-nav {
    order: 3;
    width: 100%;
    overflow-x: auto;
    padding-top: 0.5rem;
  }

  .form-grid,
  .detail-grid {
    grid-template-columns: 1fr;
  }

  .detail-item:nth-child(odd) {
    border-right: none;
  }

  .data-table,
  .queue-table {
    display: block;
    overflow-x: auto;
  }

  .stat-row {
    flex-wrap: wrap;
  }

  .stat-row .stat {
    min-width: calc(50% - 0.5rem);
    flex: 0 0 calc(50% - 0.5rem);
  }

  .chart-grid {
    grid-template-columns: 1fr;
  }

  .filter-bar {
    flex-direction: column;
    align-items: stretch;
  }

  .filter-group {
    width: 100%;
  }

  .filter-group select,
  .filter-group input {
    width: 100%;
  }

  .auth-card {
    margin: 2rem 0.5rem;
    padding: 2rem 1.5rem;
  }
}

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
        <a href="www?page=queue.html">Queue <span class="nav-badge" id="queue-badge"></span></a>
        <a href="www?page=analytics.html" class="active">Analytics</a>
      </nav>
      <span class="topbar-user"><span id="user-info"></span><button class="topbar-signout" onclick="signOut()" title="Sign out">Sign out</button></span>
    </header>

    <div id="auth" class="auth-card">
      <img src="https://oandzthkyemwojhebqwc.supabase.co/storage/v1/object/public/www/capreq-icon.png" alt="CapReq" class="auth-logo">
      <h2>CapReq</h2>
      <p class="auth-tagline">Manage infrastructure capacity requests with approvals</p>
      <p>Sign in with your Slack workspace account.</p>
      <button class="btn btn-primary btn-slack" onclick="signInWithSlack()">
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor"><path d="M5.042 15.165a2.528 2.528 0 0 1-2.52 2.523A2.528 2.528 0 0 1 0 15.165a2.527 2.527 0 0 1 2.522-2.52h2.52v2.52zm1.271 0a2.527 2.527 0 0 1 2.521-2.52 2.527 2.527 0 0 1 2.521 2.52v6.313A2.528 2.528 0 0 1 8.834 24a2.528 2.528 0 0 1-2.521-2.522v-6.313zM8.834 5.042a2.528 2.528 0 0 1-2.521-2.52A2.528 2.528 0 0 1 8.834 0a2.528 2.528 0 0 1 2.521 2.522v2.52H8.834zm0 1.271a2.528 2.528 0 0 1 2.521 2.521 2.528 2.528 0 0 1-2.521 2.521H2.522A2.528 2.528 0 0 1 0 8.834a2.528 2.528 0 0 1 2.522-2.521h6.312zM18.956 8.834a2.528 2.528 0 0 1 2.522-2.521A2.528 2.528 0 0 1 24 8.834a2.528 2.528 0 0 1-2.522 2.521h-2.522V8.834zm-1.27 0a2.528 2.528 0 0 1-2.523 2.521 2.527 2.527 0 0 1-2.52-2.521V2.522A2.527 2.527 0 0 1 15.163 0a2.528 2.528 0 0 1 2.523 2.522v6.312zM15.163 18.956a2.528 2.528 0 0 1 2.523 2.522A2.528 2.528 0 0 1 15.163 24a2.527 2.527 0 0 1-2.52-2.522v-2.522h2.52zm0-1.27a2.527 2.527 0 0 1-2.52-2.523 2.527 2.527 0 0 1 2.52-2.52h6.315A2.528 2.528 0 0 1 24 15.165a2.528 2.528 0 0 1-2.522 2.523h-6.315z"/></svg>
        Sign in with Slack
      </button>
      <p id="auth-msg" class="hidden mt-2"></p>
    </div>

    <div id="app" class="hidden">
      <div class="page-header fade-in">
        <h1>Analytics</h1>
        <p>Capacity request metrics and trends</p>
      </div>

      <div id="msg"></div>

      <div class="chart-grid fade-in fade-in-1">
        <div class="chart-card">
          <div class="card-header"><h3>Requests by State</h3></div>
          <div class="card-body"><canvas id="chart-state"></canvas></div>
        </div>
        <div class="chart-card">
          <div class="card-header"><h3>Approval Latency (hours)</h3></div>
          <div class="card-body"><canvas id="chart-latency"></canvas></div>
        </div>
        <div class="chart-card">
          <div class="card-header"><h3>Cost by Region</h3></div>
          <div class="card-body"><canvas id="chart-region"></canvas></div>
        </div>
        <div class="chart-card">
          <div class="card-header"><h3>Request Volume</h3></div>
          <div class="card-body"><canvas id="chart-volume"></canvas></div>
        </div>
        <div class="chart-card">
          <div class="card-header"><h3>Time in State (hours)</h3></div>
          <div class="card-body"><canvas id="chart-time-state"></canvas></div>
        </div>
        <div class="chart-card">
          <div class="card-header"><h3>VP Escalation Rate</h3></div>
          <div class="card-body"><canvas id="chart-escalation"></canvas></div>
        </div>
      </div>

      <footer class="app-footer fade-in fade-in-3">
        <p>Analytics are computed from all capacity requests. Charts update on page load.</p>
      </footer>
    </div>
  </div>

  <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/chart.js@4/dist/chart.umd.min.js"></script>
  <script>
    const SUPABASE_URL = 'https://oandzthkyemwojhebqwc.supabase.co';
    const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9hbmR6dGhreWVtd29qaGVicXdjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzExMDgwNzUsImV4cCI6MjA4NjY4NDA3NX0.v7hwYm4a-b1aiWj04cCQY2WT9v08FEqvioFU3BG7nus';
  </script>
  <script>
    const sb = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

    const COLORS = {
      amber:  '#f59e0b',
      green:  '#22c55e',
      red:    '#ef4444',
      blue:   '#38bdf8',
      purple: '#a78bfa',
      muted:  '#8888a0'
    };
    const PALETTE = [COLORS.amber, COLORS.green, COLORS.red, COLORS.blue, COLORS.purple, COLORS.muted, '#f472b6', '#34d399', '#fb923c'];

    // Chart.js global defaults for dark theme
    Chart.defaults.color = '#8888a0';
    Chart.defaults.borderColor = '#2a2a3a';
    Chart.defaults.plugins.legend.labels.boxWidth = 12;
    Chart.defaults.plugins.legend.labels.padding = 12;

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

    async function signInWithSlack() {
      const { data, error } = await sb.auth.signInWithOAuth({
        provider: 'slack_oidc',
        options: { redirectTo: window.location.href }
      });
      if (error) {
        const msg = document.getElementById('auth-msg');
        msg.classList.remove('hidden');
        msg.className = 'msg msg-error mt-2';
        msg.textContent = error.message;
      }
    }

    async function signOut() {
      await sb.auth.signOut();
      location.reload();
    }

    function getSlackUserId(user) {
      if (user.user_metadata?.provider_id) return user.user_metadata.provider_id;
      const slack = user.identities?.find(i => i.provider === 'slack_oidc');
      if (slack?.identity_data?.provider_id) return slack.identity_data.provider_id;
      if (user.user_metadata?.sub) return user.user_metadata.sub;
      return user.id || user.email;
    }

    async function showApp(user) {
      document.getElementById('auth').classList.add('hidden');
      document.getElementById('app').classList.remove('hidden');
      const displayName = user.user_metadata?.name || user.user_metadata?.full_name || user.email;
      document.getElementById('user-info').textContent = displayName;
      window._userId = getSlackUserId(user);
      await loadCharts();
    }

    function parseInterval(s) {
      if (!s) return 0;
      let hours = 0;
      const dayMatch = s.match(/(\d+)\s*day/);
      if (dayMatch) hours += parseInt(dayMatch[1]) * 24;
      const timeMatch = s.match(/(\d+):(\d+):(\d+)/);
      if (timeMatch) {
        hours += parseInt(timeMatch[1]);
        hours += parseInt(timeMatch[2]) / 60;
      }
      return Math.round(hours * 10) / 10;
    }

    async function loadCharts() {
      const [summaryRes, latencyRes, timeStateRes] = await Promise.all([
        sb.from('v_request_summary').select('*'),
        sb.from('v_approval_latency').select('*'),
        sb.from('v_time_in_state').select('*')
      ]);

      const summary = summaryRes.data || [];
      const latency = latencyRes.data || [];
      const timeState = timeStateRes.data || [];

      // 1. Requests by State (Doughnut)
      const stateCounts = {};
      summary.forEach(r => { stateCounts[r.state] = (stateCounts[r.state] || 0) + 1; });
      const stateLabels = Object.keys(stateCounts);
      new Chart(document.getElementById('chart-state'), {
        type: 'doughnut',
        data: {
          labels: stateLabels.map(s => s.replace(/_/g, ' ')),
          datasets: [{
            data: stateLabels.map(s => stateCounts[s]),
            backgroundColor: stateLabels.map((_, i) => PALETTE[i % PALETTE.length]),
            borderWidth: 0
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: { legend: { position: 'right' } }
        }
      });

      // 2. Approval Latency (Horizontal Bar)
      const latencyLabels = [];
      const latencyValues = [];
      const latencyColors = [COLORS.amber, COLORS.blue, COLORS.purple];
      latency.forEach((row, i) => {
        latencyLabels.push(row.approval_stage || row.stage || ('Stage ' + (i + 1)));
        latencyValues.push(parseInterval(row.avg_latency || row.average_latency));
      });
      if (latencyLabels.length === 0) {
        latencyLabels.push('Commercial', 'Technical', 'VP');
        latencyValues.push(0, 0, 0);
      }
      new Chart(document.getElementById('chart-latency'), {
        type: 'bar',
        data: {
          labels: latencyLabels,
          datasets: [{
            label: 'Avg Hours',
            data: latencyValues,
            backgroundColor: latencyLabels.map((_, i) => latencyColors[i % latencyColors.length]),
            borderWidth: 0
          }]
        },
        options: {
          indexAxis: 'y',
          responsive: true,
          maintainAspectRatio: false,
          plugins: { legend: { display: false } },
          scales: { x: { beginAtZero: true } }
        }
      });

      // 3. Cost by Region (Stacked Bar)
      const regionCost = {};
      summary.forEach(r => {
        if (r.region && r.estimated_monthly_cost_usd != null) {
          regionCost[r.region] = (regionCost[r.region] || 0) + Number(r.estimated_monthly_cost_usd);
        }
      });
      const regionLabels = Object.keys(regionCost).sort();
      new Chart(document.getElementById('chart-region'), {
        type: 'bar',
        data: {
          labels: regionLabels,
          datasets: [{
            label: 'Total Cost ($)',
            data: regionLabels.map(r => regionCost[r]),
            backgroundColor: COLORS.amber,
            borderWidth: 0
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: { legend: { display: false } },
          scales: { y: { beginAtZero: true } }
        }
      });

      // 4. Request Volume (Line - count per month)
      const monthCounts = {};
      summary.forEach(r => {
        if (r.created_at) {
          const d = new Date(r.created_at);
          const key = d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0');
          monthCounts[key] = (monthCounts[key] || 0) + 1;
        }
      });
      const monthLabels = Object.keys(monthCounts).sort();
      new Chart(document.getElementById('chart-volume'), {
        type: 'line',
        data: {
          labels: monthLabels,
          datasets: [{
            label: 'Requests',
            data: monthLabels.map(m => monthCounts[m]),
            borderColor: COLORS.blue,
            backgroundColor: 'rgba(56, 189, 248, 0.1)',
            fill: true,
            tension: 0.3,
            borderWidth: 2,
            pointRadius: 3
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: { legend: { display: false } },
          scales: { y: { beginAtZero: true } }
        }
      });

      // 5. Time in State (Bar)
      const tsLabels = [];
      const tsValues = [];
      timeState.forEach(row => {
        tsLabels.push((row.event_type || '').replace(/_/g, ' '));
        tsValues.push(parseInterval(row.median_duration || row.avg_duration));
      });
      if (tsLabels.length === 0) {
        tsLabels.push('No data');
        tsValues.push(0);
      }
      new Chart(document.getElementById('chart-time-state'), {
        type: 'bar',
        data: {
          labels: tsLabels,
          datasets: [{
            label: 'Median Hours',
            data: tsValues,
            backgroundColor: COLORS.purple,
            borderWidth: 0
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: { legend: { display: false } },
          scales: { y: { beginAtZero: true } }
        }
      });

      // 6. VP Escalation Rate (Doughnut)
      let escalated = 0, notEscalated = 0;
      summary.forEach(r => {
        if (r.escalation_required) escalated++;
        else notEscalated++;
      });
      new Chart(document.getElementById('chart-escalation'), {
        type: 'doughnut',
        data: {
          labels: ['Escalated', 'Not Escalated'],
          datasets: [{
            data: [escalated, notEscalated],
            backgroundColor: [COLORS.red, COLORS.green],
            borderWidth: 0
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: { legend: { position: 'right' } }
        }
      });
    }

    function esc(s) {
      if (s == null) return '';
      const d = document.createElement('div');
      d.textContent = String(s);
      return d.innerHTML;
    }

    init();
  </script>
</body>
</html>
$page$);

