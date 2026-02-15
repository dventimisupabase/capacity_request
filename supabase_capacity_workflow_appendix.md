# Engineering Appendix: Control-Plane Capacity Request Workflow (Supabase-native)

This appendix describes a **reference architecture** for the large instance provisioning workflow using Supabase-native primitives. It is a starting point — the implementation may diverge where a better architecture emerges.

---

## 1. Scope and invariants

- Authoritative workflow state lives in **Postgres**.
- Slack and Linear are **projection / interaction surfaces**, not sources of truth.
- All state transitions are derived from an **append-only event log**.
- The "current state" is a materialized projection stored in `capacity_requests`.
- The `capacity_requests` projection table is **only writable by the reducer function** (`apply_capacity_event`), enforced by Postgres grants and RLS.
- Side effects (Slack notifications, Linear issue updates) are dispatched via **pg_net** (async HTTP from Postgres). pg_net enqueues requests inside the transaction but the background worker delivers them only after commit — so side effects never fire for rolled-back transitions, yet never block or roll back the state mutation.
- The entire stack runs on Supabase-managed Postgres extensions: **pg_net** (outbound HTTP), **Vault** (secret storage), **pgcrypto** (HMAC signature verification), **pg_cron** (timers), and **PostgREST** (HTTP→RPC gateway). No Edge Functions.
- Every Capacity Request (CR) has a stable ID (e.g. `CR-2026-000123`) used across Slack, Linear, and internal links.

---

## 2. State machine

### 2.1 States

**Active states:**

| State | Description |
|---|---|
| `SUBMITTED` | Initial state. Request recorded, pending review. |
| `UNDER_REVIEW` | Commercial and technical reviews in progress (parallel). |
| `CUSTOMER_CONFIRMATION_REQUIRED` | Both reviews approved; awaiting customer response. |
| `PROVISIONING` | Customer confirmed; provisioning underway. |
| `COMPLETED` | Provisioning finished and verified. |

**Terminal states:**

| State | Description |
|---|---|
| `REJECTED` | Either commercial or technical review denied the request. |
| `CANCELLED` | Cancelled by an authorized actor from any non-terminal state. |
| `EXPIRED` | Customer confirmation deadline elapsed without response. |
| `FAILED` | Provisioning encountered an unrecoverable error. |

### 2.2 Events

| Event | Description |
|---|---|
| `REQUEST_SUBMITTED` | A new capacity request is created. |
| `COMMERCIAL_APPROVED` | Commercial review approves the request. |
| `COMMERCIAL_REJECTED` | Commercial review denies the request. |
| `TECH_REVIEW_APPROVED` | Technical review approves the request. |
| `TECH_REVIEW_REJECTED` | Technical review denies the request. |
| `CUSTOMER_CONFIRMED` | Customer accepts the provisioning offer. |
| `CUSTOMER_DECLINED` | Customer explicitly declines. |
| `CUSTOMER_CONFIRMATION_TIMEOUT` | Confirmation deadline elapsed (emitted by pg_cron). |
| `PROVISIONING_COMPLETE` | Provisioning finished successfully. |
| `PROVISIONING_FAILED` | Provisioning encountered an unrecoverable error. |
| `CANCEL_APPROVED` | Authorized cancellation from any non-terminal state. |

### 2.3 Transition table

```
Current State                     Event                            Next State
─────────────────────────────────────────────────────────────────────────────────
SUBMITTED                         REQUEST_SUBMITTED                UNDER_REVIEW

UNDER_REVIEW                      COMMERCIAL_APPROVED              UNDER_REVIEW¹
UNDER_REVIEW                      TECH_REVIEW_APPROVED             UNDER_REVIEW¹
UNDER_REVIEW                      COMMERCIAL_REJECTED              REJECTED
UNDER_REVIEW                      TECH_REVIEW_REJECTED             REJECTED

CUSTOMER_CONFIRMATION_REQUIRED    CUSTOMER_CONFIRMED               PROVISIONING
CUSTOMER_CONFIRMATION_REQUIRED    CUSTOMER_DECLINED                CANCELLED
CUSTOMER_CONFIRMATION_REQUIRED    CUSTOMER_CONFIRMATION_TIMEOUT    EXPIRED

PROVISIONING                      PROVISIONING_COMPLETE            COMPLETED
PROVISIONING                      PROVISIONING_FAILED              FAILED

Any non-terminal state            CANCEL_APPROVED                  CANCELLED
─────────────────────────────────────────────────────────────────────────────────
¹ When both commercial_approved_at AND technical_approved_at are set,
  the reducer transitions to CUSTOMER_CONFIRMATION_REQUIRED instead.
```

