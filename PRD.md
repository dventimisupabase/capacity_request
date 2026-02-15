# CapReq Phase 6 — Product Requirements Document

## Overview

Phase 6 encompasses four workstreams that take CapReq from a functional MVP to a production-grade operations tool: backend reliability and security hardening, quick-win feature additions, operator-facing tooling (approval queue, search/filter), an analytics dashboard, and a full visual redesign of the web UI.

**Scope**: 12 enhancements across 4 bundles, touching SQL migrations, edge functions, and all web UI pages.

---

## 1. Quick Wins Bundle

### 1.1 Slack DM Notifications

**What**: When a request transitions to a state requiring someone's action, send a Slack DM to that person in addition to the channel post.

**Who it helps**: Approvers who may miss channel messages in busy Slack workspaces.

**Behavior**:
- SUBMITTED → UNDER_REVIEW: DM the `commercial_owner_user_id` ("You have a new request to review commercially") and post to `infra_owner_group` channel ("New request needs technical review")
- VP escalation triggered: DM the VP approver (need a way to identify VP — could be a new Vault secret `VP_SLACK_USER_ID` or a column on the request)
- UNDER_REVIEW → CUSTOMER_CONFIRMATION_REQUIRED: DM the requester ("All approvals received, customer confirmation pending")

**Implementation approach**: Add DM dispatch logic to the outbox insertion in `apply_capacity_event()`. Use Slack `chat.postMessage` with `channel` set to the user's Slack ID (not a channel). Requires mapping Supabase user IDs to Slack user IDs — either store `slack_user_id` on the request or use a lookup table.

**Open question**: How do we map `commercial_owner_user_id` (currently a free-text field) to a Slack user ID? Options: (a) require Slack user ID format in the field, (b) add a `users` lookup table, (c) use Slack's `users.lookupByEmail` API.

### 1.2 Confirmation Reminder

**What**: Send a reminder notification when a customer confirmation deadline is 50% elapsed.

**Who it helps**: Customers who received the confirmation request but forgot to act on it.

**Behavior**:
- Request enters CUSTOMER_CONFIRMATION_REQUIRED with `next_deadline_at` set (currently 7 days from transition)
- When the timer sweep (`run_capacity_request_timers()`) runs and finds a request where `now() > created_at_for_state + (deadline - created_at_for_state) / 2` and no reminder has been sent → enqueue a reminder via outbox
- Reminder goes to the same Slack channel as the original notification, threaded to the original message
- Track that reminder was sent (e.g., a `reminder_sent_at` column on `capacity_requests`, or a new event type `CONFIRMATION_REMINDER_SENT`)

**Edge cases**:
- If the customer confirms before the 50% mark, no reminder is sent
- If the request is cancelled before the 50% mark, no reminder is sent
- Only one reminder per request (idempotent check)

### 1.3 Request Comments / Notes

**What**: Allow actors to attach free-text notes when performing actions (approve, reject, cancel, etc.). Display notes in the event timeline.

**Who it helps**: All stakeholders — provides context for why decisions were made.

**Behavior**:
- Add a `notes` TEXT column to `capacity_request_events`
- `apply_capacity_event()` accepts an optional `p_notes` parameter
- Slack interactive buttons: add a modal prompt for notes when rejecting or cancelling (optional for approvals)
- Slack slash commands: `/capacity reject CR-2026-000001 --reason "Budget not approved"`
- Web UI detail page: display notes in the event timeline next to each event
- Web UI confirm page: optional text area for customer to add a note when confirming/declining
- Block Kit messages: include notes in the notification when present

**Data model change**: `ALTER TABLE capacity_request_events ADD COLUMN notes text;`

### 1.4 Request Age Indicators

**What**: Color-code dashboard table rows by request age to highlight stale requests.

**Who it helps**: Operators scanning the dashboard for requests that need attention.

**Behavior**:
- Green: created < 24 hours ago
- Yellow/amber: created 24–72 hours ago
- Red: created > 72 hours ago
- Only applies to non-terminal states (COMPLETED, REJECTED, CANCELLED, EXPIRED, FAILED rows are not colored)
- Implemented as a CSS class applied in the `loadRequests()` JS function based on `created_at` timestamp

---

## 2. High-Impact Bundle

### 2.1 Idempotency Keys for Webhooks

**What**: Prevent duplicate event application when Slack buttons are clicked multiple times or webhooks are retried.

**Who it helps**: System reliability — prevents data corruption from duplicate actions.

**Behavior**:
- Add an `idempotency_key` TEXT column to `capacity_request_events` with a UNIQUE constraint
- `apply_capacity_event()` accepts an optional `p_idempotency_key` parameter
- If a key is provided and already exists in the events table, the function returns the existing event instead of creating a new one (no error, idempotent success)
- Slack interactive payloads: use `actions[0].action_id + "-" + container.message_ts` as the idempotency key
- Provisioning webhook: use `X-Idempotency-Key` header if provided
- Web UI: generate a client-side UUID per button click, pass as idempotency key

