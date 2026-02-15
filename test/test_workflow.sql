-- test/test_workflow.sql
-- Runnable SQL test script for the capacity request workflow.
-- Exercises core functions via DO blocks with assertions.
-- Run against a Postgres instance with migrations 1-3 applied.
--
-- Usage: psql -v ON_ERROR_STOP=1 -f test/test_workflow.sql

BEGIN;

-- ============================================================
-- Test 1: ID generation format (CR-YYYY-NNNNNN)
-- ============================================================
DO $$
DECLARE
  id1 text;
  id2 text;
BEGIN
  id1 := next_capacity_request_id();
  id2 := next_capacity_request_id();

  -- Format: CR-YYYY-NNNNNN
  ASSERT id1 ~ '^CR-\d{4}-\d{6}$',
    format('ID format mismatch: %s', id1);

  -- Year matches current year
  ASSERT id1 LIKE 'CR-' || extract(year FROM now())::int || '-%',
    format('ID year mismatch: %s', id1);

  -- Sequential
  ASSERT split_part(id2, '-', 3)::int = split_part(id1, '-', 3)::int + 1,
    format('IDs not sequential: %s, %s', id1, id2);

  RAISE NOTICE 'PASS: Test 1 - ID generation';
END;
$$;

-- ============================================================
-- Test 2: compute_next_state — pure transition logic
-- ============================================================
DO $$
DECLARE
  s capacity_request_state;
BEGIN
  -- SUBMITTED + REQUEST_SUBMITTED -> UNDER_REVIEW
  s := compute_next_state('SUBMITTED', 'REQUEST_SUBMITTED', false, false);
  ASSERT s = 'UNDER_REVIEW', format('Expected UNDER_REVIEW, got %s', s);

  -- UNDER_REVIEW + COMMERCIAL_APPROVED (only commercial done) -> UNDER_REVIEW
  s := compute_next_state('UNDER_REVIEW', 'COMMERCIAL_APPROVED', true, false);
  ASSERT s = 'UNDER_REVIEW', format('Expected UNDER_REVIEW, got %s', s);

  -- UNDER_REVIEW + TECH_REVIEW_APPROVED (only tech done) -> UNDER_REVIEW
  s := compute_next_state('UNDER_REVIEW', 'TECH_REVIEW_APPROVED', false, true);
  ASSERT s = 'UNDER_REVIEW', format('Expected UNDER_REVIEW, got %s', s);

  -- UNDER_REVIEW + COMMERCIAL_APPROVED (both done) -> CUSTOMER_CONFIRMATION_REQUIRED
  s := compute_next_state('UNDER_REVIEW', 'COMMERCIAL_APPROVED', true, true);
  ASSERT s = 'CUSTOMER_CONFIRMATION_REQUIRED', format('Expected CUSTOMER_CONFIRMATION_REQUIRED, got %s', s);

  -- UNDER_REVIEW + TECH_REVIEW_APPROVED (both done) -> CUSTOMER_CONFIRMATION_REQUIRED
  s := compute_next_state('UNDER_REVIEW', 'TECH_REVIEW_APPROVED', true, true);
  ASSERT s = 'CUSTOMER_CONFIRMATION_REQUIRED', format('Expected CUSTOMER_CONFIRMATION_REQUIRED, got %s', s);

  -- UNDER_REVIEW + COMMERCIAL_REJECTED -> REJECTED
  s := compute_next_state('UNDER_REVIEW', 'COMMERCIAL_REJECTED', false, false);
  ASSERT s = 'REJECTED', format('Expected REJECTED, got %s', s);

  -- UNDER_REVIEW + TECH_REVIEW_REJECTED -> REJECTED
  s := compute_next_state('UNDER_REVIEW', 'TECH_REVIEW_REJECTED', false, false);
  ASSERT s = 'REJECTED', format('Expected REJECTED, got %s', s);

  -- CUSTOMER_CONFIRMATION_REQUIRED + CUSTOMER_CONFIRMED -> PROVISIONING
  s := compute_next_state('CUSTOMER_CONFIRMATION_REQUIRED', 'CUSTOMER_CONFIRMED', true, true);
  ASSERT s = 'PROVISIONING', format('Expected PROVISIONING, got %s', s);

  -- CUSTOMER_CONFIRMATION_REQUIRED + CUSTOMER_DECLINED -> CANCELLED
  s := compute_next_state('CUSTOMER_CONFIRMATION_REQUIRED', 'CUSTOMER_DECLINED', true, true);
  ASSERT s = 'CANCELLED', format('Expected CANCELLED, got %s', s);

  -- CUSTOMER_CONFIRMATION_REQUIRED + CUSTOMER_CONFIRMATION_TIMEOUT -> EXPIRED
  s := compute_next_state('CUSTOMER_CONFIRMATION_REQUIRED', 'CUSTOMER_CONFIRMATION_TIMEOUT', true, true);
  ASSERT s = 'EXPIRED', format('Expected EXPIRED, got %s', s);

  -- PROVISIONING + PROVISIONING_COMPLETE -> COMPLETED
  s := compute_next_state('PROVISIONING', 'PROVISIONING_COMPLETE', true, true);
  ASSERT s = 'COMPLETED', format('Expected COMPLETED, got %s', s);

  -- PROVISIONING + PROVISIONING_FAILED -> FAILED
  s := compute_next_state('PROVISIONING', 'PROVISIONING_FAILED', true, true);
  ASSERT s = 'FAILED', format('Expected FAILED, got %s', s);

  -- CANCEL_APPROVED from non-terminal states
  s := compute_next_state('SUBMITTED', 'CANCEL_APPROVED', false, false);
  ASSERT s = 'CANCELLED', format('Expected CANCELLED, got %s', s);

  s := compute_next_state('UNDER_REVIEW', 'CANCEL_APPROVED', false, false);
  ASSERT s = 'CANCELLED', format('Expected CANCELLED, got %s', s);

  s := compute_next_state('CUSTOMER_CONFIRMATION_REQUIRED', 'CANCEL_APPROVED', true, true);
  ASSERT s = 'CANCELLED', format('Expected CANCELLED, got %s', s);

  s := compute_next_state('PROVISIONING', 'CANCEL_APPROVED', true, true);
  ASSERT s = 'CANCELLED', format('Expected CANCELLED, got %s', s);

  RAISE NOTICE 'PASS: Test 2 - compute_next_state pure transitions';
END;
$$;

-- ============================================================
-- Test 3: compute_next_state — invalid transitions raise exceptions
-- ============================================================
DO $$
BEGIN
  -- Terminal state COMPLETED rejects all events
  BEGIN
    PERFORM compute_next_state('COMPLETED', 'PROVISIONING_COMPLETE', true, true);
    ASSERT false, 'Should have raised exception for COMPLETED + PROVISIONING_COMPLETE';
  EXCEPTION WHEN OTHERS THEN
    NULL; -- expected
  END;

  -- Terminal state REJECTED rejects events
  BEGIN
    PERFORM compute_next_state('REJECTED', 'REQUEST_SUBMITTED', false, false);
    ASSERT false, 'Should have raised exception for REJECTED + REQUEST_SUBMITTED';
  EXCEPTION WHEN OTHERS THEN
    NULL; -- expected
  END;

  -- CANCEL_APPROVED from terminal state
  BEGIN
    PERFORM compute_next_state('CANCELLED', 'CANCEL_APPROVED', false, false);
    ASSERT false, 'Should have raised exception for CANCELLED + CANCEL_APPROVED';
  EXCEPTION WHEN OTHERS THEN
    NULL; -- expected
  END;

  BEGIN
    PERFORM compute_next_state('EXPIRED', 'CANCEL_APPROVED', false, false);
    ASSERT false, 'Should have raised exception for EXPIRED + CANCEL_APPROVED';
  EXCEPTION WHEN OTHERS THEN
    NULL; -- expected
  END;

  BEGIN
    PERFORM compute_next_state('FAILED', 'CANCEL_APPROVED', false, false);
    ASSERT false, 'Should have raised exception for FAILED + CANCEL_APPROVED';
  EXCEPTION WHEN OTHERS THEN
    NULL; -- expected
  END;

  -- Invalid event for state
  BEGIN
    PERFORM compute_next_state('SUBMITTED', 'COMMERCIAL_APPROVED', false, false);
    ASSERT false, 'Should have raised exception for SUBMITTED + COMMERCIAL_APPROVED';
  EXCEPTION WHEN OTHERS THEN
    NULL; -- expected
  END;

  BEGIN
    PERFORM compute_next_state('PROVISIONING', 'CUSTOMER_CONFIRMED', true, true);
    ASSERT false, 'Should have raised exception for PROVISIONING + CUSTOMER_CONFIRMED';
  EXCEPTION WHEN OTHERS THEN
    NULL; -- expected
  END;

  RAISE NOTICE 'PASS: Test 3 - compute_next_state invalid transitions';
END;
$$;

-- ============================================================
-- Test 4: Happy path — full lifecycle through reducer
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  event_count integer;
BEGIN
  -- Create request -> immediately transitions to UNDER_REVIEW
  req := create_capacity_request(
    p_requester_user_id         := 'U_requester',
    p_commercial_owner_user_id  := 'U_commercial',
    p_infra_owner_group         := 'infra-team',
    p_customer_ref              := '{"org_id": "org_123", "name": "Acme Corp"}'::jsonb,
    p_requested_size            := '32XL',
    p_quantity                  := 2,
    p_region                    := 'us-east-1',
    p_needed_by_date            := '2026-03-01'::date,
    p_expected_duration_days    := 90
  );

  ASSERT req.id ~ '^CR-\d{4}-\d{6}$', format('Bad ID: %s', req.id);
  ASSERT req.state = 'UNDER_REVIEW', format('Expected UNDER_REVIEW after create, got %s', req.state);
  ASSERT req.version = 2, format('Expected version 2 after create, got %s', req.version);
  ASSERT req.commercial_approved_at IS NULL, 'commercial_approved_at should be NULL';
  ASSERT req.technical_approved_at IS NULL, 'technical_approved_at should be NULL';
  ASSERT req.next_deadline_at IS NULL, 'next_deadline_at should be NULL in UNDER_REVIEW';

  -- Commercial approve (first approval, stays in UNDER_REVIEW)
  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_commercial');
  ASSERT req.state = 'UNDER_REVIEW', format('Expected UNDER_REVIEW after first approval, got %s', req.state);
  ASSERT req.version = 3, format('Expected version 3, got %s', req.version);
  ASSERT req.commercial_approved_at IS NOT NULL, 'commercial_approved_at should be set';
  ASSERT req.technical_approved_at IS NULL, 'technical_approved_at should still be NULL';

  -- Tech approve (second approval, both done -> CUSTOMER_CONFIRMATION_REQUIRED)
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra');
  ASSERT req.state = 'CUSTOMER_CONFIRMATION_REQUIRED',
    format('Expected CUSTOMER_CONFIRMATION_REQUIRED after both approvals, got %s', req.state);
  ASSERT req.version = 4, format('Expected version 4, got %s', req.version);
  ASSERT req.technical_approved_at IS NOT NULL, 'technical_approved_at should be set';
  ASSERT req.next_deadline_at IS NOT NULL, 'next_deadline_at should be set';
  ASSERT req.next_deadline_at > now(), 'Deadline should be in the future';

  -- Customer confirms -> PROVISIONING
  req := apply_capacity_event(req.id, 'CUSTOMER_CONFIRMED', 'user', 'U_customer');
  ASSERT req.state = 'PROVISIONING', format('Expected PROVISIONING, got %s', req.state);
  ASSERT req.version = 5, format('Expected version 5, got %s', req.version);
  ASSERT req.next_deadline_at IS NULL, 'next_deadline_at should be cleared after PROVISIONING';

  -- Provisioning complete -> COMPLETED
  req := apply_capacity_event(req.id, 'PROVISIONING_COMPLETE', 'system', 'provisioner');
  ASSERT req.state = 'COMPLETED', format('Expected COMPLETED, got %s', req.state);
  ASSERT req.version = 6, format('Expected version 6, got %s', req.version);

  -- Verify event log completeness
  SELECT count(*) INTO event_count
    FROM capacity_request_events
    WHERE capacity_request_id = req.id;
  ASSERT event_count = 5, format('Expected 5 events, got %s', event_count);

  RAISE NOTICE 'PASS: Test 4 - Happy path lifecycle (% through 5 events)', req.id;
END;
$$;

-- ============================================================
-- Test 5: Dual-flag logic — single approval stays UNDER_REVIEW
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
BEGIN
  -- Create request
  req := create_capacity_request(
    'U_req2', 'U_comm2', 'infra-2',
    '{"org_id": "org_456"}'::jsonb,
    '16XL', 1, 'eu-west-1', '2026-04-01'::date, 60
  );

  -- Tech approve first (only tech done)
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra2');
  ASSERT req.state = 'UNDER_REVIEW',
    format('Expected UNDER_REVIEW after only tech approval, got %s', req.state);
  ASSERT req.technical_approved_at IS NOT NULL, 'tech should be set';
  ASSERT req.commercial_approved_at IS NULL, 'commercial should still be NULL';

  -- Commercial approve (both now done)
  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm2');
  ASSERT req.state = 'CUSTOMER_CONFIRMATION_REQUIRED',
    format('Expected CUSTOMER_CONFIRMATION_REQUIRED, got %s', req.state);
  ASSERT req.commercial_approved_at IS NOT NULL, 'commercial should now be set';

  RAISE NOTICE 'PASS: Test 5 - Dual-flag logic (tech first, then commercial)';
END;
$$;

-- ============================================================
-- Test 6: Unhappy path — commercial rejection
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
BEGIN
  req := create_capacity_request(
    'U_req3', 'U_comm3', 'infra-3',
    '{"org_id": "org_789"}'::jsonb,
    '32XL', 1, 'ap-southeast-1', '2026-05-01'::date, 30
  );

  req := apply_capacity_event(req.id, 'COMMERCIAL_REJECTED', 'user', 'U_comm3');
  ASSERT req.state = 'REJECTED', format('Expected REJECTED, got %s', req.state);

  RAISE NOTICE 'PASS: Test 6 - Commercial rejection';
END;
$$;

