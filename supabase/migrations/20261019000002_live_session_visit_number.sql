BEGIN;
-- Rank the current booking against the customer's full lounge history.
-- Filtering to in_progress first made every single active booking visit #1.
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

  IF NOT (public.is_super_admin() OR private.can_operate_playspot_lounge(p_lounge_id) OR public.is_lounge_member_or_admin(p_lounge_id)) THEN
    RAISE EXCEPTION 'Unauthorized: You do not have permission to view live bookings for this lounge' USING ERRCODE = '42501';
  END IF;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', b.id,
      'out_booking_id', b.id,
      'lounge_id', b.lounge_id,
      'user_id', b.user_id,
      'room_id', b.room_id,
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
  LEFT JOIN public.rooms r ON b.room_id = r.id;

  RETURN v_result;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.get_live_bookings_with_items(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_live_bookings_with_items(uuid)
  TO authenticated, service_role, supabase_auth_admin;
COMMIT;
