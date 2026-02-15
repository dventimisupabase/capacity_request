-- Migration 1: Extensions, Enums, Sequence, and ID helper
-- Enables required Postgres extensions and creates the domain types
-- that define the capacity request state machine vocabulary.

-- Extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_net;
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Enum: workflow states (5 active + 4 terminal)
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

-- Enum: event types that drive state transitions
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

-- Enum: who performed the action
CREATE TYPE capacity_request_actor_type AS ENUM (
  'user',
  'system',
  'cron'
);

-- Sequence for human-readable CR IDs
CREATE SEQUENCE capacity_request_seq;

-- Helper: generate CR-YYYY-NNNNNN format IDs
CREATE FUNCTION next_capacity_request_id() RETURNS text AS $$
  SELECT 'CR-' || extract(year FROM now())::int || '-' || lpad(nextval('capacity_request_seq')::text, 6, '0');
$$ LANGUAGE sql;