-- ============================================================
-- Test 7: Unhappy path — tech rejection
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
BEGIN
  req := create_capacity_request(
    'U_req4', 'U_comm4', 'infra-4',
    '{"org_id": "org_101"}'::jsonb,
    '32XL', 3, 'us-west-2', '2026-06-01'::date, 45
  );

  -- Commercial approves first
  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm4');
  ASSERT req.state = 'UNDER_REVIEW', 'Should stay UNDER_REVIEW';

  -- Then tech rejects
  req := apply_capacity_event(req.id, 'TECH_REVIEW_REJECTED', 'user', 'U_infra4');
  ASSERT req.state = 'REJECTED', format('Expected REJECTED, got %s', req.state);

  RAISE NOTICE 'PASS: Test 7 - Tech rejection after commercial approval';
END;
$$;

-- ============================================================
-- Test 8: Unhappy path — customer decline
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
BEGIN
  req := create_capacity_request(
    'U_req5', 'U_comm5', 'infra-5',
    '{"org_id": "org_202"}'::jsonb,
    '24XL', 1, 'eu-central-1', '2026-07-01'::date, 60
  );

  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm5');
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra5');
  ASSERT req.state = 'CUSTOMER_CONFIRMATION_REQUIRED', 'Should be awaiting customer';

  req := apply_capacity_event(req.id, 'CUSTOMER_DECLINED', 'user', 'U_customer5');
  ASSERT req.state = 'CANCELLED', format('Expected CANCELLED, got %s', req.state);

  RAISE NOTICE 'PASS: Test 8 - Customer decline';
END;
$$;

-- ============================================================
-- Test 9: Unhappy path — customer confirmation timeout
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
BEGIN
  req := create_capacity_request(
    'U_req6', 'U_comm6', 'infra-6',
    '{"org_id": "org_303"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-08-01'::date, 30
  );

  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm6');
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra6');
  ASSERT req.state = 'CUSTOMER_CONFIRMATION_REQUIRED', 'Should be awaiting customer';

  -- Simulate timeout (normally from pg_cron)
  req := apply_capacity_event(req.id, 'CUSTOMER_CONFIRMATION_TIMEOUT', 'cron', 'pg_cron_timer');
  ASSERT req.state = 'EXPIRED', format('Expected EXPIRED, got %s', req.state);

  RAISE NOTICE 'PASS: Test 9 - Customer confirmation timeout';
END;
$$;

-- ============================================================
-- Test 10: Unhappy path — cancel from active state
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
BEGIN
  req := create_capacity_request(
    'U_req7', 'U_comm7', 'infra-7',
    '{"org_id": "org_404"}'::jsonb,
    '32XL', 2, 'us-west-1', '2026-09-01'::date, 90
  );

  ASSERT req.state = 'UNDER_REVIEW', 'Should be UNDER_REVIEW after create';

  -- Cancel from UNDER_REVIEW
  req := apply_capacity_event(req.id, 'CANCEL_APPROVED', 'user', 'U_admin',
    '{"reason": "Customer changed requirements"}'::jsonb);
  ASSERT req.state = 'CANCELLED', format('Expected CANCELLED, got %s', req.state);
  ASSERT req.cancellation_reason = 'Customer changed requirements',
    format('Wrong cancellation reason: %s', req.cancellation_reason);
  ASSERT req.cancellation_authorizer_user_id = 'U_admin',
    format('Wrong cancellation authorizer: %s', req.cancellation_authorizer_user_id);

  RAISE NOTICE 'PASS: Test 10 - Cancel from active state with reason';
END;
$$;

-- ============================================================
-- Test 11: Cancel from PROVISIONING state
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
BEGIN
  req := create_capacity_request(
    'U_req8', 'U_comm8', 'infra-8',
    '{"org_id": "org_505"}'::jsonb,
    '32XL', 1, 'eu-west-1', '2026-10-01'::date, 60
  );

  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm8');
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra8');
  req := apply_capacity_event(req.id, 'CUSTOMER_CONFIRMED', 'user', 'U_customer8');
  ASSERT req.state = 'PROVISIONING', 'Should be PROVISIONING';

  req := apply_capacity_event(req.id, 'CANCEL_APPROVED', 'user', 'U_admin',
    '{"reason": "Duplicate request"}'::jsonb);
  ASSERT req.state = 'CANCELLED', format('Expected CANCELLED, got %s', req.state);

  RAISE NOTICE 'PASS: Test 11 - Cancel from PROVISIONING';
END;
$$;

-- ============================================================
-- Test 12: Terminal states reject all events
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
BEGIN
  -- Create and reject a request
  req := create_capacity_request(
    'U_req9', 'U_comm9', 'infra-9',
    '{"org_id": "org_606"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-11-01'::date, 30
  );
  req := apply_capacity_event(req.id, 'COMMERCIAL_REJECTED', 'user', 'U_comm9');
  ASSERT req.state = 'REJECTED', 'Should be REJECTED';

  -- Try to apply events to rejected request
  BEGIN
    PERFORM apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm9');
    ASSERT false, 'Should have raised exception for event on REJECTED request';
  EXCEPTION WHEN OTHERS THEN
    NULL; -- expected
  END;

  BEGIN
    PERFORM apply_capacity_event(req.id, 'CANCEL_APPROVED', 'user', 'U_admin');
    ASSERT false, 'Should have raised exception for CANCEL on REJECTED request';
  EXCEPTION WHEN OTHERS THEN
    NULL; -- expected
  END;

  RAISE NOTICE 'PASS: Test 12 - Terminal states reject events';
END;
$$;

-- ============================================================
-- Test 13: Provisioning failure
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
BEGIN
  req := create_capacity_request(
    'U_req10', 'U_comm10', 'infra-10',
    '{"org_id": "org_707"}'::jsonb,
    '32XL', 1, 'ap-northeast-1', '2026-12-01'::date, 30
  );

  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm10');
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra10');
  req := apply_capacity_event(req.id, 'CUSTOMER_CONFIRMED', 'user', 'U_customer10');
  ASSERT req.state = 'PROVISIONING', 'Should be PROVISIONING';

  req := apply_capacity_event(req.id, 'PROVISIONING_FAILED', 'system', 'provisioner',
    '{"error": "Instance limit reached in region"}'::jsonb);
  ASSERT req.state = 'FAILED', format('Expected FAILED, got %s', req.state);

  -- FAILED is terminal
  BEGIN
    PERFORM apply_capacity_event(req.id, 'PROVISIONING_COMPLETE', 'system', 'provisioner');
    ASSERT false, 'Should have raised exception for event on FAILED request';
  EXCEPTION WHEN OTHERS THEN
    NULL; -- expected
  END;

  RAISE NOTICE 'PASS: Test 13 - Provisioning failure and terminal state';
END;
$$;

-- ============================================================
-- Test 14: Event log integrity — correct types and ordering
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  events capacity_request_event_type[];
BEGIN
  req := create_capacity_request(
    'U_req11', 'U_comm11', 'infra-11',
    '{"org_id": "org_808"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-12-15'::date, 30
  );

  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm11');
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra11');
  req := apply_capacity_event(req.id, 'CUSTOMER_CONFIRMED', 'user', 'U_customer11');
  req := apply_capacity_event(req.id, 'PROVISIONING_COMPLETE', 'system', 'provisioner');

  SELECT array_agg(event_type ORDER BY created_at) INTO events
    FROM capacity_request_events
    WHERE capacity_request_id = req.id;

  ASSERT events = ARRAY[
    'REQUEST_SUBMITTED',
    'COMMERCIAL_APPROVED',
    'TECH_REVIEW_APPROVED',
    'CUSTOMER_CONFIRMED',
    'PROVISIONING_COMPLETE'
  ]::capacity_request_event_type[],
    format('Event sequence mismatch: %s', events::text);

  RAISE NOTICE 'PASS: Test 14 - Event log integrity';
END;
$$;

-- ============================================================
-- Test 15: Confirmation deadline is set correctly
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  expected_deadline timestamptz;
BEGIN
  -- Create with custom TTL of 14 days
  req := create_capacity_request(
    'U_req12', 'U_comm12', 'infra-12',
    '{"org_id": "org_909"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-12-20'::date, 30,
    NULL, 14  -- 14 day TTL
  );

  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm12');
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra12');

  ASSERT req.state = 'CUSTOMER_CONFIRMATION_REQUIRED', 'Should need confirmation';
  ASSERT req.next_deadline_at IS NOT NULL, 'Deadline should be set';

  -- Deadline should be approximately 14 days from now (within a few seconds)
  ASSERT req.next_deadline_at BETWEEN now() + interval '13 days 23 hours'
                                  AND now() + interval '14 days 1 hour',
    format('Deadline not ~14 days from now: %s', req.next_deadline_at);

  RAISE NOTICE 'PASS: Test 15 - Custom confirmation TTL deadline';
END;
$$;

-- ============================================================
-- Test 16: slack_channel_id parameter on create
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
BEGIN
  req := create_capacity_request(
    'U_req13', 'U_comm13', 'infra-13',
    '{"org_id": "org_slack"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-12-25'::date, 30,
    NULL, 7, 'C_TEST_CHANNEL'
  );

  ASSERT req.slack_channel_id = 'C_TEST_CHANNEL',
    format('Expected slack_channel_id C_TEST_CHANNEL, got %s', req.slack_channel_id);

  -- Also verify NULL default works (all existing tests use it implicitly)
  RAISE NOTICE 'PASS: Test 16 - slack_channel_id parameter on create';
END;
$$;

-- ============================================================
-- Test 17: Outbox table schema and enqueue on side effects
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  outbox_row record;
  outbox_count integer;
BEGIN
  -- Direct insert into outbox to verify schema
  INSERT INTO capacity_request_outbox (capacity_request_id, destination, payload)
  SELECT cr.id, 'slack', '{"text":"test"}'::jsonb
  FROM capacity_requests cr LIMIT 1
  RETURNING * INTO outbox_row;

  ASSERT outbox_row.id IS NOT NULL, 'Outbox row should have UUID id';
  ASSERT outbox_row.delivered_at IS NULL, 'delivered_at should be NULL';
  ASSERT outbox_row.attempts = 0, 'attempts should default to 0';
  ASSERT outbox_row.max_attempts = 5, 'max_attempts should default to 5';
  ASSERT outbox_row.pg_net_request_id IS NULL, 'pg_net_request_id should be NULL';

  -- Clean up direct insert
  DELETE FROM capacity_request_outbox WHERE id = outbox_row.id;

  -- Create a request WITH slack_channel_id and apply an event
  -- dispatch_side_effects should enqueue an outbox row
  req := create_capacity_request(
    'U_outbox1', 'U_comm_outbox', 'infra-outbox',
    '{"org_id": "org_outbox"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-12-01'::date, 30,
    NULL, 7, 'C_OUTBOX_TEST'
  );

  -- The create triggers REQUEST_SUBMITTED -> UNDER_REVIEW which dispatches side effects
  SELECT count(*) INTO outbox_count
  FROM capacity_request_outbox
  WHERE capacity_request_id = req.id;

  ASSERT outbox_count > 0,
    format('Expected outbox rows for request with slack_channel_id, got %s', outbox_count);

  RAISE NOTICE 'PASS: Test 17 - Outbox table schema and enqueue';
END;
$$;

-- ============================================================
-- Test 18: Outbox delivery mechanics (partial index filtering)
-- ============================================================
DO $$
DECLARE
  req_id text;
  pending_count integer;
BEGIN
  -- Get any existing request ID for FK
  SELECT id INTO req_id FROM capacity_requests LIMIT 1;

  -- Insert various outbox rows to test filtering
  -- 1. Pending (should be found by index)
  INSERT INTO capacity_request_outbox (capacity_request_id, destination, payload, attempts)
  VALUES (req_id, 'slack', '{"text":"pending"}'::jsonb, 0);

  -- 2. Delivered (should NOT be found by index)
  INSERT INTO capacity_request_outbox (capacity_request_id, destination, payload, delivered_at, attempts)
  VALUES (req_id, 'slack', '{"text":"delivered"}'::jsonb, now(), 1);

  -- 3. Max attempts exceeded (should NOT be found by index)
  INSERT INTO capacity_request_outbox (capacity_request_id, destination, payload, attempts, max_attempts)
  VALUES (req_id, 'slack', '{"text":"exhausted"}'::jsonb, 5, 5);

  -- Query using the same condition as the partial index
  SELECT count(*) INTO pending_count
  FROM capacity_request_outbox
  WHERE capacity_request_id = req_id
    AND delivered_at IS NULL
    AND attempts < max_attempts
    AND payload->>'text' IN ('pending', 'delivered', 'exhausted');

  -- Only the 'pending' row should match
  ASSERT pending_count >= 1,
    format('Expected at least 1 pending outbox row, got %s', pending_count);

  -- Verify delivered row is excluded
  ASSERT NOT EXISTS (
    SELECT 1 FROM capacity_request_outbox
    WHERE capacity_request_id = req_id
      AND delivered_at IS NULL
      AND attempts < max_attempts
      AND payload->>'text' = 'delivered'
  ), 'Delivered row should be excluded from undelivered query';

  -- Verify exhausted row is excluded
  ASSERT NOT EXISTS (
    SELECT 1 FROM capacity_request_outbox
    WHERE capacity_request_id = req_id
      AND delivered_at IS NULL
      AND attempts < max_attempts
      AND payload->>'text' = 'exhausted'
  ), 'Exhausted row should be excluded from undelivered query';

  RAISE NOTICE 'PASS: Test 18 - Outbox delivery mechanics';
END;
$$;

-- ============================================================
-- Test 19: High-cost request requires VP approval
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
BEGIN
  -- Create request with cost above threshold ($100k > $50k default)
  req := create_capacity_request(
    'U_vp1', 'U_comm_vp1', 'infra-vp',
    '{"org_id": "org_vp1"}'::jsonb,
    '32XL', 10, 'us-east-1', '2026-12-01'::date, 90,
    100000, 7  -- $100k cost, no slack channel
  );
  ASSERT req.state = 'UNDER_REVIEW', 'Should be UNDER_REVIEW after create';

  -- Apply commercial + technical approval
  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_vp1');
  ASSERT req.state = 'UNDER_REVIEW', 'Should stay UNDER_REVIEW after commercial approval';

  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra_vp1');
  ASSERT req.state = 'UNDER_REVIEW',
    format('High-cost request should stay UNDER_REVIEW without VP approval, got %s', req.state);

  -- VP approval should advance to CUSTOMER_CONFIRMATION_REQUIRED
  req := apply_capacity_event(req.id, 'VP_APPROVED', 'user', 'U_vp_approver');
  ASSERT req.state = 'CUSTOMER_CONFIRMATION_REQUIRED',
    format('Expected CUSTOMER_CONFIRMATION_REQUIRED after VP approval, got %s', req.state);
  ASSERT req.vp_approved_at IS NOT NULL, 'vp_approved_at should be set';

  RAISE NOTICE 'PASS: Test 19 - High-cost request requires VP approval';
