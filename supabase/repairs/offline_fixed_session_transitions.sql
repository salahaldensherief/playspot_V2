BEGIN;
CREATE OR REPLACE FUNCTION private.offline_fixed_session_receipt(p_booking_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_booking public.bookings%ROWTYPE;v_paid numeric;v_timezone text;v_start timestamp;v_end timestamp;
BEGIN
  SELECT * INTO STRICT v_booking FROM public.bookings WHERE id=p_booking_id;
  SELECT coalesce(v_booking.cashier_booking_timezone,timezone) INTO v_timezone FROM public.lounges WHERE id=v_booking.lounge_id;
  v_paid:=private.cash_collection_paid_amount(v_booking.id,v_booking.lounge_id,v_booking.payment_status);
  v_start:=v_booking.date+v_booking.start_time;
  v_end:=v_booking.date+v_booking.end_time+CASE WHEN v_booking.end_time<=v_booking.start_time THEN interval '1 day' ELSE interval '0' END;
  RETURN jsonb_build_object('booking_id',v_booking.id,'lounge_id',v_booking.lounge_id,'room_id',v_booking.room_id,
    'shift_id',v_booking.shift_id,'status',v_booking.status::text,'timezone',v_timezone,
    'start_ms',extract(epoch FROM (v_start AT TIME ZONE v_timezone))*1000,
    'end_ms',extract(epoch FROM (v_end AT TIME ZONE v_timezone))*1000,
    'capacity_end_ms',floor(CASE WHEN isempty(v_booking.cashier_capacity_period) THEN extract(epoch FROM (v_start AT TIME ZONE v_timezone))*1000
      ELSE extract(epoch FROM (upper(v_booking.cashier_capacity_period) AT TIME ZONE v_timezone))*1000 END),
    'started_at',v_booking.actual_start_time,'closed_at',v_booking.cashier_closed_at,
    'total_minor',v_booking.total_price*100,'paid_minor',v_paid*100,'due_minor',(v_booking.total_price-v_paid)*100,
    'payment_status',v_booking.payment_status);
END; $$;
REVOKE ALL ON FUNCTION private.offline_fixed_session_receipt(uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.lock_offline_fixed_session(p_operation jsonb)
RETURNS public.bookings LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_room uuid;v_lounge uuid;v_booking public.bookings%ROWTYPE;v_total numeric;
BEGIN
  SELECT room_id,lounge_id INTO v_room,v_lounge FROM public.bookings WHERE id=(p_operation->>'booking_id')::uuid;
  IF NOT FOUND OR v_lounge IS DISTINCT FROM (p_operation->>'lounge_id')::uuid THEN
    RAISE EXCEPTION 'OFFLINE_BOOKING_SCOPE_MISMATCH' USING ERRCODE='42501';
  END IF;
  -- Existing online lifecycle RPCs lock the booking before its room. Match
  -- that order rather than retaining a room while waiting on their booking.
  SELECT * INTO STRICT v_booking FROM public.bookings WHERE id=(p_operation->>'booking_id')::uuid FOR UPDATE;
  IF v_booking.room_id IS DISTINCT FROM v_room OR v_booking.lounge_id IS DISTINCT FROM v_lounge OR v_booking.is_open_time IS TRUE THEN
    RAISE EXCEPTION 'OFFLINE_FIXED_SESSION_SCOPE_CHANGED' USING ERRCODE='55000';
  END IF;
  PERFORM 1 FROM public.rooms WHERE id=v_room AND lounge_id=v_lounge FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'OFFLINE_ROOM_UNAVAILABLE' USING ERRCODE='55000'; END IF;
  PERFORM private.lock_cash_collection_shift((p_operation->>'shift_id')::uuid,v_lounge);
  IF v_booking.shift_id IS DISTINCT FROM (p_operation->>'shift_id')::uuid THEN
    RAISE EXCEPTION 'OFFLINE_BOOKING_SHIFT_MISMATCH' USING ERRCODE='55000';
  END IF;
  IF jsonb_typeof(p_operation->'quoted_total_minor') IS DISTINCT FROM 'number' THEN
    RAISE EXCEPTION 'OFFLINE_BOOKING_QUOTE_REQUIRED' USING ERRCODE='22023';
  END IF;
  v_total:=(p_operation->>'quoted_total_minor')::numeric;
  IF v_total<0 OR v_total<>trunc(v_total) OR v_total>9007199254740991 OR v_booking.total_price*100 IS DISTINCT FROM v_total THEN
    RAISE EXCEPTION 'OFFLINE_BOOKING_PRICE_CHANGED' USING ERRCODE='22023';
  END IF;
  RETURN v_booking;
END; $$;
REVOKE ALL ON FUNCTION private.lock_offline_fixed_session(jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.apply_cashier_start_operation(p_operation jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_booking public.bookings%ROWTYPE;v_timezone text;v_at timestamptz:=(p_operation->>'occurred_at')::timestamptz;v_final numeric;
BEGIN
  v_booking:=private.lock_offline_fixed_session(p_operation);
  PERFORM private.lock_offline_booking_room(v_booking.room_id,v_booking.lounge_id);
  SELECT timezone INTO v_timezone FROM public.lounges WHERE id=v_booking.lounge_id;
  IF v_timezone IS NULL OR NOT EXISTS(SELECT 1 FROM pg_catalog.pg_timezone_names WHERE name=v_timezone)
    OR (v_booking.cashier_booking_timezone IS NOT NULL AND v_booking.cashier_booking_timezone<>v_timezone) THEN
    RAISE EXCEPTION 'INVALID_LOUNGE_TIMEZONE' USING ERRCODE='22023';
  END IF;
  IF v_booking.status<>'upcoming'::public.booking_status
    OR v_at<(v_booking.date+v_booking.start_time) AT TIME ZONE v_timezone
    OR v_at>=((v_booking.date+v_booking.end_time)+CASE WHEN v_booking.end_time<=v_booking.start_time THEN interval '1 day' ELSE interval '0' END)
      AT TIME ZONE v_timezone THEN RAISE EXCEPTION 'OFFLINE_SESSION_OUTSIDE_BOOKED_WINDOW' USING ERRCODE='55000'; END IF;
  IF EXISTS(SELECT 1 FROM public.bookings WHERE room_id=v_booking.room_id AND id<>v_booking.id AND status='in_progress'::public.booking_status) THEN
    RAISE EXCEPTION 'OFFLINE_ROOM_STILL_OCCUPIED' USING ERRCODE='55000';
  END IF;
  UPDATE public.bookings SET status='in_progress',checked_in_at=v_at,actual_start_time=v_at,
    cashier_booking_timezone=v_timezone,updated_at=now() WHERE id=v_booking.id RETURNING total_price INTO v_final;
  IF v_final*100 IS DISTINCT FROM (p_operation->>'quoted_total_minor')::numeric THEN
    RAISE EXCEPTION 'OFFLINE_BOOKING_PRICE_CHANGED' USING ERRCODE='22023';
  END IF;
  UPDATE public.rooms SET status='occupied',is_available=false,updated_at=now() WHERE id=v_booking.room_id;
  RETURN private.offline_fixed_session_receipt(v_booking.id);
END; $$;
REVOKE ALL ON FUNCTION private.apply_cashier_start_operation(jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.apply_cashier_close_operation(p_operation jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_booking public.bookings%ROWTYPE;v_at timestamptz:=(p_operation->>'occurred_at')::timestamptz;v_final numeric;
BEGIN
  v_booking:=private.lock_offline_fixed_session(p_operation);
  IF v_booking.status<>'in_progress'::public.booking_status OR v_booking.actual_start_time IS NULL
    OR v_at<v_booking.actual_start_time OR v_booking.cashier_booking_timezone IS NULL THEN
    RAISE EXCEPTION 'OFFLINE_SESSION_NOT_READY_TO_CLOSE' USING ERRCODE='55000';
  END IF;
  UPDATE public.bookings SET status='completed',cashier_closed_at=v_at,updated_at=now() WHERE id=v_booking.id RETURNING total_price INTO v_final;
  IF v_final*100 IS DISTINCT FROM (p_operation->>'quoted_total_minor')::numeric THEN
    RAISE EXCEPTION 'OFFLINE_BOOKING_PRICE_CHANGED' USING ERRCODE='22023';
  END IF;
  UPDATE public.rooms r SET status='available',is_available=true,updated_at=now()
    WHERE r.id=v_booking.room_id AND r.status='occupied' AND r.is_active IS TRUE
      AND NOT EXISTS(SELECT 1 FROM public.bookings WHERE room_id=r.id AND id<>v_booking.id AND status='in_progress'::public.booking_status);
  RETURN private.offline_fixed_session_receipt(v_booking.id);
END; $$;
REVOKE ALL ON FUNCTION private.apply_cashier_close_operation(jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.validate_offline_session_snapshot(p_operation jsonb,p_receipt jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_snapshot jsonb:=p_operation->'quoted_session';v_field text;v_started jsonb;
BEGIN
  IF jsonb_typeof(v_snapshot) IS DISTINCT FROM 'object'
    OR NOT v_snapshot ?& ARRAY['room_id','timezone','start_ms','end_ms','started_ms','paid_minor'] THEN
    RAISE EXCEPTION 'OFFLINE_SESSION_SNAPSHOT_REQUIRED' USING ERRCODE='22023';
  END IF;
  FOREACH v_field IN ARRAY ARRAY['room_id','timezone','start_ms','end_ms','paid_minor'] LOOP
    IF v_snapshot->v_field IS DISTINCT FROM p_receipt->v_field THEN
      RAISE EXCEPTION 'OFFLINE_SESSION_SNAPSHOT_CHANGED' USING ERRCODE='22023';
    END IF;
  END LOOP;
  v_started:=CASE WHEN p_receipt->>'started_at' IS NULL THEN 'null'::jsonb
    ELSE to_jsonb(floor(extract(epoch FROM (p_receipt->>'started_at')::timestamptz)*1000)) END;
  IF v_snapshot->'started_ms' IS DISTINCT FROM v_started THEN
    RAISE EXCEPTION 'OFFLINE_SESSION_SNAPSHOT_CHANGED' USING ERRCODE='22023';
  END IF;
END; $$;
REVOKE ALL ON FUNCTION private.validate_offline_session_snapshot(jsonb,jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.apply_cashier_fixed_operation(p_operation jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_result jsonb;
BEGIN
  INSERT INTO private.cashier_sync_context VALUES(txid_current(),(p_operation->>'lounge_id')::uuid,
    auth.uid(),(p_operation->>'permit_id')::uuid);
  INSERT INTO private.cashier_booking_command_context VALUES(txid_current(),(p_operation->>'booking_id')::uuid,p_operation->>'kind');
  CASE p_operation->>'kind'
    WHEN 'reserve' THEN v_result:=private.apply_cashier_reservation_operation(p_operation);
    WHEN 'start' THEN v_result:=private.apply_cashier_start_operation(p_operation);
    WHEN 'close' THEN v_result:=private.apply_cashier_close_operation(p_operation);
    ELSE RAISE EXCEPTION 'OFFLINE_OPERATION_KIND_NOT_IMPLEMENTED' USING ERRCODE='0A000';
  END CASE;
  PERFORM private.validate_offline_session_snapshot(p_operation,v_result);
  DELETE FROM private.cashier_booking_command_context WHERE transaction_id=txid_current();
  DELETE FROM private.cashier_sync_context WHERE transaction_id=txid_current();
  RETURN v_result;
END; $$;
REVOKE ALL ON FUNCTION private.apply_cashier_fixed_operation(jsonb) FROM PUBLIC,anon,authenticated;
COMMIT;
