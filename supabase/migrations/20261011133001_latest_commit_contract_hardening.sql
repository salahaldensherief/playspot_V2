BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';

CREATE OR REPLACE FUNCTION public.get_pending_payouts_overview()
RETURNS TABLE(lounge_id uuid,lounge_name text,pending_amount numeric,total_transactions bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  PERFORM private.assert_payout_admin();
  RETURN QUERY SELECT p.lounge_id,COALESCE(l.name_ar,l.name_en,l.name)::text,
    sum(CASE WHEN p.funds_holder='platform' THEN p.net_to_lounge ELSE -p.commission END),count(*)
  FROM private.payment_settlement_values p JOIN public.lounges l ON l.id=p.lounge_id
  WHERE p.status='completed' AND p.payout_id IS NULL
    AND NOT EXISTS (SELECT 1 FROM private.cash_collection_receipts r JOIN public.bookings b ON b.id=r.booking_id
      WHERE r.booking_id=p.booking_id AND (b.status::text<>'completed' OR b.payment_status IS DISTINCT FROM 'paid'))
  GROUP BY p.lounge_id,COALESCE(l.name_ar,l.name_en,l.name)
  HAVING bool_and(p.financials_valid) AND count(*) FILTER(WHERE p.funds_holder IS NULL)=0
    AND sum(CASE WHEN p.funds_holder='platform' THEN p.net_to_lounge ELSE -p.commission END)>0;
END; $$;

CREATE OR REPLACE FUNCTION public.create_payout(p_lounge_id uuid,p_period_start date,p_period_end date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_payout uuid;v_total numeric;v_count bigint;v_ids uuid[];
BEGIN
  PERFORM private.assert_payout_admin();
  IF p_lounge_id IS NULL OR p_period_start IS NULL OR p_period_end IS NULL OR p_period_start>p_period_end THEN
    RAISE EXCEPTION 'INVALID_PAYOUT_PERIOD' USING ERRCODE='22023';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(p_lounge_id::text,0));
  IF EXISTS (SELECT 1 FROM public.payouts WHERE lounge_id=p_lounge_id
    AND status IN ('pending','approved','processing','paid','needs_review')
    AND daterange(period_start,period_end,'[]') && daterange(p_period_start,p_period_end,'[]')) THEN
    RAISE EXCEPTION 'OVERLAPPING_ACTIVE_PAYOUT' USING ERRCODE='55000';
  END IF;
  -- A canonical collector locks bookings before payments. Preserve that lock order.
  PERFORM 1 FROM public.bookings b WHERE EXISTS(SELECT 1 FROM public.payments p
    WHERE p.booking_id=b.id AND p.lounge_id=p_lounge_id AND p.payout_id IS NULL
      AND p.status='completed' AND (p.paid_at AT TIME ZONE 'Africa/Cairo')::date<=p_period_end)
    ORDER BY b.id FOR UPDATE;
  PERFORM 1 FROM public.payments WHERE lounge_id=p_lounge_id AND payout_id IS NULL
    AND status='completed' AND (paid_at AT TIME ZONE 'Africa/Cairo')::date<=p_period_end ORDER BY id FOR UPDATE;
  IF EXISTS(SELECT 1 FROM private.payment_settlement_values WHERE lounge_id=p_lounge_id
    AND status='completed' AND payout_id IS NULL AND settlement_date<=p_period_end AND financials_valid IS NOT TRUE) THEN
    RAISE EXCEPTION 'PAYMENT_FINANCIALS_REQUIRE_RECONCILIATION' USING ERRCODE='55000';
  END IF;
  IF EXISTS(SELECT 1 FROM private.payment_settlement_values WHERE lounge_id=p_lounge_id
    AND status='completed' AND payout_id IS NULL AND settlement_date<=p_period_end AND funds_holder IS NULL) THEN
    RAISE EXCEPTION 'PAYMENT_FUNDS_CUSTODY_REQUIRED' USING ERRCODE='55000';
  END IF;
  SELECT array_agg(p.id ORDER BY p.id),count(*),sum(CASE WHEN p.funds_holder='platform' THEN p.net_to_lounge ELSE -p.commission END)
    INTO v_ids,v_count,v_total FROM private.payment_settlement_values p
    WHERE p.lounge_id=p_lounge_id AND p.status='completed' AND p.payout_id IS NULL
      AND p.settlement_date<=p_period_end AND (p.funds_holder='lounge' OR p.settlement_date>=p_period_start)
      AND NOT EXISTS (SELECT 1 FROM private.cash_collection_receipts r JOIN public.bookings b ON b.id=r.booking_id
        WHERE r.booking_id=p.booking_id AND (b.status::text<>'completed' OR b.payment_status IS DISTINCT FROM 'paid'));
  IF v_count=0 OR v_total<=0 THEN
    RETURN jsonb_build_object('success',false,'error','NO_POSITIVE_SETTLEMENT_BALANCE');
  END IF;
  INSERT INTO public.payouts(lounge_id,period_start,period_end,total_amount,status,created_by)
    VALUES(p_lounge_id,p_period_start,p_period_end,v_total,'pending',auth.uid()) RETURNING id INTO v_payout;
  INSERT INTO private.payout_settlement_entries
    SELECT v_payout,id,lounge_id,funds_holder,payment_method,amount,commission,net_to_lounge,
      CASE WHEN funds_holder='platform' THEN net_to_lounge ELSE -commission END
    FROM private.payment_settlement_values WHERE id=ANY(v_ids);
  UPDATE public.payments SET payout_id=v_payout WHERE id=ANY(v_ids);
  PERFORM private.assert_payout_settlement(v_payout);
  RETURN jsonb_build_object('success',true,'payout_id',v_payout,'amount',v_total,'payment_count',v_count);
END; $$;

CREATE OR REPLACE FUNCTION public.complete_booking_session(p_booking_id uuid, p_action_by uuid DEFAULT NULL::uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_room public.rooms%ROWTYPE;
  v_lounge public.lounges%ROWTYPE;
  v_now timestamptz := now();
  v_start_time timestamptz;
  v_elapsed_minutes integer;
  v_billable_raw integer;
  v_billable_minutes integer;
  v_rounding integer := 15;
  v_minimum integer := 30;
  v_max integer := 720;
  v_rate numeric := 50;
  v_room_price numeric;
  v_total_price numeric;
  v_amount_paid numeric := 0;
  v_amount_due numeric := 0;
  v_snap jsonb;
  v_payment_status text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  PERFORM private.require_active_booking_actor();

  SELECT b.*
  INTO v_booking
  FROM public.bookings AS b
  WHERE b.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT public.is_super_admin()
     AND NOT public.has_lounge_permission(v_booking.lounge_id, 'sessions_control') THEN
    RAISE EXCEPTION 'Not authorized for session control in this lounge' USING ERRCODE = '42501';
  END IF;

  -- Idempotency: if already completed, return existing totals without recalculating
  IF v_booking.status = 'completed'::public.booking_status THEN
    v_amount_paid := private.booking_collected_amount(p_booking_id,v_booking.lounge_id,v_booking.payment_status,v_booking.total_price);
    v_amount_due := GREATEST(0, v_booking.total_price - v_amount_paid);
    v_payment_status := CASE WHEN v_amount_paid>=v_booking.total_price THEN 'paid' WHEN v_amount_paid>0 THEN 'partial' ELSE 'unpaid' END;
    UPDATE public.bookings SET payment_status=v_payment_status,updated_at=v_now
      WHERE id=p_booking_id AND payment_status IS DISTINCT FROM v_payment_status;

    RETURN json_build_object(
      'success', true,
      'booking_id', p_booking_id,
      'lounge_id', v_booking.lounge_id,
      'status', 'completed',
      'final_total', v_booking.total_price,
      'amount_paid', v_amount_paid,
      'amount_due', v_amount_due,
      'payment_status', v_payment_status,
      'idempotent', true
    );
  END IF;

  IF v_booking.status <> 'in_progress'::public.booking_status THEN
    RAISE EXCEPTION 'Only in-progress sessions can be completed' USING ERRCODE = '55000';
  END IF;

  v_amount_paid := private.booking_collected_amount(p_booking_id,v_booking.lounge_id,v_booking.payment_status,v_booking.total_price);

  -- If this is an Open Time session, calculate billing from snapshot
  IF COALESCE(v_booking.is_open_time, false) IS TRUE THEN
    v_snap := v_booking.open_time_pricing_snapshot;

    IF v_snap IS NOT NULL AND v_snap <> '{}'::jsonb THEN
      v_rate := COALESCE((v_snap->>'effective_hourly_rate')::numeric, (v_snap->>'base_hourly_rate')::numeric, 50);
      v_minimum := COALESCE((v_snap->>'minimum_minutes')::integer, 30);
      v_rounding := COALESCE((v_snap->>'rounding_minutes')::integer, 15);
      v_max := COALESCE((v_snap->>'max_minutes')::integer, 720);
    ELSE
      -- Fallback to lounge & room current settings
      SELECT l.* INTO v_lounge FROM public.lounges l WHERE l.id = v_booking.lounge_id;
      SELECT r.* INTO v_room FROM public.rooms r WHERE r.id = v_booking.room_id;
      v_minimum := COALESCE(v_room.open_time_minimum_minutes, v_lounge.open_time_minimum_minutes, 30);
      v_rounding := COALESCE(v_room.open_time_rounding_minutes, v_lounge.open_time_rounding_minutes, 15);
      v_max := COALESCE(v_room.open_time_max_minutes, v_lounge.open_time_max_minutes, 720);
      v_rate := CASE
        WHEN v_booking.play_mode = 'multi' AND COALESCE(v_room.hourly_rate_multi, 0) > 0 THEN v_room.hourly_rate_multi
        ELSE COALESCE(v_room.hourly_rate_single, v_room.hourly_rate, 50)
      END;
    END IF;

    v_start_time := COALESCE(v_booking.open_time_started_at, v_booking.actual_start_time, v_booking.created_at);
    v_elapsed_minutes := GREATEST(1, ROUND(EXTRACT(EPOCH FROM (v_now - v_start_time)) / 60.0)::integer);

    -- Apply max cap as billing ceiling
    IF v_max IS NOT NULL AND v_max > 0 THEN
      v_billable_raw := LEAST(v_elapsed_minutes, v_max);
    ELSE
      v_billable_raw := v_elapsed_minutes;
    END IF;

    -- Apply minimum minutes
    v_billable_raw := GREATEST(v_billable_raw, v_minimum);

    -- Apply rounding
    v_billable_minutes := CEIL(v_billable_raw::numeric / v_rounding::numeric)::integer * v_rounding;

    v_room_price := ROUND((v_rate / 60.0) * v_billable_minutes, 2);
    v_total_price := v_room_price + COALESCE(v_booking.addons_total, 0) - COALESCE(v_booking.discount_amount, 0);

    v_payment_status := CASE WHEN v_amount_paid>=v_total_price THEN 'paid' WHEN v_amount_paid>0 THEN 'partial' ELSE 'unpaid' END;
    UPDATE public.bookings
    SET payment_status=v_payment_status, status = 'completed'::public.booking_status,
        open_time_closed_at = v_now,
        open_time_billing_minutes = v_billable_minutes,
        duration_minutes = v_billable_minutes,
        room_price = v_room_price,
        total_price = v_total_price,
        updated_at = v_now
    WHERE id = p_booking_id;
  ELSE
    -- Standard pre-booked session completion
    v_total_price := v_booking.total_price;
    v_payment_status := CASE WHEN v_amount_paid>=v_total_price THEN 'paid' WHEN v_amount_paid>0 THEN 'partial' ELSE 'unpaid' END;
    UPDATE public.bookings
    SET payment_status=v_payment_status, status = 'completed'::public.booking_status,
        updated_at = v_now
    WHERE id = p_booking_id;
  END IF;

  IF (SELECT total_price FROM public.bookings WHERE id=p_booking_id) IS DISTINCT FROM v_total_price THEN
    RAISE EXCEPTION 'BOOKING_PRICE_CHANGED_DURING_COMPLETION' USING ERRCODE='55000';
  END IF;

  -- Release room
  IF v_booking.room_id IS NOT NULL THEN
    UPDATE public.rooms AS r
    SET status = 'available',
        is_available = true,
        updated_at = v_now
    WHERE r.id = v_booking.room_id
      AND r.lounge_id = v_booking.lounge_id
      AND r.status = 'occupied';
  END IF;

  v_amount_due := GREATEST(0, v_total_price - v_amount_paid);

  RETURN json_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'lounge_id', v_booking.lounge_id,
    'status', 'completed',
    'final_total', v_total_price,
    'amount_paid', v_amount_paid,
    'amount_due', v_amount_due,
    'payment_status', v_payment_status
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.complete_booking_payment(p_booking_id uuid, p_payment_method text DEFAULT 'cash'::text, p_final_amount numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_amount numeric;
  v_paid numeric;
  v_collected jsonb;
  v_commission numeric;
  v_shift_id uuid;
  v_new_status public.booking_status;
  v_voucher_to_consume text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF p_payment_method IS NULL OR p_payment_method NOT IN (
    'cash','manual_transfer','card','vodafone_cash','fawry','instapay','app_wallet'
  ) THEN
    RAISE EXCEPTION 'Invalid payment method' USING ERRCODE = '22023';
  END IF;

  PERFORM private.require_active_booking_actor();
  IF p_payment_method='app_wallet' THEN
    RAISE EXCEPTION 'USE_VERIFIED_WALLET_PAYMENT' USING ERRCODE='22023';
  END IF;

  SELECT b.*
  INTO v_booking
  FROM public.bookings AS b
  WHERE b.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT public.is_super_admin()
     AND NOT public.has_lounge_permission(v_booking.lounge_id, 'billing_checkout') THEN
    RAISE EXCEPTION 'Not authorized for billing checkout in this lounge' USING ERRCODE = '42501';
  END IF;

  v_paid:=private.booking_collected_amount(p_booking_id,v_booking.lounge_id,v_booking.payment_status,v_booking.total_price);
  IF v_booking.payment_status = 'paid' AND v_paid=v_booking.total_price THEN
    IF v_booking.payment_method IS DISTINCT FROM p_payment_method
      OR (p_final_amount IS NOT NULL AND p_final_amount IS DISTINCT FROM v_booking.total_price) THEN
      RAISE EXCEPTION 'PAYMENT_REPLAY_PAYLOAD_CONFLICT' USING ERRCODE='22023';
    END IF;
    RETURN jsonb_build_object(
      'success', true,
      'booking_id', p_booking_id,
      'room_id', v_booking.room_id,
      'status', v_booking.status::text,
      'amount_paid', v_booking.total_price,
      'payment_method', v_booking.payment_method,
      'idempotent', true
    );
  END IF;

  IF v_booking.status::text IN ('cancelled', 'rejected') THEN
    RAISE EXCEPTION 'Cannot collect payment for a cancelled or rejected booking' USING ERRCODE = '55000';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.payments AS p
    WHERE p.booking_id = p_booking_id AND p.status = 'refunded'
  ) THEN
    RAISE EXCEPTION 'A refunded payment cannot be completed again through this RPC' USING ERRCODE = '55000';
  END IF;

  IF v_booking.total_price IS NULL OR v_booking.total_price < 0
    OR v_booking.total_price::text IN ('NaN','Infinity','-Infinity')
    OR v_booking.total_price<>round(v_booking.total_price,2) THEN
    RAISE EXCEPTION 'Booking has an invalid server-calculated total' USING ERRCODE = '22023';
  END IF;

  IF p_final_amount IS NOT NULL AND p_final_amount IS DISTINCT FROM v_booking.total_price THEN
    RAISE EXCEPTION 'Payment amount must match the booking total; update an approved discount before collecting'
      USING ERRCODE = '22023';
  END IF;

  IF v_paid>v_booking.total_price THEN
    RAISE EXCEPTION 'PAYMENT_REQUIRES_RECONCILIATION' USING ERRCODE='55000';
  END IF;
  IF v_paid>0 AND p_payment_method<>'cash' THEN
    RAISE EXCEPTION 'ELECTRONIC_INSTALLMENT_REQUIRES_RECEIPT_LEDGER' USING ERRCODE='55000';
  END IF;
  IF p_payment_method='cash' AND v_paid>0 AND EXISTS(SELECT 1 FROM public.payments
    WHERE booking_id=p_booking_id AND payment_method<>'cash') THEN
    RAISE EXCEPTION 'MIXED_PAYMENT_REQUIRES_RECEIPT_LEDGER' USING ERRCODE='55000';
  END IF;
  v_amount := round(v_booking.total_price, 2);
  v_commission := round(v_amount * 0.15, 2);

  SELECT s.id
  INTO v_shift_id
  FROM public.shifts AS s
  WHERE s.lounge_id = v_booking.lounge_id
    AND s.status = 'open'
    AND s.closed_at IS NULL
    AND (p_payment_method<>'cash' OR (s.cashier_id=auth.uid()
      AND (s.staff_user_id IS NULL OR s.staff_user_id=auth.uid())))
  ORDER BY s.opened_at DESC
  LIMIT 1
  FOR SHARE;

  IF v_shift_id IS NULL THEN
    RAISE EXCEPTION 'An open shift is required to collect payment' USING ERRCODE = '55000';
  END IF;

  IF v_booking.status = 'completed'::public.booking_status THEN
    v_new_status := 'completed'::public.booking_status;
  ELSIF v_booking.status = 'in_progress'::public.booking_status THEN
    v_new_status := 'in_progress'::public.booking_status;
  ELSE
    v_new_status := 'upcoming'::public.booking_status;
  END IF;

  -- Consume attached voucher if exists
  v_voucher_to_consume := COALESCE(
    v_booking.applied_voucher_code,
    CASE 
      WHEN v_booking.discount_reason ~* '^voucher:\s*([A-Za-z0-9_-]+)' 
      THEN substring(v_booking.discount_reason from '(?i)^voucher:\s*([A-Za-z0-9_-]+)')
      ELSE NULL 
    END
  );

  IF v_voucher_to_consume IS NOT NULL AND v_booking.user_id IS NOT NULL THEN
    UPDATE public.user_vouchers
    SET status = 'used',
        used_at = now(),
        used_booking_id = p_booking_id
    WHERE UPPER(TRIM(code)) = UPPER(TRIM(v_voucher_to_consume))
      AND user_id = v_booking.user_id
      AND status = 'active';
  END IF;

  IF p_payment_method='cash' THEN
    IF v_amount>v_paid THEN
      v_collected:=public.collect_booking_cash_partial(p_booking_id,v_shift_id,(v_amount-v_paid)*100,gen_random_uuid());
    END IF;
    UPDATE public.bookings SET status=v_new_status,payment_status='paid',payment_method='cash',
      shift_id=v_shift_id,updated_at=now() WHERE id=p_booking_id;
    RETURN jsonb_build_object('success',true,'booking_id',p_booking_id,'room_id',v_booking.room_id,
      'status',v_new_status::text,'amount_paid',v_amount,'amount_collected',v_amount-v_paid,
      'payment_method','cash','shift_id',v_shift_id,'collection',v_collected);
  END IF;

  INSERT INTO public.payments (
    booking_id, user_id, lounge_id, amount, commission, net_to_lounge,
    payment_method, status, paid_at, discount_amount, discount_percentage,
    discount_reason, discount_approved_by
  ) VALUES (
    p_booking_id, v_booking.user_id, v_booking.lounge_id, v_amount,
    v_commission, v_amount - v_commission, p_payment_method, 'completed', now(),
    COALESCE(v_booking.discount_amount, 0), COALESCE(v_booking.discount_percentage, 0),
    v_booking.discount_reason, v_booking.discount_approved_by
  )
  ON CONFLICT (booking_id) DO UPDATE SET
    user_id = EXCLUDED.user_id,
    lounge_id = EXCLUDED.lounge_id,
    amount = EXCLUDED.amount,
    commission = EXCLUDED.commission,
    net_to_lounge = EXCLUDED.net_to_lounge,
    payment_method = EXCLUDED.payment_method,
    status = 'completed',
    paid_at = EXCLUDED.paid_at,
    discount_amount = EXCLUDED.discount_amount,
    discount_percentage = EXCLUDED.discount_percentage,
    discount_reason = EXCLUDED.discount_reason,
    discount_approved_by = EXCLUDED.discount_approved_by;

  INSERT INTO public.shift_payments (
    shift_id, lounge_id, booking_id, payment_method, category, amount, paid_at
  ) VALUES (
    v_shift_id, v_booking.lounge_id, p_booking_id, p_payment_method, 'gaming_time', v_amount, now()
  );

  UPDATE public.bookings AS b
  SET status = v_new_status,
      payment_status = 'paid',
      payment_method = p_payment_method,
      total_price = v_amount,
      shift_id = v_shift_id,
      updated_at = now()
  WHERE b.id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'room_id', v_booking.room_id,
    'status', v_new_status::text,
    'amount_paid', v_amount,
    'payment_method', p_payment_method,
    'commission', v_commission,
    'net_to_lounge', v_amount - v_commission,
    'shift_id', v_shift_id
  );
END;
$function$;

DROP FUNCTION IF EXISTS public.get_all_bookings_admin(uuid,text,integer,integer);

CREATE OR REPLACE FUNCTION public.get_all_bookings_admin(
  p_lounge_id uuid DEFAULT NULL::uuid,
  p_status text DEFAULT NULL::text,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0,
  p_search text DEFAULT NULL::text,
  p_payment_status text DEFAULT NULL::text,
  p_date date DEFAULT NULL::date
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_super boolean;
  v_lounge_ids uuid[];
  v_target_lounge uuid;
  v_result JSONB;
BEGIN
  PERFORM private.require_active_booking_actor();
  IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 1000 OR p_offset IS NULL OR p_offset<0 THEN
    RAISE EXCEPTION 'INVALID_BOOKING_PAGE' USING ERRCODE='22023';
  END IF;
  v_super := public.is_super_admin();
  IF p_lounge_id IS NOT NULL AND v_super IS NOT TRUE
    AND public.has_lounge_permission(p_lounge_id,'bookings.view') IS NOT TRUE THEN
    RAISE EXCEPTION 'BOOKING_READ_PERMISSION_DENIED' USING ERRCODE='42501';
  END IF;
  v_target_lounge := p_lounge_id;
  IF v_super IS NOT TRUE THEN
    SELECT COALESCE(array_agg(l.id),'{}'::uuid[]) INTO v_lounge_ids
    FROM public.lounges l WHERE public.has_lounge_permission(l.id,'bookings.view') IS TRUE;
  END IF;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', b.id,
      'out_booking_id', b.id,
      'user_id', b.user_id,
      'lounge_id', b.lounge_id,
      'room_id', b.room_id,
      'user_name', COALESCE(b.user_name, p.full_name, 'Walk-in Customer'),
      'customer_name', COALESCE(b.user_name, p.full_name, 'Walk-in Customer'),
      'user_phone', COALESCE(b.user_phone, p.phone),
      'customer_phone', COALESCE(b.user_phone, p.phone),
      'user_email', p.email,
      'customer_email', p.email,
      'room_name', COALESCE(r.name_ar, r.name_en, r.name, 'Room'),
      'out_room_name', COALESCE(r.name_ar, r.name_en, r.name, 'Room'),
      'controllers_count', r.controllers_count,
      'screen_size', r.screen_size,
      'out_booking_date', b.date,
      'date', b.date,
      'out_start_time', b.start_time,
      'start_time', b.start_time,
      'out_end_time', b.end_time,
      'end_time', b.end_time,
      'duration_minutes', b.duration_minutes,
      'status', b.status,
      'out_booking_status', b.status,
      'payment_status', b.payment_status,
      'out_payment_status', b.payment_status,
      'payment_method', b.payment_method,
      'out_payment_method', b.payment_method,
      'total_price', b.total_price,
      'out_total_price', b.total_price,
      'addons_price', b.addons_price,
      'out_addons_price', b.addons_price,
      'voucher_code', b.applied_voucher_code,
      'discount_amount', b.discount_amount,
      'discount_percentage', b.discount_percentage,
      'discount_reason', b.discount_reason,
      'play_mode', b.play_mode,
      'room_price', b.room_price,
      'shift_id', b.shift_id,
      'created_at', b.created_at,
      'checked_in_at', b.checked_in_at,
      'canteen_orders', (
        SELECT COALESCE(jsonb_agg(
          jsonb_build_object(
            'id', co.id,
            'items', co.items,
            'total_price', co.total_price,
            'status', co.status,
            'created_at', co.created_at
          )
        ), '[]'::jsonb)
        FROM public.canteen_orders co
        WHERE co.booking_id = b.id
      ),
      'extras', (
        SELECT COALESCE(jsonb_agg(
          jsonb_build_object(
            'id', bi.id,
            'extra_id', bi.extra_id,
            'name', bi.name,
            'quantity', bi.quantity,
            'unit_price', bi.unit_price,
            'total_price', bi.total_price,
            'status', bi.status
          )
        ), '[]'::jsonb)
        FROM public.booking_items bi
        WHERE bi.booking_id = b.id
      )
    )
  ), '[]'::jsonb) INTO v_result
  FROM (
    SELECT bk.*
    FROM public.bookings bk
    LEFT JOIN public.profiles pr ON bk.user_id = pr.id
    LEFT JOIN public.rooms rm ON bk.room_id = rm.id
    WHERE (v_target_lounge IS NULL OR bk.lounge_id = v_target_lounge)
      AND (v_super IS TRUE OR bk.lounge_id=ANY(v_lounge_ids))
      AND (p_status IS NULL OR p_status = '' OR bk.status::text = p_status)
      AND (p_payment_status IS NULL OR p_payment_status = '' OR bk.payment_status = p_payment_status)
      AND (p_date IS NULL OR bk.date = p_date)
      AND (
        p_search IS NULL
        OR p_search = ''
        OR bk.id::text ILIKE '%' || p_search || '%'
        OR bk.user_name ILIKE '%' || p_search || '%'
        OR bk.user_phone ILIKE '%' || p_search || '%'
        OR pr.full_name ILIKE '%' || p_search || '%'
        OR pr.phone ILIKE '%' || p_search || '%'
        OR pr.email ILIKE '%' || p_search || '%'
        OR rm.name ILIKE '%' || p_search || '%'
      )
    ORDER BY bk.created_at DESC,bk.id
    LIMIT p_limit
    OFFSET p_offset
  ) b
  LEFT JOIN public.profiles p ON b.user_id = p.id
  LEFT JOIN public.rooms r ON b.room_id = r.id;

  RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_cashier_writer(p_lounge_id uuid, p_device_id uuid, p_online boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_profile public.profiles%ROWTYPE;
  v_lounge public.lounges%ROWTYPE;
  v_writer private.cashier_writer_authorities%ROWTYPE;
  v_permit private.cashier_writer_permits%ROWTYPE;
  v_now timestamptz := date_trunc('milliseconds',statement_timestamp());
  v_super_admin boolean;
  v_created boolean;
  v_permissions jsonb;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='28000'; END IF;
  IF p_device_id IS NULL OR p_lounge_id IS NULL OR p_online IS NULL THEN
    RAISE EXCEPTION 'INVALID_CASHIER_WRITER_REQUEST' USING ERRCODE='22023';
  END IF;
  PERFORM private.lock_cashier_lounge(p_lounge_id);
  SELECT p.* INTO v_profile FROM public.profiles p JOIN auth.users u ON u.id=p.id WHERE p.id=v_actor FOR SHARE OF p,u;
  IF NOT FOUND OR v_profile.is_active IS NOT TRUE OR v_profile.is_banned IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'ACCOUNT_NOT_ELIGIBLE' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_lounge FROM public.lounges WHERE id=p_lounge_id FOR SHARE;
  IF NOT FOUND OR v_lounge.status IS DISTINCT FROM 'active' OR v_lounge.is_active IS NOT TRUE THEN
    RAISE EXCEPTION 'LOUNGE_NOT_APPROVED' USING ERRCODE='42501';
  END IF;
  v_super_admin:=public.is_super_admin() IS TRUE;
  IF NOT v_super_admin AND public.has_lounge_permission(p_lounge_id,'sessions_control') IS NOT TRUE THEN
    RAISE EXCEPTION 'CASHIER_WRITER_PERMISSION_DENIED' USING ERRCODE='42501';
  END IF;
  v_permissions:=private.cashier_effective_permissions(p_lounge_id);
  INSERT INTO private.cashier_writer_authorities(lounge_id,actor_id,device_id,issued_at,permit_expires_at,heartbeat_expires_at)
    VALUES(p_lounge_id,v_actor,p_device_id,v_now,v_now+interval '24 hours',v_now)
    ON CONFLICT(lounge_id) DO NOTHING RETURNING * INTO v_writer;
  v_created:=FOUND;
  SELECT * INTO STRICT v_writer FROM private.cashier_writer_authorities WHERE lounge_id=p_lounge_id FOR UPDATE;
  -- Only an explicit completed release permits a fresh writer claim.
  IF v_writer.released_at IS NOT NULL THEN
    IF NOT EXISTS(SELECT 1 FROM private.cashier_bootstrap_claim_context WHERE transaction_id=txid_current()
      AND lounge_id=p_lounge_id AND actor_id=v_actor AND device_id=p_device_id) THEN
      RAISE EXCEPTION 'CASHIER_RECLAIM_REQUIRES_BOOTSTRAP' USING ERRCODE='55000';
    END IF;
    -- A delayed heartbeat from the retired shift must not claim the writer
    -- again. Bootstrap of the next shift must have exactly one own open shift.
    IF (SELECT count(*) FROM public.shifts WHERE lounge_id=p_lounge_id
      AND coalesce(cashier_id,staff_user_id)=v_actor AND status='open' AND closed_at IS NULL)<>1 THEN
      RAISE EXCEPTION 'OFFLINE_BOOTSTRAP_REQUIRES_ONE_OWN_SHIFT' USING ERRCODE='55000';
    END IF;
    UPDATE private.cashier_writer_authorities SET actor_id=v_actor,device_id=p_device_id,
      writer_generation=gen_random_uuid(),permit_id=gen_random_uuid(),issued_at=v_now,permit_expires_at=v_now+interval '24 hours',
      heartbeat_expires_at=v_now,online_requested=false,released_at=NULL,updated_at=v_now
      WHERE lounge_id=p_lounge_id RETURNING * INTO v_writer;
    v_created:=true;
  END IF;
  IF NOT v_created AND v_writer.online_requested IS DISTINCT FROM p_online
    AND NOT EXISTS(SELECT 1 FROM private.cashier_bootstrap_claim_context
      WHERE transaction_id=txid_current() AND lounge_id=p_lounge_id
        AND actor_id=v_actor AND device_id=p_device_id) THEN
    RAISE EXCEPTION 'CASHIER_MODE_CHANGE_REQUIRES_BOOTSTRAP' USING ERRCODE='55000';
  END IF;
  -- Losing a heartbeat never authorizes another independent offline writer.
  IF v_writer.actor_id<>v_actor OR v_writer.device_id<>p_device_id THEN
    RAISE EXCEPTION 'CASHIER_WRITER_ALREADY_ASSIGNED' USING ERRCODE='55000';
  END IF;
  v_now:=date_trunc('milliseconds',clock_timestamp());
  IF NOT v_created THEN
    SELECT * INTO v_permit FROM private.cashier_writer_permits WHERE permit_id=v_writer.permit_id FOR SHARE;
    IF NOT FOUND OR (v_permit.lounge_id,v_permit.actor_id,v_permit.device_id,v_permit.issued_at,v_permit.expires_at)
      IS DISTINCT FROM (v_writer.lounge_id,v_writer.actor_id,v_writer.device_id,v_writer.issued_at,v_writer.permit_expires_at) THEN
      RAISE EXCEPTION 'CASHIER_PERMIT_RECORD_MISSING_OR_CHANGED' USING ERRCODE='55000';
    END IF;
  END IF;
  IF v_created OR v_now>=v_permit.expires_at OR v_permissions IS DISTINCT FROM v_permit.permissions THEN
    INSERT INTO private.cashier_writer_permits(permit_id,lounge_id,actor_id,device_id,issued_at,expires_at,permissions)
      VALUES(CASE WHEN v_created THEN v_writer.permit_id ELSE gen_random_uuid() END,
        p_lounge_id,v_actor,p_device_id,v_now,v_now+interval '24 hours',v_permissions) RETURNING * INTO v_permit;
  END IF;
  INSERT INTO private.cashier_permit_generations(permit_id,writer_generation)
    VALUES(v_permit.permit_id,v_writer.writer_generation) ON CONFLICT(permit_id) DO NOTHING;
  IF NOT EXISTS(SELECT 1 FROM private.cashier_permit_generations WHERE permit_id=v_permit.permit_id
    AND writer_generation=v_writer.writer_generation) THEN
    RAISE EXCEPTION 'CASHIER_PERMIT_GENERATION_MISMATCH' USING ERRCODE='55000';
  END IF;
  UPDATE private.cashier_writer_authorities SET
    permit_id=v_permit.permit_id,issued_at=v_permit.issued_at,permit_expires_at=v_permit.expires_at,
    heartbeat_expires_at=CASE WHEN p_online THEN v_now+interval '90 seconds' ELSE v_now END,
    online_requested=p_online, updated_at=v_now
  WHERE lounge_id=p_lounge_id RETURNING * INTO v_writer;
  RETURN jsonb_build_object(
    'protocol_version',2,'server_time_ms',floor(extract(epoch FROM v_now)*1000)::bigint,'online_requested',p_online,
    'actor_id',v_actor,'lounge_id',p_lounge_id,'device_id',p_device_id,'permit_id',v_writer.permit_id,
    'profile_active',true,'profile_banned',false,'lounge_status',v_lounge.status,'lounge_active',true,
    'offline_enabled',true,'issued_ms',floor(extract(epoch FROM v_writer.issued_at)*1000)::bigint,
    'expires_ms',floor(extract(epoch FROM v_writer.permit_expires_at)*1000)::bigint,
    'heartbeat_expires_at',v_writer.heartbeat_expires_at,
    'last_applied_sequence',v_writer.last_applied_sequence,'timezone',to_jsonb(v_lounge)->>'timezone',
    'permissions',v_permit.permissions
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_lounge_online_availability(p_lounge_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_now timestamptz:=clock_timestamp();
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.lounges AS lounge
    LEFT JOIN private.cashier_writer_authorities AS writer ON writer.lounge_id=lounge.id
    WHERE lounge.id=p_lounge_id AND lounge.status='active'
      AND lounge.is_active IS TRUE AND lounge.is_open IS TRUE
      AND (writer.lounge_id IS NULL OR (
        writer.released_at IS NULL AND writer.online_requested IS TRUE
        AND writer.heartbeat_expires_at>v_now
        AND EXISTS(SELECT 1 FROM private.cashier_writer_permits permit WHERE permit.permit_id=writer.permit_id
          AND (permit.lounge_id,permit.actor_id,permit.device_id,permit.issued_at,permit.expires_at)
            IS NOT DISTINCT FROM (writer.lounge_id,writer.actor_id,writer.device_id,writer.issued_at,writer.permit_expires_at)
          AND permit.expires_at>v_now)
        AND EXISTS (
          SELECT 1 FROM public.profiles AS profile
          JOIN auth.users AS identity ON identity.id=profile.id
          WHERE profile.id=writer.actor_id AND profile.is_active IS TRUE
            AND profile.is_banned IS FALSE
            AND (EXISTS (SELECT 1 FROM public.platform_super_admins AS admin WHERE admin.user_id=profile.id)
              OR private.user_permission_value(writer.actor_id,lounge.id,'sessions_control') IS TRUE)
        )
      ))
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.blind_close_shift(p_shift_id uuid, p_cashier_id uuid, p_counted_cash numeric, p_notes text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_shift public.shifts%ROWTYPE;
  v_cash_sales numeric;
  v_expenses numeric;
  v_expected numeric;
  v_difference numeric;
  v_manager boolean;
  v_actor uuid := auth.uid();
  v_now timestamptz := clock_timestamp();
  v_lounge_id uuid;
BEGIN
  IF p_counted_cash IS NULL OR p_counted_cash < 0 OR p_counted_cash::text IN ('NaN','Infinity','-Infinity') OR p_counted_cash<>round(p_counted_cash,2) THEN RAISE EXCEPTION 'Counted cash must be non-negative' USING ERRCODE = '22023'; END IF;
  SELECT lounge_id INTO v_lounge_id FROM public.shifts WHERE id=p_shift_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Shift not found' USING ERRCODE='P0002'; END IF;
  PERFORM private.lock_cashier_lounge(v_lounge_id);
  SELECT s.* INTO v_shift FROM public.shifts s WHERE s.id = p_shift_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Shift not found' USING ERRCODE = 'P0002'; END IF;
  IF v_shift.status <> 'open' THEN RAISE EXCEPTION 'Shift is not open' USING ERRCODE = '55000'; END IF;
  IF v_shift.cashier_id IS DISTINCT FROM p_cashier_id THEN RAISE EXCEPTION 'Shift does not belong to the specified cashier' USING ERRCODE = '42501'; END IF;
  IF auth.role() IS DISTINCT FROM 'service_role' AND (
    NOT COALESCE(private.can_operate_playspot_lounge(v_shift.lounge_id), false)
    OR NOT COALESCE(public.has_lounge_permission(v_shift.lounge_id, 'shifts_blind_close'), false)
  ) THEN
    RAISE EXCEPTION 'Shift closure is not permitted for this actor' USING ERRCODE = '42501';
  END IF;
  v_manager := private.can_manage_playspot_lounge(v_shift.lounge_id);
  IF v_actor IS DISTINCT FROM p_cashier_id AND NOT v_manager AND auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'Only the shift cashier or an authorized manager may close this shift' USING ERRCODE = '42501';
  END IF;
  SELECT COALESCE(SUM(sp.amount), 0) INTO v_cash_sales FROM public.shift_payments sp
  WHERE sp.shift_id = p_shift_id AND sp.payment_method = 'cash';
  SELECT COALESCE(SUM(se.amount), 0) INTO v_expenses FROM public.shift_expenses se WHERE se.shift_id = p_shift_id;
  v_expected := COALESCE(v_shift.starting_cash, 0) + v_cash_sales - v_expenses;
  v_difference := p_counted_cash - v_expected;
  UPDATE public.shifts SET actual_cash_counted = p_counted_cash, expected_cash = v_expected,
    difference = v_difference, status = 'closed', closed_at = v_now, end_time = v_now,
    notes = COALESCE(p_notes, notes)
  WHERE id = p_shift_id;

  INSERT INTO public.shift_audit_logs
    (lounge_id, shift_id, entity_type, entity_id, action, actor_user_id, old_data, new_data)
  VALUES
    (v_shift.lounge_id, p_shift_id, 'shift', p_shift_id, 'update', v_actor,
     jsonb_build_object('status', v_shift.status, 'expected_cash', v_shift.expected_cash,
                        'actual_cash_counted', v_shift.actual_cash_counted, 'difference', v_shift.difference),
     jsonb_build_object('status', 'closed', 'expected_cash', v_expected,
                        'actual_cash_counted', p_counted_cash, 'difference', v_difference,
                        'cash_sales', v_cash_sales, 'expenses', v_expenses, 'notes', p_notes));
  RETURN jsonb_build_object('success', true, 'shift_id', p_shift_id, 'status', 'closed',
    'actual_cash_counted', p_counted_cash,
    'expected_cash', CASE WHEN private.can_view_shift_financials(v_shift.lounge_id) THEN to_jsonb(v_expected) ELSE 'null'::jsonb END,
    'difference', CASE WHEN private.can_view_shift_financials(v_shift.lounge_id) THEN to_jsonb(v_difference) ELSE 'null'::jsonb END,
    'manager_report', private.can_view_shift_financials(v_shift.lounge_id), 'financials_visible', private.can_view_shift_financials(v_shift.lounge_id));
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_lounge_operating_status(p_lounge_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_lounge public.lounges%ROWTYPE; v_online boolean; v_fault boolean;v_boundary timestamptz;v_future_date date;v_today date;
BEGIN
 SELECT * INTO v_lounge FROM public.lounges WHERE id=p_lounge_id AND status='active' AND is_active IS TRUE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','unavailable','can_book_online',false,'contact_phone',NULL); END IF;
 v_online:=public.get_lounge_online_availability(p_lounge_id);
 v_fault:=v_lounge.is_open IS TRUE AND NOT v_online
   AND EXISTS(SELECT 1 FROM public.shifts WHERE lounge_id=p_lounge_id AND status='open' AND closed_at IS NULL)
   AND EXISTS(SELECT 1 FROM private.cashier_writer_authorities w
     JOIN public.profiles p ON p.id=w.actor_id JOIN auth.users u ON u.id=p.id
     WHERE w.lounge_id=p_lounge_id AND p.is_active IS TRUE AND p.is_banned IS FALSE
       AND (w.online_requested IS FALSE OR w.heartbeat_expires_at<=clock_timestamp()));
 v_today := (now() AT TIME ZONE v_lounge.timezone)::date;
 IF v_lounge.allow_future_bookings IS TRUE AND (v_lounge.allow_request_without_shift IS TRUE
   OR EXISTS(SELECT 1 FROM public.shifts WHERE lounge_id=p_lounge_id AND status='open' AND closed_at IS NULL)) THEN
   SELECT greatest(w.permit_expires_at,COALESCE((SELECT max(p.expires_at)
     FROM private.cashier_writer_permits p JOIN private.cashier_permit_generations g ON g.permit_id=p.permit_id
     WHERE p.lounge_id=w.lounge_id AND p.actor_id=w.actor_id AND p.device_id=w.device_id
       AND g.writer_generation=w.writer_generation),w.permit_expires_at)) INTO v_boundary
     FROM private.cashier_writer_authorities w WHERE w.lounge_id=p_lounge_id AND w.released_at IS NULL;
   v_future_date := greatest(v_today+1,COALESCE((v_boundary AT TIME ZONE v_lounge.timezone)::date
     + CASE WHEN (v_boundary AT TIME ZONE v_lounge.timezone)::time>time '00:00' THEN 1 ELSE 0 END,v_today+1));
   IF v_future_date>v_today+COALESCE(v_lounge.future_booking_max_days_advance,14) THEN v_future_date:=NULL; END IF;
 END IF;
 RETURN jsonb_build_object('future_booking_date_from',v_future_date,'status',CASE WHEN v_online THEN 'open' WHEN v_fault THEN 'technical_issue' ELSE 'closed' END,
   'can_book_online',v_online,'contact_phone',CASE WHEN v_fault THEN nullif(btrim(v_lounge.contact_phone),'') ELSE NULL END);
END; $function$;

CREATE OR REPLACE FUNCTION public.validate_voucher_by_code(p_code text,p_user_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_actor uuid;v_target uuid;v_voucher public.user_vouchers%ROWTYPE;
BEGIN
  v_actor:=private.require_active_booking_actor();
  v_target:=COALESCE(p_user_id,v_actor);
  IF v_target<>v_actor AND public.is_super_admin() IS NOT TRUE AND NOT EXISTS(
    SELECT 1 FROM public.bookings b WHERE b.user_id=v_target
      AND b.status::text NOT IN ('cancelled','rejected','expired')
      AND public.has_lounge_permission(b.lounge_id,'billing_checkout') IS TRUE
  ) THEN RAISE EXCEPTION 'VOUCHER_CUSTOMER_SCOPE_DENIED' USING ERRCODE='42501'; END IF;
  SELECT * INTO v_voucher FROM public.user_vouchers
    WHERE upper(trim(code))=upper(trim(p_code)) AND user_id=v_target
      AND status='active' AND (expires_at IS NULL OR expires_at>now());
  IF NOT FOUND THEN RETURN jsonb_build_object('valid',false,'error','Voucher is invalid, expired, or already used'); END IF;
  RETURN jsonb_build_object('valid',true,'voucher_id',v_voucher.id,'code',v_voucher.code,
    'reward_type',v_voucher.reward_type,'reward_value',v_voucher.reward_value,'min_spend',0,'user_id',v_voucher.user_id);
END; $$;

CREATE OR REPLACE FUNCTION public.delete_lounge_admin(p_lounge_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  PERFORM private.require_active_booking_actor();
  IF public.is_super_admin() IS NOT TRUE THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
  END IF;

  UPDATE public.lounges
  SET is_active = false,
      updated_at = now()
  WHERE id = p_lounge_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Lounge not found' USING ERRCODE = 'P0002';
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'lounge_id', p_lounge_id,
    'message', 'Lounge deactivated successfully'
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.apply_booking_discount(
  p_booking_id uuid,
  p_discount_amount numeric DEFAULT 0,
  p_discount_percentage numeric DEFAULT 0,
  p_discount_reason text DEFAULT NULL::text,
  p_voucher_code text DEFAULT NULL::text
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_amount numeric := GREATEST(COALESCE(p_discount_amount, 0), 0);
  v_percentage numeric := GREATEST(COALESCE(p_discount_percentage, 0), 0);
  v_reason text := NULLIF(btrim(p_discount_reason), '');
  v_clean_voucher text := NULLIF(upper(btrim(p_voucher_code)), '');
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  PERFORM private.require_active_booking_actor();
  SELECT b.*
  INTO v_booking
  FROM public.bookings AS b
  WHERE b.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002';
  END IF;

  IF public.is_super_admin() IS NOT TRUE AND public.has_lounge_permission(v_booking.lounge_id,'billing_checkout') IS NOT TRUE THEN
    RAISE EXCEPTION 'DISCOUNT_APPROVAL_DENIED' USING ERRCODE='42501';
  END IF;
  IF p_discount_amount IS NULL OR p_discount_percentage IS NULL
    OR p_discount_amount::text IN ('NaN','Infinity','-Infinity')
    OR p_discount_percentage::text IN ('NaN','Infinity','-Infinity')
    OR p_discount_amount<0 OR p_discount_percentage<0 OR p_discount_amount<>round(p_discount_amount,2) THEN
    RAISE EXCEPTION 'INVALID_DISCOUNT' USING ERRCODE='22023';
  END IF;

  IF v_amount > 0 AND v_percentage > 0 THEN
    RAISE EXCEPTION 'Use either a fixed discount or a percentage discount, not both'
      USING ERRCODE = '22023';
  END IF;

  IF v_percentage > 100 THEN
    RAISE EXCEPTION 'Discount percentage must be between 0 and 100'
      USING ERRCODE = '22023';
  END IF;

  IF (v_amount > 0 OR v_percentage > 0) AND v_reason IS NULL AND v_clean_voucher IS NULL THEN
    RAISE EXCEPTION 'Discount reason or voucher code is required'
      USING ERRCODE = '22023';
  END IF;

  IF v_clean_voucher IS NOT NULL THEN
    RAISE EXCEPTION 'USE_SERVER_VALIDATED_VOUCHER_CHECKOUT' USING ERRCODE='22023';
  END IF;
  UPDATE public.bookings
  SET
    discount_amount = v_amount,
    discount_percentage = v_percentage,
    discount_reason = v_reason,
    applied_voucher_code = COALESCE(v_clean_voucher, applied_voucher_code),
    discount_approved_by = auth.uid(),
    updated_at = now()
  WHERE id = p_booking_id
  RETURNING *
  INTO v_booking;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', v_booking.id,
    'discount_amount', v_booking.discount_amount,
    'discount_percentage', v_booking.discount_percentage,
    'discount_reason', v_booking.discount_reason,
    'applied_voucher_code', v_booking.applied_voucher_code,
    'total_price', v_booking.total_price
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.start_tournament_match(p_match_id uuid, p_room_id uuid DEFAULT NULL::uuid)
 RETURNS tournament_matches
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_match public.tournament_matches%ROWTYPE;
  v_tournament public.tournaments%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000';
  END IF;

  PERFORM private.require_active_booking_actor();
  SELECT *
  INTO v_match
  FROM public.tournament_matches
  WHERE id = p_match_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'match_not_found' USING ERRCODE = 'P0002';
  END IF;

  SELECT *
  INTO v_tournament
  FROM public.tournaments
  WHERE id = v_match.tournament_id;

  IF NOT (
    public.is_super_admin() IS TRUE
    OR private.is_lounge_manager(v_tournament.lounge_id) IS TRUE
  ) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;

  IF v_match.status <> 'scheduled'
     OR v_match.player1_id IS NULL
     OR v_match.player2_id IS NULL THEN
    RAISE EXCEPTION 'match_not_ready' USING ERRCODE = '55000';
  END IF;

  IF p_room_id IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM public.rooms AS r
    WHERE r.id = p_room_id
      AND r.lounge_id = v_tournament.lounge_id
      AND r.is_active IS TRUE
      AND r.status <> 'deleted'
  ) THEN
    RAISE EXCEPTION 'invalid_tournament_room' USING ERRCODE = '22023';
  END IF;

  UPDATE public.tournament_matches
  SET room_id = COALESCE(p_room_id, room_id),
      status = 'in_progress',
      started_at = COALESCE(started_at, now()),
      updated_at = now()
  WHERE id = v_match.id
  RETURNING *
  INTO v_match;

  PERFORM public.tournament_audit(
    v_tournament.id,
    'match_started',
    NULL,
    v_match.id,
    NULL,
    to_jsonb(v_match)
  );

  RETURN v_match;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_pending_payouts_overview() FROM PUBLIC,anon,service_role,supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.get_pending_payouts_overview() TO authenticated;

REVOKE ALL ON FUNCTION public.create_payout(uuid,date,date) FROM PUBLIC,anon,service_role,supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.create_payout(uuid,date,date) TO authenticated;

REVOKE ALL ON FUNCTION public.complete_booking_session(uuid,uuid) FROM PUBLIC,anon,service_role,supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.complete_booking_session(uuid,uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.complete_booking_payment(uuid,text,numeric) FROM PUBLIC,anon,service_role,supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.complete_booking_payment(uuid,text,numeric) TO authenticated;

REVOKE ALL ON FUNCTION public.get_all_bookings_admin(uuid,text,integer,integer,text,text,date) FROM PUBLIC,anon,service_role,supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.get_all_bookings_admin(uuid,text,integer,integer,text,text,date) TO authenticated;

REVOKE ALL ON FUNCTION public.refresh_cashier_writer(uuid,uuid,boolean) FROM PUBLIC,anon,service_role,supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.refresh_cashier_writer(uuid,uuid,boolean) TO authenticated;

REVOKE ALL ON FUNCTION public.blind_close_shift(uuid,uuid,numeric,text) FROM PUBLIC,anon,service_role,supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.blind_close_shift(uuid,uuid,numeric,text) TO authenticated;

REVOKE ALL ON FUNCTION public.validate_voucher_by_code(text,uuid) FROM PUBLIC,anon,service_role,supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.validate_voucher_by_code(text,uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.delete_lounge_admin(uuid) FROM PUBLIC,anon,service_role,supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.delete_lounge_admin(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.apply_booking_discount(uuid,numeric,numeric,text,text) FROM PUBLIC,anon,service_role,supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.apply_booking_discount(uuid,numeric,numeric,text,text) TO authenticated;

REVOKE ALL ON FUNCTION public.start_tournament_match(uuid,uuid) FROM PUBLIC,anon,service_role,supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.start_tournament_match(uuid,uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.get_lounge_online_availability(uuid),public.get_lounge_operating_status(uuid) FROM PUBLIC,service_role,supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.get_lounge_online_availability(uuid),public.get_lounge_operating_status(uuid) TO anon,authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