END;
$$;

-- ============================================================
-- Test 20: Low-cost request skips VP approval
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
BEGIN
  -- Create request with cost below threshold ($5k < $50k default)
  req := create_capacity_request(
    'U_vp2', 'U_comm_vp2', 'infra-vp2',
    '{"org_id": "org_vp2"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-12-01'::date, 30,
    5000, 7  -- $5k cost
  );

  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_vp2');
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra_vp2');

  ASSERT req.state = 'CUSTOMER_CONFIRMATION_REQUIRED',
    format('Low-cost request should advance directly, got %s', req.state);

  RAISE NOTICE 'PASS: Test 20 - Low-cost request skips VP';
END;
$$;

-- ============================================================
-- Test 21: NULL cost skips VP approval
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
BEGIN
  -- Create request with NULL cost (default)
  req := create_capacity_request(
    'U_vp3', 'U_comm_vp3', 'infra-vp3',
    '{"org_id": "org_vp3"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-12-01'::date, 30
  );

  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_vp3');
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra_vp3');

  ASSERT req.state = 'CUSTOMER_CONFIRMATION_REQUIRED',
    format('NULL cost request should advance directly, got %s', req.state);

  RAISE NOTICE 'PASS: Test 21 - NULL cost skips VP';
END;
$$;

-- ============================================================
-- Test 22: VP rejection rejects request
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
BEGIN
  -- Create high-cost request
  req := create_capacity_request(
    'U_vp4', 'U_comm_vp4', 'infra-vp4',
    '{"org_id": "org_vp4"}'::jsonb,
    '32XL', 5, 'us-east-1', '2026-12-01'::date, 90,
    100000, 7
  );

  -- VP rejection from UNDER_REVIEW -> REJECTED
  req := apply_capacity_event(req.id, 'VP_REJECTED', 'user', 'U_vp_rejector');
  ASSERT req.state = 'REJECTED',
    format('Expected REJECTED after VP rejection, got %s', req.state);

  RAISE NOTICE 'PASS: Test 22 - VP rejection rejects request';
END;
$$;

-- ============================================================
-- Test 23: VP approval on non-escalated request still works
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
BEGIN
  -- Low-cost request, but VP approves anyway (no-op flag)
  req := create_capacity_request(
    'U_vp5', 'U_comm_vp5', 'infra-vp5',
    '{"org_id": "org_vp5"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-12-01'::date, 30,
    1000, 7  -- $1k cost, well below threshold
  );

  -- VP_APPROVED while commercial and tech are still pending
  -- should keep state as UNDER_REVIEW (still need commercial+tech)
  req := apply_capacity_event(req.id, 'VP_APPROVED', 'user', 'U_vp_approver');
  ASSERT req.state = 'UNDER_REVIEW',
    format('Expected UNDER_REVIEW (still needs commercial+tech), got %s', req.state);

  -- Now apply commercial + tech, should advance
  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_vp5');
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra_vp5');
  ASSERT req.state = 'CUSTOMER_CONFIRMATION_REQUIRED',
    format('Expected CUSTOMER_CONFIRMATION_REQUIRED, got %s', req.state);

  RAISE NOTICE 'PASS: Test 23 - VP approval on non-escalated request';
END;
$$;

-- ============================================================
-- Test 24: Observability views return data
-- ============================================================
DO $$
DECLARE
  row_count integer;
BEGIN
  -- v_time_in_state should have rows (we have many requests with multiple events)
  SELECT count(*) INTO row_count FROM v_time_in_state;
  ASSERT row_count > 0, format('v_time_in_state should have rows, got %s', row_count);

  -- v_approval_latency should have rows
  SELECT count(*) INTO row_count FROM v_approval_latency;
  ASSERT row_count > 0, format('v_approval_latency should have rows, got %s', row_count);

  -- v_request_summary should have one row per request
  SELECT count(*) INTO row_count FROM v_request_summary;
  ASSERT row_count > 0, format('v_request_summary should have rows, got %s', row_count);

  -- v_provisioning_duration should have rows (requests that went through provisioning)
  SELECT count(*) INTO row_count FROM v_provisioning_duration;
  ASSERT row_count > 0, format('v_provisioning_duration should have rows, got %s', row_count);

  -- v_terminal_state_counts should show counts for terminal states
  SELECT count(*) INTO row_count FROM v_terminal_state_counts;
  ASSERT row_count > 0, format('v_terminal_state_counts should have rows, got %s', row_count);

  RAISE NOTICE 'PASS: Test 24 - Observability views return data';
END;
$$;

-- ============================================================
-- Setup for provisioning webhook tests: insert Vault secret
-- ============================================================
DO $$
BEGIN
  PERFORM vault.create_secret('test-provisioning-secret', 'PROVISIONING_WEBHOOK_SECRET');
  RAISE NOTICE 'Setup: Provisioning webhook Vault secret inserted';
END;
$$;

-- ============================================================
-- Test 25: Provisioning webhook — happy path complete
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  result json;
BEGIN
  -- Create request and advance to PROVISIONING
  req := create_capacity_request(
    'U_wh1', 'U_comm_wh1', 'infra-wh1',
    '{"org_id": "org_wh1"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-12-01'::date, 30,
    5000, 7
  );
  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_wh1');
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra_wh1');
  req := apply_capacity_event(req.id, 'CUSTOMER_CONFIRMED', 'user', 'U_customer_wh1');
  ASSERT req.state = 'PROVISIONING', format('Setup failed: expected PROVISIONING, got %s', req.state);

  -- Simulate the provisioning webhook header
  PERFORM set_config('request.headers', json_build_object(
    'x-provisioning-api-key', 'test-provisioning-secret'
  )::text, true);

  -- Call the webhook
  result := handle_provisioning_webhook(json_build_object(
    'request_id', req.id,
    'status', 'complete',
    'details', json_build_object('instance_id', 'i-abc123', 'ip', '10.0.1.5')
  )::text);

  ASSERT result->>'status' = 'ok', format('Expected ok, got %s', result->>'status');
  ASSERT result->>'new_state' = 'COMPLETED', format('Expected COMPLETED, got %s', result->>'new_state');

  -- Verify the request is actually COMPLETED
  SELECT * INTO req FROM capacity_requests WHERE id = req.id;
  ASSERT req.state = 'COMPLETED', format('Request should be COMPLETED, got %s', req.state);

  RAISE NOTICE 'PASS: Test 25 - Provisioning webhook happy path complete';
END;
$$;

-- ============================================================
-- Test 26: Provisioning webhook — happy path failed
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  result json;
BEGIN
  -- Create request and advance to PROVISIONING
  req := create_capacity_request(
    'U_wh2', 'U_comm_wh2', 'infra-wh2',
    '{"org_id": "org_wh2"}'::jsonb,
    '32XL', 1, 'eu-west-1', '2026-12-01'::date, 30,
    5000, 7
  );
  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_wh2');
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra_wh2');
  req := apply_capacity_event(req.id, 'CUSTOMER_CONFIRMED', 'user', 'U_customer_wh2');
  ASSERT req.state = 'PROVISIONING', 'Setup failed';

  PERFORM set_config('request.headers', json_build_object(
    'x-provisioning-api-key', 'test-provisioning-secret'
  )::text, true);

  result := handle_provisioning_webhook(json_build_object(
    'request_id', req.id,
    'status', 'failed',
    'details', json_build_object('error', 'Region capacity exhausted')
  )::text);

  ASSERT result->>'status' = 'ok', format('Expected ok, got %s', result->>'status');
  ASSERT result->>'new_state' = 'FAILED', format('Expected FAILED, got %s', result->>'new_state');

  SELECT * INTO req FROM capacity_requests WHERE id = req.id;
  ASSERT req.state = 'FAILED', format('Request should be FAILED, got %s', req.state);

  RAISE NOTICE 'PASS: Test 26 - Provisioning webhook happy path failed';
END;
$$;

-- ============================================================
-- Test 27: Provisioning webhook — invalid API key rejected
-- ============================================================
DO $$
DECLARE
  result json;
  req capacity_requests;
BEGIN
  -- Create request in PROVISIONING state
  req := create_capacity_request(
    'U_wh3', 'U_comm_wh3', 'infra-wh3',
    '{"org_id": "org_wh3"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-12-01'::date, 30,
    5000, 7
  );
  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_wh3');
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra_wh3');
  req := apply_capacity_event(req.id, 'CUSTOMER_CONFIRMED', 'user', 'U_customer_wh3');

  -- Set wrong API key
  PERFORM set_config('request.headers', json_build_object(
    'x-provisioning-api-key', 'wrong-secret'
  )::text, true);

  BEGIN
    result := handle_provisioning_webhook(json_build_object(
      'request_id', req.id,
      'status', 'complete'
    )::text);
    ASSERT false, 'Should have raised exception for invalid API key';
  EXCEPTION WHEN OTHERS THEN
    ASSERT SQLERRM LIKE '%Invalid provisioning API key%',
      format('Expected API key error, got: %s', SQLERRM);
  END;

  RAISE NOTICE 'PASS: Test 27 - Invalid API key rejected';
END;
$$;

-- ============================================================
-- Test 28: Provisioning webhook — wrong state rejected
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  result json;
BEGIN
  -- Create request but leave it in UNDER_REVIEW (not PROVISIONING)
  req := create_capacity_request(
    'U_wh4', 'U_comm_wh4', 'infra-wh4',
    '{"org_id": "org_wh4"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-12-01'::date, 30,
    5000, 7
  );
  ASSERT req.state = 'UNDER_REVIEW', 'Setup: should be UNDER_REVIEW';

  PERFORM set_config('request.headers', json_build_object(
    'x-provisioning-api-key', 'test-provisioning-secret'
  )::text, true);

  result := handle_provisioning_webhook(json_build_object(
    'request_id', req.id,
    'status', 'complete'
  )::text);

  ASSERT result->>'status' = 'error',
    format('Expected error status, got %s', result->>'status');
  ASSERT result->>'message' LIKE '%not in PROVISIONING state%',
    format('Expected state error message, got: %s', result->>'message');

  RAISE NOTICE 'PASS: Test 28 - Wrong state rejected';
END;
$$;

-- ============================================================
-- Test 29: Provisioning webhook — unknown status rejected
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  result json;
BEGIN
  -- Create request in PROVISIONING state
  req := create_capacity_request(
    'U_wh5', 'U_comm_wh5', 'infra-wh5',
    '{"org_id": "org_wh5"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-12-01'::date, 30,
    5000, 7
  );
  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_wh5');
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra_wh5');
  req := apply_capacity_event(req.id, 'CUSTOMER_CONFIRMED', 'user', 'U_customer_wh5');

  PERFORM set_config('request.headers', json_build_object(
    'x-provisioning-api-key', 'test-provisioning-secret'
  )::text, true);

  result := handle_provisioning_webhook(json_build_object(
    'request_id', req.id,
    'status', 'in_progress'
  )::text);

  ASSERT result->>'status' = 'error',
    format('Expected error status, got %s', result->>'status');
  ASSERT result->>'message' LIKE '%Unknown status%',
    format('Expected unknown status message, got: %s', result->>'message');

  RAISE NOTICE 'PASS: Test 29 - Unknown status rejected';
END;
$$;

-- ============================================================
-- Test 30: Provisioning webhook — missing request_id
-- ============================================================
DO $$
DECLARE
  result json;
BEGIN
  PERFORM set_config('request.headers', json_build_object(
    'x-provisioning-api-key', 'test-provisioning-secret'
  )::text, true);

  result := handle_provisioning_webhook(json_build_object(
    'status', 'complete'
  )::text);

  ASSERT result->>'status' = 'error',
    format('Expected error status, got %s', result->>'status');
  ASSERT result->>'message' LIKE '%request_id%',
    format('Expected missing request_id message, got: %s', result->>'message');

  RAISE NOTICE 'PASS: Test 30 - Missing request_id';
END;
$$;

-- ============================================================
-- Test 31: Provisioning webhook — nonexistent request_id
-- ============================================================
DO $$
DECLARE
  result json;
BEGIN
  PERFORM set_config('request.headers', json_build_object(
    'x-provisioning-api-key', 'test-provisioning-secret'
  )::text, true);

  result := handle_provisioning_webhook(json_build_object(
    'request_id', 'CR-2026-999999',
    'status', 'complete'
  )::text);

  ASSERT result->>'status' = 'error',
    format('Expected error status, got %s', result->>'status');
  ASSERT result->>'message' LIKE '%not found%',
    format('Expected not found message, got: %s', result->>'message');

  RAISE NOTICE 'PASS: Test 31 - Nonexistent request_id';
END;
$$;

-- ============================================================
-- Test 32: Provisioning webhook — details payload stored in event
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  result json;
  stored_payload jsonb;
BEGIN
  -- Create request in PROVISIONING state
  req := create_capacity_request(
    'U_wh6', 'U_comm_wh6', 'infra-wh6',
    '{"org_id": "org_wh6"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-12-01'::date, 30,
    5000, 7
  );
  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_wh6');
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra_wh6');
  req := apply_capacity_event(req.id, 'CUSTOMER_CONFIRMED', 'user', 'U_customer_wh6');

  PERFORM set_config('request.headers', json_build_object(
    'x-provisioning-api-key', 'test-provisioning-secret'
  )::text, true);

  result := handle_provisioning_webhook(json_build_object(
    'request_id', req.id,
    'status', 'complete',
    'details', json_build_object('instance_id', 'i-xyz789', 'ip', '10.0.2.10', 'flavor', 'metal')
  )::text);

  ASSERT result->>'status' = 'ok', format('Expected ok, got %s', result->>'status');

  -- Verify details are stored in the event payload
  SELECT payload INTO stored_payload
  FROM capacity_request_events
  WHERE capacity_request_id = req.id
    AND event_type = 'PROVISIONING_COMPLETE'
  ORDER BY created_at DESC
  LIMIT 1;

  ASSERT stored_payload IS NOT NULL, 'Event payload should not be NULL';
  ASSERT stored_payload->>'instance_id' = 'i-xyz789',
    format('Expected instance_id i-xyz789, got %s', stored_payload->>'instance_id');
  ASSERT stored_payload->>'ip' = '10.0.2.10',
    format('Expected ip 10.0.2.10, got %s', stored_payload->>'ip');
  ASSERT stored_payload->>'flavor' = 'metal',
    format('Expected flavor metal, got %s', stored_payload->>'flavor');

  RAISE NOTICE 'PASS: Test 32 - Details payload stored in event';
