-- ============================================================================
-- Test Suite: p2_multi_resource_and_activities_tests.sql
-- Description: Isolated test suite for Phase 5 (P2) Multi-Resource & Activities
--              Layer (PlayStation, Billiards, Table Tennis, VR, Capabilities).
-- Safety: Wrapped in BEGIN ... ROLLBACK to guarantee zero live database mutations.
-- ============================================================================

BEGIN;

DO $$
DECLARE
  v_owner_id uuid := gen_random_uuid();
  v_customer_id uuid := gen_random_uuid();
  v_lounge_id uuid := gen_random_uuid();
  v_billiard_act_id uuid;
  v_vr_act_id uuid;
  v_ps5_act_id uuid;
  v_billiard_room_id uuid := gen_random_uuid();
  v_vr_room_id uuid := gen_random_uuid();
  v_ps5_room_id uuid := gen_random_uuid();
  v_shift_id uuid := gen_random_uuid();
  v_result jsonb;
  v_activities jsonb;
  v_rooms_by_act jsonb;
  v_validation jsonb;
  v_booking_id uuid := gen_random_uuid();
  v_session_res jsonb;
  v_test_date date := (now() AT TIME ZONE 'Africa/Cairo')::date;
BEGIN
  -- --------------------------------------------------------------------------
  -- 0. Seed Test Fixtures (Users, Lounge, Active Shift)
  -- --------------------------------------------------------------------------
  INSERT INTO auth.users (id, email, aud, role)
  VALUES
    (v_owner_id, 'owner_res@playspot.test', 'authenticated', 'authenticated'),
    (v_customer_id, 'customer_res@playspot.test', 'authenticated', 'authenticated');

  INSERT INTO public.profiles (id, email, full_name, phone, role)
  VALUES
    (v_owner_id, 'owner_res@playspot.test', 'Owner Resources', '+201000000051', 'owner'),
    (v_customer_id, 'customer_res@playspot.test', 'Customer Resources', '+201000000052', 'user')
  ON CONFLICT (id) DO UPDATE SET
    role = EXCLUDED.role;

  INSERT INTO public.lounges (
    id, owner_id, name, name_ar, name_en, opening_time, closing_time,
    is_open, is_active, status, allow_future_bookings, vodafone_cash_number,
    allow_cash_payment, require_prepaid_first_time, allow_open_time_sessions
  )
  VALUES (
    v_lounge_id, v_owner_id, 'Multi-Resource Lounge', 'صالة الأنشطة المتعددة',
    'Multi-Resource Lounge', '10:00:00'::time, '23:00:00'::time,
    true, true, 'active', true, '01000000000',
    true, false, true
  );

  INSERT INTO public.shifts (
    id, lounge_id, cashier_id, staff_user_id, opened_at, status
  )
  VALUES (
    v_shift_id, v_lounge_id, v_owner_id, v_owner_id, now(), 'open'
  );

  -- Retrieve activity type IDs
  SELECT id INTO v_billiard_act_id FROM public.activity_types WHERE name = 'billiard' LIMIT 1;
  SELECT id INTO v_vr_act_id FROM public.activity_types WHERE name = 'vr' LIMIT 1;
  SELECT id INTO v_ps5_act_id FROM public.activity_types WHERE name IN ('ps5', 'playstation') LIMIT 1;

  -- --------------------------------------------------------------------------
  -- 1. Test save_lounge_room for Billiards (Zero Controllers, No Screen)
  -- --------------------------------------------------------------------------
  PERFORM set_config('request.jwt.claim.sub', v_owner_id::text, true);

  v_result := public.save_lounge_room(
    p_room_id => v_billiard_room_id,
    p_lounge_id => v_lounge_id,
    p_name => 'Billiard Table 1 (Brunswick 9ft)',
    p_single_price => 90.0,
    p_multi_price => 90.0,
    p_activity_ids => ARRAY[v_billiard_act_id],
    p_max_capacity => 6,
    p_resource_type => 'billiard',
    p_resource_attributes => jsonb_build_object('table_size', '9ft', 'cues_count', 4, 'cloth_color', 'blue'),
    p_pricing_model => 'per_room_hour',
    p_min_capacity => 2
  );

  IF (v_result->>'success')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'TEST FAILED: save_lounge_room for Billiards failed: %', v_result;
  END IF;

  IF (v_result->>'requires_screen')::boolean IS NOT FALSE
     OR (v_result->>'requires_controllers')::boolean IS NOT FALSE
     OR (v_result->>'controllers_count')::integer <> 0 THEN
    RAISE EXCEPTION 'TEST FAILED: Billiards room must not require screen or controllers: %', v_result;
  END IF;

  -- --------------------------------------------------------------------------
  -- 2. Test save_lounge_room for VR Station (Headsets, Screen & Controllers)
  -- --------------------------------------------------------------------------
  v_result := public.save_lounge_room(
    p_room_id => v_vr_room_id,
    p_lounge_id => v_lounge_id,
    p_name => 'VR Arena Station 1',
    p_single_price => 150.0,
    p_multi_price => 200.0,
    p_activity_ids => ARRAY[v_vr_act_id],
    p_max_capacity => 2,
    p_resource_type => 'vr',
    p_resource_attributes => jsonb_build_object('headset_model', 'Meta Quest 3', 'headsets_count', 2, 'play_area', '4x4m'),
    p_pricing_model => 'per_room_hour',
    p_min_capacity => 1
  );

  IF (v_result->>'success')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'TEST FAILED: save_lounge_room for VR failed: %', v_result;
  END IF;

  -- --------------------------------------------------------------------------
  -- 3. Test save_lounge_room for PlayStation 5 (Console, Controllers, Screen)
  -- --------------------------------------------------------------------------
  v_result := public.save_lounge_room(
    p_room_id => v_ps5_room_id,
    p_lounge_id => v_lounge_id,
    p_name => 'PlayStation 5 VIP Lounge',
    p_single_price => 100.0,
    p_multi_price => 120.0,
    p_activity_ids => ARRAY[v_ps5_act_id],
    p_max_capacity => 4,
    p_resource_type => 'console',
    p_controllers_count => 4,
    p_screen_size => '65"'
  );

  IF (v_result->>'success')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'TEST FAILED: save_lounge_room for PS5 failed: %', v_result;
  END IF;

  -- --------------------------------------------------------------------------
  -- 4. Test get_lounge_activities Catalog RPC
  -- --------------------------------------------------------------------------
  v_activities := public.get_lounge_activities(v_lounge_id);

  IF jsonb_array_length(v_activities) < 3 THEN
    RAISE EXCEPTION 'TEST FAILED: get_lounge_activities expected at least 3 activities, got: %', v_activities;
  END IF;

  -- Verify Billiards activity has requires_screen = false and requires_controllers = false
  IF NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_activities) elem
    WHERE elem->>'name' = 'billiard'
      AND (elem->>'requires_screen')::boolean IS FALSE
      AND (elem->>'requires_controllers')::boolean IS FALSE
      AND (elem->>'rooms_count')::integer = 1
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: get_lounge_activities missing accurate Billiards capabilities: %', v_activities;
  END IF;

  -- --------------------------------------------------------------------------
  -- 5. Test get_rooms_by_activity Filter RPC
  -- --------------------------------------------------------------------------
  v_rooms_by_act := public.get_rooms_by_activity(v_lounge_id, v_billiard_act_id, v_test_date);

  IF jsonb_array_length(v_rooms_by_act) <> 1 THEN
    RAISE EXCEPTION 'TEST FAILED: get_rooms_by_activity expected 1 billiard room, got: %', v_rooms_by_act;
  END IF;

  IF (v_rooms_by_act->0->>'resource_type') <> 'billiard'
     OR (v_rooms_by_act->0->'resource_attributes'->>'table_size') <> '9ft' THEN
    RAISE EXCEPTION 'TEST FAILED: Billiard room attributes missing in get_rooms_by_activity: %', v_rooms_by_act;
  END IF;

  -- --------------------------------------------------------------------------
  -- 6. Test validate_resource_booking_constraints
  -- --------------------------------------------------------------------------
  -- Billiard min capacity is 2, player count 1 should fail
  v_validation := public.validate_resource_booking_constraints(v_billiard_room_id, 1);
  IF (v_validation->>'valid')::boolean IS NOT FALSE
     OR (v_validation->>'error_code') <> 'CAPACITY_UNDERFLOW' THEN
    RAISE EXCEPTION 'TEST FAILED: Expected CAPACITY_UNDERFLOW for 1 player on Billiard: %', v_validation;
  END IF;

  -- Player count 4 should pass
  v_validation := public.validate_resource_booking_constraints(v_billiard_room_id, 4);
  IF (v_validation->>'valid')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'TEST FAILED: Expected valid for 4 players on Billiard: %', v_validation;
  END IF;

  -- --------------------------------------------------------------------------
  -- 7. Test Seamless Integration with Open Time Session Engine
  -- --------------------------------------------------------------------------
  -- Start an open time session on the Billiards table
  v_session_res := public.start_open_time_session(
    p_room_id => v_billiard_room_id,
    p_customer_name => 'Billiard Player'::text
  );

  IF (v_session_res->>'success')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'TEST FAILED: start_open_time_session on Billiards table failed: %', v_session_res;
  END IF;

  -- Room must now be marked occupied
  IF NOT EXISTS (
    SELECT 1 FROM public.rooms WHERE id = v_billiard_room_id AND status = 'occupied'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: Billiards room status was not marked occupied';
  END IF;

  RAISE NOTICE 'ALL PHASE 5 MULTI-RESOURCE & ACTIVITIES TESTS PASSED SUCCESSFULLY!';
END $$;

ROLLBACK;
