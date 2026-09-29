-- =============================================================================
-- Migration: 20260929160000_canteen_menu_savings_and_stock_filter.sql
-- Description: Enrich get_canteen_menu with separate_items_price and savings,
--              and filter get_upsell_suggestions for stock availability.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_canteen_menu(
  p_lounge_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $f$
DECLARE
  v_tz text;
  v_local_ts timestamp without time zone;
  v_local_time time without time zone;
  v_dow smallint;
  v_extras jsonb;
  v_combos jsonb;
BEGIN
  SELECT COALESCE(NULLIF(btrim(timezone), ''), 'Africa/Cairo') INTO v_tz
  FROM public.lounges WHERE id = p_lounge_id;

  v_local_ts := now() AT TIME ZONE COALESCE(v_tz, 'Africa/Cairo');
  v_local_time := v_local_ts::time;
  v_dow := EXTRACT(DOW FROM v_local_ts)::smallint;

  -- Fetch Available Extras
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', e.id,
        'name_ar', e.name_ar,
        'name_en', e.name_en,
        'price', e.price,
        'cost_price', e.cost_price,
        'image_url', e.image_url,
        'category', e.category,
        'is_available', e.is_available AND (e.track_stock IS NOT TRUE OR COALESCE(e.stock_quantity, 0) > 0),
        'stock_quantity', e.stock_quantity,
        'track_stock', e.track_stock
      ) ORDER BY e.category, e.name_ar
    ), '[]'::jsonb
  ) INTO v_extras
  FROM public.extras e
  WHERE e.lounge_id = p_lounge_id AND e.is_active = true;

  -- Fetch Active & Available Combos with pre-calculated separate items price and savings
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', c.id,
        'name_ar', c.name_ar,
        'name_en', c.name_en,
        'description_ar', c.description_ar,
        'description_en', c.description_en,
        'price', c.price,
        'image_url', c.image_url,
        'separate_items_price', COALESCE((
          SELECT SUM(ce.price * ci.quantity)
          FROM public.canteen_combo_items ci
          JOIN public.extras ce ON ce.id = ci.extra_id
          WHERE ci.combo_id = c.id
        ), c.price),
        'savings', GREATEST(0, COALESCE((
          SELECT SUM(ce.price * ci.quantity)
          FROM public.canteen_combo_items ci
          JOIN public.extras ce ON ce.id = ci.extra_id
          WHERE ci.combo_id = c.id
        ), c.price) - c.price),
        'is_available', (
          (c.days_of_week IS NULL OR v_dow = ANY(c.days_of_week))
          AND (c.available_from IS NULL OR v_local_time >= c.available_from)
          AND (c.available_to IS NULL OR v_local_time <= c.available_to)
          -- Ensure all components in combo have stock
          AND NOT EXISTS (
            SELECT 1 FROM public.canteen_combo_items ci
            JOIN public.extras ce ON ce.id = ci.extra_id
            WHERE ci.combo_id = c.id
              AND (ce.is_available IS FALSE OR (ce.track_stock IS TRUE AND COALESCE(ce.stock_quantity, 0) < ci.quantity))
          )
        ),
        'items', (
          SELECT jsonb_agg(
            jsonb_build_object(
              'extra_id', ci.extra_id,
              'name_ar', ce.name_ar,
              'name_en', ce.name_en,
              'price', ce.price,
              'quantity', ci.quantity
            )
          ) FROM public.canteen_combo_items ci
          JOIN public.extras ce ON ce.id = ci.extra_id
          WHERE ci.combo_id = c.id
        )
      ) ORDER BY c.sort_order ASC, c.created_at DESC
    ), '[]'::jsonb
  ) INTO v_combos
  FROM public.canteen_combos c
  WHERE c.lounge_id = p_lounge_id AND c.is_active = true;

  RETURN jsonb_build_object(
    'extras', v_extras,
    'combos', v_combos
  );
END;
$f$;

REVOKE ALL ON FUNCTION public.get_canteen_menu(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_canteen_menu(uuid) TO authenticated, service_role;

-- Update get_upsell_suggestions to hide items/combos that are out of stock
CREATE OR REPLACE FUNCTION public.get_upsell_suggestions(
  p_booking_id uuid
)
RETURNS TABLE(
  rule_id uuid,
  suggestion_type text,
  target_id uuid,
  name_ar text,
  name_en text,
  original_price numeric,
  discount_percent numeric,
  final_price numeric,
  image_url text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $f$
DECLARE
  v_booking record;
  v_elapsed_mins integer;
BEGIN
  SELECT b.id, b.lounge_id, b.status, b.created_at, b.room_id
  INTO v_booking
  FROM public.bookings b
  WHERE b.id = p_booking_id;

  IF v_booking.id IS NULL THEN
    RETURN;
  END IF;

  v_elapsed_mins := EXTRACT(EPOCH FROM (now() - v_booking.created_at)) / 60;

  RETURN QUERY
  SELECT
    r.id AS rule_id,
    CASE WHEN r.suggest_combo_id IS NOT NULL THEN 'combo' ELSE 'extra' END AS suggestion_type,
    COALESCE(r.suggest_combo_id, r.suggest_extra_id) AS target_id,
    COALESCE(c.name_ar, e.name_ar) AS name_ar,
    COALESCE(c.name_en, e.name_en) AS name_en,
    COALESCE(c.price, e.price) AS original_price,
    r.discount_percent,
    ROUND(
      COALESCE(c.price, e.price) * (1.0 - (COALESCE(r.discount_percent, 0) / 100.0)),
      2
    ) AS final_price,
    COALESCE(c.image_url, e.image_url) AS image_url
  FROM public.upsell_rules r
  LEFT JOIN public.canteen_combos c ON c.id = r.suggest_combo_id
  LEFT JOIN public.extras e ON e.id = r.suggest_extra_id
  WHERE r.lounge_id = v_booking.lounge_id
    AND r.is_active = true
    -- Ensure target is not out of stock
    AND (
      (r.suggest_extra_id IS NOT NULL AND e.is_available = true AND (e.track_stock IS NOT TRUE OR COALESCE(e.stock_quantity, 0) > 0))
      OR (r.suggest_combo_id IS NOT NULL AND c.is_active = true AND NOT EXISTS (
        SELECT 1 FROM public.canteen_combo_items ci
        JOIN public.extras ce ON ce.id = ci.extra_id
        WHERE ci.combo_id = c.id
          AND (ce.is_available IS FALSE OR (ce.track_stock IS TRUE AND COALESCE(ce.stock_quantity, 0) < ci.quantity))
      ))
    )
    -- Check impression frequency limit
    AND (
      SELECT count(*) FROM public.upsell_events ue
      WHERE ue.booking_id = p_booking_id AND ue.rule_id = r.id AND ue.event = 'shown'
    ) < r.max_impressions_per_booking
    -- Trigger evaluation
    AND (
      (r.trigger_type = 'session_start')
      OR (r.trigger_type = 'session_minutes_elapsed' AND v_elapsed_mins >= COALESCE((r.trigger_params->>'minutes')::integer, 30))
      OR (r.trigger_type = 'time_of_day')
    )
  ORDER BY r.priority DESC, r.created_at DESC
  LIMIT 2;
END;
$f$;

REVOKE ALL ON FUNCTION public.get_upsell_suggestions(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_upsell_suggestions(uuid) TO authenticated, service_role;
