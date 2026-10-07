BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
-- Preserve sales history while allowing catalogue entries to be deactivated.
ALTER TABLE public.canteen_order_items
  ADD COLUMN IF NOT EXISTS combo_id uuid REFERENCES public.canteen_combos(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS combo_line_id uuid REFERENCES public.canteen_order_items(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS line_kind text NOT NULL DEFAULT 'item'
    CHECK (line_kind IN ('item','combo_parent','combo_component')),
  ADD COLUMN IF NOT EXISTS upsell_rule_id uuid REFERENCES public.upsell_rules(id) ON DELETE RESTRICT;

CREATE OR REPLACE FUNCTION private.canteen_combo_window_available(
  p_combo public.canteen_combos, p_now timestamp
)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path TO '' AS $function$
  SELECT COALESCE(p_combo.is_active, false)
    AND (p_combo.valid_from IS NULL OR p_now::date >= p_combo.valid_from)
    AND (p_combo.valid_to IS NULL OR p_now::date <= p_combo.valid_to)
    AND (p_combo.days_of_week IS NULL OR extract(dow FROM p_now)::integer = ANY(p_combo.days_of_week))
    AND (p_combo.available_from IS NULL OR p_combo.available_to IS NULL
      OR CASE WHEN p_combo.available_to > p_combo.available_from
        THEN p_now::time >= p_combo.available_from AND p_now::time < p_combo.available_to
        ELSE p_now::time >= p_combo.available_from OR p_now::time < p_combo.available_to END);
$function$;
REVOKE ALL ON FUNCTION private.canteen_combo_window_available(public.canteen_combos,timestamp) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.place_canteen_order(
  p_booking_id uuid DEFAULT NULL, p_items jsonb DEFAULT '[]'::jsonb, p_note text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_booking public.bookings%ROWTYPE;
  v_shift_id uuid;
  v_lounge_id uuid;
  v_shift_count integer;
  v_order_id uuid := gen_random_uuid();
  v_parent_id uuid;
  v_note text := NULLIF(btrim(p_note), '');
  v_now timestamp;
  v_item jsonb;
  v_extra_id uuid;
  v_combo_id uuid;
  v_rule_id uuid;
  v_quantity integer;
  v_price numeric;
  v_name text;
  v_extra public.extras%ROWTYPE;
  v_combo public.canteen_combos%ROWTYPE;
  v_component record;
  v_demand record;
  v_suggestion jsonb;
  v_suggestions jsonb := '[]'::jsonb;
  v_total numeric := 0;
  v_lines jsonb := '[]'::jsonb;
  v_demands jsonb := '[]'::jsonb;
  v_shortages jsonb := '[]'::jsonb;
  v_component_count integer;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;
  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array'
     OR jsonb_array_length(p_items) NOT BETWEEN 1 AND 50 THEN
    RAISE EXCEPTION 'Items must be a JSON array containing 1 to 50 entries' USING ERRCODE = '22023';
  END IF;
  IF length(v_note) > 1000 THEN
    RAISE EXCEPTION 'Order note is too long' USING ERRCODE = '22023';
  END IF;
  IF p_booking_id IS NOT NULL THEN
    SELECT b.* INTO v_booking FROM public.bookings b WHERE b.id = p_booking_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002'; END IF;
    IF v_booking.status NOT IN ('pending','upcoming','in_progress') THEN
      RAISE EXCEPTION 'Canteen orders are not allowed for this booking status' USING ERRCODE = '55000';
    END IF;
    IF v_actor IS DISTINCT FROM v_booking.user_id
       AND NOT private.can_operate_playspot_lounge(v_booking.lounge_id) THEN
      RAISE EXCEPTION 'Not authorized to order for this booking' USING ERRCODE = '42501';
    END IF;
    v_lounge_id := v_booking.lounge_id;
    IF v_actor = v_booking.user_id THEN
      v_suggestions := private.get_canteen_upsell_suggestions(p_booking_id, true);
    END IF;
  ELSE
    SELECT count(*), (array_agg(s.id ORDER BY s.opened_at DESC))[1],
      (array_agg(s.lounge_id ORDER BY s.opened_at DESC))[1]
    INTO v_shift_count, v_shift_id, v_lounge_id
    FROM public.shifts s WHERE s.status = 'open' AND s.cashier_id = v_actor;
    IF v_shift_count <> 1 THEN
      RAISE EXCEPTION 'A single open cashier shift is required for a counter sale' USING ERRCODE = '55000';
    END IF;
  END IF;
  IF v_lounge_id IS NULL THEN RAISE EXCEPTION 'Booking has no lounge' USING ERRCODE = '55000'; END IF;
  SELECT timezone(l.timezone, now()) INTO v_now FROM public.lounges l WHERE l.id = v_lounge_id;

  -- Lock catalogue rows before expanding components. Use the same combo order
  -- as save_canteen_combo, then a global extra-id order for every cart.
  PERFORM c.id FROM public.canteen_combos c
  WHERE c.id IN (SELECT NULLIF(value->>'combo_id','')::uuid FROM jsonb_array_elements(p_items))
  ORDER BY c.id FOR SHARE;
  PERFORM ci.combo_id FROM public.canteen_combo_items ci
  WHERE ci.combo_id IN (SELECT NULLIF(value->>'combo_id','')::uuid FROM jsonb_array_elements(p_items))
  ORDER BY ci.combo_id, ci.extra_id FOR SHARE;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    IF jsonb_typeof(v_item) <> 'object' THEN
      RAISE EXCEPTION 'Each item must be an object' USING ERRCODE = '22023';
    END IF;
    BEGIN
      v_extra_id := NULLIF(v_item->>'extra_id','')::uuid;
      v_combo_id := NULLIF(v_item->>'combo_id','')::uuid;
      v_rule_id := NULLIF(v_item->>'upsell_rule_id','')::uuid;
      v_quantity := (v_item->>'quantity')::integer;
    EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
      RAISE EXCEPTION 'Invalid item identifier or quantity' USING ERRCODE = '22023';
    END;
    IF (v_extra_id IS NULL) = (v_combo_id IS NULL)
       OR v_quantity IS NULL OR v_quantity NOT BETWEEN 1 AND 100
       OR COALESCE(v_item->>'quantity','') !~ '^[0-9]+$' THEN
      RAISE EXCEPTION 'Each item requires exactly one extra_id or combo_id and quantity 1 to 100' USING ERRCODE = '22023';
    END IF;
    v_parent_id := gen_random_uuid();
    IF v_combo_id IS NOT NULL THEN
      SELECT c.* INTO v_combo FROM public.canteen_combos c
      WHERE c.id = v_combo_id AND c.lounge_id = v_lounge_id;
      IF NOT FOUND OR NOT private.canteen_combo_window_available(v_combo, v_now) THEN
        RAISE EXCEPTION 'Combo unavailable' USING ERRCODE = '23514';
      END IF;
      v_price := v_combo.price;
      v_name := COALESCE(v_combo.name_ar,v_combo.name_en);
      v_component_count := 0;
      FOR v_component IN SELECT ci.* FROM public.canteen_combo_items ci WHERE ci.combo_id = v_combo_id LOOP
        v_component_count := v_component_count + 1;
        v_demands := v_demands || jsonb_build_array(jsonb_build_object('id',v_component.extra_id,
          'quantity',v_component.quantity::bigint * v_quantity));
      END LOOP;
      IF v_component_count = 0 THEN RAISE EXCEPTION 'Combo has no components' USING ERRCODE = '23514'; END IF;
    ELSE
      SELECT e.* INTO v_extra FROM public.extras e WHERE e.id = v_extra_id AND e.lounge_id = v_lounge_id;
      IF NOT FOUND THEN RAISE EXCEPTION 'Extra unavailable' USING ERRCODE = '23514'; END IF;
      v_price := v_extra.price;
      v_name := COALESCE(v_extra.name_ar,v_extra.name_en,v_extra.name);
      v_demands := v_demands || jsonb_build_array(jsonb_build_object('id',v_extra_id,'quantity',v_quantity));
    END IF;
    IF v_rule_id IS NOT NULL THEN
      SELECT value INTO v_suggestion FROM jsonb_array_elements(v_suggestions)
      WHERE value->>'rule_id' = v_rule_id::text
        AND value->>'target_id' = COALESCE(v_combo_id,v_extra_id)::text
        AND value->>'suggestion_type' = CASE WHEN v_combo_id IS NOT NULL THEN 'combo' ELSE 'extra' END;
      IF NOT FOUND THEN RAISE EXCEPTION 'UPSELL_OFFER_UNAVAILABLE' USING ERRCODE = '23514'; END IF;
      v_price := round(v_price * (1 - (v_suggestion->>'discount_percent')::numeric / 100),2);
    END IF;
    IF v_price IS NULL OR v_price < 0 THEN RAISE EXCEPTION 'Invalid canteen price' USING ERRCODE = '23514'; END IF;
    v_total := v_total + round(v_price * v_quantity,2);
    v_lines := v_lines || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
      'id',v_parent_id,'extra_id',v_extra_id,'product_id',v_extra_id,'combo_id',v_combo_id,
      'upsell_rule_id',v_rule_id,'is_combo',v_combo_id IS NOT NULL,'name',v_name,
      'name_ar',CASE WHEN v_combo_id IS NOT NULL THEN v_combo.name_ar ELSE v_extra.name_ar END,
      'name_en',CASE WHEN v_combo_id IS NOT NULL THEN v_combo.name_en ELSE v_extra.name_en END,
      'quantity',v_quantity,'price',v_price,'unit_price',v_price,'total_price',round(v_price*v_quantity,2),
      'line_kind',CASE WHEN v_combo_id IS NOT NULL THEN 'combo_parent' ELSE 'item' END)));
  END LOOP;

  -- Aggregate shared components and standalone items before testing stock.
  -- This prevents each line independently accepting the same last units.
  FOR v_demand IN
    SELECT (value->>'id')::uuid id, sum((value->>'quantity')::bigint) quantity
    FROM jsonb_array_elements(v_demands) GROUP BY 1 ORDER BY 1
  LOOP
    SELECT e.* INTO v_extra FROM public.extras e WHERE e.id = v_demand.id FOR UPDATE;
    IF NOT FOUND OR v_extra.lounge_id IS DISTINCT FROM v_lounge_id
       OR v_extra.is_active IS NOT TRUE OR v_extra.is_available IS NOT TRUE THEN
      RAISE EXCEPTION 'Extra or combo component unavailable' USING ERRCODE = '23514';
    END IF;
    IF v_demand.quantity > 2147483647 THEN RAISE EXCEPTION 'Quantity is too large' USING ERRCODE = '22023'; END IF;
    IF v_extra.track_stock IS TRUE AND COALESCE(v_extra.stock_quantity,0) < v_demand.quantity THEN
      v_shortages := v_shortages || jsonb_build_array(jsonb_build_object('id',v_extra.id,
        'name',COALESCE(v_extra.name_ar,v_extra.name_en,v_extra.name),
        'available',COALESCE(v_extra.stock_quantity,0),'requested',v_demand.quantity));
    END IF;
  END LOOP;
  IF jsonb_array_length(v_shortages) > 0 THEN
    RAISE EXCEPTION 'OUT_OF_STOCK' USING ERRCODE = 'P0001',
      DETAIL = jsonb_build_object('unavailable_items',v_shortages)::text;
  END IF;

  -- Standard item prices are re-read under the inventory lock; a changed
  -- catalogue cannot silently produce a different charge from the line price.
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_lines) line JOIN public.extras e
    ON e.id = (line->>'extra_id')::uuid LEFT JOIN public.upsell_rules rule ON rule.id = (line->>'upsell_rule_id')::uuid
    WHERE round(e.price * (1 - COALESCE(rule.discount_percent,0)/100),2)
      IS DISTINCT FROM (line->>'unit_price')::numeric) THEN
    RAISE EXCEPTION 'CANTEEN_PRICE_CHANGED' USING ERRCODE = '40001';
  END IF;
  UPDATE public.extras e SET stock_quantity = e.stock_quantity - d.quantity
  FROM (SELECT (value->>'id')::uuid id, sum((value->>'quantity')::integer)::integer quantity
    FROM jsonb_array_elements(v_demands) GROUP BY 1) d
  WHERE e.id = d.id AND e.track_stock IS TRUE;

  INSERT INTO public.canteen_orders(id,booking_id,lounge_id,user_id,shift_id,items,total_price,status,note,notes)
  VALUES(v_order_id,p_booking_id,v_lounge_id,COALESCE(v_booking.user_id,v_actor),v_shift_id,v_lines,v_total,'pending',v_note,v_note);
  FOR v_item IN SELECT value FROM jsonb_array_elements(v_lines) LOOP
    v_parent_id := (v_item->>'id')::uuid;
    v_combo_id := (v_item->>'combo_id')::uuid;
    INSERT INTO public.canteen_order_items(id,order_id,extra_id,combo_id,upsell_rule_id,item_name,quantity,unit_price,total_price,line_kind)
    VALUES(v_parent_id,v_order_id,(v_item->>'extra_id')::uuid,v_combo_id,(v_item->>'upsell_rule_id')::uuid,
      v_item->>'name',(v_item->>'quantity')::integer,(v_item->>'unit_price')::numeric,
      (v_item->>'total_price')::numeric,v_item->>'line_kind');
    IF v_combo_id IS NOT NULL THEN
      INSERT INTO public.canteen_order_items(order_id,extra_id,combo_id,combo_line_id,item_name,quantity,unit_price,total_price,line_kind)
      SELECT v_order_id,ci.extra_id,v_combo_id,v_parent_id,COALESCE(e.name_ar,e.name_en,e.name),
        ci.quantity * (v_item->>'quantity')::integer,0,0,'combo_component'
      FROM public.canteen_combo_items ci JOIN public.extras e ON e.id = ci.extra_id WHERE ci.combo_id = v_combo_id;
    END IF;
    IF p_booking_id IS NOT NULL THEN
      INSERT INTO public.booking_items(booking_id,extra_id,product_id,quantity,unit_price,total_price,price,name,status)
      VALUES(p_booking_id,(v_item->>'extra_id')::uuid,(v_item->>'extra_id')::uuid,
        (v_item->>'quantity')::integer,(v_item->>'unit_price')::numeric,(v_item->>'total_price')::numeric,
        (v_item->>'unit_price')::numeric,v_item->>'name','pending');
    END IF;
  END LOOP;
  IF p_booking_id IS NOT NULL THEN
    UPDATE public.bookings SET addons_price = COALESCE(addons_price,0) + v_total,
      addons_total = COALESCE(addons_price,0) + v_total, updated_at = now() WHERE id = p_booking_id;
    FOR v_rule_id IN SELECT DISTINCT (value->>'upsell_rule_id')::uuid FROM jsonb_array_elements(v_lines)
      WHERE value->>'upsell_rule_id' IS NOT NULL LOOP
      PERFORM public.record_upsell_event(v_rule_id,p_booking_id,'accepted',v_order_id,NULL);
    END LOOP;
  ELSE
    INSERT INTO public.shift_payments(shift_id,lounge_id,payment_method,category,amount,paid_at,canteen_order_id)
    VALUES(v_shift_id,v_lounge_id,'cash','other',v_total,now(),v_order_id);
  END IF;
  RETURN jsonb_build_object('success',true,'order_id',v_order_id,'lounge_id',v_lounge_id,'shift_id',v_shift_id,'total_price',v_total);