END;
$$;

-- ============================================================
-- Test 33: build_block_kit_message() returns valid Block Kit for UNDER_REVIEW
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  kit jsonb;
BEGIN
  req := create_capacity_request(
    'U_bk1', 'U_comm_bk1', 'infra-bk1',
    '{"org_id": "org_bk1", "name": "BlockKit Corp"}'::jsonb,
    '32XL', 2, 'us-east-1', '2026-03-01'::date, 90,
    10000, 7, 'C_BLOCKKIT'
  );

  -- Build Block Kit for the initial SUBMITTED->UNDER_REVIEW transition
  kit := build_block_kit_message(req, 'SUBMITTED', 'UNDER_REVIEW', 'REQUEST_SUBMITTED', 'U_bk1');

  ASSERT kit IS NOT NULL, 'Block Kit should not be NULL';
  ASSERT kit ? 'blocks', 'Block Kit should have blocks key';
  ASSERT kit ? 'text', 'Block Kit should have text fallback';
  ASSERT kit ? 'channel', 'Block Kit should have channel';
  ASSERT kit->>'channel' = 'C_BLOCKKIT', format('Expected channel C_BLOCKKIT, got %s', kit->>'channel');
  -- No thread_ts when slack_thread_ts is NULL
  ASSERT NOT (kit ? 'thread_ts') OR kit->>'thread_ts' IS NULL,
    'thread_ts should not be set when slack_thread_ts is NULL';

  RAISE NOTICE 'PASS: Test 33 - build_block_kit_message valid Block Kit for UNDER_REVIEW';
END;
$$;

-- ============================================================
-- Test 34: Block Kit includes VP buttons when cost >= threshold
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  kit jsonb;
  actions_block jsonb;
  action_ids text[];
BEGIN
  req := create_capacity_request(
    'U_bk2', 'U_comm_bk2', 'infra-bk2',
    '{"org_id": "org_bk2"}'::jsonb,
    '32XL', 10, 'us-east-1', '2026-03-01'::date, 90,
    100000, 7, 'C_BLOCKKIT2'  -- $100k, above threshold
  );

  kit := build_block_kit_message(req, 'SUBMITTED', 'UNDER_REVIEW', 'REQUEST_SUBMITTED', 'U_bk2');

  -- Find actions block
  SELECT b INTO actions_block
  FROM jsonb_array_elements(kit->'blocks') AS b
  WHERE b->>'type' = 'actions';

  ASSERT actions_block IS NOT NULL, 'Should have an actions block';

  -- Collect action_ids
  SELECT array_agg(e->>'action_id') INTO action_ids
  FROM jsonb_array_elements(actions_block->'elements') AS e;

  ASSERT 'vp_approve' = ANY(action_ids), format('Should have vp_approve button, got %s', action_ids);
  ASSERT 'vp_reject' = ANY(action_ids), format('Should have vp_reject button, got %s', action_ids);

  RAISE NOTICE 'PASS: Test 34 - Block Kit includes VP buttons when cost >= threshold';
END;
$$;

-- ============================================================
-- Test 35: Block Kit excludes VP buttons when cost < threshold
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  kit jsonb;
  actions_block jsonb;
  action_ids text[];
BEGIN
  req := create_capacity_request(
    'U_bk3', 'U_comm_bk3', 'infra-bk3',
    '{"org_id": "org_bk3"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7, 'C_BLOCKKIT3'  -- $5k, below threshold
  );

  kit := build_block_kit_message(req, 'SUBMITTED', 'UNDER_REVIEW', 'REQUEST_SUBMITTED', 'U_bk3');

  SELECT b INTO actions_block
  FROM jsonb_array_elements(kit->'blocks') AS b
  WHERE b->>'type' = 'actions';

  ASSERT actions_block IS NOT NULL, 'Should have an actions block';

  SELECT array_agg(e->>'action_id') INTO action_ids
  FROM jsonb_array_elements(actions_block->'elements') AS e;

  ASSERT NOT ('vp_approve' = ANY(action_ids)),
    format('Should NOT have vp_approve button for low cost, got %s', action_ids);
  ASSERT NOT ('vp_reject' = ANY(action_ids)),
    format('Should NOT have vp_reject button for low cost, got %s', action_ids);

  RAISE NOTICE 'PASS: Test 35 - Block Kit excludes VP buttons when cost < threshold';
END;
$$;

-- ============================================================
-- Test 36: Block Kit includes thread_ts when slack_thread_ts is set
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  kit jsonb;
BEGIN
  req := create_capacity_request(
    'U_bk4', 'U_comm_bk4', 'infra-bk4',
    '{"org_id": "org_bk4"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7, 'C_BLOCKKIT4'
  );

  -- Manually set slack_thread_ts
  UPDATE capacity_requests SET slack_thread_ts = '1234567890.123456' WHERE id = req.id;
  SELECT * INTO req FROM capacity_requests WHERE id = req.id;

  kit := build_block_kit_message(req, 'UNDER_REVIEW', 'UNDER_REVIEW', 'COMMERCIAL_APPROVED', 'U_comm_bk4');

  ASSERT kit->>'thread_ts' = '1234567890.123456',
    format('Expected thread_ts 1234567890.123456, got %s', kit->>'thread_ts');

  RAISE NOTICE 'PASS: Test 36 - Block Kit includes thread_ts when set';
END;
$$;

-- ============================================================
-- Test 37: Block Kit for CUSTOMER_CONFIRMATION_REQUIRED has confirm/decline
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  kit jsonb;
  actions_block jsonb;
  action_ids text[];
BEGIN
  req := create_capacity_request(
    'U_bk5', 'U_comm_bk5', 'infra-bk5',
    '{"org_id": "org_bk5"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7, 'C_BLOCKKIT5'
  );
  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_bk5');
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra_bk5');
  ASSERT req.state = 'CUSTOMER_CONFIRMATION_REQUIRED', 'Setup failed';

  kit := build_block_kit_message(req, 'UNDER_REVIEW', 'CUSTOMER_CONFIRMATION_REQUIRED', 'TECH_REVIEW_APPROVED', 'U_infra_bk5');

  SELECT b INTO actions_block
  FROM jsonb_array_elements(kit->'blocks') AS b
  WHERE b->>'type' = 'actions';

  ASSERT actions_block IS NOT NULL, 'Should have an actions block';

  SELECT array_agg(e->>'action_id') INTO action_ids
  FROM jsonb_array_elements(actions_block->'elements') AS e;

  ASSERT 'customer_confirm' = ANY(action_ids),
    format('Should have customer_confirm button, got %s', action_ids);
  ASSERT 'customer_decline' = ANY(action_ids),
    format('Should have customer_decline button, got %s', action_ids);
  ASSERT 'cancel' = ANY(action_ids),
    format('Should have cancel button, got %s', action_ids);

  RAISE NOTICE 'PASS: Test 37 - Block Kit for CUSTOMER_CONFIRMATION_REQUIRED';
END;
$$;

-- ============================================================
-- Test 38: Block Kit for terminal state (COMPLETED) has no actions
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  kit jsonb;
  actions_block jsonb;
BEGIN
  req := create_capacity_request(
    'U_bk6', 'U_comm_bk6', 'infra-bk6',
    '{"org_id": "org_bk6"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7, 'C_BLOCKKIT6'
  );
  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_bk6');
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra_bk6');
  req := apply_capacity_event(req.id, 'CUSTOMER_CONFIRMED', 'user', 'U_customer_bk6');
  req := apply_capacity_event(req.id, 'PROVISIONING_COMPLETE', 'system', 'provisioner');
  ASSERT req.state = 'COMPLETED', 'Setup failed';

  kit := build_block_kit_message(req, 'PROVISIONING', 'COMPLETED', 'PROVISIONING_COMPLETE');

  SELECT b INTO actions_block
  FROM jsonb_array_elements(kit->'blocks') AS b
  WHERE b->>'type' = 'actions';

  -- Terminal states may have a "View in Web" button if WEB_APP_BASE_URL is set,
  -- but should have no action buttons (approve/reject/cancel)
  IF actions_block IS NOT NULL THEN
    DECLARE
      action_ids text[];
    BEGIN
      SELECT array_agg(e->>'action_id') INTO action_ids
      FROM jsonb_array_elements(actions_block->'elements') AS e;
      -- Only view_web should be present
      ASSERT action_ids = ARRAY['view_web'],
        format('Terminal state should only have view_web button, got %s', action_ids);
    END;
  END IF;

  RAISE NOTICE 'PASS: Test 38 - Block Kit for terminal state has no action buttons';
END;
$$;

-- ============================================================
-- Test 39: VP approve via interactive payload maps to VP_APPROVED
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  result json;
  raw_body text;
  payload_json text;
BEGIN
  -- Create high-cost request in UNDER_REVIEW
  req := create_capacity_request(
    'U_vpa1', 'U_comm_vpa1', 'infra-vpa1',
    '{"org_id": "org_vpa1"}'::jsonb,
    '32XL', 10, 'us-east-1', '2026-03-01'::date, 90,
    100000, 7, 'C_VPA'
  );

  -- Build a fake interactive payload for vp_approve
  payload_json := json_build_object(
    'type', 'block_actions',
    'user', json_build_object('id', 'U_vp_approver'),
    'actions', json_build_array(json_build_object(
      'action_id', 'vp_approve',
      'value', req.id
    ))
  )::text;

  -- Simulate Slack signature verification by inserting a vault secret
  BEGIN
    PERFORM vault.create_secret('test-signing-secret', 'SLACK_SIGNING_SECRET');
  EXCEPTION WHEN unique_violation THEN NULL;
  END;

  -- Build form-encoded body
  raw_body := 'payload=' || replace(replace(replace(payload_json, '{', '%7B'), '}', '%7D'), '"', '%22');

  -- Set headers with valid timestamp
  PERFORM set_config('request.headers', json_build_object(
    'x-slack-signature', 'v0=' || encode(
      hmac(
        'v0:' || extract(epoch FROM now())::bigint::text || ':' || raw_body,
        'test-signing-secret',
        'sha256'
      ), 'hex'),
    'x-slack-request-timestamp', extract(epoch FROM now())::bigint::text
  )::text, true);

  result := handle_slack_webhook(raw_body);

  -- After VP approve, state should reflect VP_APPROVED event applied
  SELECT * INTO req FROM capacity_requests WHERE id = req.id;
  ASSERT req.vp_approved_at IS NOT NULL,
    'vp_approved_at should be set after VP approve action';

  RAISE NOTICE 'PASS: Test 39 - VP approve via interactive payload';
END;
$$;

-- ============================================================
-- Test 40: VP reject via interactive payload maps to VP_REJECTED
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  result json;
  raw_body text;
  payload_json text;
BEGIN
  -- Create high-cost request in UNDER_REVIEW
  req := create_capacity_request(
    'U_vpr1', 'U_comm_vpr1', 'infra-vpr1',
    '{"org_id": "org_vpr1"}'::jsonb,
    '32XL', 10, 'us-east-1', '2026-03-01'::date, 90,
    100000, 7, 'C_VPR'
  );

  payload_json := json_build_object(
    'type', 'block_actions',
    'user', json_build_object('id', 'U_vp_rejector'),
    'actions', json_build_array(json_build_object(
      'action_id', 'vp_reject',
      'value', req.id
    ))
  )::text;

  raw_body := 'payload=' || replace(replace(replace(payload_json, '{', '%7B'), '}', '%7D'), '"', '%22');

  PERFORM set_config('request.headers', json_build_object(
    'x-slack-signature', 'v0=' || encode(
      hmac(
        'v0:' || extract(epoch FROM now())::bigint::text || ':' || raw_body,
        'test-signing-secret',
        'sha256'
      ), 'hex'),
    'x-slack-request-timestamp', extract(epoch FROM now())::bigint::text
  )::text, true);

  result := handle_slack_webhook(raw_body);

  SELECT * INTO req FROM capacity_requests WHERE id = req.id;
  ASSERT req.state = 'REJECTED',
    format('Expected REJECTED after VP reject, got %s', req.state);

  RAISE NOTICE 'PASS: Test 40 - VP reject via interactive payload';
END;
$$;

-- ============================================================
-- Test 41: /capacity list returns user's requests
-- ============================================================
DO $$
DECLARE
  result json;
  raw_body text;
BEGIN
  -- Create some requests for a specific user
  PERFORM create_capacity_request(
    'U_list_user', 'U_comm_list', 'infra-list',
    '{"org_id": "org_list"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7, 'C_LIST'
  );

  raw_body := 'command=%2Fcapacity&text=list&user_id=U_list_user&channel_id=C_LIST';

  PERFORM set_config('request.headers', json_build_object(
    'x-slack-signature', 'v0=' || encode(
      hmac(
        'v0:' || extract(epoch FROM now())::bigint::text || ':' || raw_body,
        'test-signing-secret',
        'sha256'
      ), 'hex'),
    'x-slack-request-timestamp', extract(epoch FROM now())::bigint::text
  )::text, true);

  result := handle_slack_webhook(raw_body);

  ASSERT result->>'response_type' = 'ephemeral',
    format('Expected ephemeral response, got %s', result->>'response_type');
  ASSERT result->>'text' LIKE '%CR-%',
    format('Expected request IDs in list, got: %s', result->>'text');

  RAISE NOTICE 'PASS: Test 41 - /capacity list returns user requests';
END;
$$;

-- ============================================================
-- Test 42: /capacity view <id> returns Block Kit with blocks
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  result json;
  raw_body text;
BEGIN
  req := create_capacity_request(
    'U_view_user', 'U_comm_view', 'infra-view',
    '{"org_id": "org_view"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7, 'C_VIEW'
  );

  raw_body := 'command=%2Fcapacity&text=view+' || req.id || '&user_id=U_view_user&channel_id=C_VIEW';

  PERFORM set_config('request.headers', json_build_object(
    'x-slack-signature', 'v0=' || encode(
      hmac(
        'v0:' || extract(epoch FROM now())::bigint::text || ':' || raw_body,
        'test-signing-secret',
        'sha256'
      ), 'hex'),
    'x-slack-request-timestamp', extract(epoch FROM now())::bigint::text
  )::text, true);

  result := handle_slack_webhook(raw_body);

  ASSERT result->>'response_type' = 'ephemeral',
    format('Expected ephemeral response, got %s', result->>'response_type');
  ASSERT (result::jsonb) ? 'blocks',
    'View response should have blocks key';

  RAISE NOTICE 'PASS: Test 42 - /capacity view returns Block Kit';
