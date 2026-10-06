CREATE OR REPLACE FUNCTION public.get_lounge_booking_rooms(
  p_lounge_id uuid,
  p_activity_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_rooms jsonb;
BEGIN
  IF p_lounge_id IS NULL THEN
    RAISE EXCEPTION 'Lounge ID is required' USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.lounges AS l
    WHERE l.id = p_lounge_id
      AND l.status = 'active'
      AND l.is_active IS TRUE
  ) THEN
    RETURN '[]'::jsonb;
  END IF;

  SELECT COALESCE(
    jsonb_agg(room_payload ORDER BY room_name, room_id),
    '[]'::jsonb
  )
  INTO v_rooms
  FROM (
    SELECT
      r.id AS room_id,
      COALESCE(r.name_en, r.name_ar, r.name, '') AS room_name,
      to_jsonb(r)
      || jsonb_build_object(
        'space_types',
        CASE
          WHEN st.id IS NULL THEN NULL
          ELSE jsonb_build_object(
            'id', st.id,
            'name', st.name,
            'label', st.label
          )
        END,
        'room_activities',
        COALESCE(
          (
            SELECT jsonb_agg(
              jsonb_build_object(
                'activity_type_id', a.id,
                'activity_types', jsonb_build_object(
                  'id', a.id,
                  'name', a.name,
                  'label', a.label,
                  'category', a.category,
                  'icon_name', a.icon_name,
                  'pricing_model', a.pricing_model,
                  'requires_screen', a.requires_screen,
                  'requires_controllers', a.requires_controllers
                )
              )
              ORDER BY COALESCE(a.sort_order, 9999), a.label, a.name
            )
            FROM public.room_activities AS ra
            JOIN public.activity_types AS a
              ON a.id = ra.activity_type_id
            WHERE ra.room_id = r.id
          ),
          '[]'::jsonb
        ),
        'promotions',
        COALESCE(
          (
            SELECT jsonb_agg(to_jsonb(pr) ORDER BY pr.created_at DESC)
            FROM public.promotions AS pr
            WHERE pr.is_active IS TRUE
              AND (pr.expires_at IS NULL OR pr.expires_at > now())
              AND (
                pr.room_id = r.id
                OR (pr.room_id IS NULL AND pr.lounge_id = r.lounge_id)
              )
          ),
          '[]'::jsonb
        )
      ) AS room_payload
    FROM public.rooms AS r
    LEFT JOIN public.space_types AS st
      ON st.id = r.space_type_id
    WHERE r.lounge_id = p_lounge_id
      AND COALESCE(r.is_active, true) IS TRUE
      AND COALESCE(r.status, 'available') NOT IN ('maintenance', 'deleted')
      AND (
        p_activity_id IS NULL
        OR EXISTS (
          SELECT 1
          FROM public.room_activities AS filter_ra
          WHERE filter_ra.room_id = r.id
            AND filter_ra.activity_type_id = p_activity_id
        )
      )
  ) AS catalog;

  RETURN v_rooms;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_lounge_booking_rooms(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_lounge_booking_rooms(uuid, uuid)
TO anon, authenticated;