---

## 3. Data model (Postgres)

### 3.1 Enum types

```sql
CREATE TYPE capacity_request_state AS ENUM (
  'SUBMITTED',
  'UNDER_REVIEW',
  'CUSTOMER_CONFIRMATION_REQUIRED',
  'PROVISIONING',
  'COMPLETED',
  'REJECTED',
  'CANCELLED',
  'EXPIRED',
  'FAILED'
);

CREATE TYPE capacity_request_event_type AS ENUM (
  'REQUEST_SUBMITTED',
  'COMMERCIAL_APPROVED',
  'COMMERCIAL_REJECTED',
  'TECH_REVIEW_APPROVED',
  'TECH_REVIEW_REJECTED',
  'CUSTOMER_CONFIRMED',
  'CUSTOMER_DECLINED',
  'CUSTOMER_CONFIRMATION_TIMEOUT',
  'PROVISIONING_COMPLETE',
  'PROVISIONING_FAILED',
  'CANCEL_APPROVED'
);

CREATE TYPE capacity_request_actor_type AS ENUM (
  'user',
  'system',
  'cron'
);
```

### 3.2 ID generation

Capacity request IDs are human-readable text keys generated from a Postgres sequence:

```sql
CREATE SEQUENCE capacity_request_seq;

-- Helper used by create_capacity_request()
CREATE FUNCTION next_capacity_request_id() RETURNS text AS $$
  SELECT format('CR-%s-%06s', extract(year FROM now())::int, nextval('capacity_request_seq'));
$$ LANGUAGE sql;
```

Example: `CR-2026-000001`. The text primary key is used directly in Slack messages and Linear issues. UUIDs are used only for event table rows.

### 3.3 Tables

#### capacity_requests

_Current workflow projection — writable only by the reducer._

| Column | Type | Notes |
|---|---|---|
| `id` | text, PK | `CR-{YYYY}-{seq:06d}` |
| `version` | integer, NOT NULL, DEFAULT 1 | Optimistic concurrency guard |
| `state` | capacity_request_state, NOT NULL | Current state |
| `created_at` | timestamptz, NOT NULL, DEFAULT now() | |
| `updated_at` | timestamptz, NOT NULL, DEFAULT now() | |
| `requester_user_id` | text, NOT NULL | Who submitted the request |
| `commercial_owner_user_id` | text | Assigned commercial reviewer |
| `infra_owner_group` | text | Assigned technical review group |
| `customer_ref` | jsonb | Customer identifiers (org id, name) |
| `requested_size` | text | e.g. "32XL" |
| `quantity` | integer | |
| `region` | text | Target AWS region |
| `needed_by_date` | date | |
| `expected_duration_days` | integer | |
| `estimated_monthly_cost_usd` | numeric | |
| `commercial_approved_at` | timestamptz | Set when COMMERCIAL_APPROVED received |
| `technical_approved_at` | timestamptz | Set when TECH_REVIEW_APPROVED received |
| `next_deadline_at` | timestamptz | Deadline for current state (indexed) |
| `confirmation_ttl_days` | integer, NOT NULL, DEFAULT 7 | Overridable per request |
| `slack_channel_id` | text | |
| `slack_thread_ts` | text | |
| `linear_issue_id` | text | |
| `last_notified_at` | timestamptz | |
| `cancellation_reason` | text | |
| `cancellation_authorizer_user_id` | text | |

#### capacity_request_events

_Append-only event log._

| Column | Type | Notes |
|---|---|---|
| `id` | uuid, PK, DEFAULT gen_random_uuid() | |
| `capacity_request_id` | text, NOT NULL, FK | |
| `event_type` | capacity_request_event_type, NOT NULL | |
| `actor_type` | capacity_request_actor_type, NOT NULL | |
| `actor_id` | text, NOT NULL | |
| `payload` | jsonb | Event-specific data |
| `created_at` | timestamptz, NOT NULL, DEFAULT now() | |

### 3.4 Indexes