END;
$$;

-- ============================================================
-- Test 43: /capacity view with bad ID returns error
-- ============================================================
DO $$
DECLARE
  result json;
  raw_body text;
BEGIN
  raw_body := 'command=%2Fcapacity&text=view+CR-2026-999999&user_id=U_view_user&channel_id=C_VIEW';

  PERFORM set_config('request.headers', json_build_object(
    'x-slack-signature', 'v0=' || encode(
      hmac(
        'v0:' || extract(epoch FROM now())::bigint::text || ':' || raw_body,
        'test-signing-secret',
        'sha256'
      ), 'hex'),
    'x-slack-request-timestamp', extract(epoch FROM now())::bigint::text
  )::text, true);

  result := handle_slack_webhook(raw_body);

  ASSERT result->>'response_type' = 'ephemeral',
    format('Expected ephemeral, got %s', result->>'response_type');
  ASSERT result->>'text' LIKE '%not found%',
    format('Expected not found message, got: %s', result->>'text');

  RAISE NOTICE 'PASS: Test 43 - /capacity view bad ID returns error';
END;
$$;

-- ============================================================
-- Test 44: /capacity help returns help text
-- ============================================================
DO $$
DECLARE
  result json;
  raw_body text;
BEGIN
  raw_body := 'command=%2Fcapacity&text=help&user_id=U_help_user&channel_id=C_HELP';

  PERFORM set_config('request.headers', json_build_object(
    'x-slack-signature', 'v0=' || encode(
      hmac(
        'v0:' || extract(epoch FROM now())::bigint::text || ':' || raw_body,
        'test-signing-secret',
        'sha256'
      ), 'hex'),
    'x-slack-request-timestamp', extract(epoch FROM now())::bigint::text
  )::text, true);

  result := handle_slack_webhook(raw_body);

  ASSERT result->>'response_type' = 'ephemeral',
    format('Expected ephemeral, got %s', result->>'response_type');
  ASSERT result->>'text' LIKE '%help%' OR result->>'text' LIKE '%list%',
    format('Expected help text with commands, got: %s', result->>'text');

  RAISE NOTICE 'PASS: Test 44 - /capacity help returns help text';
END;
$$;

-- ============================================================
-- Test 45: Empty /capacity returns help (changed from usage)
-- ============================================================
DO $$
DECLARE
  result json;
  raw_body text;
BEGIN
  raw_body := 'command=%2Fcapacity&text=&user_id=U_empty_user&channel_id=C_EMPTY';

  PERFORM set_config('request.headers', json_build_object(
    'x-slack-signature', 'v0=' || encode(
      hmac(
        'v0:' || extract(epoch FROM now())::bigint::text || ':' || raw_body,
        'test-signing-secret',
        'sha256'
      ), 'hex'),
    'x-slack-request-timestamp', extract(epoch FROM now())::bigint::text
  )::text, true);

  result := handle_slack_webhook(raw_body);

  ASSERT result->>'response_type' = 'ephemeral',
    format('Expected ephemeral, got %s', result->>'response_type');
  ASSERT result->>'text' LIKE '%help%' OR result->>'text' LIKE '%list%' OR result->>'text' LIKE '%view%',
    format('Expected help text with available commands, got: %s', result->>'text');

  RAISE NOTICE 'PASS: Test 45 - Empty /capacity returns help';
END;
$$;

-- ============================================================
-- Test 46: handle_slack_modal_submission() creates request
-- ============================================================
DO $$
DECLARE
  result json;
  modal_payload text;
  req_count_before integer;
  req_count_after integer;
BEGIN
  SELECT count(*) INTO req_count_before FROM capacity_requests;

  -- Build a view_submission payload matching Slack's format
  modal_payload := json_build_object(
    'type', 'view_submission',
    'user', json_build_object('id', 'U_modal_user'),
    'view', json_build_object(
      'private_metadata', 'C_MODAL_CHANNEL',
      'state', json_build_object(
        'values', json_build_object(
          'size', json_build_object('size_select', json_build_object('type', 'static_select', 'selected_option', json_build_object('value', '32XL'))),
          'region', json_build_object('region_select', json_build_object('type', 'static_select', 'selected_option', json_build_object('value', 'us-east-1'))),
          'quantity', json_build_object('quantity_input', json_build_object('type', 'number_input', 'value', '2')),
          'duration', json_build_object('duration_input', json_build_object('type', 'number_input', 'value', '90')),
          'needed_by', json_build_object('needed_by_picker', json_build_object('type', 'datepicker', 'selected_date', '2026-06-01')),
          'cost', json_build_object('cost_input', json_build_object('type', 'number_input', 'value', '15000')),
          'customer', json_build_object('customer_input', json_build_object('type', 'plain_text_input', 'value', 'Modal Corp')),
          'commercial_owner', json_build_object('commercial_owner_select', json_build_object('type', 'users_select', 'selected_user', 'U_comm_modal')),
          'infra_group', json_build_object('infra_group_input', json_build_object('type', 'plain_text_input', 'value', 'infra-modal'))
        )
      )
    )
  )::text;

  result := handle_slack_modal_submission(modal_payload);

  -- NULL result means success (modal closes)
  ASSERT result IS NULL, format('Expected NULL (close modal), got %s', result::text);

  SELECT count(*) INTO req_count_after FROM capacity_requests;
  ASSERT req_count_after = req_count_before + 1,
    format('Expected one new request, before=%s after=%s', req_count_before, req_count_after);

  RAISE NOTICE 'PASS: Test 46 - Modal submission creates request';
END;
$$;

-- ============================================================
-- Test 47: Modal submission with missing required fields returns error
-- ============================================================
DO $$
DECLARE
  result json;
  modal_payload text;
BEGIN
  -- Missing size and region
  modal_payload := json_build_object(
    'type', 'view_submission',
    'user', json_build_object('id', 'U_modal_bad'),
    'view', json_build_object(
      'private_metadata', 'C_MODAL_BAD',
      'state', json_build_object(
        'values', json_build_object(
          'quantity', json_build_object('quantity_input', json_build_object('type', 'number_input', 'value', '2')),
          'duration', json_build_object('duration_input', json_build_object('type', 'number_input', 'value', '90')),
          'needed_by', json_build_object('needed_by_picker', json_build_object('type', 'datepicker', 'selected_date', '2026-06-01'))
        )
      )
    )
  )::text;

  result := handle_slack_modal_submission(modal_payload);

  -- Should return an errors object for Slack to display
  ASSERT result IS NOT NULL,
    'Expected error response for missing fields';
  ASSERT (result::jsonb) ? 'response_action',
    format('Expected response_action in error, got: %s', result::text);

  RAISE NOTICE 'PASS: Test 47 - Modal submission missing fields returns error';
END;
$$;

-- ============================================================
-- Test 48: Interactive button response includes replace_original and blocks
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  result json;
  raw_body text;
  payload_json text;
BEGIN
  req := create_capacity_request(
    'U_btn1', 'U_comm_btn1', 'infra-btn1',
    '{"org_id": "org_btn1"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7, 'C_BTN'
  );

  payload_json := json_build_object(
    'type', 'block_actions',
    'user', json_build_object('id', 'U_comm_btn1'),
    'actions', json_build_array(json_build_object(
      'action_id', 'commercial_approve',
      'value', req.id
    ))
  )::text;

  raw_body := 'payload=' || replace(replace(replace(payload_json, '{', '%7B'), '}', '%7D'), '"', '%22');

  PERFORM set_config('request.headers', json_build_object(
    'x-slack-signature', 'v0=' || encode(
      hmac(
        'v0:' || extract(epoch FROM now())::bigint::text || ':' || raw_body,
        'test-signing-secret',
        'sha256'
      ), 'hex'),
    'x-slack-request-timestamp', extract(epoch FROM now())::bigint::text
  )::text, true);

  result := handle_slack_webhook(raw_body);

  ASSERT (result::jsonb)->>'replace_original' = 'true',
    format('Expected replace_original=true, got: %s', result::text);
  ASSERT (result::jsonb) ? 'blocks',
    format('Expected blocks in response, got: %s', result::text);

  RAISE NOTICE 'PASS: Test 48 - Interactive button response has replace_original and blocks';
END;
$$;

-- ============================================================
-- Test 49: After commercial approval, commercial buttons hidden, tech buttons remain
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  kit jsonb;
  actions_block jsonb;
  action_ids text[];
BEGIN
  req := create_capacity_request(
    'U_ctx1', 'U_comm_ctx1', 'infra-ctx1',
    '{"org_id": "org_ctx1"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7, 'C_CTX1'
  );

  -- Apply commercial approval (state stays UNDER_REVIEW, waiting on tech)
  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_ctx1');
  ASSERT req.state = 'UNDER_REVIEW', 'State should still be UNDER_REVIEW';
  ASSERT req.commercial_approved_at IS NOT NULL, 'commercial_approved_at should be set';

  kit := build_block_kit_message(req, 'UNDER_REVIEW', 'UNDER_REVIEW', 'COMMERCIAL_APPROVED', 'U_comm_ctx1');

  SELECT b INTO actions_block
  FROM jsonb_array_elements(kit->'blocks') AS b
  WHERE b->>'type' = 'actions';

  ASSERT actions_block IS NOT NULL, 'Should have an actions block';

  SELECT array_agg(e->>'action_id') INTO action_ids
  FROM jsonb_array_elements(actions_block->'elements') AS e;

  -- Commercial buttons should be gone
  ASSERT NOT ('commercial_approve' = ANY(action_ids)),
    format('commercial_approve should be hidden after approval, got %s', action_ids);
  ASSERT NOT ('commercial_reject' = ANY(action_ids)),
    format('commercial_reject should be hidden after approval, got %s', action_ids);

  -- Tech buttons should still be present
  ASSERT 'tech_approve' = ANY(action_ids),
    format('tech_approve should still be present, got %s', action_ids);
  ASSERT 'tech_reject' = ANY(action_ids),
    format('tech_reject should still be present, got %s', action_ids);

  -- Cancel should still be present
  ASSERT 'cancel' = ANY(action_ids),
    format('cancel should still be present, got %s', action_ids);

  RAISE NOTICE 'PASS: Test 49 - After commercial approval, commercial buttons hidden, tech buttons remain';
END;
$$;

-- ============================================================
-- Test 50: build_workflow_mrkdwn returns pipeline for UNDER_REVIEW
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  mrkdwn text;
BEGIN
  req := create_capacity_request(
    'U_wf1', 'U_comm_wf1', 'infra-wf1',
    '{"org_id": "org_wf1", "name": "Workflow Corp"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7, 'C_WF1'
  );

  mrkdwn := build_workflow_mrkdwn(req, 'UNDER_REVIEW');

  ASSERT mrkdwn IS NOT NULL, 'Workflow mrkdwn should not be NULL';
  ASSERT mrkdwn LIKE '%Submitted%', format('Should contain Submitted, got: %s', mrkdwn);
  ASSERT mrkdwn LIKE '%Under Review%', format('Should contain Under Review, got: %s', mrkdwn);
  ASSERT mrkdwn LIKE '%Confirming%', format('Should contain Confirming, got: %s', mrkdwn);
  ASSERT mrkdwn LIKE '%Provisioning%', format('Should contain Provisioning, got: %s', mrkdwn);
  ASSERT mrkdwn LIKE '%Completed%', format('Should contain Completed, got: %s', mrkdwn);
  -- Should have approval sub-bullets
  ASSERT mrkdwn LIKE '%Commercial Pending%', format('Should show Commercial Pending, got: %s', mrkdwn);
  ASSERT mrkdwn LIKE '%Technical Pending%', format('Should show Technical Pending, got: %s', mrkdwn);

  RAISE NOTICE 'PASS: Test 50 - build_workflow_mrkdwn for UNDER_REVIEW';
END;
$$;

-- ============================================================
-- Test 51: build_workflow_mrkdwn shows approval progress
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  mrkdwn text;
BEGIN
  req := create_capacity_request(
    'U_wf2', 'U_comm_wf2', 'infra-wf2',
    '{"org_id": "org_wf2"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7, 'C_WF2'
  );

  -- Approve commercial
  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_wf2');

  mrkdwn := build_workflow_mrkdwn(req, 'UNDER_REVIEW');

  ASSERT mrkdwn LIKE '%Commercial Approved%', format('Should show Commercial Approved, got: %s', mrkdwn);
  ASSERT mrkdwn LIKE '%Technical Pending%', format('Should show Technical Pending, got: %s', mrkdwn);

  RAISE NOTICE 'PASS: Test 51 - build_workflow_mrkdwn shows approval progress';
END;
$$;

-- ============================================================
-- Test 52: build_workflow_mrkdwn for terminal state (COMPLETED)
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  mrkdwn text;
BEGIN
  req := create_capacity_request(
    'U_wf3', 'U_comm_wf3', 'infra-wf3',
    '{"org_id": "org_wf3"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7, 'C_WF3'
  );
  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_wf3');
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra_wf3');
  req := apply_capacity_event(req.id, 'CUSTOMER_CONFIRMED', 'user', 'U_customer_wf3');
  req := apply_capacity_event(req.id, 'PROVISIONING_COMPLETE', 'system', 'provisioner');
  ASSERT req.state = 'COMPLETED', 'Setup failed';

  mrkdwn := build_workflow_mrkdwn(req, 'COMPLETED');

  ASSERT mrkdwn IS NOT NULL, 'Should not be NULL for COMPLETED';
  ASSERT mrkdwn LIKE '%Completed%', format('Should contain Completed, got: %s', mrkdwn);

  RAISE NOTICE 'PASS: Test 52 - build_workflow_mrkdwn for COMPLETED';
END;
$$;

-- ============================================================
-- Test 53: build_workflow_mrkdwn for REJECTED shows terminal indicator
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  mrkdwn text;
BEGIN
  req := create_capacity_request(
    'U_wf4', 'U_comm_wf4', 'infra-wf4',
    '{"org_id": "org_wf4"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7, 'C_WF4'
  );
  req := apply_capacity_event(req.id, 'COMMERCIAL_REJECTED', 'user', 'U_comm_wf4');
  ASSERT req.state = 'REJECTED', 'Setup failed';

  mrkdwn := build_workflow_mrkdwn(req, 'REJECTED');

  ASSERT mrkdwn LIKE '%REJECTED%', format('Should contain REJECTED, got: %s', mrkdwn);

  RAISE NOTICE 'PASS: Test 53 - build_workflow_mrkdwn for REJECTED';
