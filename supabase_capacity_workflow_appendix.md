# Engineering Appendix: Control-Plane Capacity Request Workflow (Supabase-native)

This appendix describes a concrete, Supabase-native implementation of the large instance provisioning workflow. It is intended as an engineering reference and is **not part of the RFC decision surface**.

---

## 1. Scope and invariants

- Authoritative workflow state lives in **Postgres**.
- Slack and Linear are **projection / interaction surfaces**, not sources of truth.
- Only server-side code (Edge Functions / SQL functions) may mutate workflow state.
- All state transitions are derived from an **append-only event log**.
- The “current state” is a materialized projection.
- Every Capacity Request (CR) has a stable ID (e.g. `CR-2026-000123`) used across Slack, Linear, and internal links.

---

## 2. Data model (Postgres)

### 2.1 Enum types

**States**
- SUBMITTED
- COMMERCIAL_APPROVAL_REQUIRED
- TECHNICAL_REVIEW_REQUIRED
- CUSTOMER_CONFIRMATION_REQUIRED
- PROVISIONING_IN_PROGRESS
- READY_FOR_CUSTOMER
- ACTIVATED
- CANCELLED
- EXPIRED
- FAILED

**Events (minimum)**
- REQUEST_SUBMITTED
- COMMERCIAL_APPROVED
- COMMERCIAL_REJECTED
- TECH_REVIEW_APPROVED
- TECH_REVIEW_REJECTED
- CUSTOMER_CONFIRMED
- CUSTOMER_DECLINED
- CUSTOMER_CONFIRMATION_TIMEOUT
- AWS_PROCUREMENT_STARTED
- AWS_CAPACITY_READY
- AWS_PROCUREMENT_FAILED
- CANCEL_APPROVED
- ACTIVATION_CONFIRMED

---

### 2.2 Tables

#### capacity_requests
_Current workflow projection_

- id (text, PK)
- state (enum)
- created_at
- updated_at
- requester_user_id
- commercial_owner_user_id
- infra_owner_group
- customer_ref (jsonb)
- requested_size
- quantity
- region
- needed_by_date
- expected_duration_days
- estimated_monthly_cost_usd
- slack_channel_id
- slack_thread_ts
- linear_issue_id
- customer_confirmation_deadline_at
- last_notified_at
- cancellation_reason
- cancellation_authorizer_user_id

#### capacity_request_events
_Append-only event log_

- id (uuid, PK)
- capacity_request_id
- event_type
- actor_type
- actor_id
- payload (jsonb)
- created_at

#### capacity_request_tasks (optional)

- id
- capacity_request_id
- task_type
- assigned_to
- due_at
- status
- created_at
- updated_at

---

## 3. State machine rules

Reducer contract: apply_event(request_id, event)

Examples:

REQUEST_SUBMITTED → COMMERCIAL_APPROVAL_REQUIRED  
COMMERCIAL_APPROVED → TECHNICAL_REVIEW_REQUIRED  
TECH_REVIEW_APPROVED → CUSTOMER_CONFIRMATION_REQUIRED  
CUSTOMER_CONFIRMED → PROVISIONING_IN_PROGRESS  
AWS_CAPACITY_READY → READY_FOR_CUSTOMER  
ACTIVATION_CONFIRMED → ACTIVATED  

Timeout path:

CUSTOMER_CONFIRMATION_REQUIRED → (TTL expires) → EXPIRED → cancellation decision required.

---

## 4. Timers using pg_cron

Function: run_capacity_request_timers()

Responsibilities:
- Detect expired confirmation deadlines
- Emit CUSTOMER_CONFIRMATION_TIMEOUT events
- Create cancellation decision tasks

Schedule: every 15 minutes.

---

## 5. Edge Functions

### create_capacity_request
Creates CR record, emits REQUEST_SUBMITTED event, posts Slack message, creates Linear issue.

### record_capacity_event
Validates actor permissions, records event, applies reducer, posts notifications.

### get_capacity_request
Returns current state + recent events.

---

## 6. Integrations

Slack: slash command + approval buttons  
Linear: issue creation and comments  
Supabase: Postgres tables + Edge Functions + pg_cron  
Vercel: optional future web UI

---

## 7. Observability

Metrics derivable from Postgres:
- Time in state
- Approval latency
- Expired request count
- Cancelled-after-procurement count

---

## 8. Rollout plan

Phase 1:
- Tables + reducer
- Slack create/approve flow
- Linear issue creation
- pg_cron timers

Phase 2:
- Threshold-based approvals
- Warning notifications
- Optional web UI
- Optional AWS signal integration

---

## 9. Security notes

- Store minimal customer identifiers.
- Log all decisions with actor attribution.
- Use RLS policies and service-role reducers.