```sql
-- Timer sweep: find requests with approaching or elapsed deadlines
CREATE INDEX idx_capacity_requests_deadline
  ON capacity_requests (next_deadline_at)
  WHERE next_deadline_at IS NOT NULL
    AND state NOT IN ('COMPLETED', 'REJECTED', 'CANCELLED', 'EXPIRED', 'FAILED');

-- Event log lookups by request
CREATE INDEX idx_capacity_request_events_request_id
  ON capacity_request_events (capacity_request_id, created_at);
```

---

## 4. Reducer (PL/pgSQL)

The reducer is the single path for all state mutations. It runs inside a Postgres transaction, guaranteeing atomicity.

### 4.1 compute_next_state

A **pure function** encoding the transition table. Takes the current state, the event type, and the approval flags; returns the next state or raises an exception for invalid transitions. Testable independently with no side effects.

```sql
CREATE FUNCTION compute_next_state(
  current_state     capacity_request_state,
  event             capacity_request_event_type,
  commercial_done   boolean,
  technical_done    boolean
) RETURNS capacity_request_state AS $$
BEGIN
  -- CANCEL_APPROVED from any non-terminal state
  IF event = 'CANCEL_APPROVED' THEN
    IF current_state IN ('COMPLETED', 'REJECTED', 'CANCELLED', 'EXPIRED', 'FAILED') THEN
      RAISE EXCEPTION 'Cannot cancel a request in terminal state %', current_state;
    END IF;
    RETURN 'CANCELLED';
  END IF;

  CASE current_state
    WHEN 'SUBMITTED' THEN
      IF event = 'REQUEST_SUBMITTED' THEN RETURN 'UNDER_REVIEW'; END IF;

    WHEN 'UNDER_REVIEW' THEN
      IF event IN ('COMMERCIAL_APPROVED', 'TECH_REVIEW_APPROVED') THEN
        -- After applying this approval, are both done?
        IF commercial_done AND technical_done THEN
          RETURN 'CUSTOMER_CONFIRMATION_REQUIRED';
        END IF;
        RETURN 'UNDER_REVIEW';
      END IF;
      IF event IN ('COMMERCIAL_REJECTED', 'TECH_REVIEW_REJECTED') THEN
        RETURN 'REJECTED';
      END IF;

    WHEN 'CUSTOMER_CONFIRMATION_REQUIRED' THEN
      IF event = 'CUSTOMER_CONFIRMED' THEN RETURN 'PROVISIONING'; END IF;
      IF event = 'CUSTOMER_DECLINED' THEN RETURN 'CANCELLED'; END IF;
      IF event = 'CUSTOMER_CONFIRMATION_TIMEOUT' THEN RETURN 'EXPIRED'; END IF;

    WHEN 'PROVISIONING' THEN
      IF event = 'PROVISIONING_COMPLETE' THEN RETURN 'COMPLETED'; END IF;
      IF event = 'PROVISIONING_FAILED' THEN RETURN 'FAILED'; END IF;

    ELSE
      -- Terminal states accept no events (except CANCEL_APPROVED, handled above)
      NULL;
  END CASE;

  RAISE EXCEPTION 'Invalid transition: state=% event=%', current_state, event;
END;
$$ LANGUAGE plpgsql IMMUTABLE;
```

### 4.2 apply_capacity_event

The main reducer. Locks the row, computes the transition, inserts the event, and updates the projection atomically.