END;
$$;

-- ============================================================
-- Test 54: build_workflow_mrkdwn includes VP sub-bullet for high-cost
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  mrkdwn text;
BEGIN
  req := create_capacity_request(
    'U_wf5', 'U_comm_wf5', 'infra-wf5',
    '{"org_id": "org_wf5"}'::jsonb,
    '32XL', 10, 'us-east-1', '2026-03-01'::date, 90,
    100000, 7, 'C_WF5'
  );

  mrkdwn := build_workflow_mrkdwn(req, 'UNDER_REVIEW');

  ASSERT mrkdwn LIKE '%VP Pending%', format('High-cost request should show VP Pending, got: %s', mrkdwn);

  RAISE NOTICE 'PASS: Test 54 - build_workflow_mrkdwn includes VP for high-cost';
END;
$$;

-- ============================================================
-- Test 55: get_operator_guidance returns correct text per state
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  guidance text;
BEGIN
  req := create_capacity_request(
    'U_og1', 'U_comm_og1', 'infra-og1',
    '{"org_id": "org_og1"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7, 'C_OG1'
  );

  -- UNDER_REVIEW with no approvals
  guidance := get_operator_guidance(req, 'UNDER_REVIEW');
  ASSERT guidance LIKE '%commercial and technical%',
    format('UNDER_REVIEW no-approvals guidance wrong: %s', guidance);

  -- Commercial approved
  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_og1');
  guidance := get_operator_guidance(req, 'UNDER_REVIEW');
  ASSERT guidance LIKE '%Commercial review complete%',
    format('UNDER_REVIEW commercial-done guidance wrong: %s', guidance);

  -- Both approved -> CUSTOMER_CONFIRMATION_REQUIRED
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra_og1');
  guidance := get_operator_guidance(req, 'CUSTOMER_CONFIRMATION_REQUIRED');
  ASSERT guidance LIKE '%Customer must confirm%',
    format('CUSTOMER_CONFIRMATION guidance wrong: %s', guidance);

  -- Customer confirms -> PROVISIONING
  req := apply_capacity_event(req.id, 'CUSTOMER_CONFIRMED', 'user', 'U_customer_og1');
  guidance := get_operator_guidance(req, 'PROVISIONING');
  ASSERT guidance LIKE '%Admin Studio%',
    format('PROVISIONING guidance should mention Admin Studio: %s', guidance);

  -- Complete
  req := apply_capacity_event(req.id, 'PROVISIONING_COMPLETE', 'system', 'provisioner');
  guidance := get_operator_guidance(req, 'COMPLETED');
  ASSERT guidance LIKE '%fulfilled%',
    format('COMPLETED guidance wrong: %s', guidance);

  RAISE NOTICE 'PASS: Test 55 - get_operator_guidance returns correct text per state';
END;
$$;

-- ============================================================
-- Test 56: get_operator_guidance for VP-pending high-cost request
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  guidance text;
BEGIN
  req := create_capacity_request(
    'U_og2', 'U_comm_og2', 'infra-og2',
    '{"org_id": "org_og2"}'::jsonb,
    '32XL', 10, 'us-east-1', '2026-03-01'::date, 90,
    100000, 7, 'C_OG2'
  );

  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_og2');
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra_og2');
  ASSERT req.state = 'UNDER_REVIEW', 'High-cost should stay UNDER_REVIEW without VP';

  guidance := get_operator_guidance(req, 'UNDER_REVIEW');
  ASSERT guidance LIKE '%VP approval%',
    format('Should mention VP approval for high-cost: %s', guidance);

  RAISE NOTICE 'PASS: Test 56 - get_operator_guidance for VP-pending high-cost';
END;
$$;

-- ============================================================
-- Test 57: get_operator_guidance for terminal states
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  guidance text;
BEGIN
  -- REJECTED
  req := create_capacity_request(
    'U_og3', 'U_comm_og3', 'infra-og3',
    '{"org_id": "org_og3"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7
  );
  req := apply_capacity_event(req.id, 'COMMERCIAL_REJECTED', 'user', 'U_comm_og3');
  guidance := get_operator_guidance(req, 'REJECTED');
  ASSERT guidance LIKE '%rejected%', format('REJECTED guidance wrong: %s', guidance);

  -- EXPIRED
  req := create_capacity_request(
    'U_og4', 'U_comm_og4', 'infra-og4',
    '{"org_id": "org_og4"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7
  );
  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_og4');
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra_og4');
  req := apply_capacity_event(req.id, 'CUSTOMER_CONFIRMATION_TIMEOUT', 'cron', 'pg_cron_timer');
  guidance := get_operator_guidance(req, 'EXPIRED');
  ASSERT guidance LIKE '%expired%', format('EXPIRED guidance wrong: %s', guidance);

  -- FAILED
  req := create_capacity_request(
    'U_og5', 'U_comm_og5', 'infra-og5',
    '{"org_id": "org_og5"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7
  );
  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_og5');
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra_og5');
  req := apply_capacity_event(req.id, 'CUSTOMER_CONFIRMED', 'user', 'U_customer_og5');
  req := apply_capacity_event(req.id, 'PROVISIONING_FAILED', 'system', 'provisioner');
  guidance := get_operator_guidance(req, 'FAILED');
  ASSERT guidance LIKE '%failed%', format('FAILED guidance wrong: %s', guidance);

  RAISE NOTICE 'PASS: Test 57 - get_operator_guidance for terminal states';
END;
$$;

-- ============================================================
-- Test 58: Block Kit message includes workflow pipeline section
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  kit jsonb;
  has_pipeline boolean := false;
  b jsonb;
BEGIN
  req := create_capacity_request(
    'U_bkw1', 'U_comm_bkw1', 'infra-bkw1',
    '{"org_id": "org_bkw1"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7, 'C_BKW1'
  );

  kit := build_block_kit_message(req, 'SUBMITTED', 'UNDER_REVIEW', 'REQUEST_SUBMITTED', 'U_bkw1');
  ASSERT kit IS NOT NULL, 'Block Kit should not be NULL';

  -- Check that blocks contain the workflow pipeline text
  FOR b IN SELECT * FROM jsonb_array_elements(kit->'blocks')
  LOOP
    IF b->>'type' = 'section' AND b->'text'->>'text' LIKE '%Submitted%Under Review%' THEN
      has_pipeline := true;
    END IF;
  END LOOP;

  ASSERT has_pipeline, 'Block Kit should contain workflow pipeline section';

  RAISE NOTICE 'PASS: Test 58 - Block Kit includes workflow pipeline section';
END;
$$;

-- ============================================================
-- Test 59: Block Kit message includes guidance context block
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  kit jsonb;
  has_guidance boolean := false;
  b jsonb;
BEGIN
  req := create_capacity_request(
    'U_bkw2', 'U_comm_bkw2', 'infra-bkw2',
    '{"org_id": "org_bkw2"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7, 'C_BKW2'
  );

  kit := build_block_kit_message(req, 'SUBMITTED', 'UNDER_REVIEW', 'REQUEST_SUBMITTED', 'U_bkw2');

  FOR b IN SELECT * FROM jsonb_array_elements(kit->'blocks')
  LOOP
    IF b->>'type' = 'context' THEN
      -- Check if any element contains guidance text
      IF EXISTS (
        SELECT 1 FROM jsonb_array_elements(b->'elements') e
        WHERE e->>'text' LIKE '%commercial and technical%'
      ) THEN
        has_guidance := true;
      END IF;
    END IF;
  END LOOP;

  ASSERT has_guidance, 'Block Kit should contain operator guidance context block';

  RAISE NOTICE 'PASS: Test 59 - Block Kit includes guidance context block';
END;
$$;

-- ============================================================
-- Test 60: Duplicate idempotency key returns existing state, no new event
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  req2 capacity_requests;
  event_count_before integer;
  event_count_after integer;
BEGIN
  req := create_capacity_request(
    'U_idem1', 'U_comm_idem1', 'infra-idem1',
    '{"org_id": "org_idem1"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7
  );

  -- First call with idempotency key
  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_idem1', '{}'::jsonb, 'idem-key-1');

  SELECT count(*) INTO event_count_before FROM capacity_request_events WHERE capacity_request_id = req.id;

  -- Second call with same idempotency key — should be a no-op
  req2 := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_idem1', '{}'::jsonb, 'idem-key-1');

  SELECT count(*) INTO event_count_after FROM capacity_request_events WHERE capacity_request_id = req.id;

  ASSERT event_count_after = event_count_before,
    format('Expected no new event, before=%s after=%s', event_count_before, event_count_after);
  ASSERT req2.version = req.version,
    format('Expected same version, got %s vs %s', req2.version, req.version);

  RAISE NOTICE 'PASS: Test 60 - Duplicate idempotency key returns existing state, no new event';
END;
$$;

-- ============================================================
-- Test 61: Different idempotency keys create separate events
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  event_count integer;
BEGIN
  req := create_capacity_request(
    'U_idem2', 'U_comm_idem2', 'infra-idem2',
    '{"org_id": "org_idem2"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7
  );

  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_idem2', '{}'::jsonb, 'idem-key-2a');
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra_idem2', '{}'::jsonb, 'idem-key-2b');

  SELECT count(*) INTO event_count FROM capacity_request_events WHERE capacity_request_id = req.id;

  -- REQUEST_SUBMITTED (from create) + COMMERCIAL_APPROVED + TECH_REVIEW_APPROVED = 3
  ASSERT event_count = 3,
    format('Expected 3 events, got %s', event_count);
  ASSERT req.state = 'CUSTOMER_CONFIRMATION_REQUIRED',
    format('Expected CUSTOMER_CONFIRMATION_REQUIRED, got %s', req.state);

  RAISE NOTICE 'PASS: Test 61 - Different idempotency keys create separate events';
END;
$$;

-- ============================================================
-- Test 62: Notes stored on event and visible in v_request_events
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  event_notes text;
BEGIN
  req := create_capacity_request(
    'U_notes1', 'U_comm_notes1', 'infra-notes1',
    '{"org_id": "org_notes1"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7
  );

  req := apply_capacity_event(
    req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_notes1',
    '{}'::jsonb, NULL, 'Budget confirmed with finance'
  );

  SELECT notes INTO event_notes
    FROM v_request_events
    WHERE capacity_request_id = req.id
      AND event_type = 'COMMERCIAL_APPROVED';

  ASSERT event_notes = 'Budget confirmed with finance',
    format('Expected notes text, got: %s', event_notes);

  RAISE NOTICE 'PASS: Test 62 - Notes stored on event and visible in v_request_events';
END;
$$;

-- ============================================================
-- Test 63: Backward compat — callers with 4-5 args still work
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  evt_key text;
  evt_notes text;
BEGIN
  req := create_capacity_request(
    'U_bc1', 'U_comm_bc1', 'infra-bc1',
    '{"org_id": "org_bc1"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7
  );

  -- 4-arg call (payload defaults to '{}')
  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_bc1');

  -- 5-arg call (explicit payload, idempotency_key and notes default to NULL)
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra_bc1', '{"source": "test"}'::jsonb);

  -- Verify new columns are NULL
  SELECT idempotency_key, notes INTO evt_key, evt_notes
    FROM capacity_request_events
    WHERE capacity_request_id = req.id
      AND event_type = 'COMMERCIAL_APPROVED';

  ASSERT evt_key IS NULL, format('Expected NULL idempotency_key, got: %s', evt_key);
  ASSERT evt_notes IS NULL, format('Expected NULL notes, got: %s', evt_notes);

  -- Verify state advanced correctly
  ASSERT req.state = 'CUSTOMER_CONFIRMATION_REQUIRED',
    format('Expected CUSTOMER_CONFIRMATION_REQUIRED, got %s', req.state);

  RAISE NOTICE 'PASS: Test 63 - Backward compat with 4-5 arg calls';
END;
$$;

-- ============================================================
-- Test 64: Multiple NULL idempotency keys don't conflict
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  event_count integer;
BEGIN
  req := create_capacity_request(
    'U_null1', 'U_comm_null1', 'infra-null1',
    '{"org_id": "org_null1"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7
  );

  -- Full workflow with no idempotency keys (all NULL)
  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_null1');
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra_null1');
  req := apply_capacity_event(req.id, 'CUSTOMER_CONFIRMED', 'user', 'U_cust_null1');
  req := apply_capacity_event(req.id, 'PROVISIONING_COMPLETE', 'system', 'provisioner');

  SELECT count(*) INTO event_count FROM capacity_request_events WHERE capacity_request_id = req.id;

  -- REQUEST_SUBMITTED + 4 events = 5
  ASSERT event_count = 5,
    format('Expected 5 events with NULL keys, got %s', event_count);
  ASSERT req.state = 'COMPLETED',
    format('Expected COMPLETED, got %s', req.state);

  RAISE NOTICE 'PASS: Test 64 - Multiple NULL idempotency keys coexist without conflict';
END;
$$;

-- ============================================================
-- Setup for confirmation token tests: insert Vault secret
-- ============================================================
DO $$
BEGIN
  BEGIN
    PERFORM vault.create_secret('test-confirmation-token-secret', 'CONFIRMATION_TOKEN_SECRET');
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
  RAISE NOTICE 'Setup: Confirmation token Vault secret inserted';
END;
$$;

-- ============================================================
-- Test 65: generate_confirmation_token returns 64-char hex string
-- ============================================================
DO $$
DECLARE
  token text;
BEGIN
  token := generate_confirmation_token('CR-2026-000001', now() + interval '7 days');

  ASSERT token IS NOT NULL, 'Token should not be NULL';
  ASSERT length(token) = 64, format('Expected 64-char hex string, got length %s', length(token));
  ASSERT token ~ '^[0-9a-f]{64}$', format('Token should be lowercase hex, got %s', token);

  RAISE NOTICE 'PASS: Test 65 - generate_confirmation_token returns 64-char hex string';
END;
$$;

-- ============================================================
-- Test 66: get_confirmation_request with valid token returns request data
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  token text;
  expires_epoch bigint;
  result jsonb;
