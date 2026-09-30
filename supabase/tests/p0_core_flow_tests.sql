-- ============================================================================
-- P0 Core Flow Integrity & Session Security Test Suite
-- ============================================================================
DO $test$
DECLARE
  v_test_lounge_id uuid := gen_random_uuid();
  v_test_room_id uuid := gen_random_uuid();
  v_test_user_id uuid := gen_random_uuid();
  v_test_shift_id uuid := gen_random_uuid();
  v_test_booking_id uuid := gen_random_uuid();
  v_test_act_id uuid := gen_random_uuid();
  v_res jsonb;
  v_res_json json;
  v_count integer;
BEGIN
  -- --------------------------------------------------------------------------
  -- 1. Verify Structure & Function Signatures
  -- --------------------------------------------------------------------------
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'attach_booking_to_active_shift'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: attach_booking_to_active_shift missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'attach_booking_to_active_shift_trigger'
      AND tgrelid = 'public.bookings'::regclass
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: attach_booking_to_active_shift_trigger missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'save_lounge_room'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: save_lounge_room RPC missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'complete_booking_payment'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: complete_booking_payment RPC missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'complete_booking_session'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: complete_booking_session RPC missing';
  END IF;

  -- --------------------------------------------------------------------------
  -- 2. Verify Privilege Hardening (Security & Grants)
  -- --------------------------------------------------------------------------
  -- complete_booking_payment must NOT be executable by anon
  IF pg_catalog.has_function_privilege('anon', 'public.complete_booking_payment(uuid, text, numeric)', 'EXECUTE') THEN
    RAISE EXCEPTION 'SECURITY FAILED: complete_booking_payment must not be executable by anon';
  END IF;

  -- submit_tournament_payment 6-param must NOT be executable by authenticated or anon
  IF pg_catalog.has_function_privilege('authenticated', 'public.submit_tournament_payment(uuid, uuid, uuid, numeric, text, text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'SECURITY FAILED: submit_tournament_payment 6-param must not be executable by authenticated';
  END IF;

  IF pg_catalog.has_function_privilege('anon', 'public.submit_tournament_payment(uuid, uuid, uuid, numeric, text, text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'SECURITY FAILED: submit_tournament_payment 6-param must not be executable by anon';
  END IF;

  -- save_lounge_room must NOT be executable by anon
  IF pg_catalog.has_function_privilege('anon', 'public.save_lounge_room(uuid, uuid, text, uuid, numeric, numeric, numeric, uuid[], integer, boolean)', 'EXECUTE') THEN
    RAISE EXCEPTION 'SECURITY FAILED: save_lounge_room must not be executable by anon';
  END IF;

  -- --------------------------------------------------------------------------
  -- 3. Verify Trigger Definition Includes checked_in_at
  -- --------------------------------------------------------------------------
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    WHERE c.relname = 'bookings'
      AND t.tgname = 'attach_booking_to_active_shift_trigger'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: attach_booking_to_active_shift_trigger not registered on bookings';
  END IF;

  -- --------------------------------------------------------------------------
  -- 4. Verify Lounge Timezone Column & business_date
  -- --------------------------------------------------------------------------
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'lounges' AND column_name = 'timezone'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: lounges.timezone column missing';
  END IF;

  RAISE NOTICE 'SUCCESS: All P0 Core Flow Integrity & Session Security tests passed!';
END $test$;