**Data model change**: `ALTER TABLE capacity_request_events ADD COLUMN idempotency_key text UNIQUE;`

### 2.2 Approval Queue Page

**What**: A new web page (`queue.html`) showing only the requests that need the current user's action.

**Who it helps**: Approvers who want a focused view of their pending work.

**Behavior**:
- Filtered view based on the logged-in user's identity:
  - If user matches `commercial_owner_user_id` → show UNDER_REVIEW requests where `commercial_approved_at IS NULL`
  - If user matches `infra_owner_group` → show UNDER_REVIEW requests where `technical_approved_at IS NULL`
  - Requests in CUSTOMER_CONFIRMATION_REQUIRED where user is the requester → show for confirmation
- Each row has inline action buttons (Approve / Reject) that call `apply_capacity_event()` directly
- Shows count badge in the nav bar ("Queue (3)")
- Empty state: "No pending actions -- you're all caught up"

**SQL support**: May need a new view `v_my_pending_actions` or an RPC function that accepts the user ID and returns matching requests.

**Nav change**: Add "Queue" link to the topbar on all pages.

### 2.3 Search & Filter on Dashboard

**What**: Add filtering controls to the dashboard so operators can find specific requests quickly.

**Who it helps**: Anyone managing more than a handful of requests.

**Behavior**:
- Filter bar above the table with:
  - State dropdown (multi-select): all 9 states, default "all"
  - Region dropdown: all configured regions, default "all"
  - Text search: filters by request ID, customer name (searches `customer_ref->>'name'`)
  - Date range: "Last 7 days", "Last 30 days", "Last 90 days", "All time"
- Filters apply client-side to the already-fetched data (for simplicity) OR via Supabase query params (for scalability)
- URL query params persist filter state (e.g., `?state=UNDER_REVIEW&region=us-east-1`) so links are shareable
- Clear filters button resets to defaults

### 2.4 Tighten RLS on Detail Views

**What**: Restrict `v_request_detail` and `v_request_events` so users can only see requests they're involved in.

**Who it helps**: Security — prevents unauthorized access to request details.

**Current state**: Migration 20260216000013 grants `SELECT` on these views to `anon` and `authenticated` without row filtering. The underlying `capacity_requests` table has proper RLS but views bypass it.