```sql
CREATE FUNCTION apply_capacity_event(
  p_request_id  text,
  p_event_type  capacity_request_event_type,
  p_actor_type  capacity_request_actor_type,
  p_actor_id    text,
  p_payload     jsonb DEFAULT '{}'
) RETURNS capacity_requests AS $$
DECLARE
  req           capacity_requests;
  new_state     capacity_request_state;
  commercial_done boolean;
  technical_done  boolean;
BEGIN
  -- Lock the row for the duration of this transaction
  SELECT * INTO STRICT req
    FROM capacity_requests
    WHERE id = p_request_id
    FOR UPDATE;

  -- Compute approval flags AFTER this event is applied
  commercial_done := req.commercial_approved_at IS NOT NULL
                     OR p_event_type = 'COMMERCIAL_APPROVED';
  technical_done  := req.technical_approved_at IS NOT NULL
                     OR p_event_type = 'TECH_REVIEW_APPROVED';

  -- Pure transition logic
  new_state := compute_next_state(req.state, p_event_type, commercial_done, technical_done);

  -- Append event
  INSERT INTO capacity_request_events (capacity_request_id, event_type, actor_type, actor_id, payload)
    VALUES (p_request_id, p_event_type, p_actor_type, p_actor_id, p_payload);

  -- Update projection with optimistic concurrency check
  UPDATE capacity_requests SET
    state                = new_state,
    version              = version + 1,
    updated_at           = now(),
    commercial_approved_at = CASE
      WHEN p_event_type = 'COMMERCIAL_APPROVED' THEN now()
      ELSE commercial_approved_at
    END,
    technical_approved_at = CASE
      WHEN p_event_type = 'TECH_REVIEW_APPROVED' THEN now()
      ELSE technical_approved_at
    END,
    next_deadline_at     = CASE
      WHEN new_state = 'CUSTOMER_CONFIRMATION_REQUIRED'
        THEN now() + (confirmation_ttl_days || ' days')::interval
      ELSE NULL
    END,
    cancellation_reason  = CASE
      WHEN p_event_type = 'CANCEL_APPROVED' THEN p_payload->>'reason'
      ELSE cancellation_reason
    END,
    cancellation_authorizer_user_id = CASE
      WHEN p_event_type = 'CANCEL_APPROVED' THEN p_actor_id
      ELSE cancellation_authorizer_user_id
    END
  WHERE id = p_request_id AND version = req.version
  RETURNING * INTO STRICT req;

  RETURN req;
END;
$$ LANGUAGE plpgsql;
```

### 4.3 create_capacity_request

Handles initial creation and the first event (`REQUEST_SUBMITTED`) in one transaction.

```sql
CREATE FUNCTION create_capacity_request(
  p_requester_user_id         text,
  p_commercial_owner_user_id  text,
  p_infra_owner_group         text,
  p_customer_ref              jsonb,
  p_requested_size            text,
  p_quantity                  integer,
  p_region                    text,
  p_needed_by_date            date,
  p_expected_duration_days    integer,
  p_estimated_monthly_cost_usd numeric DEFAULT NULL,
  p_confirmation_ttl_days     integer DEFAULT 7
) RETURNS capacity_requests AS $$
DECLARE
  new_id  text;
  req     capacity_requests;
BEGIN
  new_id := next_capacity_request_id();

  INSERT INTO capacity_requests (
    id, state, requester_user_id, commercial_owner_user_id,
    infra_owner_group, customer_ref, requested_size, quantity,
    region, needed_by_date, expected_duration_days,
    estimated_monthly_cost_usd, confirmation_ttl_days
  ) VALUES (
    new_id, 'SUBMITTED', p_requester_user_id, p_commercial_owner_user_id,
    p_infra_owner_group, p_customer_ref, p_requested_size, p_quantity,
    p_region, p_needed_by_date, p_expected_duration_days,
    p_estimated_monthly_cost_usd, p_confirmation_ttl_days
  );

  -- Apply the initial event to transition SUBMITTED → UNDER_REVIEW
  req := apply_capacity_event(new_id, 'REQUEST_SUBMITTED', 'user', p_requester_user_id, '{}');

  RETURN req;
END;
$$ LANGUAGE plpgsql;
```

### 4.4 Secrets helper

Retrieves decrypted secrets from Supabase Vault for use in pg_net calls.

```sql
CREATE FUNCTION get_secret(secret_name text) RETURNS text AS $$
  SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = secret_name LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;
```

Secrets are stored via the Supabase Dashboard (avoids logging plaintext in SQL statement logs):

| Secret name | Contents |
|---|---|
| `SLACK_BOT_TOKEN` | Slack bot OAuth token (`xoxb-...`) |
| `SLACK_SIGNING_SECRET` | Slack app signing secret (for request verification) |
| `LINEAR_API_KEY` | Linear API key |

### 4.5 Side-effect dispatch (pg_net)

Side effects are dispatched via `net.http_post()` — an async, non-blocking HTTP call. pg_net enqueues the request inside the current transaction; the background worker delivers it after commit. If the transaction rolls back, enqueued requests are discarded.