BEGIN
  req := create_capacity_request(
    'U_token1', 'U_comm_token1', 'infra-token1',
    '{"org_id": "org_token1"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7
  );

  expires_epoch := extract(epoch FROM now() + interval '7 days')::bigint;
  token := generate_confirmation_token(req.id, to_timestamp(expires_epoch));

  result := get_confirmation_request(req.id, token, expires_epoch);

  ASSERT result IS NOT NULL, 'Result should not be NULL';
  ASSERT result->>'id' = req.id, format('Expected id %s, got %s', req.id, result->>'id');
  ASSERT result->>'state' IS NOT NULL, 'Result should have state';
  ASSERT result->>'requested_size' = '32XL', format('Expected 32XL, got %s', result->>'requested_size');
  ASSERT result->>'region' = 'us-east-1', format('Expected us-east-1, got %s', result->>'region');

  RAISE NOTICE 'PASS: Test 66 - get_confirmation_request with valid token returns request data';
END;
$$;

-- ============================================================
-- Test 67: get_confirmation_request with expired token raises exception
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  token text;
  past_epoch bigint;
BEGIN
  req := create_capacity_request(
    'U_token2', 'U_comm_token2', 'infra-token2',
    '{"org_id": "org_token2"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30
  );

  past_epoch := extract(epoch FROM now() - interval '1 hour')::bigint;
  token := generate_confirmation_token(req.id, to_timestamp(past_epoch));

  BEGIN
    PERFORM get_confirmation_request(req.id, token, past_epoch);
    ASSERT false, 'Should have raised exception for expired token';
  EXCEPTION WHEN OTHERS THEN
    ASSERT SQLERRM LIKE '%expired%', format('Expected expired error, got: %s', SQLERRM);
  END;

  RAISE NOTICE 'PASS: Test 67 - get_confirmation_request with expired token raises exception';
END;
$$;