**Behavior**:
- Authenticated users can see requests where:
  - `requester_user_id = auth.uid()` (they created it)
  - `commercial_owner_user_id = auth.uid()` (they're the commercial reviewer)
  - User has an admin role (TBD: how to identify admins — JWT claim, or a separate `user_roles` table)
- Anonymous users (customer confirmation flow) can see only the specific request linked in their magic link URL (by ID)
- Service role bypasses all restrictions (for Slack bot operations)

**Open question**: How should admin users be identified? Options: (a) Supabase custom claims in JWT, (b) a `user_roles` table, (c) a Vault-stored list of admin email addresses.

---

## 3. Analytics Dashboard

### 3.1 Analytics Page

**What**: A new web page (`analytics.html`) with charts visualizing request metrics and operational health.

**Who it helps**: Managers and operators who need visibility into trends, bottlenecks, and costs.

**Charts**:

1. **Requests by State** (donut/pie chart)
   - Data source: `v_terminal_state_counts` + count of active-state requests
   - Shows distribution of all requests across states

2. **Approval Latency** (horizontal bar chart)
   - Data source: `v_approval_latency`
   - Shows average time for commercial, technical, and VP approvals
   - Grouped by month or rolling 30-day window

3. **Monthly Cost by Region** (stacked bar or line chart)
   - Data source: `v_request_summary` aggregated by region and month
   - Shows `estimated_monthly_cost_usd` summed per region per month

4. **Request Volume Over Time** (line chart)
   - Data source: `capacity_requests` grouped by `created_at` month
   - Shows new requests per month, optionally split by terminal outcome

5. **Time in State** (box plot or bar chart)
   - Data source: `v_time_in_state`
   - Shows median/p90 duration per state to identify bottlenecks

6. **VP Escalation Rate** (single stat + trend)
   - Percentage of requests requiring VP approval (where `vp_approved_at IS NOT NULL` or escalation was triggered)
   - Trend line over time

**Tech stack**: Chart.js via CDN (~60KB gzipped). No build step. All data fetched from existing Supabase views via the JS client.

**Layout**: Responsive grid — 2 columns on desktop, 1 on mobile. Each chart in a card with a title and subtitle.

**Nav change**: Add "Analytics" link to topbar on all pages.

### 3.2 SLA Tracking Views (supporting SQL)

**What**: SQL views that flag requests exceeding time-in-state thresholds.

**Thresholds** (configurable via Vault or hardcoded initially):
- UNDER_REVIEW: > 48 hours → "SLA breach"
- CUSTOMER_CONFIRMATION_REQUIRED: > 72 hours → "At risk" (distinct from the 7-day expiration)
- PROVISIONING: > 24 hours → "SLA breach"

**View**: `v_sla_status` — joins `v_time_in_state` with thresholds, adds a `sla_status` column ('ok', 'at_risk', 'breached').

**Usage**: Analytics page can show SLA compliance percentage. Dashboard can optionally show a warning icon on breached rows.

---

## 4. Web UI Redesign

### 4.1 Design Direction

**What**: Comprehensive visual overhaul of all pages (index, detail, new, confirm, queue, analytics) with a cohesive, distinctive aesthetic.

**Aesthetic**: Industrial ops-console evolved — keep the dark theme foundation but elevate it with:
- **Typography**: Distinctive display font for headings (e.g., JetBrains Mono or IBM Plex Mono for the monospace/technical feel, paired with a clean sans-serif like DM Sans or Outfit for body text) — loaded via Google Fonts CDN
- **Color system**: Deep navy/charcoal base (#0a0f1a), with an amber/gold accent (#f0b429) for active states, teal (#0ea5e9) for interactive elements, and a clear red/green for status. All via CSS custom properties.
- **Layout**: Full-bleed cards with subtle borders, generous whitespace, asymmetric header with brand mark
- **Motion**: Staggered fade-in on page load, smooth hover transitions on table rows and buttons, subtle pulse on active stepper node (already exists)
- **Texture**: Subtle grid or dot pattern on the background, very slight noise overlay for depth
- **Data density**: The dashboard table should feel like a Bloomberg terminal or Datadog — information-dense but organized

### 4.2 Scope

**Files affected**:
- `www/style.css` — complete rewrite of styles (preserving class names where possible for JS compatibility)
- `www/index.html` — update structure for new filter bar, nav changes
- `www/detail.html` — update structure, integrate comments in timeline
- `www/new.html` — update form styling
- `www/confirm.html` — update styling
- `www/queue.html` — NEW page (built in new design from the start)
- `www/analytics.html` — NEW page (built in new design from the start)

**Constraints**:
- No build step — pure HTML/CSS/JS
- Supabase JS client via CDN (existing)
- Chart.js via CDN (new, for analytics only)
- Google Fonts via CDN (new)
- Must remain functional on mobile (responsive)
- All existing JS functionality preserved

---

## Implementation Phases

### Phase 6a: Backend Migrations (SQL only, no UI)
- Migration 15: Idempotency keys + notes column
- Migration 16: Tighten RLS on detail views
- Migration 17: Confirmation reminder logic in timer sweep
- Migration 18: Slack DM dispatch helpers
- Migration 19: SLA tracking views
- Migration 20: Approval queue view/RPC
- Tests for all new functionality

### Phase 6b: Web UI Redesign + New Pages
- Rewrite `style.css` with new design system
- Update all 4 existing pages (index, detail, new, confirm)
- Build `queue.html` and `analytics.html`
- Add search/filter to index.html
- Add age indicators to dashboard rows
- Add comments/notes to detail.html timeline
- Deploy to Vercel

### Phase 6c: Slack Integration Updates
- Update `build_block_kit_message()` to include notes
- Update `handle_slack_webhook()` to accept notes from interactive payloads
- Add DM dispatch to outbox processing
- Update slash command to support `--reason` flag

---

## Open Questions

1. **User identity mapping**: How to map `commercial_owner_user_id` to Slack user ID for DMs? (Free-text field today)
2. **Admin identification**: How to identify admin users for RLS? (JWT claims vs. user_roles table vs. Vault list)
3. **VP identification**: Who receives VP escalation DMs? (New Vault secret vs. column on request)
4. **Chart library**: Chart.js (most popular, ~60KB) vs. Frappe Charts (lighter, ~17KB) vs. uPlot (fastest, ~35KB)?
5. **Filter approach**: Client-side filtering (simpler, works for <1000 requests) vs. server-side Supabase queries (scales better)?

---

## Verification Criteria

1. All existing 59 tests continue to pass
2. New tests for idempotency, RLS, notes, reminders, SLA views pass
3. Duplicate Slack button clicks do not create duplicate events
4. Authenticated users can only see their own requests (unless admin)
5. Approval queue shows correct requests for each user role
6. Dashboard filters work and persist in URL
7. Age indicators correctly color-code rows
8. Analytics charts render with real data from observability views
9. Notes appear in event timeline on web and in Block Kit messages
10. Confirmation reminder fires at ~50% of deadline
11. All pages render correctly on mobile (320px-768px viewport)
12. Lighthouse performance score > 90 for all pages
