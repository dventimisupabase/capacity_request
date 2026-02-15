-- Migration 8a: Escalation Schema
-- Adds VP_APPROVED and VP_REJECTED enum values and vp_approved_at column.
-- Must commit before new enum values can be used in function bodies (PG requirement).

ALTER TYPE capacity_request_event_type ADD VALUE 'VP_APPROVED';
ALTER TYPE capacity_request_event_type ADD VALUE 'VP_REJECTED';

ALTER TABLE capacity_requests ADD COLUMN vp_approved_at timestamptz;