-- ============================================================
-- Test 68: get_confirmation_request with tampered token raises exception
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  expires_epoch bigint;
BEGIN
  req := create_capacity_request(
    'U_token3', 'U_comm_token3', 'infra-token3',
    '{"org_id": "org_token3"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30
  );

  expires_epoch := extract(epoch FROM now() + interval '7 days')::bigint;

  BEGIN
    PERFORM get_confirmation_request(req.id, 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef', expires_epoch);
    ASSERT false, 'Should have raised exception for tampered token';
  EXCEPTION WHEN OTHERS THEN
    ASSERT SQLERRM LIKE '%Invalid confirmation token%', format('Expected invalid token error, got: %s', SQLERRM);
  END;

  RAISE NOTICE 'PASS: Test 68 - get_confirmation_request with tampered token raises exception';
END;
$$;

-- ============================================================
-- Test 69: get_confirmation_request with nonexistent request_id raises exception
-- ============================================================
DO $$
DECLARE
  expires_epoch bigint;
  token text;
BEGIN
  expires_epoch := extract(epoch FROM now() + interval '7 days')::bigint;
  token := generate_confirmation_token('CR-2026-999999', to_timestamp(expires_epoch));

  BEGIN
    PERFORM get_confirmation_request('CR-2026-999999', token, expires_epoch);
    ASSERT false, 'Should have raised exception for nonexistent request';
  EXCEPTION WHEN OTHERS THEN
    ASSERT SQLERRM LIKE '%not found%', format('Expected not found error, got: %s', SQLERRM);
  END;

  RAISE NOTICE 'PASS: Test 69 - get_confirmation_request with nonexistent request_id raises exception';
END;
$$;

-- ============================================================
-- Test 70: v_request_summary still returns rows (regression)
-- ============================================================
DO $$
DECLARE
  row_count integer;
BEGIN
  SELECT count(*) INTO row_count FROM v_request_summary;
  ASSERT row_count > 0, format('v_request_summary should have rows, got %s', row_count);

  RAISE NOTICE 'PASS: Test 70 - v_request_summary still returns rows (regression)';
END;
$$;

-- ============================================================
-- Test 71: v_request_events still returns rows with notes column (regression)
-- ============================================================
DO $$
DECLARE
  row_count integer;
  has_notes boolean;
BEGIN
  SELECT count(*) INTO row_count FROM v_request_events;
  ASSERT row_count > 0, format('v_request_events should have rows, got %s', row_count);

  -- Verify notes column exists by selecting it
  SELECT EXISTS(
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'v_request_events' AND column_name = 'notes'
  ) INTO has_notes;
  ASSERT has_notes, 'v_request_events should have notes column';

  RAISE NOTICE 'PASS: Test 71 - v_request_events still returns rows with notes column (regression)';
END;
$$;

-- ============================================================
-- Test 72: All 5 observability views still return rows (regression)
-- ============================================================
DO $$
DECLARE
  row_count integer;
BEGIN
  SELECT count(*) INTO row_count FROM v_time_in_state;
  ASSERT row_count > 0, format('v_time_in_state should have rows, got %s', row_count);

  SELECT count(*) INTO row_count FROM v_approval_latency;
  ASSERT row_count > 0, format('v_approval_latency should have rows, got %s', row_count);

  SELECT count(*) INTO row_count FROM v_provisioning_duration;
  ASSERT row_count > 0, format('v_provisioning_duration should have rows, got %s', row_count);

  SELECT count(*) INTO row_count FROM v_terminal_state_counts;
  ASSERT row_count > 0, format('v_terminal_state_counts should have rows, got %s', row_count);

  SELECT count(*) INTO row_count FROM v_request_detail;
  ASSERT row_count > 0, format('v_request_detail should have rows, got %s', row_count);

  RAISE NOTICE 'PASS: Test 72 - All observability views still return rows (regression)';
END;
$$;

-- ============================================================
-- Test 73: compute_next_state CONFIRMATION_REMINDER_SENT returns same state
-- ============================================================
DO $$
DECLARE
  s capacity_request_state;
BEGIN
  s := compute_next_state('CUSTOMER_CONFIRMATION_REQUIRED', 'CONFIRMATION_REMINDER_SENT', true, true);
  ASSERT s = 'CUSTOMER_CONFIRMATION_REQUIRED',
    format('Expected CUSTOMER_CONFIRMATION_REQUIRED, got %s', s);

  RAISE NOTICE 'PASS: Test 73 - compute_next_state CONFIRMATION_REMINDER_SENT returns same state';
END;
$$;

-- ============================================================
-- Test 74: CONFIRMATION_REMINDER_SENT in wrong state raises exception
-- ============================================================
DO $$
BEGIN
  BEGIN
    PERFORM compute_next_state('UNDER_REVIEW', 'CONFIRMATION_REMINDER_SENT', true, true);
    ASSERT false, 'Should have raised exception for reminder in wrong state';
  EXCEPTION WHEN OTHERS THEN
    ASSERT SQLERRM LIKE '%CONFIRMATION_REMINDER_SENT only valid%',
      format('Expected validation error, got: %s', SQLERRM);
  END;

  BEGIN
    PERFORM compute_next_state('PROVISIONING', 'CONFIRMATION_REMINDER_SENT', true, true);
    ASSERT false, 'Should have raised exception for reminder in PROVISIONING';
  EXCEPTION WHEN OTHERS THEN
    NULL; -- expected
  END;

  RAISE NOTICE 'PASS: Test 74 - CONFIRMATION_REMINDER_SENT in wrong state raises exception';
END;
$$;

-- ============================================================
-- Test 75: apply_capacity_event with CONFIRMATION_REMINDER_SENT
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  event_count integer;
  old_version integer;
BEGIN
  req := create_capacity_request(
    'U_remind1', 'U_comm_remind1', 'infra-remind1',
    '{"org_id": "org_remind1"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7
  );

  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_remind1');
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra_remind1');
  ASSERT req.state = 'CUSTOMER_CONFIRMATION_REQUIRED', 'Setup failed';

  old_version := req.version;

  req := apply_capacity_event(req.id, 'CONFIRMATION_REMINDER_SENT', 'cron', 'pg_cron_timer');
  ASSERT req.state = 'CUSTOMER_CONFIRMATION_REQUIRED',
    format('State should be unchanged, got %s', req.state);
  ASSERT req.version = old_version + 1,
    format('Version should increment, expected %s got %s', old_version + 1, req.version);

  SELECT count(*) INTO event_count
  FROM capacity_request_events
  WHERE capacity_request_id = req.id
    AND event_type = 'CONFIRMATION_REMINDER_SENT';
  ASSERT event_count = 1, format('Expected 1 reminder event, got %s', event_count);

  RAISE NOTICE 'PASS: Test 75 - apply_capacity_event with CONFIRMATION_REMINDER_SENT';
END;
$$;

-- ============================================================
-- Test 76: Timer sweep sends reminder when >50% deadline elapsed
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  reminder_count integer;
BEGIN
  req := create_capacity_request(
    'U_timer1', 'U_comm_timer1', 'infra-timer1',
    '{"org_id": "org_timer1"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7, 'C_TIMER1'
  );

  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_timer1');
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra_timer1');
  ASSERT req.state = 'CUSTOMER_CONFIRMATION_REQUIRED', 'Setup failed';

  -- Manipulate updated_at and next_deadline_at to simulate >50% elapsed
  -- Set updated_at to 5 days ago and deadline to 2 days from now (7-day window)
  -- Midpoint = updated_at + 3.5 days = now() - 1.5 days, so now() is past midpoint
  UPDATE capacity_requests
  SET updated_at = now() - interval '5 days',
      next_deadline_at = now() + interval '2 days'
  WHERE id = req.id;

  -- Run timer sweep
  PERFORM run_capacity_request_timers();

  SELECT count(*) INTO reminder_count
  FROM capacity_request_events
  WHERE capacity_request_id = req.id
    AND event_type = 'CONFIRMATION_REMINDER_SENT';
  ASSERT reminder_count = 1,
    format('Expected 1 reminder after timer sweep, got %s', reminder_count);

  RAISE NOTICE 'PASS: Test 76 - Timer sweep sends reminder when >50%% deadline elapsed';
END;
$$;

-- ============================================================
-- Test 77: Timer sweep does NOT send duplicate reminder
-- ============================================================
DO $$
DECLARE
  reminder_count integer;
  req_id text;
BEGIN
  -- Use the request from Test 76 (it already has a reminder)
  SELECT cr.id INTO req_id
  FROM capacity_requests cr
  WHERE cr.requester_user_id = 'U_timer1'
    AND cr.state = 'CUSTOMER_CONFIRMATION_REQUIRED'
  LIMIT 1;

  ASSERT req_id IS NOT NULL, 'Setup: should find timer1 request';

  -- Run timer sweep again
  PERFORM run_capacity_request_timers();

  SELECT count(*) INTO reminder_count
  FROM capacity_request_events
  WHERE capacity_request_id = req_id
    AND event_type = 'CONFIRMATION_REMINDER_SENT';
  ASSERT reminder_count = 1,
    format('Expected still 1 reminder (no duplicate), got %s', reminder_count);

  RAISE NOTICE 'PASS: Test 77 - Timer sweep does NOT send duplicate reminder';
END;
$$;

-- ============================================================
-- Test 78: Reminder creates outbox entry with 'Reminder' text
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  outbox_row record;
BEGIN
  req := create_capacity_request(
    'U_remind2', 'U_comm_remind2', 'infra-remind2',
    '{"org_id": "org_remind2"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7, 'C_REMIND2'
  );

  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_remind2');
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra_remind2');
  ASSERT req.state = 'CUSTOMER_CONFIRMATION_REQUIRED', 'Setup failed';

  -- Apply reminder directly
  req := apply_capacity_event(req.id, 'CONFIRMATION_REMINDER_SENT', 'cron', 'pg_cron_timer');

  -- Check outbox for reminder text
  SELECT * INTO outbox_row
  FROM capacity_request_outbox
  WHERE capacity_request_id = req.id
    AND payload->>'text' LIKE '%Reminder%'
  ORDER BY created_at DESC
  LIMIT 1;

  ASSERT outbox_row.id IS NOT NULL, 'Should have outbox entry with Reminder text';
  ASSERT outbox_row.payload->>'text' LIKE '%Reminder%',
    format('Outbox text should contain Reminder, got: %s', outbox_row.payload->>'text');

  RAISE NOTICE 'PASS: Test 78 - Reminder creates outbox entry with Reminder text';
END;
$$;

-- ============================================================
-- Test 79: create_capacity_request with vp_approver_user_id stores it
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
BEGIN
  req := create_capacity_request(
    p_requester_user_id         := 'U_vpa_store1',
    p_commercial_owner_user_id  := 'U_comm_vpa_s1',
    p_infra_owner_group         := 'infra-vpa-s1',
    p_customer_ref              := '{"org_id": "org_vpa_s1"}'::jsonb,
    p_requested_size            := '32XL',
    p_quantity                  := 1,
    p_region                    := 'us-east-1',
    p_needed_by_date            := '2026-03-01'::date,
    p_expected_duration_days    := 30,
    p_estimated_monthly_cost_usd := 100000,
    p_confirmation_ttl_days     := 7,
    p_slack_channel_id          := NULL,
    p_vp_approver_user_id       := 'U_vp_boss'
  );

  ASSERT req.vp_approver_user_id = 'U_vp_boss',
    format('Expected vp_approver_user_id U_vp_boss, got %s', req.vp_approver_user_id);

  RAISE NOTICE 'PASS: Test 79 - create_capacity_request with vp_approver_user_id stores it';
END;
$$;

-- ============================================================
-- Test 80: create_capacity_request without vp_approver defaults to NULL
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
BEGIN
  req := create_capacity_request(
    'U_vpa_default', 'U_comm_vpa_d', 'infra-vpa-d',
    '{"org_id": "org_vpa_d"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7
  );

  ASSERT req.vp_approver_user_id IS NULL,
    format('Expected NULL vp_approver_user_id, got %s', req.vp_approver_user_id);

  RAISE NOTICE 'PASS: Test 80 - create_capacity_request without vp_approver defaults to NULL';
END;
$$;

-- ============================================================
-- Test 81: enqueue_slack_dm creates outbox row with user ID as channel
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  outbox_id uuid;
  outbox_row record;
  event_id uuid;
BEGIN
  req := create_capacity_request(
    'U_dm1', 'U_comm_dm1', 'infra-dm1',
    '{"org_id": "org_dm1"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30
  );

  SELECT id INTO event_id FROM capacity_request_events
  WHERE capacity_request_id = req.id LIMIT 1;

  outbox_id := enqueue_slack_dm(req.id, event_id, 'U_target_dm', 'Hello via DM');

  ASSERT outbox_id IS NOT NULL, 'Should return outbox UUID';

  SELECT * INTO outbox_row FROM capacity_request_outbox WHERE id = outbox_id;
  ASSERT outbox_row.payload->>'channel' = 'U_target_dm',
    format('Expected channel U_target_dm, got %s', outbox_row.payload->>'channel');
  ASSERT outbox_row.payload->>'text' = 'Hello via DM',
    format('Expected text Hello via DM, got %s', outbox_row.payload->>'text');

  RAISE NOTICE 'PASS: Test 81 - enqueue_slack_dm creates outbox row with user ID as channel';
END;
$$;

-- ============================================================
-- Test 82: enqueue_slack_dm with NULL user ID returns NULL, no outbox row
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  outbox_id uuid;
  event_id uuid;
  outbox_count integer;
BEGIN
  req := create_capacity_request(
    'U_dm2', 'U_comm_dm2', 'infra-dm2',
    '{"org_id": "org_dm2"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30
  );

  SELECT id INTO event_id FROM capacity_request_events
  WHERE capacity_request_id = req.id LIMIT 1;

  SELECT count(*) INTO outbox_count FROM capacity_request_outbox WHERE capacity_request_id = req.id;

  outbox_id := enqueue_slack_dm(req.id, event_id, NULL, 'Should not send');

  ASSERT outbox_id IS NULL, 'Should return NULL for NULL user ID';

  -- Also test empty string
  outbox_id := enqueue_slack_dm(req.id, event_id, '', 'Should not send either');
  ASSERT outbox_id IS NULL, 'Should return NULL for empty user ID';

  RAISE NOTICE 'PASS: Test 82 - enqueue_slack_dm with NULL user ID returns NULL';
END;
$$;

-- ============================================================
-- Test 83: DM outbox entry created for commercial_owner on SUBMITTED -> UNDER_REVIEW
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  dm_row record;
BEGIN
  req := create_capacity_request(
    'U_dm_test3', 'U_comm_dm_test3', 'infra-dm-t3',
    '{"org_id": "org_dm_t3"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7
  );

  -- The create call triggers SUBMITTED -> UNDER_REVIEW which should DM the commercial owner
  SELECT * INTO dm_row
  FROM capacity_request_outbox
  WHERE capacity_request_id = req.id
    AND payload->>'channel' = 'U_comm_dm_test3'
    AND payload->>'text' LIKE '%commercial review%'
  LIMIT 1;

  ASSERT dm_row.id IS NOT NULL,
    'Should have DM outbox entry for commercial owner on SUBMITTED -> UNDER_REVIEW';

  RAISE NOTICE 'PASS: Test 83 - DM outbox entry created for commercial_owner on SUBMITTED -> UNDER_REVIEW';
END;
$$;

-- ============================================================
-- Test 84: DM outbox entry created for vp_approver when VP escalation needed
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  dm_row record;
BEGIN
  -- Create high-cost request with VP approver
  req := create_capacity_request(
    p_requester_user_id         := 'U_dm_vp1',
    p_commercial_owner_user_id  := 'U_comm_dm_vp1',
    p_infra_owner_group         := 'infra-dm-vp1',
    p_customer_ref              := '{"org_id": "org_dm_vp1"}'::jsonb,
    p_requested_size            := '32XL',
    p_quantity                  := 10,
    p_region                    := 'us-east-1',
    p_needed_by_date            := '2026-03-01'::date,
    p_expected_duration_days    := 90,
    p_estimated_monthly_cost_usd := 100000,
    p_confirmation_ttl_days     := 7,
    p_slack_channel_id          := NULL,
    p_vp_approver_user_id       := 'U_vp_dm_target'
  );

  -- Apply commercial + tech approval (VP still pending, triggers DM)
  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_dm_vp1');
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra_dm_vp1');

  -- State should stay UNDER_REVIEW (VP approval still needed)
  ASSERT req.state = 'UNDER_REVIEW',
    format('Expected UNDER_REVIEW (VP needed), got %s', req.state);

  -- Check for VP DM
  SELECT * INTO dm_row
  FROM capacity_request_outbox
  WHERE capacity_request_id = req.id
    AND payload->>'channel' = 'U_vp_dm_target'
    AND payload->>'text' LIKE '%VP approval%'
  LIMIT 1;

  ASSERT dm_row.id IS NOT NULL,
    'Should have DM outbox entry for VP approver when escalation needed';

  RAISE NOTICE 'PASS: Test 84 - DM outbox entry created for vp_approver when VP escalation needed';
END;
$$;

-- ============================================================
-- Test 85: get_sla_threshold_hours returns correct defaults
-- ============================================================
DO $$
DECLARE
  h numeric;
BEGIN
  h := get_sla_threshold_hours('UNDER_REVIEW');
  ASSERT h = 48, format('Expected 48 for UNDER_REVIEW, got %s', h);

  h := get_sla_threshold_hours('CUSTOMER_CONFIRMATION_REQUIRED');
  ASSERT h = 72, format('Expected 72 for CUSTOMER_CONFIRMATION_REQUIRED, got %s', h);

  h := get_sla_threshold_hours('PROVISIONING');
  ASSERT h = 24, format('Expected 24 for PROVISIONING, got %s', h);

  h := get_sla_threshold_hours('COMPLETED');
  ASSERT h IS NULL, format('Expected NULL for COMPLETED, got %s', h);

  h := get_sla_threshold_hours('SUBMITTED');
  ASSERT h IS NULL, format('Expected NULL for SUBMITTED, got %s', h);

  RAISE NOTICE 'PASS: Test 85 - get_sla_threshold_hours returns correct defaults';
END;
$$;

-- ============================================================
-- Test 86: v_sla_status returns 'ok' for a freshly created UNDER_REVIEW request
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  sla record;
BEGIN
  req := create_capacity_request(
    'U_sla1', 'U_comm_sla1', 'infra-sla1',
    '{"org_id": "org_sla1"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7
  );

  SELECT * INTO sla FROM v_sla_status WHERE id = req.id;

  ASSERT sla.id IS NOT NULL, 'Should find request in v_sla_status';
  ASSERT sla.sla_status = 'ok', format('Expected ok, got %s', sla.sla_status);
  ASSERT sla.sla_threshold_hours = 48, format('Expected 48h threshold, got %s', sla.sla_threshold_hours);

  RAISE NOTICE 'PASS: Test 86 - v_sla_status returns ok for fresh UNDER_REVIEW request';
END;
$$;

-- ============================================================
-- Test 87: v_sla_status returns 'breached' when updated_at set >48h ago
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  sla record;
BEGIN
  req := create_capacity_request(
    'U_sla2', 'U_comm_sla2', 'infra-sla2',
    '{"org_id": "org_sla2"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7
  );

  -- Set updated_at to 50 hours ago (> 48h SLA)
  UPDATE capacity_requests SET updated_at = now() - interval '50 hours' WHERE id = req.id;

  SELECT * INTO sla FROM v_sla_status WHERE id = req.id;

  ASSERT sla.id IS NOT NULL, 'Should find request in v_sla_status';
  ASSERT sla.sla_status = 'breached', format('Expected breached, got %s', sla.sla_status);

  RAISE NOTICE 'PASS: Test 87 - v_sla_status returns breached when >48h elapsed';
END;
$$;

-- ============================================================
-- Test 88: v_sla_status returns 'at_risk' at 80% of threshold
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  sla record;
BEGIN
  req := create_capacity_request(
    'U_sla3', 'U_comm_sla3', 'infra-sla3',
    '{"org_id": "org_sla3"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7
  );

  -- Set updated_at to 40 hours ago (83% of 48h, > 75% threshold)
  UPDATE capacity_requests SET updated_at = now() - interval '40 hours' WHERE id = req.id;

  SELECT * INTO sla FROM v_sla_status WHERE id = req.id;

  ASSERT sla.id IS NOT NULL, 'Should find request in v_sla_status';
  ASSERT sla.sla_status = 'at_risk', format('Expected at_risk, got %s', sla.sla_status);

  RAISE NOTICE 'PASS: Test 88 - v_sla_status returns at_risk at 80%% of threshold';
END;
$$;

-- ============================================================
-- Test 89: v_sla_status excludes terminal-state requests
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  sla_count integer;
BEGIN
  req := create_capacity_request(
    'U_sla4', 'U_comm_sla4', 'infra-sla4',
    '{"org_id": "org_sla4"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7
  );

  -- Reject the request (terminal state)
  req := apply_capacity_event(req.id, 'COMMERCIAL_REJECTED', 'user', 'U_comm_sla4');
  ASSERT req.state = 'REJECTED', 'Setup: should be REJECTED';

  SELECT count(*) INTO sla_count FROM v_sla_status WHERE id = req.id;
  ASSERT sla_count = 0,
    format('Terminal state request should not appear in v_sla_status, got %s rows', sla_count);

  RAISE NOTICE 'PASS: Test 89 - v_sla_status excludes terminal-state requests';
END;
$$;

-- ============================================================
-- Test 90: get_my_pending_actions returns commercial_review for assigned owner
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  action_row record;
BEGIN
  req := create_capacity_request(
    'U_queue1', 'U_comm_queue1', 'infra-queue1',
    '{"org_id": "org_queue1"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7
  );

  SELECT * INTO action_row
  FROM get_my_pending_actions('U_comm_queue1')
  WHERE request_id = req.id;

  ASSERT action_row.request_id IS NOT NULL,
    'Should find pending action for commercial owner';
  ASSERT action_row.action_needed = 'commercial_review',
    format('Expected commercial_review, got %s', action_row.action_needed);

  RAISE NOTICE 'PASS: Test 90 - get_my_pending_actions returns commercial_review for assigned owner';
END;
$$;

-- ============================================================
-- Test 91: get_my_pending_actions returns vp_approval for VP approver on escalated request
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  action_row record;
BEGIN
  req := create_capacity_request(
    p_requester_user_id         := 'U_queue_vp1',
    p_commercial_owner_user_id  := 'U_comm_queue_vp1',
    p_infra_owner_group         := 'infra-queue-vp1',
    p_customer_ref              := '{"org_id": "org_queue_vp1"}'::jsonb,
    p_requested_size            := '32XL',
    p_quantity                  := 10,
    p_region                    := 'us-east-1',
    p_needed_by_date            := '2026-03-01'::date,
    p_expected_duration_days    := 90,
    p_estimated_monthly_cost_usd := 100000,
    p_confirmation_ttl_days     := 7,
    p_slack_channel_id          := NULL,
    p_vp_approver_user_id       := 'U_vp_queue_target'
  );

  SELECT * INTO action_row
  FROM get_my_pending_actions('U_vp_queue_target')
  WHERE request_id = req.id;

  ASSERT action_row.request_id IS NOT NULL,
    'Should find pending VP approval action';
  ASSERT action_row.action_needed = 'vp_approval',
    format('Expected vp_approval, got %s', action_row.action_needed);

  RAISE NOTICE 'PASS: Test 91 - get_my_pending_actions returns vp_approval for VP approver';
END;
$$;

-- ============================================================
-- Test 92: get_my_pending_actions returns customer_confirmation
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  action_row record;
BEGIN
  req := create_capacity_request(
    'U_queue_cust1', 'U_comm_queue_c1', 'infra-queue-c1',
    '{"org_id": "org_queue_c1"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7
  );

  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_queue_c1');
  req := apply_capacity_event(req.id, 'TECH_REVIEW_APPROVED', 'user', 'U_infra_queue_c1');
  ASSERT req.state = 'CUSTOMER_CONFIRMATION_REQUIRED', 'Setup failed';

  SELECT * INTO action_row
  FROM get_my_pending_actions('U_queue_cust1')
  WHERE request_id = req.id;

  ASSERT action_row.request_id IS NOT NULL,
    'Should find pending customer confirmation action';
  ASSERT action_row.action_needed = 'customer_confirmation',
    format('Expected customer_confirmation, got %s', action_row.action_needed);

  RAISE NOTICE 'PASS: Test 92 - get_my_pending_actions returns customer_confirmation';
END;
$$;

-- ============================================================
-- Test 93: get_my_pending_actions returns empty for user with no pending actions
-- ============================================================
DO $$
DECLARE
  action_count integer;
BEGIN
  SELECT count(*) INTO action_count
  FROM get_my_pending_actions('U_nobody_has_this_id');

  ASSERT action_count = 0,
    format('Expected 0 pending actions for unknown user, got %s', action_count);

  RAISE NOTICE 'PASS: Test 93 - get_my_pending_actions returns empty for user with no pending actions';
END;
$$;

-- ============================================================
-- Test 94: get_my_pending_actions does NOT return already-approved actions
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  action_count integer;
BEGIN
  req := create_capacity_request(
    'U_queue_done1', 'U_comm_queue_done1', 'infra-queue-d1',
    '{"org_id": "org_queue_d1"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7
  );

  -- Commercial owner approves
  req := apply_capacity_event(req.id, 'COMMERCIAL_APPROVED', 'user', 'U_comm_queue_done1');

  -- Commercial owner should no longer see this request as pending
  SELECT count(*) INTO action_count
  FROM get_my_pending_actions('U_comm_queue_done1')
  WHERE request_id = req.id;

  ASSERT action_count = 0,
    format('Expected 0 (already approved), got %s', action_count);

  RAISE NOTICE 'PASS: Test 94 - get_my_pending_actions does NOT return already-approved actions';
END;
$$;

-- ============================================================
-- Test 95: get_my_pending_actions includes sla_status column with 'ok' for fresh requests
-- ============================================================
DO $$
DECLARE
  req capacity_requests;
  action_row record;
BEGIN
  req := create_capacity_request(
    'U_queue_sla1', 'U_comm_queue_sla1', 'infra-queue-sla1',
    '{"org_id": "org_queue_sla1"}'::jsonb,
    '32XL', 1, 'us-east-1', '2026-03-01'::date, 30,
    5000, 7
  );

  SELECT * INTO action_row
  FROM get_my_pending_actions('U_comm_queue_sla1')
  WHERE request_id = req.id;

  ASSERT action_row.request_id IS NOT NULL, 'Should find pending action';
  ASSERT action_row.sla_status = 'ok',
    format('Expected sla_status ok for fresh request, got %s', action_row.sla_status);

  RAISE NOTICE 'PASS: Test 95 - get_my_pending_actions includes sla_status ok for fresh requests';
END;
$$;

-- ============================================================
-- Summary
-- ============================================================
DO $$
DECLARE
  total_requests integer;
  total_events integer;
BEGIN
  SELECT count(*) INTO total_requests FROM capacity_requests;
  SELECT count(*) INTO total_events FROM capacity_request_events;
  RAISE NOTICE '---';
  RAISE NOTICE 'All tests passed. Created % requests with % events.', total_requests, total_events;
END;
$$;

ROLLBACK;
