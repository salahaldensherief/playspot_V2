BEGIN;

-- Restore booking schedule/payment and order notes in the authorized live read.
CREATE OR REPLACE FUNCTION public.get_live_bookings_with_items(p_lounge_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_result JSONB;
BEGIN
  IF p_lounge_id IS NULL THEN
    RAISE EXCEPTION 'Invalid lounge_id parameter';
  END IF;

  IF NOT (
    public.is_super_admin()
    OR EXISTS (
      SELECT 1 FROM public.lounges l
      WHERE l.id = p_lounge_id AND l.owner_id = auth.uid()
    )
    OR public.has_lounge_permission(p_lounge_id, 'bookings.view')
    OR public.has_lounge_permission(p_lounge_id, 'sessions_control')
  ) THEN
    RAISE EXCEPTION 'Unauthorized: You do not have permission to view live bookings for this lounge' USING ERRCODE = '42501';
  END IF;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', b.id,
      'out_booking_id', b.id,
      'lounge_id', b.lounge_id,
      'user_id', b.user_id,
      'room_id', b.room_id,
      'date', b.date,
      'scheduled_start_utc', (COALESCE(b.start_at, b.date + b.start_time) AT TIME ZONE COALESCE(l.timezone, 'Africa/Cairo')),
      'scheduled_end_utc', (b.end_at AT TIME ZONE COALESCE(l.timezone, 'Africa/Cairo')),
      'payment_status', b.payment_status,
      'payment_method', b.payment_method,
      'is_open_time', b.is_open_time,
      'start_time', b.start_time,
      'end_time', b.end_time,
      'duration_minutes', b.duration_minutes,
      'total_price', b.total_price,
      'addons_price', b.addons_price,
      'status', b.status,
      'created_at', b.created_at,
      'user_name', COALESCE(b.user_name, p.full_name, 'Walk-in Customer'),
      'user_phone', COALESCE(b.user_phone, p.phone),
      'room_name', COALESCE(r.name_ar, r.name_en, r.name, 'Room'),
      'visit_number', b.visit_num,
      'out_visit_number', b.visit_num,
      'canteen_orders', (
        SELECT COALESCE(jsonb_agg(
          jsonb_build_object(
            'id', co.id,
            'items', co.items,
            'total_price', co.total_price,
            'note', co.note,
            'status', co.status,
            'created_at', co.created_at
          )
        ), '[]'::jsonb)
        FROM public.canteen_orders co
        WHERE co.booking_id = b.id
      )
    )
  ), '[]'::jsonb) INTO v_result
  FROM (
    SELECT
      bk.*,
      (
        SELECT 1 + count(DISTINCT previous.created_at)
        FROM public.bookings AS previous
        WHERE previous.lounge_id = bk.lounge_id
          AND previous.created_at < bk.created_at
          AND previous.status IN ('in_progress'::public.booking_status, 'completed'::public.booking_status)
          AND (
            (bk.user_id IS NOT NULL AND previous.user_id = bk.user_id)
            OR (
              bk.user_id IS NULL
              AND previous.user_id IS NULL
              AND NULLIF(btrim(bk.user_phone), '') IS NOT NULL
              AND bk.user_phone NOT IN ('null', 'No Phone')
              AND btrim(previous.user_phone) = btrim(bk.user_phone)
            )
          )
      ) AS visit_num
    FROM public.bookings bk
    WHERE bk.lounge_id = p_lounge_id AND bk.status = 'in_progress'::public.booking_status
    ORDER BY bk.created_at DESC
  ) b
  LEFT JOIN public.profiles p ON b.user_id = p.id
  LEFT JOIN public.rooms r ON b.room_id = r.id
  JOIN public.lounges l ON b.lounge_id = l.id;

  RETURN v_result;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.get_live_bookings_with_items(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_live_bookings_with_items(uuid)
  TO authenticated, service_role, supabase_auth_admin;

-- Keep the dashboard bookings workspace on the same schedule and note contract.
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
      'scheduled_start_utc', (COALESCE(b.start_at, b.date + b.start_time) AT TIME ZONE COALESCE(l.timezone, 'Africa/Cairo')),
      'scheduled_end_utc', (b.end_at AT TIME ZONE COALESCE(l.timezone, 'Africa/Cairo')),
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
      'cancellation_reason', b.cancellation_reason,
      'cancelled_by', b.cancelled_by,
      'cancelled_at', b.cancelled_at,
      'rejection_reason', b.rejection_reason,
      'canteen_orders', (
        SELECT COALESCE(jsonb_agg(
          jsonb_build_object(
            'id', co.id,
            'items', co.items,
            'total_price', co.total_price,
            'note', co.note,
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
  LEFT JOIN public.rooms r ON b.room_id = r.id
  JOIN public.lounges l ON b.lounge_id = l.id;

  RETURN v_result;
END;
$function$;


COMMIT;


