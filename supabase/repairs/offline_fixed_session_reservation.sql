BEGIN;
CREATE OR REPLACE FUNCTION private.offline_booking_interval(p_operation jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_start numeric;v_end numeric;v_start_at timestamptz;v_end_at timestamptz;v_start_local timestamp;v_end_local timestamp;v_timezone text;
BEGIN
  IF jsonb_typeof(p_operation->'payload'->'start_ms') IS DISTINCT FROM 'number'
    OR jsonb_typeof(p_operation->'payload'->'end_ms') IS DISTINCT FROM 'number' THEN
    RAISE EXCEPTION 'INVALID_OFFLINE_BOOKING_INTERVAL' USING ERRCODE='22023';
  END IF;
  v_start:=(p_operation->'payload'->>'start_ms')::numeric;v_end:=(p_operation->'payload'->>'end_ms')::numeric;
  IF v_start<0 OR v_end>253402300799000 OR mod(v_start,60000)<>0 OR mod(v_end,60000)<>0
    OR v_end<=v_start OR v_end-v_start>86400000
    OR v_start<floor(extract(epoch FROM (p_operation->>'occurred_at')::timestamptz)/60)*60000 THEN
    RAISE EXCEPTION 'INVALID_OFFLINE_BOOKING_INTERVAL' USING ERRCODE='22023';
  END IF;
  SELECT timezone INTO v_timezone FROM public.lounges WHERE id=(p_operation->>'lounge_id')::uuid;
  IF v_timezone IS NULL OR v_timezone IS DISTINCT FROM p_operation->'payload'->>'timezone'
    OR NOT EXISTS(SELECT 1 FROM pg_catalog.pg_timezone_names WHERE name=v_timezone) THEN
    RAISE EXCEPTION 'INVALID_LOUNGE_TIMEZONE' USING ERRCODE='22023';
  END IF;
  v_start_at:=to_timestamp((v_start/1000)::double precision);v_end_at:=to_timestamp((v_end/1000)::double precision);
  v_start_local:=v_start_at AT TIME ZONE v_timezone;v_end_local:=v_end_at AT TIME ZONE v_timezone;
  IF v_start_local AT TIME ZONE v_timezone IS DISTINCT FROM v_start_at
    OR v_end_local AT TIME ZONE v_timezone IS DISTINCT FROM v_end_at
    OR v_end_local-v_start_local IS DISTINCT FROM v_end_at-v_start_at THEN
    RAISE EXCEPTION 'OFFLINE_DST_INTERVAL_REQUIRES_REVIEW' USING ERRCODE='22023';
  END IF;
  RETURN jsonb_build_object('start',v_start_local,'end',v_end_local,'timezone',v_timezone,'minutes',((v_end-v_start)/60000)::integer);
END; $$;
REVOKE ALL ON FUNCTION private.offline_booking_interval(jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.lock_offline_booking_room(p_room_id uuid,p_lounge_id uuid)
RETURNS public.rooms LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_room public.rooms%ROWTYPE;
BEGIN
  SELECT * INTO v_room FROM public.rooms WHERE id=p_room_id FOR UPDATE;
  IF NOT FOUND OR v_room.lounge_id IS DISTINCT FROM p_lounge_id OR v_room.is_active IS NOT TRUE
    OR v_room.status NOT IN ('available','occupied') OR v_room.status IS NULL
    OR (v_room.is_available IS NOT TRUE AND v_room.status<>'occupied') THEN
    RAISE EXCEPTION 'OFFLINE_ROOM_UNAVAILABLE' USING ERRCODE='55000';
  END IF;
  RETURN v_room;
END; $$;
REVOKE ALL ON FUNCTION private.lock_offline_booking_room(uuid,uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.quote_offline_fixed_booking(p_operation jsonb,p_interval jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_quote jsonb;v_total numeric;
BEGIN
  IF p_operation->'payload'->>'play_mode' NOT IN ('single','multi') OR p_operation->'payload'->>'play_mode' IS NULL
    OR jsonb_typeof(p_operation->'quoted_total_minor') IS DISTINCT FROM 'number'
    OR jsonb_typeof(p_operation->'payload'->'customer_name') IS DISTINCT FROM 'string'
    OR (p_operation->'payload' ? 'customer_phone' AND p_operation->'payload'->'customer_phone'<>'null'::jsonb
      AND jsonb_typeof(p_operation->'payload'->'customer_phone') IS DISTINCT FROM 'string')
    OR nullif(btrim(p_operation->'payload'->>'customer_name'),'') IS NULL
    OR length(p_operation->'payload'->>'customer_name')>120
    OR length(coalesce(p_operation->'payload'->>'customer_phone',''))>32 THEN
    RAISE EXCEPTION 'INVALID_OFFLINE_BOOKING' USING ERRCODE='22023';
  END IF;
  v_total:=(p_operation->>'quoted_total_minor')::numeric;
  IF v_total<=0 OR v_total<>trunc(v_total) OR v_total>9007199254740991 THEN
    RAISE EXCEPTION 'INVALID_OFFLINE_BOOKING' USING ERRCODE='22023';
  END IF;
  v_quote:=public.quote_booking_price((p_operation->'payload'->>'room_id')::uuid,
    (p_interval->>'start')::timestamp::date,(p_interval->>'start')::timestamp::time,(p_interval->>'end')::timestamp::time,
    p_operation->'payload'->>'play_mode',0,NULL);
  IF (v_quote->>'final_total')::numeric*100 IS DISTINCT FROM v_total
    OR (v_quote->>'room_subtotal')::numeric IS DISTINCT FROM (v_quote->>'final_total')::numeric
    OR (v_quote->>'duration_minutes')::numeric IS DISTINCT FROM (p_interval->>'minutes')::numeric THEN
    RAISE EXCEPTION 'OFFLINE_BOOKING_PRICE_CHANGED' USING ERRCODE='22023';
  END IF;
  RETURN v_quote;
END; $$;
REVOKE ALL ON FUNCTION private.quote_offline_fixed_booking(jsonb,jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.apply_cashier_reservation_operation(p_operation jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_room public.rooms%ROWTYPE;v_interval jsonb;v_quote jsonb;v_booking public.bookings%ROWTYPE;
BEGIN
  v_interval:=private.offline_booking_interval(p_operation);
  IF NOT EXISTS(SELECT 1 FROM public.lounges WHERE id=(p_operation->>'lounge_id')::uuid AND allow_cash_payment IS TRUE) THEN
    RAISE EXCEPTION 'OFFLINE_CASH_BOOKING_DISABLED' USING ERRCODE='55000';
  END IF;
  v_room:=private.lock_offline_booking_room((p_operation->'payload'->>'room_id')::uuid,(p_operation->>'lounge_id')::uuid);
  PERFORM private.lock_cash_collection_shift((p_operation->>'shift_id')::uuid,v_room.lounge_id);
  IF EXISTS(SELECT 1 FROM public.tournament_matches WHERE room_id=v_room.id AND status<>'cancelled'
    AND scheduled_at IS NOT NULL AND scheduled_end_at IS NOT NULL
    AND tstzrange(scheduled_at,scheduled_end_at,'[)') && tstzrange(
      to_timestamp((p_operation->'payload'->>'start_ms')::double precision/1000),
      to_timestamp((p_operation->'payload'->>'end_ms')::double precision/1000),'[)')) THEN
    RAISE EXCEPTION 'OFFLINE_TOURNAMENT_ROOM_CONFLICT' USING ERRCODE='55000';
  END IF;
  v_quote:=private.quote_offline_fixed_booking(p_operation,v_interval);
  INSERT INTO public.bookings(id,user_id,lounge_id,room_id,date,start_time,end_time,start_at,end_at,room_price,total_price,
    status,user_name,user_phone,room_name,play_mode,duration_minutes,shift_id,payment_status,payment_method,created_at,cashier_booking_timezone)
    VALUES((p_operation->>'booking_id')::uuid,NULL,v_room.lounge_id,v_room.id,(v_interval->>'start')::timestamp::date,
      (v_interval->>'start')::timestamp::time,(v_interval->>'end')::timestamp::time,
      (v_interval->>'start')::timestamp::time,(v_interval->>'end')::timestamp::time,
      (v_quote->>'room_subtotal')::numeric,(v_quote->>'final_total')::numeric,'upcoming',
      btrim(p_operation->'payload'->>'customer_name'),p_operation->'payload'->>'customer_phone',v_room.name,
      p_operation->'payload'->>'play_mode',(v_interval->>'minutes')::integer,(p_operation->>'shift_id')::uuid,
      'unpaid','cash',(p_operation->>'occurred_at')::timestamptz,v_interval->>'timezone') RETURNING * INTO v_booking;
  IF v_booking.total_price*100 IS DISTINCT FROM (p_operation->>'quoted_total_minor')::numeric THEN
    RAISE EXCEPTION 'OFFLINE_BOOKING_PRICE_CHANGED' USING ERRCODE='22023';
  END IF;
  RETURN private.offline_fixed_session_receipt(v_booking.id);
END; $$;
REVOKE ALL ON FUNCTION private.apply_cashier_reservation_operation(jsonb) FROM PUBLIC,anon,authenticated;
COMMIT;
