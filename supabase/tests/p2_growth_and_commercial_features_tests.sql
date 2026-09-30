-- ============================================================================
-- Test Suite: Phase 6 (P2) Growth & Commercial Features Tests
-- File: supabase/tests/p2_growth_and_commercial_features_tests.sql
-- ============================================================================

DO $$
DECLARE
  v_test_owner uuid := gen_random_uuid();
  v_test_customer uuid := gen_random_uuid();
  v_test_lounge uuid := gen_random_uuid();
  v_test_shift uuid := gen_random_uuid();
  v_test_room uuid := gen_random_uuid();
  v_test_booking uuid := gen_random_uuid();
  v_test_pkg uuid;
  v_user_pkg_res jsonb;
  v_user_pkg_id uuid;
  v_deduct_res jsonb;
  v_refund_res jsonb;
  v_avail_pkgs jsonb;
  v_quote_std jsonb;
  v_quote_peak jsonb;
  v_quote_special jsonb;
  v_noshow_res jsonb;
  v_intel_res jsonb;
  v_segments_res jsonb;
  v_campaign_res jsonb;
  v_campaign_id uuid;
  v_worker_res jsonb;
  v_extra_1 uuid := gen_random_uuid();
  v_extra_2 uuid := gen_random_uuid();
  v_combo_id uuid := gen_random_uuid();
  v_menu_res jsonb;
  v_upsell_res jsonb;
  v_rule_id uuid := gen_random_uuid();
  v_order_res jsonb;
  v_stock_1 integer;
  v_stock_2 integer;
  v_out_of_stock_caught boolean := false;
