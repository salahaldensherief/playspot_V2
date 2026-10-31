BEGIN;
CREATE OR REPLACE FUNCTION public.get_all_bookings_admin(p_lounge_id uuid DEFAULT NULL::uuid, p_status text DEFAULT NULL::text, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
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
      'user_phone', COALESCE(b.user_phone, p.phone),
      'user_email', p.email,
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
      'voucher_code', NULL::text,
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
    WHERE (v_super IS TRUE OR bk.lounge_id=ANY(v_lounge_ids))
      AND (v_target_lounge IS NULL OR bk.lounge_id = v_target_lounge)
      AND (p_status IS NULL OR p_status = '' OR bk.status::text = p_status)
    ORDER BY bk.created_at DESC,bk.id
    LIMIT p_limit
    OFFSET p_offset
  ) b
  LEFT JOIN public.profiles p ON b.user_id = p.id
  LEFT JOIN public.rooms r ON b.room_id = r.id;

  RETURN v_result;
END;
$function$;


REVOKE ALL ON FUNCTION public.get_all_bookings_admin(uuid,text,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_all_bookings_admin(uuid,text,integer,integer) TO authenticated;
COMMIT;