```sql
CREATE FUNCTION dispatch_side_effects(
  req         capacity_requests,
  old_state   capacity_request_state,
  new_state   capacity_request_state,
  event_type  capacity_request_event_type
) RETURNS void AS $$
DECLARE
  slack_token text := get_secret('SLACK_BOT_TOKEN');
BEGIN
  -- State-specific notifications
  CASE new_state
    WHEN 'UNDER_REVIEW' THEN
      IF old_state = 'SUBMITTED' THEN
        -- New request: post initial Slack message with approval buttons
        PERFORM net.http_post(
          url     := 'https://slack.com/api/chat.postMessage',
          headers := jsonb_build_object(
            'Content-Type',  'application/json',
            'Authorization', 'Bearer ' || slack_token
          ),
          body    := jsonb_build_object(
            'channel', req.slack_channel_id,
            'text',    format('New capacity request %s: %s × %s in %s. Awaiting commercial and technical review.',
                              req.id, req.quantity, req.requested_size, req.region),
            'metadata', jsonb_build_object('event_type', 'capacity_request', 'event_payload', jsonb_build_object('cr_id', req.id))
          )
        );
      ELSE
        -- Approval recorded; update thread
        PERFORM net.http_post(
          url     := 'https://slack.com/api/chat.postMessage',
          headers := jsonb_build_object(
            'Content-Type',  'application/json',
            'Authorization', 'Bearer ' || slack_token
          ),
          body    := jsonb_build_object(
            'channel', req.slack_channel_id,
            'thread_ts', req.slack_thread_ts,
            'text',    format('%s recorded for %s. Commercial: %s | Technical: %s',
                              event_type, req.id,
                              CASE WHEN req.commercial_approved_at IS NOT NULL THEN 'approved' ELSE 'pending' END,
                              CASE WHEN req.technical_approved_at IS NOT NULL THEN 'approved' ELSE 'pending' END)
          )
        );
      END IF;

    WHEN 'CUSTOMER_CONFIRMATION_REQUIRED' THEN
      -- Notify customer with confirm/decline prompt
      PERFORM net.http_post(
        url     := 'https://slack.com/api/chat.postMessage',
        headers := jsonb_build_object(
          'Content-Type',  'application/json',
          'Authorization', 'Bearer ' || slack_token
        ),
        body    := jsonb_build_object(
          'channel', req.slack_channel_id,
          'thread_ts', req.slack_thread_ts,
          'text',    format('%s approved. Customer confirmation required by %s.',
                            req.id, req.next_deadline_at::date)
        )
      );

    WHEN 'REJECTED' THEN
      PERFORM net.http_post(
        url     := 'https://slack.com/api/chat.postMessage',
        headers := jsonb_build_object(
          'Content-Type',  'application/json',
          'Authorization', 'Bearer ' || slack_token
        ),
        body    := jsonb_build_object(
          'channel', req.slack_channel_id,
          'thread_ts', req.slack_thread_ts,
          'text',    format('%s has been rejected (%s).', req.id, event_type)
        )
      );

    WHEN 'PROVISIONING' THEN
      PERFORM net.http_post(
        url     := 'https://slack.com/api/chat.postMessage',
        headers := jsonb_build_object(
          'Content-Type',  'application/json',
          'Authorization', 'Bearer ' || slack_token
        ),
        body    := jsonb_build_object(
          'channel', req.slack_channel_id,
          'thread_ts', req.slack_thread_ts,
          'text',    format('%s confirmed by customer. Provisioning started.', req.id)
        )
      );

    WHEN 'COMPLETED', 'CANCELLED', 'EXPIRED', 'FAILED' THEN
      PERFORM net.http_post(
        url     := 'https://slack.com/api/chat.postMessage',
        headers := jsonb_build_object(
          'Content-Type',  'application/json',
          'Authorization', 'Bearer ' || slack_token
        ),
        body    := jsonb_build_object(
          'channel', req.slack_channel_id,
          'thread_ts', req.slack_thread_ts,
          'text',    format('%s → %s.', req.id, new_state)
        )
      );

    ELSE NULL;
  END CASE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

The reducer calls `dispatch_side_effects` as the last step of `apply_capacity_event`, after the projection update:

```sql
-- At the end of apply_capacity_event, before RETURN:
PERFORM dispatch_side_effects(req, old_state, new_state, p_event_type);
```

(Where `old_state` is captured from `req.state` before calling `compute_next_state`.)

---

## 5. HTTP interface (PostgREST RPC)

All PL/pgSQL functions are exposed as HTTP endpoints automatically via PostgREST. No Edge Functions are needed.

### 5.1 Endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/rest/v1/rpc/create_capacity_request` | POST | Create a new CR and transition to UNDER_REVIEW |
| `/rest/v1/rpc/apply_capacity_event` | POST | Record an event and advance the state machine |
| `/rest/v1/rpc/get_capacity_request` | POST | Retrieve current state + event history |