END;
$function$;
REVOKE ALL ON FUNCTION public.place_canteen_order(uuid,jsonb,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.place_canteen_order(uuid,jsonb,text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION private.get_canteen_upsell_suggestions(p_booking_id uuid, p_for_order boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_now timestamp := timezone('Africa/Cairo', now());
  v_start_at timestamp;
  v_elapsed_minutes integer;
  v_result jsonb := '[]'::jsonb;
  v_rule public.upsell_rules%ROWTYPE;
  v_trigger_ok boolean;
  v_target_type text;
  v_target_id uuid;
  v_name_ar text;
  v_name_en text;
  v_image_url text;
  v_original_price numeric;
  v_discount numeric;
  v_final_price numeric;
  v_start_time time;
  v_end_time time;
  v_category text;
  v_minutes integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000';
  END IF;

  SELECT b.*
  INTO v_booking
  FROM public.bookings AS b
  WHERE b.id = p_booking_id
    AND b.user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found' USING ERRCODE='P0002';
  END IF;

  IF v_booking.status <> 'in_progress'::public.booking_status THEN
    RETURN '[]'::jsonb;
  END IF;

  SELECT timezone(l.timezone, now()) INTO v_now FROM public.lounges l WHERE l.id = v_booking.lounge_id;
  v_start_at := COALESCE(timezone((SELECT timezone FROM public.lounges WHERE id = v_booking.lounge_id),
    COALESCE(v_booking.actual_start_time, v_booking.open_time_started_at)),
    v_booking.date + v_booking.start_time);
  v_elapsed_minutes := GREATEST(
    0,
    floor(extract(epoch FROM (v_now - v_start_at))/60.0)::integer
  );

  FOR v_rule IN
    SELECT r.*
    FROM public.upsell_rules AS r
    WHERE r.lounge_id = v_booking.lounge_id
      AND r.is_active IS TRUE
      AND NOT EXISTS (SELECT 1 FROM public.canteen_upsell_events ev
        WHERE ev.rule_id = r.id AND ev.booking_id = p_booking_id
          AND ev.event_type IN ('accepted','conversion','dismissed'))
      AND (p_for_order OR (
        SELECT count(*)
        FROM public.canteen_upsell_events AS ev
        WHERE ev.rule_id = r.id
          AND ev.booking_id = p_booking_id
          AND ev.event_type IN ('shown','impression')
      ) < r.max_impressions_per_booking)
    ORDER BY r.priority DESC, r.created_at ASC
  LOOP
    v_trigger_ok := false;

    CASE v_rule.trigger_type
      WHEN 'session_minutes_elapsed' THEN
        BEGIN
          v_minutes := COALESCE((v_rule.trigger_params->>'minutes')::integer,45);
        EXCEPTION WHEN OTHERS THEN
          v_minutes := 45;
        END;
        v_trigger_ok := v_elapsed_minutes >= GREATEST(0,v_minutes);

      WHEN 'session_start' THEN
        v_trigger_ok := v_elapsed_minutes BETWEEN 0 AND 15;

      WHEN 'time_of_day' THEN
        BEGIN
          v_start_time := COALESCE(
            NULLIF(v_rule.trigger_params->>'start_time','')::time,
            '00:00'::time
          );
          v_end_time := COALESCE(
            NULLIF(v_rule.trigger_params->>'end_time','')::time,
            '23:59:59'::time
          );
        EXCEPTION WHEN OTHERS THEN
          v_start_time := '00:00'::time;
          v_end_time := '23:59:59'::time;
        END;
        v_trigger_ok := CASE
          WHEN v_end_time > v_start_time
            THEN v_now::time >= v_start_time AND v_now::time < v_end_time
          ELSE v_now::time >= v_start_time OR v_now::time < v_end_time
        END;

      WHEN 'cart_contains_category' THEN
        v_category := lower(btrim(COALESCE(
          v_rule.trigger_params->>'category',''
        )));
        v_trigger_ok := v_category <> ''
          AND EXISTS (
            SELECT 1
            FROM public.canteen_orders AS co
            JOIN public.canteen_order_items AS coi ON coi.order_id = co.id
            JOIN public.extras AS e ON e.id = coi.extra_id
            WHERE co.booking_id = p_booking_id
              AND lower(btrim(e.category)) = v_category
          );

      WHEN 'room_type' THEN
        v_trigger_ok := EXISTS (SELECT 1 FROM public.rooms room WHERE room.id = v_booking.room_id
          AND (room.room_type = v_rule.trigger_params->>'room_type'
            OR room.space_type_id::text = v_rule.trigger_params->>'space_type_id'));
      ELSE
        v_trigger_ok := false;
    END CASE;

    IF NOT v_trigger_ok THEN
      CONTINUE;
    END IF;

    IF v_rule.suggest_combo_id IS NOT NULL THEN
      SELECT
        'combo',
        c.id,
        c.name_ar,
        c.name_en,
        c.image_url,
        c.price
      INTO
        v_target_type,
        v_target_id,
        v_name_ar,
        v_name_en,
        v_image_url,
        v_original_price
      FROM public.canteen_combos AS c
      WHERE c.id = v_rule.suggest_combo_id
        AND c.lounge_id = v_booking.lounge_id
        AND private.canteen_combo_window_available(c, v_now)
        AND EXISTS (SELECT 1 FROM public.canteen_combo_items ci WHERE ci.combo_id = c.id)
        AND NOT EXISTS (
          SELECT 1
          FROM public.canteen_combo_items AS ci
          JOIN public.extras AS e ON e.id = ci.extra_id
          WHERE ci.combo_id = c.id
            AND (
              e.lounge_id IS DISTINCT FROM v_booking.lounge_id
                    OR COALESCE(e.is_active,true) IS FALSE
              OR COALESCE(e.is_available,true) IS FALSE
              OR (
                COALESCE(e.track_stock,false) IS TRUE
                AND COALESCE(e.stock_quantity,0) < ci.quantity
              )
            )
        );
    ELSE
      SELECT
        'extra',
        e.id,
        COALESCE(e.name_ar,e.name),
        COALESCE(e.name_en,e.name),
        e.image_url,
        e.price
      INTO
        v_target_type,
        v_target_id,
        v_name_ar,
        v_name_en,
        v_image_url,
        v_original_price
      FROM public.extras AS e
      WHERE e.id = v_rule.suggest_extra_id
        AND e.lounge_id = v_booking.lounge_id
        AND COALESCE(e.is_active,true) IS TRUE
        AND COALESCE(e.is_available,true) IS TRUE
        AND (
          COALESCE(e.track_stock,false) IS FALSE
          OR COALESCE(e.stock_quantity,0) > 0
        );
    END IF;

    IF v_target_id IS NULL THEN
      CONTINUE;
    END IF;

    v_discount := LEAST(
      100,
      GREATEST(0,COALESCE(v_rule.discount_percent,0))
    );
    v_final_price := round(
      GREATEST(0,v_original_price * (1 - v_discount/100.0)),
      2
    );

    v_result := v_result || jsonb_build_array(
      jsonb_build_object(
        'rule_id', v_rule.id,
        'suggestion_type', v_target_type,
        'target_id', v_target_id,
        'name_ar', v_name_ar,
        'name_en', v_name_en,
        'original_price', v_original_price,
        'discount_percent', v_discount,
        'final_price', v_final_price,
        'image_url', v_image_url
      )
    );

    v_target_id := NULL;
    IF NOT p_for_order AND jsonb_array_length(v_result) >= 2 THEN EXIT; END IF;
  END LOOP;

  RETURN v_result;
END;
$function$
;
REVOKE ALL ON FUNCTION private.get_canteen_upsell_suggestions(uuid,boolean) FROM PUBLIC, anon, authenticated;
CREATE OR REPLACE FUNCTION public.get_upsell_suggestions(p_booking_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $function$
  SELECT private.get_canteen_upsell_suggestions(p_booking_id, false);
$function$;
REVOKE ALL ON FUNCTION public.get_upsell_suggestions(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_upsell_suggestions(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.normalize_canteen_order_items()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
BEGIN
  -- Prices are immutable order snapshots, including discounted offer prices.
  SELECT COALESCE(jsonb_agg(jsonb_strip_nulls(x.value || jsonb_build_object(
    'name',COALESCE(NULLIF(x.value->>'name',''),c.name_ar,e.name_en,e.name_ar,e.name),
    'name_ar',COALESCE(x.value->>'name_ar',c.name_ar,e.name_ar),
    'name_en',COALESCE(x.value->>'name_en',c.name_en,e.name_en),
    'quantity',COALESCE((x.value->>'quantity')::integer,1),
    'price',COALESCE((x.value->>'unit_price')::numeric,(x.value->>'price')::numeric,c.price,e.price,0),
    'unit_price',COALESCE((x.value->>'unit_price')::numeric,(x.value->>'price')::numeric,c.price,e.price,0),
    'total_price',COALESCE((x.value->>'total_price')::numeric,
      COALESCE((x.value->>'unit_price')::numeric,(x.value->>'price')::numeric,c.price,e.price,0)
      * COALESCE((x.value->>'quantity')::integer,1)))) ORDER BY x.ord),'[]'::jsonb)
  INTO NEW.items
  FROM jsonb_array_elements(COALESCE(NEW.items,'[]'::jsonb)) WITH ORDINALITY x(value,ord)
  LEFT JOIN public.extras e ON e.id::text = COALESCE(x.value->>'extra_id',x.value->>'product_id',x.value->>'id')
  LEFT JOIN public.canteen_combos c ON c.id::text = x.value->>'combo_id';
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.normalize_canteen_order_items() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.record_upsell_event(
  p_rule_id uuid, p_booking_id uuid, p_event text,
  p_canteen_order_id uuid DEFAULT NULL, p_amount numeric DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_rule public.upsell_rules%ROWTYPE;
  v_event text := lower(btrim(COALESCE(p_event,'')));
  v_amount numeric := 0;
  v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000'; END IF;
  IF v_event NOT IN ('shown','dismissed','accepted','impression','conversion') THEN
    RAISE EXCEPTION 'Unsupported upsell event' USING ERRCODE = '22023';
  END IF;
  SELECT b.* INTO v_booking FROM public.bookings b
    WHERE b.id = p_booking_id AND b.user_id = auth.uid() FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002'; END IF;
  SELECT r.* INTO v_rule FROM public.upsell_rules r
    WHERE r.id = p_rule_id AND r.lounge_id = v_booking.lounge_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Upsell rule not found' USING ERRCODE = 'P0002'; END IF;
  IF v_event IN ('accepted','conversion') THEN
    -- A tap or a supplied amount is not proof of a purchase. Only discounted
    -- lines saved by the order RPC contribute to conversion revenue.
    SELECT sum(coi.total_price) INTO v_amount
    FROM public.canteen_orders co JOIN public.canteen_order_items coi ON coi.order_id = co.id
    WHERE co.id = p_canteen_order_id AND co.booking_id = p_booking_id
      AND co.user_id = auth.uid() AND co.status <> 'cancelled'
      AND coi.upsell_rule_id = p_rule_id AND coi.line_kind IN ('item','combo_parent');
    IF v_amount IS NULL THEN RAISE EXCEPTION 'UPSELL_PURCHASE_REQUIRED' USING ERRCODE = '23514'; END IF;
    SELECT id INTO v_id FROM public.canteen_upsell_events
    WHERE rule_id = p_rule_id AND booking_id = p_booking_id AND canteen_order_id = p_canteen_order_id
      AND event_type IN ('accepted','conversion') ORDER BY created_at LIMIT 1;
    v_event := 'accepted';
  ELSIF v_event = 'dismissed' THEN
    SELECT id INTO v_id FROM public.canteen_upsell_events
    WHERE rule_id = p_rule_id AND booking_id = p_booking_id AND event_type = 'dismissed'
    ORDER BY created_at LIMIT 1;
  ELSE
    IF v_booking.status <> 'in_progress' OR v_rule.is_active IS NOT TRUE THEN
      RAISE EXCEPTION 'UPSELL_OFFER_UNAVAILABLE' USING ERRCODE = '23514';
    END IF;
    IF (SELECT count(*) FROM public.canteen_upsell_events
      WHERE rule_id = p_rule_id AND booking_id = p_booking_id AND event_type IN ('shown','impression'))
      >= v_rule.max_impressions_per_booking THEN
      RETURN jsonb_build_object('success',true,'recorded',false,'event_type','shown');
    END IF;
    v_event := 'shown';
  END IF;
  IF v_id IS NULL THEN
    INSERT INTO public.canteen_upsell_events(lounge_id,rule_id,booking_id,canteen_order_id,event_type,revenue_generated)
    VALUES(v_booking.lounge_id,p_rule_id,p_booking_id,
      CASE WHEN v_event = 'accepted' THEN p_canteen_order_id ELSE NULL END,v_event,COALESCE(v_amount,0)) RETURNING id INTO v_id;
  END IF;
  RETURN jsonb_build_object('success',true,'event_id',v_id,'event_type',v_event);
END;
$function$;
REVOKE ALL ON FUNCTION public.record_upsell_event(uuid,uuid,text,uuid,numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_upsell_event(uuid,uuid,text,uuid,numeric) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_canteen_menu(p_lounge_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_now timestamp := timezone('Africa/Cairo', now());
  v_dow integer := extract(dow from timezone('Africa/Cairo', now()))::integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.lounges AS l
    WHERE l.id = p_lounge_id
      AND COALESCE(l.is_active,true) IS TRUE
      AND COALESCE(l.status,'active') <> 'deleted'
  ) THEN
    RAISE EXCEPTION 'Lounge not found' USING ERRCODE='P0002';
  END IF;

  SELECT timezone(l.timezone,now()) INTO v_now FROM public.lounges l WHERE l.id = p_lounge_id;
  v_dow := extract(dow FROM v_now)::integer;

  RETURN jsonb_build_object(
    'extras',
    COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', e.id,
          'lounge_id', e.lounge_id,
          'name', e.name,
          'name_ar', e.name_ar,
          'name_en', e.name_en,
          'price', e.price,
          'category', e.category,
          'icon_key', e.icon_key,
          'image_url', e.image_url,
          'is_available', COALESCE(e.is_available,true)
            AND (
              COALESCE(e.track_stock,false) IS FALSE
              OR COALESCE(e.stock_quantity,0) > 0
            ),
          'stock_quantity', COALESCE(e.stock_quantity,0),
          'track_stock', COALESCE(e.track_stock,false),
          'min_stock_alert', COALESCE(e.min_stock_alert,5)
        )
        ORDER BY e.category, COALESCE(e.name_en,e.name_ar,e.name)
      )
      FROM public.extras AS e
      WHERE e.lounge_id = p_lounge_id
        AND COALESCE(e.is_active,true) IS TRUE
        AND COALESCE(e.is_available,true) IS TRUE
    ), '[]'::jsonb),
    'combos',
    COALESCE((
      SELECT jsonb_agg(combo_payload ORDER BY sort_order, name_ar)
      FROM (
        SELECT
          c.sort_order,
          c.name_ar,
          jsonb_build_object(
            'id', c.id,
            'name_ar', c.name_ar,
            'name_en', c.name_en,
            'description_ar', c.description_ar,
            'description_en', c.description_en,
            'price', c.price,
            'image_url', c.image_url,
            'separate_items_price', COALESCE((
              SELECT sum(e.price * ci.quantity)
              FROM public.canteen_combo_items AS ci
              JOIN public.extras AS e ON e.id = ci.extra_id
              WHERE ci.combo_id = c.id
            ),0),
            'savings', GREATEST(
              0,
              COALESCE((
                SELECT sum(e.price * ci.quantity)
                FROM public.canteen_combo_items AS ci
                JOIN public.extras AS e ON e.id = ci.extra_id
                WHERE ci.combo_id = c.id
              ),0) - c.price
            ),
            'is_available',
              private.canteen_combo_window_available(c,v_now)
              AND EXISTS (SELECT 1 FROM public.canteen_combo_items ci WHERE ci.combo_id = c.id)
              AND (c.valid_from IS NULL OR v_now::date >= c.valid_from)
              AND (c.valid_to IS NULL OR v_now::date <= c.valid_to)
              AND (c.days_of_week IS NULL OR v_dow = ANY(c.days_of_week))
              AND (
                c.available_from IS NULL
                OR c.available_to IS NULL
                OR CASE
                  WHEN c.available_to > c.available_from
                    THEN v_now::time >= c.available_from
                     AND v_now::time < c.available_to
                  ELSE v_now::time >= c.available_from
                    OR v_now::time < c.available_to
                END
              )
              AND NOT EXISTS (
                SELECT 1
                FROM public.canteen_combo_items AS ci
                JOIN public.extras AS e ON e.id = ci.extra_id
                WHERE ci.combo_id = c.id
                  AND (
                    e.lounge_id IS DISTINCT FROM p_lounge_id
                    OR COALESCE(e.is_active,true) IS FALSE
                    OR COALESCE(e.is_available,true) IS FALSE
                    OR (
                      COALESCE(e.track_stock,false) IS TRUE
                      AND COALESCE(e.stock_quantity,0) < ci.quantity
                    )
                  )
              ),
            'items', COALESCE((
              SELECT jsonb_agg(
                jsonb_build_object(
                  'extra_id', e.id,
                  'name_ar', COALESCE(e.name_ar,e.name),
                  'name_en', COALESCE(e.name_en,e.name),
                  'price', e.price,
                  'quantity', ci.quantity
                )
                ORDER BY COALESCE(e.name_en,e.name_ar,e.name)
              )
              FROM public.canteen_combo_items AS ci
              JOIN public.extras AS e ON e.id = ci.extra_id
              WHERE ci.combo_id = c.id
            ), '[]'::jsonb)
          ) AS combo_payload
        FROM public.canteen_combos AS c
        WHERE c.lounge_id = p_lounge_id
          AND COALESCE(c.is_active,true) IS TRUE
          AND (c.valid_from IS NULL OR v_now::date >= c.valid_from)
          AND (c.valid_to IS NULL OR v_now::date <= c.valid_to)
          AND (c.days_of_week IS NULL OR v_dow = ANY(c.days_of_week))
      ) AS q
    ), '[]'::jsonb)
  );
END;
$function$
;

REVOKE ALL ON FUNCTION public.get_canteen_menu(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_canteen_menu(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.save_canteen_combo(
  p_combo jsonb,
  p_items jsonb DEFAULT '[]'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_id uuid;
  v_lounge_id uuid;
  v_item jsonb;
  v_extra_id uuid;
  v_quantity integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000';
  END IF;

  BEGIN
    v_id := NULLIF(p_combo->>'id','')::uuid;
    v_lounge_id := NULLIF(p_combo->>'lounge_id','')::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    RAISE EXCEPTION 'Invalid combo identifier' USING ERRCODE='22023';
  END;

  IF v_lounge_id IS NULL THEN
    RAISE EXCEPTION 'Lounge is required' USING ERRCODE='22023';
  END IF;

  IF NOT (
    public.is_super_admin()
    OR public.has_lounge_permission(v_lounge_id,'menu_manage_items')
  ) THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501';
  END IF;

  IF COALESCE((p_combo->>'price')::numeric,-1) < 0 THEN
    RAISE EXCEPTION 'Invalid combo price' USING ERRCODE='22023';
  END IF;

  IF NULLIF(btrim(COALESCE(p_combo->>'name_ar','')),'') IS NULL THEN
    RAISE EXCEPTION 'Arabic combo name is required' USING ERRCODE='22023';
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array'
     OR jsonb_array_length(p_items) NOT BETWEEN 1 AND 50 THEN
    RAISE EXCEPTION 'Combo items must be an array' USING ERRCODE='22023';
  END IF;

  IF v_id IS NULL THEN
    INSERT INTO public.canteen_combos (
      lounge_id,name_ar,name_en,description_ar,description_en,image_url,
      price,days_of_week,available_from,available_to,valid_from,valid_to,
      is_active,sort_order
    )
    VALUES (
      v_lounge_id,
      btrim(p_combo->>'name_ar'),
      NULLIF(btrim(COALESCE(p_combo->>'name_en','')),''),
      NULLIF(btrim(COALESCE(p_combo->>'description_ar','')),''),
      NULLIF(btrim(COALESCE(p_combo->>'description_en','')),''),
      NULLIF(btrim(COALESCE(p_combo->>'image_url','')),''),
      (p_combo->>'price')::numeric,
      CASE
        WHEN p_combo ? 'days_of_week'
          AND jsonb_typeof(p_combo->'days_of_week') = 'array'
        THEN ARRAY(
          SELECT jsonb_array_elements_text(p_combo->'days_of_week')::integer
        )
        ELSE NULL
      END,
      NULLIF(p_combo->>'available_from','')::time,
      NULLIF(p_combo->>'available_to','')::time,
      NULLIF(p_combo->>'valid_from','')::date,
      NULLIF(p_combo->>'valid_to','')::date,
      COALESCE((p_combo->>'is_active')::boolean,true),
      COALESCE((p_combo->>'sort_order')::integer,0)
    )
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.canteen_combos AS c
    SET
      name_ar=btrim(p_combo->>'name_ar'),
      name_en=NULLIF(btrim(COALESCE(p_combo->>'name_en','')),''),
      description_ar=NULLIF(btrim(COALESCE(p_combo->>'description_ar','')),''),
      description_en=NULLIF(btrim(COALESCE(p_combo->>'description_en','')),''),
      image_url=NULLIF(btrim(COALESCE(p_combo->>'image_url','')),''),
      price=(p_combo->>'price')::numeric,
      days_of_week=CASE
        WHEN p_combo ? 'days_of_week'
          AND jsonb_typeof(p_combo->'days_of_week') = 'array'
        THEN ARRAY(
          SELECT jsonb_array_elements_text(p_combo->'days_of_week')::integer
        )
        ELSE NULL
      END,
      available_from=NULLIF(p_combo->>'available_from','')::time,
      available_to=NULLIF(p_combo->>'available_to','')::time,
      valid_from=NULLIF(p_combo->>'valid_from','')::date,
      valid_to=NULLIF(p_combo->>'valid_to','')::date,
      is_active=COALESCE((p_combo->>'is_active')::boolean,true),
      sort_order=COALESCE((p_combo->>'sort_order')::integer,0),
      updated_at=now()
    WHERE c.id=v_id
      AND c.lounge_id=v_lounge_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Combo not found' USING ERRCODE='P0002';
    END IF;
  END IF;

  DELETE FROM public.canteen_combo_items WHERE combo_id=v_id;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items)
  LOOP
    BEGIN
      v_extra_id := NULLIF(v_item->>'extra_id','')::uuid;
      v_quantity := COALESCE((v_item->>'quantity')::integer,1);
    EXCEPTION WHEN OTHERS THEN
      RAISE EXCEPTION 'Invalid combo item' USING ERRCODE='22023';
    END;

    IF v_extra_id IS NULL OR v_quantity NOT BETWEEN 1 AND 100 THEN
      RAISE EXCEPTION 'Invalid combo item' USING ERRCODE='22023';
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM public.extras AS e
      WHERE e.id=v_extra_id
        AND e.lounge_id=v_lounge_id
        AND COALESCE(e.is_active,true) IS TRUE
    ) THEN
      RAISE EXCEPTION 'Combo item does not belong to lounge'
        USING ERRCODE='23514';
    END IF;

    INSERT INTO public.canteen_combo_items(combo_id,extra_id,quantity)
    VALUES(v_id,v_extra_id,v_quantity);
  END LOOP;

  RETURN (
    SELECT to_jsonb(c)
      || jsonb_build_object(
        'items', COALESCE((
          SELECT jsonb_agg(
            jsonb_build_object(
              'extra_id',e.id,
              'name_ar',COALESCE(e.name_ar,e.name),
              'name_en',COALESCE(e.name_en,e.name),
              'price',e.price,
              'quantity',ci.quantity
            )
          )
          FROM public.canteen_combo_items AS ci
          JOIN public.extras AS e ON e.id=ci.extra_id
          WHERE ci.combo_id=c.id
        ),'[]'::jsonb)
      )
    FROM public.canteen_combos AS c
    WHERE c.id=v_id
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_canteen_menu(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_upsell_suggestions(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.record_upsell_event(uuid,uuid,text,uuid,numeric)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.save_canteen_combo(jsonb,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_canteen_combo(jsonb,jsonb) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
COMMIT;
