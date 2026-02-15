# RFC: Control-Plane Capacity Request Workflow (Large Instance Provisioning)

---

## Problem

### What is the EXACT problem you are solving

Supabase supports self-serve instance scaling up to 16XL. Requests beyond that threshold require manual coordination between Sales, Solutions, and Infrastructure. Today these workflows are conversation-driven (primarily Slack) and lack durable lifecycle ownership.

This results in:

* Ambiguity over who owns decisions (e.g., whether to cancel expensive pre-provisioned capacity).
* No authoritative workflow state.
* Operational and financial risk when customers become unresponsive.
* Repeated internal confusion around “what is the process?”

There is currently no control-plane representation of a large-capacity request.

### Who are the customers asking for it?

External signals:

* Enterprise and rapidly growing customers requesting >16XL capacity.

Internal signals:

* SAs, AEs, and Infra repeatedly encountering unclear workflows.
* Infra requesting clarification after procurement has already begun.

Examples to include:

* Links to customer calls requesting large instances.
* Slack threads where Infra asks if capacity is still needed.
* Related Linear tickets or escalation threads.

### Aka why are we doing it?

Unmanaged lifecycle ownership introduces real AWS spend risk, customer risk, and internal inefficiency. This RFC proposes a minimal workflow anchored in the Supabase control plane to provide durable state, explicit approval gates, and time-based lifecycle enforcement.

---

## Prior Solutions / competitor analysis

### 1. Conversation-driven workflows (current state)

What works:

* Low friction.
* Fast iteration early on.

What does not:

* No lifecycle enforcement.
* Decisions happen implicitly in Slack.
* Lack of auditability or timers.

### 2. Heavyweight external workflow platforms (Temporal, ServiceNow, Salesforce Flow)

What works:

* Strong orchestration semantics.
* Clear lifecycle ownership.

What does not:

* High operational overhead.
* Introduces new platform complexity prematurely.
* Misaligned with Supabase’s engineering-first control-plane architecture.

Observation: Extending the Supabase control plane is likely more aligned than introducing external workflow tooling at this stage.

---

## Unresolved questions

* Who owns commercial approval for high-cost requests? AE vs Sales leadership vs Finance?
* What is the default TTL for customer confirmation (e.g., 5 business days)?
* Should provisioning begin before customer confirmation or only after?
* Should activation detection be automated via control-plane signals?

Decisions will be documented inline once resolved.

---

## Approaches

### First draft?

Option A — Control-plane anchored workflow with durable state in Supabase Postgres.

Option B — Linear-centric workflow using automation, templates, and Slack conventions.

---

## Option A — Control-Plane Anchored Workflow

This option introduces a durable workflow model inside a Supabase project.

Design overview:

* A `capacity_requests` table becomes the source of truth.
* `capacity_request_events` is append-only and drives transitions.
* Edge Functions act as reducers.
* pg_cron manages lifecycle timers.
* Slack is the interaction surface.
* Linear is informational only.

Lifecycle states:

SUBMITTED → COMMERCIAL_APPROVAL_REQUIRED → TECHNICAL_REVIEW_REQUIRED → CUSTOMER_CONFIRMATION_REQUIRED → PROVISIONING_IN_PROGRESS → READY_FOR_CUSTOMER → ACTIVATED
Terminal states: CANCELLED, EXPIRED, FAILED.

### Interaction with other features

* Slack slash command creates requests.
* Linear issue generated for Infra tracking but does not control lifecycle state.
* pg_cron emits timeout events such as CUSTOMER_CONFIRMATION_TIMEOUT.
* Edge Functions enforce role-based transitions.

### Implementation clarity

* Durable state stored in Postgres.
* State transitions occur only through events.
* Slack buttons trigger Edge Function calls.

### Corner cases by example

Customer goes dark:
TTL expires → EXPIRED → cancellation gate assigned to commercial owner.

Infra begins procurement but AE withdraws:
CANCEL_APPROVED required; decision owner explicit.

Multiple Slack threads referencing same request:
CR ID anchors lifecycle and prevents ambiguity.

### How this addresses real examples

* Infra no longer asks SAs if capacity should exist; the workflow assigns the decision owner automatically.
* Customer silence triggers expiration rather than ad-hoc Slack follow-ups.

### Pros

* Durable lifecycle ownership.
* Aligns with control-plane architecture.
* Minimal new infrastructure.
* Supports timers and auditability.

### Cons

* Requires engineering implementation.
* Initially scoped to infra-heavy workflows.
* Custom system must be maintained.

---

## Option B — Linear-Centric Workflow

Design overview:

* Linear issues represent lifecycle stages.
* Slack bots enforce status changes.
* Notion documents policy and process.

### Interaction with other features

* Linear templates define approval flow.
* Slack notifications prompt users to move issues between states.

### Implementation clarity

* Minimal engineering required.
* Relies on human discipline rather than system enforcement.

### Corner cases by example

Timeouts require manual follow-up.
Ownership may remain implicit.

### How this addresses real examples

Provides more structure than Slack-only workflows but does not eliminate ambiguity around cancellation ownership.

### Pros

* Faster initial rollout.
* Lower engineering investment.

### Cons

* No durable orchestration semantics.
* Hard to enforce timers or ownership.
* Risk of reverting to conversation-driven workflows.

---

⚠️ Don’t fill this next section out until the team decides on an approach above.

---

## Decision

TBD

---

## Reference-level implementation

TBD

---

## Launch checklist

TBD
