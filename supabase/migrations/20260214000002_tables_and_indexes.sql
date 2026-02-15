-- Migration 2: Tables and Indexes
-- Creates the projection table and append-only event log,
-- plus indexes for timer sweeps and event lookups.

-- Projection table: current workflow state (writable only by reducer)
CREATE TABLE capacity_requests (
  id                              text PRIMARY KEY,
  version                         integer NOT NULL DEFAULT 1,
  state                           capacity_request_state NOT NULL,
  created_at                      timestamptz NOT NULL DEFAULT now(),
  updated_at                      timestamptz NOT NULL DEFAULT now(),
  requester_user_id               text NOT NULL,
  commercial_owner_user_id        text,
  infra_owner_group               text,
  customer_ref                    jsonb,
  requested_size                  text,
  quantity                        integer,
  region                          text,
  needed_by_date                  date,
  expected_duration_days          integer,
  estimated_monthly_cost_usd      numeric,
  commercial_approved_at          timestamptz,
  technical_approved_at           timestamptz,
  next_deadline_at                timestamptz,
  confirmation_ttl_days           integer NOT NULL DEFAULT 7,
  slack_channel_id                text,
  slack_thread_ts                 text,
  linear_issue_id                 text,
  last_notified_at                timestamptz,
  cancellation_reason             text,
  cancellation_authorizer_user_id text
);

-- Append-only event log
CREATE TABLE capacity_request_events (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  capacity_request_id   text NOT NULL REFERENCES capacity_requests(id),
  event_type            capacity_request_event_type NOT NULL,
  actor_type            capacity_request_actor_type NOT NULL,
  actor_id              text NOT NULL,
  payload               jsonb,
  created_at            timestamptz NOT NULL DEFAULT now()
);

-- Partial index: timer sweep finds requests with approaching/elapsed deadlines
CREATE INDEX idx_capacity_requests_deadline
  ON capacity_requests (next_deadline_at)
  WHERE next_deadline_at IS NOT NULL
    AND state NOT IN ('COMPLETED', 'REJECTED', 'CANCELLED', 'EXPIRED', 'FAILED');

-- Composite index: event log lookups by request
CREATE INDEX idx_capacity_request_events_request_id
  ON capacity_request_events (capacity_request_id, created_at);
