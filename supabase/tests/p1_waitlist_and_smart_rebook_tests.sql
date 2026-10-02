-- ============================================================================
-- Test Suite: p1_waitlist_and_smart_rebook_tests.sql
-- Description: Isolated test suite for Phase 4 (P1) Waitlist Engine, Multi-Room
--              Batch Intent, Fair Claim Window & Smart Rebook Engine.
-- Safety: Wrapped in BEGIN ... ROLLBACK to ensure zero live database mutations.
-- ============================================================================

BEGIN;

DO $$
DECLARE
  v_owner_id uuid := gen_random_uuid();
  v_customer_id uuid := gen_random_uuid();
  v_other_customer_id uuid := gen_random_uuid();
  v_lounge_id uuid := gen_random_uuid();
  v_room_1 uuid := gen_random_uuid();
  v_room_2 uuid := gen_random_uuid();
  v_room_3 uuid := gen_random_uuid();
  v_shift_id uuid := gen_random_uuid();
  v_test_date date := (now() AT TIME ZONE 'Africa/Cairo')::date + 2;
  v_test_start timestamp without time zone;
  v_test_end timestamp without time zone;
  v_result jsonb;
  v_intent_id uuid;
  v_waitlist_id uuid;
  v_waitlist_id_2 uuid;
  v_hold_token uuid;
  v_past_booking_id uuid := gen_random_uuid();
  v_rebook_result jsonb;
  v_sent_count integer;
  v_claimed_result jsonb;
  v_cancelled_bool boolean;
  v_booking_waitlist_count integer;
