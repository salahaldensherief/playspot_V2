-- ============================================================================
-- Test Suite: Phase 7 (P2) Advanced Operations, Wallets & Safety Tests
-- File: supabase/tests/p2_advanced_operations_and_wallets_tests.sql
-- ============================================================================

DO $$
DECLARE
  v_test_owner uuid := gen_random_uuid();
  v_test_customer uuid := gen_random_uuid();
  v_test_friend uuid := gen_random_uuid();
  v_test_lounge uuid := gen_random_uuid();
  v_test_shift uuid := gen_random_uuid();
  v_test_room uuid := gen_random_uuid();
  v_test_booking uuid := gen_random_uuid();
  v_test_booking_2 uuid := gen_random_uuid();
  
  -- Wallet variables
  v_wallet_res jsonb;
  v_topup_res jsonb;
  v_pay_res jsonb;
  v_refund_res jsonb;
  v_insufficient_caught boolean := false;
  v_frozen_caught boolean := false;
  
  -- Group booking variables
  v_invite_res jsonb;
  v_participants_res jsonb;
  v_invite_id uuid;
  v_respond_res jsonb;
  
  -- Event booking variables
  v_event_pkg_id uuid := gen_random_uuid();
  v_event_req_res jsonb;
  v_event_req_id uuid;
  v_event_review_res jsonb;
  
  -- Promo budget variables
  v_promo_id uuid := gen_random_uuid();
  v_promo_val_res jsonb;
  v_promo_min_res jsonb;
  v_promo_budget_res jsonb;
  v_promo_user_res jsonb;
  
  -- Risk audit variables
  v_risk_log_res jsonb;
  v_risk_timeline_res jsonb;
  
  -- Tournament variables
  v_city_id uuid;
  v_tournament_id uuid := gen_random_uuid();
  v_participant_id uuid := gen_random_uuid();
  v_tournament_res json;
  v_wrong_amount_caught boolean := false;
  
  -- Roaming pass variables
  v_roam_elig_1 jsonb;
  v_roam_elig_2 jsonb;
  v_pkg_id uuid := gen_random_uuid();
