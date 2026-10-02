BEGIN;
CREATE OR REPLACE FUNCTION private.validate_offline_order_lines(p_operation jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_items jsonb:=p_operation->'payload'->'items';v_quotes jsonb:=p_operation->'quoted_items';
  v_line jsonb;v_quote jsonb;v_index integer;v_id uuid;v_quantity numeric;v_price numeric;v_total numeric;
BEGIN
  IF jsonb_typeof(v_items) IS DISTINCT FROM 'array' OR jsonb_typeof(v_quotes) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'INVALID_OFFLINE_ORDER' USING ERRCODE='22023';
  END IF;
  IF jsonb_array_length(v_items) NOT BETWEEN 1 AND 50 OR jsonb_array_length(v_quotes)<>jsonb_array_length(v_items)
    OR jsonb_typeof(p_operation->'quoted_total_minor') IS DISTINCT FROM 'number' THEN
    RAISE EXCEPTION 'INVALID_OFFLINE_ORDER' USING ERRCODE='22023';
  END IF;
  v_total:=(p_operation->>'quoted_total_minor')::numeric;
  IF v_total<0 OR v_total<>trunc(v_total) OR v_total>9007199254740991 THEN
    RAISE EXCEPTION 'INVALID_OFFLINE_ORDER' USING ERRCODE='22023';
  END IF;
  FOR v_index IN 0..jsonb_array_length(v_items)-1 LOOP
    v_line:=v_items->v_index;v_quote:=v_quotes->v_index;v_id:=(v_line->>'product_id')::uuid;
    IF v_id IS NULL OR jsonb_typeof(v_line->'quantity') IS DISTINCT FROM 'number'
      OR jsonb_typeof(v_quote->'unit_price_minor') IS DISTINCT FROM 'number'
      OR v_quote->'product_id' IS DISTINCT FROM v_line->'product_id'
      OR v_quote->'quantity' IS DISTINCT FROM v_line->'quantity' THEN
      RAISE EXCEPTION 'INVALID_OFFLINE_ORDER' USING ERRCODE='22023';
    END IF;
    v_quantity:=(v_line->>'quantity')::numeric;v_price:=(v_quote->>'unit_price_minor')::numeric;
    IF v_quantity NOT BETWEEN 1 AND 100 OR v_quantity<>trunc(v_quantity)
      OR v_price<0 OR v_price<>trunc(v_price) OR v_price>9007199254740991 THEN
      RAISE EXCEPTION 'INVALID_OFFLINE_ORDER' USING ERRCODE='22023';
    END IF;
  END LOOP;
END; $$;
REVOKE ALL ON FUNCTION private.validate_offline_order_lines(jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.lock_offline_order_booking(p_operation jsonb)
RETURNS public.bookings LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_booking public.bookings%ROWTYPE;
BEGIN
  SELECT * INTO v_booking FROM public.bookings WHERE id=(p_operation->>'booking_id')::uuid FOR UPDATE;
  IF NOT FOUND OR v_booking.lounge_id IS DISTINCT FROM (p_operation->>'lounge_id')::uuid THEN
    RAISE EXCEPTION 'OFFLINE_BOOKING_SCOPE_MISMATCH' USING ERRCODE='42501';
  END IF;
  IF v_booking.status::text<>'in_progress' OR v_booking.is_open_time IS TRUE THEN
    RAISE EXCEPTION 'OFFLINE_ORDER_REQUIRES_FIXED_ACTIVE_SESSION' USING ERRCODE='55000';
  END IF;
  PERFORM private.lock_cash_collection_shift((p_operation->>'shift_id')::uuid,v_booking.lounge_id);
  IF v_booking.shift_id IS DISTINCT FROM (p_operation->>'shift_id')::uuid THEN
    RAISE EXCEPTION 'OFFLINE_BOOKING_SHIFT_MISMATCH' USING ERRCODE='55000';
  END IF;
  IF v_booking.total_price IS NULL OR v_booking.total_price<0
    OR v_booking.total_price::text IN ('NaN','Infinity','-Infinity')
    OR v_booking.total_price<>round(v_booking.total_price,2) THEN
    RAISE EXCEPTION 'INVALID_BOOKING_TOTAL' USING ERRCODE='22023';
  END IF;
  RETURN v_booking;
END; $$;
REVOKE ALL ON FUNCTION private.lock_offline_order_booking(jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.price_offline_order_lines(p_operation jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_line jsonb;v_extra public.extras%ROWTYPE;v_lines jsonb:='[]';v_quantity integer;v_requested integer;
BEGIN
  PERFORM 1 FROM public.extras WHERE id IN
    (SELECT (value->>'product_id')::uuid FROM jsonb_array_elements(p_operation->'quoted_items')) ORDER BY id FOR UPDATE;
  FOR v_line IN SELECT value FROM jsonb_array_elements(p_operation->'quoted_items') LOOP
    SELECT * INTO v_extra FROM public.extras WHERE id=(v_line->>'product_id')::uuid;
    IF NOT FOUND OR v_extra.lounge_id IS DISTINCT FROM (p_operation->>'lounge_id')::uuid
      OR v_extra.is_active IS NOT TRUE OR v_extra.is_available IS NOT TRUE THEN
      RAISE EXCEPTION 'OFFLINE_PRODUCT_UNAVAILABLE' USING ERRCODE='55000';
    END IF;
    IF v_extra.price<0 OR v_extra.price IS NULL OR v_extra.price::text IN ('NaN','Infinity','-Infinity')
      OR v_extra.price<>round(v_extra.price,2) OR v_extra.price*100 IS DISTINCT FROM (v_line->>'unit_price_minor')::numeric THEN
      RAISE EXCEPTION 'OFFLINE_PRODUCT_PRICE_CHANGED' USING ERRCODE='22023';
    END IF;
    v_quantity:=(v_line->>'quantity')::integer;
    SELECT sum((value->>'quantity')::integer) INTO v_requested FROM jsonb_array_elements(p_operation->'quoted_items')
      WHERE (value->>'product_id')::uuid=v_extra.id;
    IF v_extra.track_stock IS NULL OR (v_extra.track_stock AND
      (v_extra.stock_quantity IS NULL OR v_extra.stock_quantity<v_requested)) THEN
      RAISE EXCEPTION 'OFFLINE_INSUFFICIENT_STOCK' USING ERRCODE='55000';
    END IF;
    v_lines:=v_lines||jsonb_build_array(jsonb_build_object('product_id',v_extra.id,'extra_id',v_extra.id,
      'quantity',v_quantity,'price',v_extra.price,'unit_price',v_extra.price,
      'total_price',v_extra.price*v_quantity,'name',v_extra.name));
  END LOOP;
  RETURN v_lines;
END; $$;
REVOKE ALL ON FUNCTION private.price_offline_order_lines(jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.insert_offline_order_lines(p_operation jsonb,p_lines jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_line jsonb;v_extra_id uuid;v_quantity integer;v_price numeric;
BEGIN
  FOR v_line IN SELECT value FROM jsonb_array_elements(p_lines) LOOP
    v_extra_id:=(v_line->>'extra_id')::uuid;v_quantity:=(v_line->>'quantity')::integer;v_price:=(v_line->>'price')::numeric;
    UPDATE public.extras SET stock_quantity=stock_quantity-v_quantity WHERE id=v_extra_id AND track_stock IS TRUE;
    INSERT INTO public.canteen_order_items(order_id,extra_id,quantity,unit_price,total_price,item_name)
      VALUES((p_operation->>'id')::uuid,v_extra_id,v_quantity,v_price,v_price*v_quantity,v_line->>'name');
    INSERT INTO public.booking_items(booking_id,product_id,extra_id,quantity,unit_price,total_price,price,name,note,status)
      VALUES((p_operation->>'booking_id')::uuid,v_extra_id,v_extra_id,v_quantity,v_price,v_price*v_quantity,v_price,
        v_line->>'name',p_operation->'payload'->>'note','pending');
  END LOOP;
END; $$;
REVOKE ALL ON FUNCTION private.insert_offline_order_lines(jsonb,jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.apply_cashier_order_operation(p_operation jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_booking public.bookings%ROWTYPE;v_lines jsonb;v_total numeric;v_paid numeric;v_final numeric;v_status text;
BEGIN
  PERFORM private.validate_offline_order_lines(p_operation);
  v_booking:=private.lock_offline_order_booking(p_operation);
  v_paid:=private.cash_collection_paid_amount(v_booking.id,v_booking.lounge_id,v_booking.payment_status);
  v_lines:=private.price_offline_order_lines(p_operation);
  SELECT sum((value->>'total_price')::numeric) INTO v_total FROM jsonb_array_elements(v_lines);
  IF (v_booking.total_price+v_total)*100 IS DISTINCT FROM (p_operation->>'quoted_total_minor')::numeric THEN
    RAISE EXCEPTION 'OFFLINE_BOOKING_PRICE_CHANGED' USING ERRCODE='22023';
  END IF;
  INSERT INTO public.canteen_orders(id,booking_id,lounge_id,user_id,shift_id,items,total_price,note,status,created_at)
    VALUES((p_operation->>'id')::uuid,v_booking.id,v_booking.lounge_id,v_booking.user_id,
      (p_operation->>'shift_id')::uuid,v_lines,v_total,p_operation->'payload'->>'note','pending',
      (p_operation->>'occurred_at')::timestamptz);
  PERFORM private.insert_offline_order_lines(p_operation,v_lines);
  v_status:=CASE WHEN v_paid=v_booking.total_price+v_total THEN 'paid' WHEN v_paid>0 THEN 'partial' ELSE 'unpaid' END;
  UPDATE public.bookings SET addons_price=coalesce(addons_price,0)+v_total,addons_total=coalesce(addons_price,0)+v_total,
    total_price=v_booking.total_price+v_total,payment_status=v_status,updated_at=now() WHERE id=v_booking.id
    RETURNING total_price INTO v_final;
  IF v_final*100 IS DISTINCT FROM (p_operation->>'quoted_total_minor')::numeric THEN
    RAISE EXCEPTION 'OFFLINE_BOOKING_PRICE_CHANGED' USING ERRCODE='22023';
  END IF;
  RETURN jsonb_build_object('booking_id',v_booking.id,'order_id',(p_operation->>'id')::uuid,
    'lounge_id',v_booking.lounge_id,'items',v_lines,'order_total_minor',v_total*100,
    'total_minor',v_final*100,'paid_minor',v_paid*100,'due_minor',(v_final-v_paid)*100,'payment_status',v_status);
END; $$;
REVOKE ALL ON FUNCTION private.apply_cashier_order_operation(jsonb) FROM PUBLIC,anon,authenticated;
COMMIT;
