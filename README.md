# CapReq

Infrastructure capacity request management with multi-stage approvals, Slack integration, and a web dashboard.

## What It Does

CapReq tracks capacity provisioning requests through a structured approval workflow:

```
SUBMITTED → UNDER REVIEW → CUSTOMER CONFIRMATION → PROVISIONING → COMPLETED
                 │                   │                    │
                 ▼                   ▼                    ▼
             REJECTED          EXPIRED/CANCELLED        FAILED
```

Requests are created via a Slack slash command (`/capacity`) or the web UI. They flow through commercial review, technical review, optional VP escalation (for high-cost requests), customer confirmation (with a configurable deadline), and finally provisioning.

## Key Features

- **Event-sourced state machine** -- immutable event log with a mutable projection table, pure state transition function, optimistic concurrency
- **Slack integration** -- slash command with modal form, Block Kit messages with contextual approve/reject buttons, threaded updates, `/capacity list|view|help` subcommands
- **Transactional outbox** -- reliable at-least-once Slack message delivery via pg_cron, no lost notifications
- **VP escalation** -- requests above a configurable cost threshold (default $50k, stored in Vault) require VP approval before proceeding
- **Customer confirmation** -- time-boxed confirmation step with automatic expiration via pg_cron timer sweep
- **Web dashboard** -- Vercel-hosted UI with workflow stepper visualization, operator guidance, request detail with event timeline
- **Provisioning webhook** -- external systems call an API to mark requests as completed or failed, secured with API key verification
- **Row-level security** -- requesters see their own requests, commercial owners see assigned, infra groups see assigned, service role bypasses all
- **Observability views** -- time-in-state, approval latency, provisioning duration, terminal state counts

## Architecture

Everything runs inside Supabase (PostgreSQL + Edge Functions):

| Layer | Technology |
|-------|-----------|
| Database | PostgreSQL 17 with pgcrypto, pg_net, pg_cron |
| State machine | SQL functions (`compute_next_state`, `apply_capacity_event`) |
| Side effects | Transactional outbox → pg_cron → pg_net → Slack API |
| Slack proxy | Deno edge function (signature verification, modal opening, request routing) |
| Provisioning proxy | Deno edge function (API key forwarding) |
| Web UI | Static HTML/CSS/JS served via Vercel |
| Auth | Supabase Auth with magic link (OTP) |
| Secrets | Supabase Vault (Slack tokens, signing secret, escalation threshold, provisioning API key) |

## Project Structure

```
capacity_request/
├── supabase/
│   ├── config.toml                  # Supabase project config
│   ├── migrations/                  # 29 SQL migrations (schema, functions, cron jobs)
│   │   ├── 20260214000001_extensions_and_enums.sql
│   │   ├── 20260214000002_tables_and_indexes.sql
│   │   ├── 20260214000003_core_functions.sql
│   │   ├── ...
│   │   └── 20260216000014_workflow_visualization.sql
│   ├── functions/
│   │   ├── slack-proxy/             # Slack webhook handler (slash commands, modals, buttons)
│   │   ├── provisioning-proxy/      # External provisioning webhook
│   │   └── www/                     # Static file server (legacy, now on Vercel)
│   └── templates/
│       └── magic_link.html          # Branded magic link email
├── www/                             # Web UI (deployed to Vercel)
│   ├── index.html                   # Dashboard -- request list
│   ├── detail.html                  # Request detail with stepper, timeline, actions
│   ├── new.html                     # Self-service request creation form
│   ├── confirm.html                 # Customer confirmation page
│   ├── style.css                    # Shared styles
│   └── config.js                    # Supabase credentials (generated at build)
├── test/
│   └── test_workflow.sql            # 59 SQL tests covering state machine, transitions, views
├── SETUP.md                         # Slack app setup and deployment guide
├── PRD.md                           # Phase 6 product requirements
└── vercel.json                      # Vercel deployment config
```

## State Machine

9 states, 11 event types, pure transition function:

| Current State | Event | Next State |
|---------------|-------|------------|
| SUBMITTED | REQUEST_SUBMITTED | UNDER_REVIEW |
| UNDER_REVIEW | COMMERCIAL_APPROVED | UNDER_REVIEW (or CUSTOMER_CONFIRMATION_REQUIRED if all approvals done) |
| UNDER_REVIEW | TECH_REVIEW_APPROVED | UNDER_REVIEW (or CUSTOMER_CONFIRMATION_REQUIRED if all approvals done) |
| UNDER_REVIEW | COMMERCIAL_REJECTED | REJECTED |
| UNDER_REVIEW | TECH_REVIEW_REJECTED | REJECTED |
| CUSTOMER_CONFIRMATION_REQUIRED | CUSTOMER_CONFIRMED | PROVISIONING |
| CUSTOMER_CONFIRMATION_REQUIRED | CUSTOMER_DECLINED | CANCELLED |
| CUSTOMER_CONFIRMATION_REQUIRED | CUSTOMER_CONFIRMATION_TIMEOUT | EXPIRED |
| PROVISIONING | PROVISIONING_COMPLETE | COMPLETED |
| PROVISIONING | PROVISIONING_FAILED | FAILED |
| Any non-terminal | CANCEL_APPROVED | CANCELLED |

VP escalation adds VP_APPROVED and VP_REJECTED events when `estimated_monthly_cost_usd` exceeds the threshold. All three approvals (commercial, technical, VP) must pass before moving to customer confirmation.

## Quick Start

### Prerequisites

- [Supabase CLI](https://supabase.com/docs/guides/cli)
- A Slack workspace (for Slack integration)
- Node.js (for Vercel CLI, optional)

### Local Development

```bash
# Start local Supabase
supabase start

# Apply migrations and seed data
supabase db reset

# Run tests
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
  -v ON_ERROR_STOP=1 \
  -f test/test_workflow.sql

# Store secrets in Vault (local)
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -c \
  "SELECT vault.create_secret('xoxb-your-token', 'SLACK_BOT_TOKEN');"
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -c \
  "SELECT vault.create_secret('your-signing-secret', 'SLACK_SIGNING_SECRET');"

# Deploy edge function
supabase functions deploy slack-proxy --no-verify-jwt

# Serve web UI locally
cd www && python3 -m http.server 3000
```

### Production Deployment

```bash
# Push migrations to hosted Supabase
supabase db push

# Push config (email templates, auth settings)
supabase config push

# Deploy edge functions
supabase functions deploy slack-proxy --no-verify-jwt
supabase functions deploy provisioning-proxy --no-verify-jwt

# Deploy web UI to Vercel
vercel --prod
```

See [SETUP.md](SETUP.md) for the full Slack app configuration walkthrough.

## Testing

The test suite covers the state machine, transitions, event types, approval flags, VP escalation, observability views, workflow visualization, and operator guidance:

```bash
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
  -v ON_ERROR_STOP=1 \
  -f test/test_workflow.sql
```

59 tests, all run inside a transaction that rolls back (no persistent side effects).

## Web UI

Hosted at [capreq.vercel.app](https://capreq.vercel.app). Pages:

- **Dashboard** (`index.html`) -- lists all requests with state badges, links to detail
- **Detail** (`detail.html`) -- workflow stepper showing current position, approval status, operator guidance, event timeline, action buttons
- **New Request** (`new.html`) -- form to create a request (size, region, quantity, duration, needed-by date, cost, customer)
- **Confirm** (`confirm.html`) -- customer-facing page to confirm or decline a request

Authentication via Supabase magic link (email OTP).

## Slack Commands

| Command | Description |
|---------|-------------|
| `/capacity` | Opens the modal creation form |
| `/capacity create` | Same as above |
| `/capacity list` | Lists recent requests |
| `/capacity view CR-2026-000001` | Shows request detail with action buttons |
| `/capacity help` | Shows available commands |

## License

Private.
