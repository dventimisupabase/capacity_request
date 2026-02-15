-- Migration 6: Timers & Cron
-- Sweep function for expired deadlines and pg_cron schedule.

-- Timer sweep: find requests with elapsed deadlines and emit timeout events.
-- Uses FOR UPDATE SKIP LOCKED to avoid blocking concurrent transactions.
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

-- Schedule: run every 5 minutes
SELECT cron.schedule(
  'capacity-request-timers',
  '*/5 * * * *',
  'SELECT run_capacity_request_timers()'
);
