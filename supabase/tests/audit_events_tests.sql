-- Audit Events & Timeline Integrity & Security Test Suite
DO $test$
DECLARE
  v_count integer;
  v_test_event_id uuid;
BEGIN
  -- 1. Verify Event Catalog Presence
  SELECT COUNT(*) INTO v_count
  FROM public.event_catalog
  WHERE code IN (
    'booking_created', 'booking_approved', 'booking_checked_in',
    'booking_completed', 'booking_cancelled', 'payment_collected',
    'shift_opened', 'shift_closed', 'permission_changed'
  );

  IF v_count < 9 THEN
    RAISE EXCEPTION 'TEST FAILED: event_catalog missing required seeded codes';
  END IF;

  -- 2. Verify audit_events Table & RLS
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'audit_events'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: audit_events table does not exist';
  END IF;

  IF NOT (SELECT relrowsecurity FROM pg_catalog.pg_class WHERE oid = 'public.audit_events'::regclass) THEN
    RAISE EXCEPTION 'TEST FAILED: audit_events RLS must be enabled';
  END IF;

  -- 3. Verify Function Execution Permissions (anon must be revoked)
  IF pg_catalog.has_function_privilege('anon', 'public.get_audit_timeline(uuid,text,text,uuid,timestamptz,timestamptz,text,timestamptz,uuid,int)', 'EXECUTE') THEN
    RAISE EXCEPTION 'TEST FAILED: get_audit_timeline must NOT be executable by anon';
  END IF;

  IF pg_catalog.has_function_privilege('anon', 'public.get_booking_timeline_for_customer(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'TEST FAILED: get_booking_timeline_for_customer must NOT be executable by anon';
  END IF;

  -- 4. Verify Immutability Trigger
  -- Insert a test event using internal helper
  SELECT private.log_audit_event(
    NULL, 'test_entity', 'test_123', 'booking_created', NULL, NULL, 'info', '{"test": true}'::jsonb
  ) INTO v_test_event_id;

  IF v_test_event_id IS NULL THEN
    RAISE EXCEPTION 'TEST FAILED: private.log_audit_event failed to insert event';
  END IF;

  -- Attempt to update test event (MUST FAIL)
  BEGIN
    UPDATE public.audit_events
    SET severity = 'critical'
    WHERE id = v_test_event_id;
    RAISE EXCEPTION 'TEST FAILED: UPDATE on audit_events should have thrown an immutability exception!';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%immutable%' THEN
      RAISE EXCEPTION 'TEST FAILED: Unexpected error message on UPDATE: %', SQLERRM;
    END IF;
  END;

  -- Attempt to delete test event (MUST FAIL)
  BEGIN
    DELETE FROM public.audit_events
    WHERE id = v_test_event_id;
    RAISE EXCEPTION 'TEST FAILED: DELETE on audit_events should have thrown an immutability exception!';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%immutable%' THEN
      RAISE EXCEPTION 'TEST FAILED: Unexpected error message on DELETE: %', SQLERRM;
    END IF;
  END;

  -- 5. Verify Legacy View Existence
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.views
    WHERE table_schema = 'public' AND table_name = 'audit_timeline_legacy_v'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: audit_timeline_legacy_v view missing';
  END IF;

  RAISE NOTICE 'SUCCESS: All Audit Events & Timeline integrity & security tests passed successfully!';
END;
$test$;