BEGIN
  -- --------------------------------------------------------------------------
  -- 0. Seed Test Fixtures (Profiles, Lounge, Rooms, Active Shift)
  -- --------------------------------------------------------------------------
  INSERT INTO auth.users (id, email, aud, role)
  VALUES
    (v_owner_id, 'owner_waitlist@playspot.test', 'authenticated', 'authenticated'),
    (v_customer_id, 'customer_waitlist@playspot.test', 'authenticated', 'authenticated'),
    (v_other_customer_id, 'other_customer_waitlist@playspot.test', 'authenticated', 'authenticated');

  INSERT INTO public.profiles (id, email, full_name, phone, role)
  VALUES
    (v_owner_id, 'owner_waitlist@playspot.test', 'Owner Waitlist', '+201000000041', 'owner'),
    (v_customer_id, 'customer_waitlist@playspot.test', 'Customer Waitlist', '+201000000042', 'user'),
    (v_other_customer_id, 'other_customer_waitlist@playspot.test', 'Other Customer', '+201000000043', 'user')
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    phone = EXCLUDED.phone,
    role = EXCLUDED.role;

  INSERT INTO public.lounges (
    id, owner_id, name, name_ar, name_en, opening_time, closing_time,
    is_open, is_active, status, allow_future_bookings, vodafone_cash_number,
    allow_cash_payment, require_prepaid_first_time
  )
  VALUES (
    v_lounge_id, v_owner_id, 'Waitlist Test Lounge', 'صالة اختبار قائمة الانتظار',
    'Waitlist Test Lounge', '10:00:00'::time, '23:00:00'::time,
    true, true, 'active', true, '01000000000',
    true, false
  );

  INSERT INTO public.rooms (
    id, lounge_id, name, name_ar, name_en, hourly_rate_single, is_available, is_active, status
  )
  VALUES
    (v_room_1, v_lounge_id, 'Room VIP 1', 'غرفة 1', 'Room VIP 1', 120.0, true, true, 'available'),
    (v_room_2, v_lounge_id, 'Room VIP 2', 'غرفة 2', 'Room VIP 2', 120.0, true, true, 'available'),
    (v_room_3, v_lounge_id, 'Room Standard 3', 'غرفة 3', 'Room Standard 3', 80.0, true, true, 'available');

  INSERT INTO public.shifts (
    id, lounge_id, cashier_id, staff_user_id, opened_at, status
  )
  VALUES (
    v_shift_id, v_lounge_id, v_owner_id, v_owner_id, now(), 'open'
  );

  v_test_start := v_test_date + '18:00:00'::time;
  v_test_end := v_test_start + interval '60 minutes';

  -- --------------------------------------------------------------------------
  -- 1. Test join_slot_waitlist: Multi-Room Batch Single Intent
  -- --------------------------------------------------------------------------
  PERFORM set_config('request.jwt.claim.sub', v_customer_id::text, true);

  v_result := public.join_slot_waitlist(
    v_lounge_id,
    ARRAY[v_room_1, v_room_2],
    to_char(v_test_date, 'YYYY-MM-DD'),
    '18:00:00'
  );

  IF (v_result->>'success')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'TEST FAILED: join_slot_waitlist returned failure: %', v_result;
  END IF;

  v_intent_id := (v_result->>'intent_id')::uuid;
  IF v_intent_id IS NULL THEN
    RAISE EXCEPTION 'TEST FAILED: intent_id should not be null in batch waitlist';
  END IF;

  -- Verify two waitlist records were created sharing the same intent_id
  SELECT count(*) INTO v_booking_waitlist_count
  FROM public.booking_waitlist
  WHERE intent_id = v_intent_id AND user_id = v_customer_id;

  IF v_booking_waitlist_count <> 2 THEN
    RAISE EXCEPTION 'TEST FAILED: Expected 2 waitlist entries for multi-room batch, found %', v_booking_waitlist_count;
  END IF;

  -- --------------------------------------------------------------------------
  -- 2. Test Fallback View slot_waitlist (Insert and Select)
  -- --------------------------------------------------------------------------
  INSERT INTO public.slot_waitlist (
    user_id, lounge_id, room_id, date, slot_time, status
  )
  VALUES (
    v_customer_id, v_lounge_id, v_room_3, v_test_date, '19:00:00'::time, 'waiting'
  );

  IF NOT EXISTS (
    SELECT 1 FROM public.booking_waitlist
    WHERE user_id = v_customer_id AND room_id = v_room_3 AND requested_date = v_test_date
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: Fallback insert via slot_waitlist view failed';
  END IF;

  -- --------------------------------------------------------------------------
  -- 3. Test Timestamp Overload join_booking_waitlist(room_id, start_at, end_at)
  -- --------------------------------------------------------------------------
  -- Create an active booking blocking room 1 for slot 20:00 - 21:00
  INSERT INTO public.bookings (
    id, user_id, lounge_id, room_id, date, start_time, end_time,
    room_price, total_price, status, payment_method, is_first_booking
  )
  VALUES (
    gen_random_uuid(), v_other_customer_id, v_lounge_id, v_room_1,
    v_test_date, '20:00:00'::time, '21:00:00'::time,
    120.0, 120.0, 'upcoming', 'cash', false
  );

  -- Joining waitlist for blocked slot should succeed
  v_result := public.join_booking_waitlist(
    v_room_1,
    v_test_date + '20:00:00'::time,
    v_test_date + '21:00:00'::time
  );

  IF (v_result->>'success')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'TEST FAILED: join_booking_waitlist failed for blocked slot: %', v_result;
  END IF;

  v_waitlist_id := (v_result->>'waitlist_id')::uuid;

  -- --------------------------------------------------------------------------
  -- 4. Test cancel_booking_waitlist
  -- --------------------------------------------------------------------------
  v_cancelled_bool := public.cancel_booking_waitlist(v_waitlist_id);
  IF v_cancelled_bool IS NOT TRUE THEN
    RAISE EXCEPTION 'TEST FAILED: cancel_booking_waitlist returned false';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.booking_waitlist WHERE id = v_waitlist_id AND status = 'cancelled'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: Waitlist entry was not marked cancelled';
  END IF;

  -- --------------------------------------------------------------------------
  -- 5. Test process_booking_waitlist: FIFO Dispatch & Fair Claim Window
  -- --------------------------------------------------------------------------
  -- Run background dispatcher as service_role
  PERFORM set_config('request.jwt.claim.sub', '', true);
  v_sent_count := public.process_booking_waitlist();

  IF v_sent_count < 1 THEN
    RAISE EXCEPTION 'TEST FAILED: process_booking_waitlist expected to dispatch notifications, sent: %', v_sent_count;
  END IF;

  -- Identify which room entry in the intent batch was notified
  SELECT id, room_id INTO v_waitlist_id, v_room_1
  FROM public.booking_waitlist
  WHERE intent_id = v_intent_id AND status = 'notified';

  IF v_waitlist_id IS NULL THEN
    RAISE EXCEPTION 'TEST FAILED: No waitlist entry in intent was marked notified';
  END IF;

  -- The other room is the sibling
  SELECT id INTO v_waitlist_id_2
  FROM public.booking_waitlist
  WHERE intent_id = v_intent_id AND id <> v_waitlist_id;

  -- Verify notification was generated
  IF NOT EXISTS (
    SELECT 1 FROM public.notifications
    WHERE user_id = v_customer_id
      AND (metadata->>'waitlist_id')::uuid = v_waitlist_id
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: Localized notification was not generated';
  END IF;

  -- --------------------------------------------------------------------------
  -- 6. Test claim_waitlist_slot: Atomic Hold Creation & Intent Cancellation
  -- --------------------------------------------------------------------------
  PERFORM set_config('request.jwt.claim.sub', v_customer_id::text, true);

  v_claimed_result := public.claim_waitlist_slot(v_waitlist_id);

  IF (v_claimed_result->>'success')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'TEST FAILED: claim_waitlist_slot failed: %', v_claimed_result;
  END IF;

  v_hold_token := (v_claimed_result->>'hold_token')::uuid;
  IF v_hold_token IS NULL THEN
    RAISE EXCEPTION 'TEST FAILED: claim_waitlist_slot did not return hold_token';
  END IF;

  -- Verify hold exists in booking_holds
  IF NOT EXISTS (
    SELECT 1 FROM public.booking_holds
    WHERE hold_token = v_hold_token
      AND user_id = v_customer_id
      AND room_id = v_room_1
      AND released_at IS NULL
      AND expires_at > now()
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: booking_holds record was not created for claimed slot';
  END IF;

  -- Verify sibling room in same intent was automatically cancelled
  IF NOT EXISTS (
    SELECT 1 FROM public.booking_waitlist
    WHERE id = v_waitlist_id_2 AND status = 'cancelled'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: Sibling room in intent batch was not cancelled upon claim';
  END IF;

  -- --------------------------------------------------------------------------
  -- 7. Test get_smart_rebook_slots: 7-14 Days Scanning & Authoritative Quotes
  -- --------------------------------------------------------------------------
  -- Seed a completed past booking for customer
  INSERT INTO public.bookings (
    id, user_id, lounge_id, room_id, date, start_time, end_time,
    room_price, total_price, status, payment_method, is_first_booking
  )
  VALUES (
    v_past_booking_id, v_customer_id, v_lounge_id, v_room_1,
    v_test_date - 7, '16:00:00'::time, '17:00:00'::time,
    120.0, 120.0, 'completed', 'cash', false
  );

  v_rebook_result := public.get_smart_rebook_slots(v_past_booking_id, 14);

  IF (v_rebook_result->>'success')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'TEST FAILED: get_smart_rebook_slots returned failure: %', v_rebook_result;
  END IF;

  IF jsonb_array_length(v_rebook_result->'recommendations') = 0 THEN
    RAISE EXCEPTION 'TEST FAILED: get_smart_rebook_slots returned empty recommendations: %', v_rebook_result;
  END IF;

  -- Verify first recommendation has date, closest_slot and quoted_price
  IF (v_rebook_result->'recommendations'->0->>'closest_slot') IS NULL
     OR (v_rebook_result->'recommendations'->0->'quoted_price'->>'final_total') IS NULL THEN
    RAISE EXCEPTION 'TEST FAILED: Recommendation missing closest_slot or quoted_price: %', v_rebook_result;
  END IF;

  RAISE NOTICE 'ALL PHASE 4 WAITLIST & SMART REBOOK TESTS PASSED SUCCESSFULLY!';
END $$;

ROLLBACK;