BEGIN
  RAISE NOTICE '=== STARTING PHASE 7 ADVANCED OPERATIONS & WALLETS TESTS ===';

  -- 1. Setup Test Users
  INSERT INTO auth.users (id, email, raw_user_meta_data)
  VALUES 
    (v_test_owner, 'owner_p7@test.com', '{"full_name": "P7 Lounge Owner"}'::jsonb),
    (v_test_customer, 'customer_p7@test.com', '{"full_name": "P7 Test Customer"}'::jsonb),
    (v_test_friend, 'friend_p7@test.com', '{"full_name": "P7 Test Friend"}'::jsonb)
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.profiles (id, full_name, role, phone)
  VALUES 
    (v_test_owner, 'P7 Lounge Owner', 'owner', '01000000001'),
    (v_test_customer, 'P7 Test Customer', 'user', '01000000002'),
    (v_test_friend, 'P7 Test Friend', 'user', '01000000003')
  ON CONFLICT (id) DO UPDATE SET full_name = EXCLUDED.full_name, role = EXCLUDED.role, phone = EXCLUDED.phone;

  -- 2. Setup Lounge & Room
  INSERT INTO public.lounges (
    id,
    name,
    owner_id,
    vodafone_cash_number,
    status,
    allow_cash_payment,
    require_prepaid_first_time
  ) VALUES (
    v_test_lounge,
    'PlaySpot Advanced Lounge',
    v_test_owner,
    '01012345678',
    'active',
    true,
    false
  );

  INSERT INTO public.rooms (
    id,
    lounge_id,
    name,
    hourly_rate_single,
    hourly_rate_multi,
    extra_controller_price,
    controllers_count,
    is_active,
    is_available,
    status
  ) VALUES (
    v_test_room,
    v_test_lounge,
    'VIP Arena 7',
    100.0,
    150.0,
    25.0,
    4,
    true,
    true,
    'available'
  );

  -- Open Shift
  INSERT INTO public.shifts (
    id,
    lounge_id,
    cashier_id,
    staff_user_id,
    opened_at,
    status,
    starting_cash
  ) VALUES (
    v_test_shift,
    v_test_lounge,
    v_test_owner,
    v_test_owner,
    now(),
    'open',
    500.0
  );

  -- Setup Booking (duration 1 hour -> total_price 100.0)
  INSERT INTO public.bookings (
    id,
    lounge_id,
    room_id,
    user_id,
    date,
    start_time,
    end_time,
    total_price,
    payment_method,
    payment_status,
    status
  ) VALUES (
    v_test_booking,
    v_test_lounge,
    v_test_room,
    v_test_customer,
    CURRENT_DATE + 1,
    '14:00:00',
    '15:00:00',
    100.0,
    'card',
    'unpaid',
    'pending'
  );

  INSERT INTO public.bookings (
    id,
    lounge_id,
    room_id,
    user_id,
    date,
    start_time,
    end_time,
    total_price,
    payment_method,
    payment_status,
    status
  ) VALUES (
    v_test_booking_2,
    v_test_lounge,
    v_test_room,
    v_test_customer,
    CURRENT_DATE + 2,
    '16:00:00',
    '17:00:00',
    100.0,
    'card',
    'unpaid',
    'pending'
  );

  -- ==========================================================================
  -- Test 1: Digital Wallet Creation & Top-up
  -- ==========================================================================
  RAISE NOTICE 'Testing Wallet Creation & Top-up...';
  
  -- Create wallet
  v_wallet_res := public.get_or_create_user_wallet(v_test_customer);
  ASSERT (v_wallet_res->>'balance')::numeric = 0.00, 'Initial wallet balance must be 0.00';
  ASSERT v_wallet_res->>'currency' = 'EGP', 'Currency must be EGP';

  -- Simulate customer caller for top-up
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_test_customer::text, 'role', 'authenticated')::text, true);

  -- Top-up 250.0 EGP with idempotency key
  v_topup_res := public.topup_user_wallet(250.0, 'vodafone_cash', v_test_lounge, 'topup_test_key_001');
  ASSERT (v_topup_res->>'success')::boolean = true, 'Topup must succeed';
  ASSERT (v_topup_res->>'balance')::numeric = 250.0, 'Wallet balance after top-up must be 250.0';

  -- Verify shift_payment was recorded for lounge shift
  ASSERT EXISTS (
    SELECT 1 FROM public.shift_payments
    WHERE shift_id = v_test_shift AND amount = 250.0 AND payment_method = 'vodafone_cash'
  ), 'Shift payment must be recorded for wallet top-up at lounge';

  -- Repeat top-up with same idempotency key (must be idempotent)
  v_topup_res := public.topup_user_wallet(250.0, 'vodafone_cash', v_test_lounge, 'topup_test_key_001');
  ASSERT (v_topup_res->>'idempotent')::boolean = true, 'Re-executing topup with same key must return idempotent';
  ASSERT (v_topup_res->>'balance')::numeric = 250.0, 'Balance must remain 250.0';

  -- ==========================================================================
  -- Test 2: Pay with Wallet & Balance Deduction
  -- ==========================================================================
  RAISE NOTICE 'Testing Pay with Wallet...';
  
  -- Pay 100.0 EGP for booking
  v_pay_res := public.pay_with_wallet(v_test_booking, 100.0, 'pay_test_key_001');
  ASSERT (v_pay_res->>'success')::boolean = true, 'Payment must succeed';
  ASSERT (v_pay_res->>'remaining_balance')::numeric = 150.0, 'Remaining balance must be 150.0';

  -- Verify booking updated
  ASSERT EXISTS (
    SELECT 1 FROM public.bookings
    WHERE id = v_test_booking AND payment_status = 'paid' AND payment_method = 'app_wallet'
  ), 'Booking must be marked paid via app_wallet';

  -- Repeat payment (idempotent)
  v_pay_res := public.pay_with_wallet(v_test_booking, 100.0, 'pay_test_key_001');
  ASSERT (v_pay_res->>'idempotent')::boolean = true OR (v_pay_res->>'already_paid')::boolean = true, 'Payment should be idempotent or already paid';

  -- Test Insufficient Balance Error on unpaid booking
  BEGIN
    PERFORM public.pay_with_wallet(v_test_booking_2, 999.0, 'pay_insufficient_key');
  EXCEPTION WHEN SQLSTATE '55000' THEN
    v_insufficient_caught := true;
  END;
  ASSERT v_insufficient_caught = true, 'Insufficient balance must throw 55000';

  -- ==========================================================================
  -- Test 3: Refund to Wallet
  -- ==========================================================================
  RAISE NOTICE 'Testing Refund to Wallet...';
  
  -- Switch caller to owner (who has billing_checkout)
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_test_owner::text, 'role', 'authenticated')::text, true);

  v_refund_res := public.refund_to_wallet(v_test_booking, 50.0, 'Booking modified refund');
  ASSERT (v_refund_res->>'success')::boolean = true, 'Refund to wallet must succeed';
  ASSERT (v_refund_res->>'balance_after')::numeric = 200.0, 'Balance after refund must be 200.0 (150 + 50)';

  -- Verify wallet transaction ledger
  ASSERT (
    SELECT count(*) FROM public.wallet_transactions
    WHERE user_id = v_test_customer
  ) = 3, 'Must have exactly 3 transactions: topup, payment, refund';

  -- ==========================================================================
  -- Test 4: Group Booking & Invite Friends
  -- ==========================================================================
  RAISE NOTICE 'Testing Group Booking Invites...';
  
  -- Customer invites friend by UUID and another by phone
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_test_customer::text, 'role', 'authenticated')::text, true);

  v_invite_res := public.invite_friends_to_booking(
    v_test_booking,
    ARRAY[v_test_friend],
    ARRAY['01099998888'],
    'player'
  );
  ASSERT (v_invite_res->>'success')::boolean = true, 'Invite must succeed';
  ASSERT (v_invite_res->>'invites_created')::integer = 2, 'Must create 2 invites';

  -- Verify notification was created for registered friend
  ASSERT EXISTS (
    SELECT 1 FROM public.notifications
    WHERE user_id = v_test_friend AND metadata->>'booking_id' = v_test_booking::text
  ), 'Notification must be created for invited friend';

  -- Get participants
  v_participants_res := public.get_booking_participants(v_test_booking);
  ASSERT jsonb_array_length(v_participants_res) = 2, 'Booking must have 2 participants';

  -- Friend accepts invite
  SELECT id INTO v_invite_id
  FROM public.booking_group_invites
  WHERE booking_id = v_test_booking AND invitee_id = v_test_friend;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_test_friend::text, 'role', 'authenticated')::text, true);
  v_respond_res := public.respond_group_booking_invite(v_invite_id, 'accepted');
  ASSERT (v_respond_res->>'success')::boolean = true, 'Respond to invite must succeed';
  ASSERT v_respond_res->>'status' = 'accepted', 'Status must be accepted';

  -- ==========================================================================
  -- Test 5: Corporate & Event Booking Packages
  -- ==========================================================================
  RAISE NOTICE 'Testing Corporate & Event Booking Packages...';
  
  -- Create event package
  INSERT INTO public.event_packages (
    id,
    lounge_id,
    title_ar,
    title_en,
    base_price,
    min_attendees,
    max_attendees,
    per_person_price,
    duration_hours
  ) VALUES (
    v_event_pkg_id,
    v_test_lounge,
    'حفل عيد ميلاد جيمينج',
    'Gaming Birthday Party',
    1000.0,
    10,
    30,
    50.0,
    3.0
  );

  -- Customer submits request for 12 attendees (base 1000 + 2*50 = 1100 estimated)
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_test_customer::text, 'role', 'authenticated')::text, true);

  v_event_req_res := public.submit_event_booking_request(
    v_test_lounge,
    'birthday',
    (CURRENT_DATE + 5),
    '18:00'::time,
    '21:00'::time,
    12,
    v_event_pkg_id,
    'Need custom PlayStation tournament cake'
  );
  ASSERT (v_event_req_res->>'success')::boolean = true, 'Event request must succeed';
  ASSERT (v_event_req_res->>'estimated_price')::numeric = 1100.0, 'Estimated price must be 1100.0';
  v_event_req_id := (v_event_req_res->>'request_id')::uuid;

  -- Owner reviews and quotes the event
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_test_owner::text, 'role', 'authenticated')::text, true);

  v_event_review_res := public.review_event_booking_request(
    v_event_req_id,
    'quote',
    1200.0, -- quoted price
    300.0,  -- deposit required
    'Cake service included with additional decorations'
  );
  ASSERT (v_event_review_res->>'success')::boolean = true, 'Event review must succeed';
  ASSERT v_event_review_res->>'status' = 'quoted', 'Status must be quoted';

  -- Verify notification sent to customer
  ASSERT EXISTS (
    SELECT 1 FROM public.notifications
    WHERE user_id = v_test_customer AND metadata->>'request_id' = v_event_req_id::text
  ), 'Customer must receive notification on event quote';

  -- ==========================================================================
  -- Test 6: Smart Offers & Coupon Budget Engine
  -- ==========================================================================
  RAISE NOTICE 'Testing Smart Offers & Coupon Budget Engine...';
  
  INSERT INTO public.promotions (
    id,
    lounge_id,
    title,
    title_ar,
    title_en,
    code,
    discount_type,
    discount_value,
    max_total_budget,
    current_budget_used,
    max_uses_per_user,
    min_booking_amount,
    is_active
  ) VALUES (
    v_promo_id,
    v_test_lounge,
    'Summer Promo',
    'عرض الصيف',
    'Summer Promo',
    'SUMMER20',
    'percentage',
    20.0,   -- 20%
    100.0,  -- max budget 100 EGP total
    0.0,
    2,      -- max 2 uses per user
    80.0,   -- min booking 80 EGP
    true
  );

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_test_customer::text, 'role', 'authenticated')::text, true);

  -- Validate for 100 EGP booking (discount 20 EGP)
  v_promo_val_res := public.validate_and_apply_promo_code(v_test_lounge, v_test_room, 'SUMMER20', 100.0);
  ASSERT (v_promo_val_res->>'valid')::boolean = true, 'Promo code must be valid';
  ASSERT (v_promo_val_res->>'discount_applied')::numeric = 20.0, 'Discount must be 20.0';
  ASSERT (v_promo_val_res->>'final_amount')::numeric = 80.0, 'Final amount must be 80.0';

  -- Record usage
  PERFORM public.record_promotion_usage(v_promo_id, v_test_booking, 20.0);

  -- Check min spend validation (< 80 EGP)
  v_promo_min_res := public.validate_and_apply_promo_code(v_test_lounge, v_test_room, 'SUMMER20', 50.0);
  ASSERT (v_promo_min_res->>'valid')::boolean = false, 'Promo must be invalid if min spend not met';
  ASSERT v_promo_min_res->>'error' = 'MINIMUM_AMOUNT_NOT_MET', 'Error must be MINIMUM_AMOUNT_NOT_MET';

  -- Check budget cap enforcement
  UPDATE public.promotions SET current_budget_used = 90.0 WHERE id = v_promo_id;
  -- With current 90.0 and 100 max budget, a 20 EGP discount would total 110 > 100
  v_promo_budget_res := public.validate_and_apply_promo_code(v_test_lounge, v_test_room, 'SUMMER20', 100.0);
  ASSERT (v_promo_budget_res->>'valid')::boolean = false, 'Promo must be invalid if budget cap exceeded';
  ASSERT v_promo_budget_res->>'error' = 'BUDGET_CAP_EXCEEDED', 'Error must be BUDGET_CAP_EXCEEDED';

  -- ==========================================================================
  -- Test 7: Financial Loss Prevention & Risk Audit Layer
  -- ==========================================================================
  RAISE NOTICE 'Testing Financial Loss Prevention & Risk Audit...';
  
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_test_owner::text, 'role', 'authenticated')::text, true);

  v_risk_log_res := public.log_financial_risk_event(
    v_test_lounge,
    v_test_shift,
    'high',
    'price_override',
    '{"reason": "Customer complaint", "original_price": 200, "overridden_price": 100}'::jsonb
  );
  ASSERT (v_risk_log_res->>'success')::boolean = true, 'Risk log must succeed';

  v_risk_timeline_res := public.get_lounge_loss_prevention_timeline(v_test_lounge);
  ASSERT jsonb_array_length(v_risk_timeline_res) >= 1, 'Risk timeline must return at least 1 record';
  ASSERT (v_risk_timeline_res->0->>'action_type') = 'price_override', 'Action type must match';

  -- ==========================================================================
  -- Test 8: Tournament Payment Submission Hardening
  -- ==========================================================================
  RAISE NOTICE 'Testing Tournament Payment Submission Hardening...';

  -- Verify obsolete 6-parameter overload was removed
  ASSERT to_regprocedure('public.submit_tournament_payment(uuid,uuid,uuid,numeric,text,text)') IS NULL,
    'Obsolete 6-parameter submit_tournament_payment must not exist';

  -- Setup tournament
  SELECT id INTO v_city_id FROM public.cities LIMIT 1;

  INSERT INTO public.tournaments (
    id,
    lounge_id,
    city_id,
    title_ar,
    title_en,
    game_name,
    bracket_size,
    max_participants,
    entry_fee,
    registration_opens_at,
    registration_closes_at,
    check_in_opens_at,
    check_in_closes_at,
    tournament_starts_at,
    status,
    created_by
  ) VALUES (
    v_tournament_id,
    v_test_lounge,
    v_city_id,
    'بطولة تيكن 8',
    'Tekken 8 Clash',
    'Tekken 8',
    16,
    16,
    150.0,
    now() - interval '1 day',
    now() + interval '2 days',
    now() + interval '3 days',
    now() + interval '3 days 1 hour',
    now() + interval '3 days 2 hours',
    'registration_open',
    v_test_owner
  );

  INSERT INTO public.tournament_participants (
    id,
    tournament_id,
    user_id,
    registration_status,
    payment_status
  ) VALUES (
    v_participant_id,
    v_tournament_id,
    v_test_customer,
    'pending_payment',
    'unpaid'
  );

  -- Switch to customer caller
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_test_customer::text, 'role', 'authenticated')::text, true);

  -- Test amount mismatch check (expected 150, passed 100)
  BEGIN
    PERFORM public.submit_tournament_payment(v_participant_id, 100.0, 'vodafone_cash', 'https://receipts.com/rec1.jpg');
  EXCEPTION WHEN SQLSTATE '22023' THEN
    v_wrong_amount_caught := true;
  END;
  ASSERT v_wrong_amount_caught = true, 'Payment amount mismatch must throw 22023';

  -- Valid submission
  v_tournament_res := public.submit_tournament_payment(v_participant_id, 150.0, 'vodafone_cash', 'https://receipts.com/rec1.jpg');
  ASSERT (v_tournament_res->>'payment_status') = 'pending', 'Payment status must be pending';
  ASSERT (v_tournament_res->>'payment_method') = 'vodafone_cash', 'Payment method must be vodafone_cash';

  ASSERT EXISTS (
    SELECT 1 FROM public.tournament_payment_submissions
    WHERE participant_id = v_participant_id AND amount = 150.0
  ), 'Submission record must be created';

  -- ==========================================================================
  -- Test 9: PlaySpot Pass Roaming Framework
  -- ==========================================================================
  RAISE NOTICE 'Testing PlaySpot Pass Roaming Framework...';

  -- Initially no roaming agreement
  v_roam_elig_1 := public.check_roaming_pass_eligibility(v_test_lounge, v_test_customer);
  ASSERT (v_roam_elig_1->>'eligible')::boolean = false, 'Customer cannot roam without agreement';
  ASSERT v_roam_elig_1->>'reason' = 'LOUNGE_NOT_ROAMING_PARTNER', 'Reason must be partner mismatch';

  -- Insert active roaming agreement
  INSERT INTO public.lounge_roaming_agreements (
    lounge_id,
    allows_roaming_pass,
    settlement_discount_rate,
    status
  ) VALUES (
    v_test_lounge,
    true,
    0.80,
    'active'
  );

  -- Still not eligible because user has no package
  v_roam_elig_1 := public.check_roaming_pass_eligibility(v_test_lounge, v_test_customer);
  ASSERT (v_roam_elig_1->>'eligible')::boolean = false, 'Customer has no active pass yet';

  -- Give user an active membership package
  INSERT INTO public.membership_packages (
    id,
    lounge_id,
    name_ar,
    name_en,
    total_hours,
    price,
    validity_days,
    is_active
  ) VALUES (
    v_pkg_id,
    v_test_lounge,
    'باقة جيمينج كبرى',
    'Mega Gaming Pass',
    50,
    1500.0,
    60,
    true
  );

  INSERT INTO public.user_membership_packages (
    user_id,
    package_id,
    lounge_id,
    total_hours,
    remaining_hours,
    purchased_price,
    expires_at,
    status
  ) VALUES (
    v_test_customer,
    v_pkg_id,
    v_test_lounge,
    50,
    50,
    1500.0,
    now() + interval '30 days',
    'active'
  );

  -- Re-check eligibility
  v_roam_elig_2 := public.check_roaming_pass_eligibility(v_test_lounge, v_test_customer);
  ASSERT (v_roam_elig_2->>'eligible')::boolean = true, 'Customer must now be eligible for roaming pass';

  RAISE NOTICE '=== ALL PHASE 7 TESTS PASSED SUCCESSFULLY! ===';
END;
$$;