BEGIN
  RAISE NOTICE '=== STARTING PHASE 6 GROWTH & COMMERCIAL FEATURES TESTS ===';

  -- 1. Setup Test Users
  INSERT INTO auth.users (id, email, raw_user_meta_data)
  VALUES 
    (v_test_owner, 'owner_p6@test.com', '{"full_name": "P6 Lounge Owner"}'::jsonb),
    (v_test_customer, 'customer_p6@test.com', '{"full_name": "P6 Test Customer"}'::jsonb)
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.profiles (id, full_name, role)
  VALUES 
    (v_test_owner, 'P6 Lounge Owner', 'owner'),
    (v_test_customer, 'P6 Test Customer', 'user')
  ON CONFLICT (id) DO UPDATE SET full_name = EXCLUDED.full_name, role = EXCLUDED.role;

  -- 2. Setup Lounge with payment method and deposit policy
  INSERT INTO public.lounges (
    id,
    name,
    owner_id,
    vodafone_cash_number,
    status,
    deposit_policy_type,
    deposit_amount,
    no_show_grace_minutes,
    auto_cancel_no_show,
    allow_cash_payment,
    require_prepaid_first_time
  ) VALUES (
    v_test_lounge,
    'PlaySpot Commercial Lounge',
    v_test_owner,
    '01012345678',
    'active',
    'fixed',
    50.0,
    15,
    true,
    true,
    false
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

  -- Setup Test Room
  INSERT INTO public.rooms (
    id,
    lounge_id,
    name,
    hourly_rate_single,
    hourly_rate_multi,
    extra_controller_price,
    is_active,
    is_available,
    status
  ) VALUES (
    v_test_room,
    v_test_lounge,
    'VIP Gaming Pod 1',
    100.0,
    150.0,
    25.0,
    true,
    true,
    'available'
  );

  -- Simulate authenticated session as owner
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_test_owner::text, 'role', 'authenticated')::text, true);

  -- ==========================================================================
  -- Test 1: Memberships & Hour Packages
  -- ==========================================================================
  RAISE NOTICE '--- Testing Memberships & Hour Packages ---';

  INSERT INTO public.membership_packages (
    lounge_id,
    name_ar,
    name_en,
    total_hours,
    price,
    validity_days,
    peak_allowed,
    is_active
  ) VALUES (
    v_test_lounge,
    'باقة 10 ساعات جيمينج',
    '10 Hours Gaming Pack',
    10.0,
    800.0,
    30,
    true,
    true
  ) RETURNING id INTO v_test_pkg;

  -- Purchase package for customer
  v_user_pkg_res := public.purchase_membership_package(
    p_package_id => v_test_pkg,
    p_payment_method => 'cash',
    p_user_id => v_test_customer
  );

  v_user_pkg_id := (v_user_pkg_res->>'user_package_id')::uuid;
  ASSERT v_user_pkg_id IS NOT NULL, 'Failed to purchase membership package';
  ASSERT (v_user_pkg_res->>'remaining_hours')::numeric = 10.0, 'Initial remaining hours mismatch';

  -- Verify shift payment record created
  ASSERT EXISTS (
    SELECT 1 FROM public.shift_payments
    WHERE shift_id = v_test_shift AND category = 'package_sale' AND amount = 800.0
  ), 'Shift payment for package sale not recorded';

  -- Simulate customer authenticated session
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_test_customer::text, 'role', 'authenticated')::text, true);

  -- Check available packages
  v_avail_pkgs := public.get_user_available_packages(v_test_lounge, v_test_room);
  ASSERT jsonb_array_length(v_avail_pkgs) = 1, 'Customer available packages count mismatch';

  -- Create booking for customer
  INSERT INTO public.bookings (
    id,
    lounge_id,
    room_id,
    user_id,
    date,
    start_time,
    end_time,
    total_price,
    status,
    payment_method,
    payment_status,
    deposit_required,
    deposit_paid,
    deposit_status
  ) VALUES (
    v_test_booking,
    v_test_lounge,
    v_test_room,
    v_test_customer,
    CURRENT_DATE + 1,
    '14:00:00',
    '16:30:00',
    250.0,
    'pending',
    'app_wallet',
    'paid',
    50.0,
    50.0,
    'paid'
  );

  -- Deduct 2.5 hours for booking
  v_deduct_res := public.deduct_package_hours(
    p_user_package_id => v_user_pkg_id,
    p_booking_id => v_test_booking,
    p_hours => 2.5
  );
  ASSERT (v_deduct_res->>'remaining_hours')::numeric = 7.5, 'Remaining hours after deduction mismatch';

  -- Verify deduction transaction audit
  ASSERT EXISTS (
    SELECT 1 FROM public.package_hour_transactions
    WHERE user_package_id = v_user_pkg_id AND delta_hours = -2.5 AND transaction_type = 'booking_usage'
  ), 'Package usage transaction not logged';

  -- Refund package hours on cancellation
  v_refund_res := public.refund_package_hours(
    p_booking_id => v_test_booking,
    p_reason => 'Customer cancelled early'
  );
  ASSERT (v_refund_res->>'refunded_hours')::numeric = 2.5, 'Refunded hours mismatch';

  SELECT remaining_hours INTO v_stock_1 FROM public.user_membership_packages WHERE id = v_user_pkg_id;
  ASSERT v_stock_1 = 10, 'Package remaining hours not restored after refund';

  RAISE NOTICE 'Memberships & Hour Packages tests PASSED!';

  -- ==========================================================================
  -- Test 2: Dynamic Pricing & Calendar Overrides
  -- ==========================================================================
  RAISE NOTICE '--- Testing Dynamic Peak & Special Date Pricing ---';

  -- Setup Recurring Peak Pricing Rule: Fridays & Saturdays 18:00 - 02:00, Multiplier 1.50 (+50%)
  INSERT INTO public.lounge_pricing_rules (
    lounge_id,
    room_id,
    name,
    day_of_week,
    start_time,
    end_time,
    rate_multiplier,
    is_active
  ) VALUES (
    v_test_lounge,
    v_test_room,
    'Weekend Evening Peak',
    ARRAY[5, 6], -- Friday, Saturday
    '18:00:00',
    '02:00:00',
    1.50,
    true
  );

  -- Setup Special Event Date: 2026-10-06 (Holiday), Multiplier 2.00 (+100%)
  INSERT INTO public.lounge_special_pricing_dates (
    lounge_id,
    room_id,
    name,
    target_date,
    start_time,
    end_time,
    rate_multiplier,
    is_active
  ) VALUES (
    v_test_lounge,
    v_test_room,
    'National Holiday Gaming Night',
    '2026-10-06',
    '00:00:00',
    '23:59:59',
    2.00,
    true
  );

  -- 1. Standard Day/Time Quote: Wednesday 14:00 - 16:00 (120 mins) @ 100/hr = 200 EGP
  v_quote_std := public.quote_booking_price(
    p_room_id => v_test_room,
    p_date => '2026-10-07', -- Wednesday
    p_start => '14:00:00',
    p_end => '16:00:00'
  );
  ASSERT (v_quote_std->>'has_peak_rates')::boolean IS FALSE, 'Standard quote should not have peak rates';
  ASSERT (v_quote_std->>'effective_hourly_rate')::numeric = 100.0, 'Standard rate mismatch';
  ASSERT (v_quote_std->>'final_total')::numeric = 200.0, 'Standard total mismatch';

  -- 2. Peak Hours Quote: Friday 19:00 - 21:00 (120 mins) @ 150/hr = 300 EGP
  v_quote_peak := public.quote_booking_price(
    p_room_id => v_test_room,
    p_date => '2026-10-09', -- Friday
    p_start => '19:00:00',
    p_end => '21:00:00'
  );
  ASSERT (v_quote_peak->>'has_peak_rates')::boolean IS TRUE, 'Peak quote should flag peak rates';
  ASSERT (v_quote_peak->>'effective_hourly_rate')::numeric = 150.0, 'Peak rate multiplier mismatch';
  ASSERT (v_quote_peak->>'final_total')::numeric = 300.0, 'Peak total mismatch';

  -- 3. Special Event Date Quote: 2026-10-06 14:00 - 16:00 (120 mins) @ 200/hr = 400 EGP
  v_quote_special := public.quote_booking_price(
    p_room_id => v_test_room,
    p_date => '2026-10-06',
    p_start => '14:00:00',
    p_end => '16:00:00'
  );
  ASSERT (v_quote_special->>'pricing_tier') = 'special_date', 'Special date pricing tier mismatch';
  ASSERT (v_quote_special->>'effective_hourly_rate')::numeric = 200.0, 'Special date hourly rate mismatch';
  ASSERT (v_quote_special->>'final_total')::numeric = 400.0, 'Special date total mismatch';

  RAISE NOTICE 'Dynamic Pricing tests PASSED!';

  -- ==========================================================================
  -- Test 3: No-Show Protection & Deposits
  -- ==========================================================================
  RAISE NOTICE '--- Testing No-Show Protection & Deposits ---';

  -- Switch back to owner session
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_test_owner::text, 'role', 'authenticated')::text, true);

  -- Mark booking as no-show
  v_noshow_res := public.mark_booking_no_show(
    p_booking_id => v_test_booking,
    p_notes => 'Customer did not arrive 20 minutes past start time'
  );

  ASSERT (v_noshow_res->>'is_no_show')::boolean IS TRUE, 'Booking not marked no-show';
  ASSERT (v_noshow_res->>'deposit_forfeited')::numeric = 50.0, 'Forfeited deposit mismatch';

  -- Verify booking record updated
  ASSERT EXISTS (
    SELECT 1 FROM public.bookings
    WHERE id = v_test_booking AND status = 'cancelled'::public.booking_status
      AND is_no_show = true AND deposit_status = 'forfeited'
  ), 'Booking record not updated with no-show and forfeited deposit';

  -- Verify shift payment record for forfeited deposit
  ASSERT EXISTS (
    SELECT 1 FROM public.shift_payments
    WHERE shift_id = v_test_shift AND category = 'deposit_forfeited' AND amount = 50.0
  ), 'Shift payment for forfeited deposit not logged';

  RAISE NOTICE 'No-Show Protection tests PASSED!';

  -- ==========================================================================
  -- Test 4: Revenue Intelligence & Analytics
  -- ==========================================================================
  RAISE NOTICE '--- Testing Revenue Intelligence Analytics ---';

  -- Create a completed booking to have gaming revenue
  INSERT INTO public.bookings (
    lounge_id,
    room_id,
    user_id,
    date,
    start_time,
    end_time,
    total_price,
    status,
    payment_method,
    payment_status,
    is_first_booking,
    created_at
  ) VALUES (
    v_test_lounge,
    v_test_room,
    v_test_customer,
    CURRENT_DATE,
    '10:00:00',
    '12:00:00',
    200.0,
    'completed',
    'card',
    'paid',
    false,
    now()
  );

  v_intel_res := public.get_lounge_revenue_intelligence(
    p_lounge_id => v_test_lounge,
    p_start_date => now() - interval '7 days',
    p_end_date => now() + interval '1 day'
  );

  ASSERT v_intel_res->'revenue' IS NOT NULL, 'Revenue block missing in intelligence response';
  ASSERT (v_intel_res->'revenue'->>'gaming_revenue')::numeric >= 100.0, 'Gaming revenue aggregation error';
  ASSERT (v_intel_res->'revenue'->>'packages_revenue')::numeric >= 800.0, 'Packages revenue aggregation error';
  ASSERT (v_intel_res->'revenue'->>'deposits_forfeited_revenue')::numeric >= 50.0, 'Deposits revenue aggregation error';
  ASSERT (v_intel_res->'operations'->>'total_rooms')::integer >= 1, 'Total rooms in operations mismatch';
  ASSERT (v_intel_res->'kpis'->>'no_show_bookings')::integer >= 1, 'No show count mismatch';

  RAISE NOTICE 'Revenue Intelligence tests PASSED!';

  -- ==========================================================================
  -- Test 5: CRM Segmentation & Win-back Campaigns
  -- ==========================================================================
  RAISE NOTICE '--- Testing CRM & Win-back Engine ---';

  v_segments_res := public.get_lounge_customer_segments(v_test_lounge);
  ASSERT (v_segments_res->>'all_customers')::integer >= 1, 'Customer segments all_customers count mismatch';

  -- Create campaign
  v_campaign_res := public.create_crm_campaign(
    p_lounge_id => v_test_lounge,
    p_title => 'We miss you at PlaySpot!',
    p_message_ar => 'خصم 25% على حجزك القادم',
    p_message_en => '25% off your next booking',
    p_segment_type => 'all',
    p_promo_code => 'COMEBACK25',
    p_discount_percent => 25.0
  );

  v_campaign_id := (v_campaign_res->>'campaign_id')::uuid;
  ASSERT v_campaign_id IS NOT NULL, 'CRM Campaign creation failed';
  ASSERT (v_campaign_res->>'target_count')::integer >= 1, 'CRM target user count mismatch';

  -- Run CRM dispatch worker
  v_worker_res := public.process_pending_crm_dispatches(10);
  ASSERT (v_worker_res->>'sent')::integer >= 1, 'CRM worker failed to dispatch notifications';

  -- Verify in-app notification created
  ASSERT EXISTS (
    SELECT 1 FROM public.notifications
    WHERE user_id = v_test_customer AND type = 'offer'
  ), 'Promotional notification not received by user';

  RAISE NOTICE 'CRM & Win-back Engine tests PASSED!';

  -- ==========================================================================
  -- Test 6: Canteen Combos, Stock Tracking & Checkout Upsell
  -- ==========================================================================
  RAISE NOTICE '--- Testing Canteen Combos & Upsell ---';

  -- Create Extras with stock tracking
  INSERT INTO public.extras (
    id,
    lounge_id,
    name,
    name_ar,
    name_en,
    price,
    category,
    track_stock,
    stock_quantity,
    is_active,
    is_available
  ) VALUES 
    (v_extra_1, v_test_lounge, 'Pepsi Can', 'بيبسي كان', 'Pepsi Can', 20.0, 'drinks', true, 10, true, true),
    (v_extra_2, v_test_lounge, 'Caramel Popcorn', 'فشار كراميل', 'Caramel Popcorn', 30.0, 'snacks', true, 5, true, true);

  -- Create Combo: 1 Pepsi + 1 Popcorn = 40 EGP (Separate price = 50, Savings = 10)
  INSERT INTO public.canteen_combos (
    id,
    lounge_id,
    name_ar,
    name_en,
    description_ar,
    description_en,
    price,
    is_active
  ) VALUES (
    v_combo_id,
    v_test_lounge,
    'كومبو السهرة',
    'Gaming Night Combo',
    'بيبسي كان + فشار كراميل',
    'Pepsi Can + Caramel Popcorn',
    40.0,
    true
  );

  INSERT INTO public.canteen_combo_items (combo_id, extra_id, quantity)
  VALUES 
    (v_combo_id, v_extra_1, 1),
    (v_combo_id, v_extra_2, 1);

  -- Test get_canteen_menu
  v_menu_res := public.get_canteen_menu(v_test_lounge);
  ASSERT jsonb_array_length(v_menu_res->'extras') >= 2, 'Menu extras count mismatch';
  ASSERT jsonb_array_length(v_menu_res->'combos') >= 1, 'Menu combos count mismatch';
  ASSERT (v_menu_res->'combos'->0->>'separate_items_price')::numeric = 50.0, 'Combo separate items price mismatch';
  ASSERT (v_menu_res->'combos'->0->>'savings')::numeric = 10.0, 'Combo savings calculation mismatch';
  ASSERT (v_menu_res->'combos'->0->>'is_available')::boolean IS TRUE, 'Combo should be in stock and available';

  -- Create Upsell Rule for this combo
  INSERT INTO public.canteen_upsell_rules (
    id,
    lounge_id,
    rule_name,
    trigger_type,
    target_type,
    combo_id,
    discount_percent,
    priority,
    is_active
  ) VALUES (
    v_rule_id,
    v_test_lounge,
    'Night Snack Upsell',
    'active_session',
    'combo',
    v_combo_id,
    10.0,
    1,
    true
  );

  -- Test get_upsell_suggestions
  v_upsell_res := public.get_upsell_suggestions(v_test_booking);
  ASSERT jsonb_array_length(v_upsell_res) >= 1, 'Upsell suggestions count mismatch';
  ASSERT (v_upsell_res->0->>'final_price')::numeric = 36.0, 'Upsell discounted final price mismatch';

  -- Test record_upsell_event
  PERFORM public.record_upsell_event(v_rule_id, v_test_booking, 'impression');
  ASSERT EXISTS (
    SELECT 1 FROM public.canteen_upsell_events WHERE rule_id = v_rule_id AND event_type = 'impression'
  ), 'Upsell impression event not recorded';

  -- Place Canteen Order for 2 Combos (2 * 40 = 80 EGP)
  v_order_res := public.place_canteen_order(
    p_booking_id => v_test_booking,
    p_items => jsonb_build_array(
      jsonb_build_object(
        'combo_id', v_combo_id,
        'quantity', 2
      )
    ),
    p_lounge_id => v_test_lounge,
    p_user_id => v_test_customer,
    p_note => 'Please deliver hot'
  );

  ASSERT (v_order_res->>'total_price')::numeric = 80.0, 'Canteen order total price mismatch';

  -- Verify constituent stock was decremented properly
  -- Pepsi was 10, now should be 10 - 2 = 8
  -- Popcorn was 5, now should be 5 - 2 = 3
  SELECT stock_quantity INTO v_stock_1 FROM public.extras WHERE id = v_extra_1;
  SELECT stock_quantity INTO v_stock_2 FROM public.extras WHERE id = v_extra_2;
  ASSERT v_stock_1 = 8, 'Pepsi stock after combo order mismatch';
  ASSERT v_stock_2 = 3, 'Popcorn stock after combo order mismatch';

  -- Test Out of stock validation: attempting to order 5 more combos (requires 5 popcorn, only 3 left!)
  BEGIN
    PERFORM public.place_canteen_order(
      p_booking_id => v_test_booking,
      p_items => jsonb_build_array(
        jsonb_build_object('combo_id', v_combo_id, 'quantity', 5)
      )
    );
  EXCEPTION WHEN OTHERS THEN
    v_out_of_stock_caught := true;
  END;
  ASSERT v_out_of_stock_caught IS TRUE, 'Out of stock validation failed to reject over-order';

  RAISE NOTICE 'Canteen Combos & Upsell tests PASSED!';

  RAISE NOTICE '=== ALL PHASE 6 TESTS PASSED SUCCESSFULLY! ===';
END;
$$;
