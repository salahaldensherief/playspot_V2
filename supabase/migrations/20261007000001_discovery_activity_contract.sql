CREATE OR REPLACE FUNCTION public.get_discovery_activities()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', activity.id,
        'name_ar', activity.display_name,
        'name_en', activity.display_name,
        'icon_key', activity.icon_key,
        'activity_category', activity.activity_category,
        'rooms_count', activity.rooms_count,
        'lounges_count', activity.lounges_count
      )
      ORDER BY activity.sort_order, activity.display_name, activity.id
    ),
    '[]'::jsonb
  )
  FROM (
    SELECT
      a.id,
      COALESCE(
        NULLIF(btrim(a.label), ''),
        initcap(replace(a.name, '_', ' '))
      ) AS display_name,
      COALESCE(NULLIF(btrim(a.icon_name), ''), 'category') AS icon_key,
      COALESCE(NULLIF(btrim(a.category), ''), 'other') AS activity_category,
      COALESCE(a.sort_order, 9999) AS sort_order,
      count(DISTINCT r.id) AS rooms_count,
      count(DISTINCT r.lounge_id) AS lounges_count
    FROM public.activity_types AS a
    JOIN public.room_activities AS ra
      ON ra.activity_type_id = a.id
    JOIN public.rooms AS r
      ON r.id = ra.room_id
    JOIN public.lounges AS l
      ON l.id = r.lounge_id
    WHERE COALESCE(r.is_active, true) IS TRUE
      AND COALESCE(r.status, 'available') <> 'deleted'
      AND l.status = 'active'
      AND l.is_active IS TRUE
    GROUP BY
      a.id,
      a.label,
      a.name,
      a.icon_name,
      a.category,
      a.sort_order
  ) AS activity;
$function$;

REVOKE ALL ON FUNCTION public.get_discovery_activities() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_discovery_activities() TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.discover_lounges(
  p_lat numeric DEFAULT NULL::numeric,
  p_lng numeric DEFAULT NULL::numeric,
  p_city text DEFAULT NULL::text,
  p_search_query text DEFAULT NULL::text,
  p_category_ids uuid[] DEFAULT NULL::uuid[],
  p_sort_type text DEFAULT 'nearest'::text,
  p_is_open_only boolean DEFAULT false,
  p_limit integer DEFAULT 20,
  p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path TO ''
AS $function$
  WITH filtered AS (
    SELECT
      l.*,
      CASE
        WHEN p_lat IS NOT NULL
         AND p_lng IS NOT NULL
         AND l.location_point IS NOT NULL
        THEN public.ST_Distance(
          l.location_point,
          public.ST_SetSRID(
            public.ST_MakePoint(
              p_lng::double precision,
              p_lat::double precision
            ),
            4326
          )::public.geography
        ) / 1000.0
        ELSE NULL
      END AS distance_km,
      (
        SELECT MIN(
          COALESCE(r.hourly_rate_single, r.hourly_rate_multi, r.hourly_rate)
        )
        FROM public.rooms AS r
        WHERE r.lounge_id = l.id
          AND r.is_active IS TRUE
          AND r.status <> 'deleted'
      ) AS min_price_per_hour
    FROM public.lounges AS l
    WHERE l.status = 'active'
      AND l.is_active IS TRUE
      AND (
        p_city IS NULL
        OR btrim(p_city) = ''
        OR lower(l.city) = lower(btrim(p_city))
      )
      AND (
        p_search_query IS NULL
        OR btrim(p_search_query) = ''
        OR l.name ILIKE '%' || btrim(p_search_query) || '%'
        OR l.name_ar ILIKE '%' || btrim(p_search_query) || '%'
        OR l.name_en ILIKE '%' || btrim(p_search_query) || '%'
        OR l.city ILIKE '%' || btrim(p_search_query) || '%'
        OR l.location ILIKE '%' || btrim(p_search_query) || '%'
        OR l.address ILIKE '%' || btrim(p_search_query) || '%'
      )
      AND (
        COALESCE(p_is_open_only, false) IS FALSE
        OR l.is_open IS TRUE
      )
      AND (
        p_category_ids IS NULL
        OR cardinality(p_category_ids) = 0
        OR EXISTS (
          SELECT 1
          FROM public.room_activities AS ra
          JOIN public.rooms AS activity_room
            ON activity_room.id = ra.room_id
          WHERE activity_room.lounge_id = l.id
            AND activity_room.is_active IS TRUE
            AND activity_room.status <> 'deleted'
            AND ra.activity_type_id = ANY(p_category_ids)
        )
        OR EXISTS (
          SELECT 1
          FROM public.lounge_categories AS lc
          WHERE lc.lounge_id = l.id
            AND lc.category_id = ANY(p_category_ids)
        )
      )
  ),
  ranked AS (
    SELECT f.*
    FROM filtered AS f
    ORDER BY
      CASE
        WHEN lower(COALESCE(p_sort_type, 'nearest')) = 'top_rated'
        THEN f.rating
      END DESC NULLS LAST,
      CASE
        WHEN lower(COALESCE(p_sort_type, 'nearest')) <> 'top_rated'
        THEN f.distance_km
      END ASC NULLS LAST,
      f.rating DESC NULLS LAST,
      f.id
    LIMIT LEAST(GREATEST(COALESCE(p_limit, 20), 1), 100)
    OFFSET GREATEST(COALESCE(p_offset, 0), 0)
  )
  SELECT COALESCE(
    jsonb_agg(
      to_jsonb(r)
      || jsonb_build_object(
        'distance_km', r.distance_km,
        'price_per_hour', COALESCE(r.min_price_per_hour, 0),
        'promotions', COALESCE(
          (
            SELECT jsonb_agg(to_jsonb(pr) ORDER BY pr.created_at DESC)
            FROM public.promotions AS pr
            WHERE pr.lounge_id = r.id
              AND pr.is_active IS TRUE
              AND (pr.expires_at IS NULL OR pr.expires_at > now())
          ),
          '[]'::jsonb
        )
      )
    ),
    '[]'::jsonb
  )
  FROM ranked AS r;
$function$;
