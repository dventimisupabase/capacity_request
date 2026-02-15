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