All requests require a Supabase `apikey` header and a `Authorization: Bearer <jwt>` header. The service-role key is used for system callers (Slack proxy, pg_cron).

### 5.2 Example: recording an event

```bash
curl -X POST 'https://<project>.supabase.co/rest/v1/rpc/apply_capacity_event' \
  -H 'Content-Type: application/json' \
  -H 'apikey: <anon-key>' \
  -H 'Authorization: Bearer <service-role-key>' \
  -d '{
    "p_request_id": "CR-2026-000042",
    "p_event_type": "COMMERCIAL_APPROVED",
    "p_actor_type": "user",
    "p_actor_id": "U12345",
    "p_payload": {}
  }'
```

### 5.3 Slack proxy (the one external component)

Slack posts slash commands and interactive payloads as `application/x-www-form-urlencoded`. PostgREST does accept that content type for [table/view INSERTs](https://docs.postgrest.org/en/v14/references/api/tables_views.html#x-www-form-urlencoded), but not for RPC functions. We could use a view with an `INSTEAD OF INSERT` trigger to avoid a proxy entirely, but PostgREST would parse the form fields into columns before our code runs — losing the raw body needed for Slack HMAC signature verification (URL encoding is not deterministic, so the original bytes cannot be reconstructed).

Instead, we use PostgREST's support for [functions with a single unnamed `text` parameter](https://docs.postgrest.org/en/v14/references/api/functions.html#functions-with-a-single-unnamed-parameter), which passes the raw request body as `$1` when `Content-Type: text/plain` is set. A **minimal Cloudflare Worker** (~15 lines) bridges the gap:

1. Receives the form-encoded POST from Slack.
2. Rewrites the `Content-Type` header to `text/plain`.
3. Forwards the raw body **unchanged** to the PostgREST RPC endpoint.
4. Returns Slack's required immediate `200 OK` response.

The proxy does no parsing, no JSON conversion, and **zero business logic**. All state management, signature verification, authorization, side effects, and lifecycle enforcement remain in Postgres. The raw body arriving intact in the PL/pgSQL function is also exactly what Slack signature verification requires.

#### Slack webhook receiver (PL/pgSQL)

PostgREST routes `POST /rest/v1/rpc/handle_slack_webhook` with `Content-Type: text/plain` to a function with a single unnamed `text` parameter. The raw form-encoded body arrives as `$1`:

```sql
CREATE FUNCTION handle_slack_webhook(text) RETURNS json AS $$
DECLARE
  raw_body    text := $1;
  sig         text;
  ts          text;
  params      jsonb;
  payload     jsonb;
  action      text;
  user_id     text;
  request_id  text;
  req         capacity_requests;
BEGIN
  -- Verify Slack request signature (see Section 8)
  sig := current_setting('request.headers', true)::json->>'x-slack-signature';
  ts  := current_setting('request.headers', true)::json->>'x-slack-request-timestamp';

  IF NOT verify_slack_signature(raw_body, ts, sig) THEN
    RAISE EXCEPTION 'Invalid Slack signature';
  END IF;

  -- Parse form-encoded body into key-value pairs
  -- e.g., "command=%2Fcapacity&text=create+32XL&user_id=U123&channel_id=C456"
  SELECT jsonb_object_agg(
    split_part(kv, '=', 1),
    regexp_replace(url_decode(split_part(kv, '=', 2)), '\+', ' ', 'g')
  ) INTO params
  FROM unnest(string_to_array(raw_body, '&')) AS kv;

  -- Route based on payload type
  IF params ? 'command' THEN
    -- Slash command: /capacity create 32XL us-east-1 ...
    -- Parse params->>'text' and call create_capacity_request()
    -- (parsing logic depends on command format)
    RETURN json_build_object('response_type', 'in_channel', 'text', 'Request created: ' || req.id);

  ELSIF params ? 'payload' THEN
    -- Interactive payload (button click): the 'payload' field is URL-encoded JSON
    payload    := (params->>'payload')::jsonb;
    action     := payload->'actions'->0->>'action_id';
    user_id    := payload->'user'->>'id';
    request_id := payload->'actions'->0->>'value';

    -- Map action_id to event_type and call apply_capacity_event()
    -- e.g., action_id 'commercial_approve' → COMMERCIAL_APPROVED
    RETURN json_build_object('text', format('Event recorded for %s.', request_id));
  END IF;

  RETURN json_build_object('error', 'Unknown payload type');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### 5.4 Pre-request hook (header-level gating)

PostgREST supports a [pre-request function](https://docs.postgrest.org/en/v14/references/transactions.html#pre-request) that runs after transaction-scoped settings are set but before the main query. It has access to request headers, path, and method via GUCs — but **not** the request body. We use it for fast rejection of obviously invalid Slack requests before the main function runs:

```sql
CREATE FUNCTION check_request() RETURNS void AS $$
DECLARE
  headers json := current_setting('request.headers', true)::json;
  path    text := current_setting('request.path', true);
  ts      text;
BEGIN
  -- Only gate Slack webhook routes
  IF path = '/rpc/handle_slack_webhook' THEN
    -- Require signature headers
    IF headers->>'x-slack-signature' IS NULL
       OR headers->>'x-slack-request-timestamp' IS NULL THEN
      RAISE EXCEPTION 'Missing Slack signature headers'
        USING HINT = 'Provide X-Slack-Signature and X-Slack-Request-Timestamp';
    END IF;

    -- Replay protection: reject if timestamp is > 5 minutes old
    ts := headers->>'x-slack-request-timestamp';
    IF abs(extract(epoch FROM now()) - ts::bigint) > 300 THEN
      RAISE EXCEPTION 'Slack request timestamp too old'
        USING HINT = 'Possible replay attack';
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;
```

Configured via PostgREST's `db-pre-request` setting:

```
db-pre-request = "check_request"
```

This rejects stale and unsigned requests before the main function runs — saving a row lock and Vault lookup. The full HMAC verification (which requires the request body) remains in `handle_slack_webhook` (Section 5.3), since there is no `request.body` GUC.

### 5.5 Request header access

PostgREST exposes all HTTP request headers as a GUC variable, accessible inside PL/pgSQL:

```sql
-- All headers as JSON
SELECT current_setting('request.headers', true)::json;

-- Specific header (always lowercase)
SELECT current_setting('request.headers', true)::json->>'x-slack-signature';
```

The Slack proxy forwards the original `X-Slack-Signature` and `X-Slack-Request-Timestamp` headers unchanged. No `X-Raw-Body` header is needed — the raw body IS the function argument.

---

## 6. Timers (pg_cron)

### 6.1 Design

The `next_deadline_at` column on `capacity_requests` is set by the reducer when entering a deadline-bearing state (currently only `CUSTOMER_CONFIRMATION_REQUIRED`). A partial index ensures efficient queries.

### 6.2 Sweep function

```sql
CREATE FUNCTION run_capacity_request_timers() RETURNS void AS $$
DECLARE
  expired RECORD;
BEGIN
  FOR expired IN
    SELECT id FROM capacity_requests
    WHERE next_deadline_at IS NOT NULL
      AND next_deadline_at <= now()
      AND state NOT IN ('COMPLETED', 'REJECTED', 'CANCELLED', 'EXPIRED', 'FAILED')
    FOR UPDATE SKIP LOCKED
  LOOP
    PERFORM apply_capacity_event(
      expired.id,
      'CUSTOMER_CONFIRMATION_TIMEOUT',
      'cron',
      'pg_cron_timer',
      '{}'
    );
  END LOOP;
END;
$$ LANGUAGE plpgsql;
```

### 6.3 Schedule

```sql
SELECT cron.schedule('capacity-request-timers', '*/5 * * * *', 'SELECT run_capacity_request_timers()');
```

Runs every **5 minutes**. Default TTL is 7 calendar days, overridable per request via `confirmation_ttl_days`.

---

## 7. Side-effect reliability

### Phase 1 — Best-effort via pg_net

pg_net enqueues HTTP requests inside the reducer's transaction. The background worker delivers them after commit. This gives us a useful guarantee: **if the transaction rolls back, side effects are never sent.** However, delivery is at-most-once — if the pg_net worker crashes or the external API is down, the request is lost.

Failures are observable in `net._http_response` (retained for 6 hours). A pg_cron job can scan for failed responses and re-enqueue:

```sql
-- Example: retry failed Slack notifications (Phase 1 monitoring)
SELECT id, url, status_code, content
FROM net._http_response
WHERE status_code >= 400 OR status_code IS NULL
ORDER BY created DESC
LIMIT 50;
```

### Phase 2 — Transactional outbox

For at-least-once delivery guarantees, adopt a transactional outbox pattern:

1. The reducer inserts a row into an `outbox` table within the same transaction (alongside the event and projection update).
2. A pg_cron job polls the outbox, calls `net.http_post()` for undelivered rows, and marks them as sent.
3. Delivery is idempotent (Slack message deduplication via `slack_thread_ts`).

---

## 8. Security

### 8.1 Data access

- The `capacity_requests` projection is writable **only by the reducer** (service role). Direct writes by authenticated users are denied via Postgres grants.
- The `capacity_request_events` table is insert-only via the reducer. No updates or deletes.
- RLS policies enforce read access based on role:
  - Requesters can read their own requests.
  - Commercial and Infra reviewers can read requests assigned to them.
  - Admins can read all requests.
- All events carry **actor attribution** (`actor_type`, `actor_id`) for full auditability.
- Store minimal customer identifiers in `customer_ref`.

### 8.2 Slack request signature verification

Slack signs every request with HMAC-SHA256. Verification is two-layered:

1. **Pre-request hook** (Section 5.4) — rejects requests with missing headers or stale timestamps. Header-only; no Vault access needed.
2. **`verify_slack_signature`** — full HMAC verification using the request body. Runs inside `handle_slack_webhook`.

The signing secret is stored in Vault; HMAC verification runs in PL/pgSQL using pgcrypto:

```sql
CREATE FUNCTION verify_slack_signature(
  raw_body   text,
  timestamp_ text,
  signature  text
) RETURNS boolean AS $$
DECLARE
  signing_secret text;
  base_string    text;
  computed_sig   text;
BEGIN
  -- Timestamp replay protection is handled by the pre-request hook (Section 5.4).
  -- This function focuses on the HMAC, which requires the request body.

  signing_secret := get_secret('SLACK_SIGNING_SECRET');
  base_string    := 'v0:' || timestamp_ || ':' || raw_body;
  computed_sig   := 'v0=' || encode(hmac(base_string, signing_secret, 'sha256'), 'hex');

  -- Compare via digest to avoid timing side-channels
  RETURN digest(computed_sig, 'sha256') = digest(signature, 'sha256');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### 8.3 Secret management

All external API credentials are stored in **Supabase Vault** (encrypted at rest, decrypted on read via the `vault.decrypted_secrets` view). Secrets are provisioned through the Supabase Dashboard to avoid logging plaintext in SQL statement logs. The `get_secret()` helper (Section 4.4) is `SECURITY DEFINER` to restrict access to the vault view.

---

## 9. Observability

Metrics derivable from Postgres:

- **Time in state** — duration between consecutive events per request.
- **Approval latency** — time from `UNDER_REVIEW` entry to both approvals landing.
- **Expired request count** — count of requests reaching `EXPIRED`.
- **Cancelled request count** — count of requests reaching `CANCELLED`, segmented by originating state.
- **Provisioning duration** — time from `PROVISIONING` entry to `COMPLETED` or `FAILED`.

All metrics are queryable directly from the event log without additional infrastructure.

---

## 10. Rollout plan

### Phase 1 — Minimum Viable Workflow

- Enable extensions: `pg_net`, `pgcrypto`, `pg_cron`. Provision secrets in Vault.
- Postgres schema: tables, enums, sequence, indexes, RLS policies, grants.
- PL/pgSQL functions: `create_capacity_request`, `apply_capacity_event`, `compute_next_state`, `dispatch_side_effects`, `verify_slack_signature`, `handle_slack_webhook`.
- Slack proxy: Cloudflare Worker (~15 lines) that rewrites `Content-Type` to `text/plain` and forwards the raw body.
- Slack integration: slash command to create requests, interactive buttons for approvals and customer confirmation, thread updates via pg_net.
- pg_cron timer: 5-minute sweep for expired deadlines.

### Phase 2 — Operational Polish

- Linear integration: issue creation and comment sync via pg_net + Linear GraphQL API.
- Transactional outbox for reliable side-effect delivery.
- Threshold-based commercial approval escalation (e.g., requests above $X require VP approval).
- Warning notifications (e.g., "2 days remaining for customer confirmation").
- Observability dashboard built on event log queries.

### Phase 3 — Automation

- Automated provisioning status integration (webhook or polling from provisioning system).
- Optional web UI for request management and reporting.
- Self-service request submission (customer-facing form).
