-- Public marketing-only combo catalogue (existing demo contract).
-- Deliberately RETURNS only public display details; not stock counts or ordering rights.
-- Keep get_canteen_menu authenticated and place_canteen_order protected.
BEGIN;
CREATE OR REPLACE FUNCTION public.get_public_canteen_combos(p_lounge_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', c.id,
      'name_ar', c.name_ar,
      'name_en', c.name_en,
      'description_ar', c.description_ar,
      'description_en', c.description_en,
      'image_url', c.image_url,
      'price', c.price,
      'separate_items_price', (
        SELECT COALESCE(SUM(e.price * ci.quantity), 0)
        FROM public.canteen_combo_items ci
        JOIN public.extras e ON e.id = ci.extra_id
        WHERE ci.combo_id = c.id
      ),
      'savings', GREATEST(0, (
        SELECT COALESCE(SUM(e.price * ci.quantity), 0)
        FROM public.canteen_combo_items ci
        JOIN public.extras e ON e.id = ci.extra_id
        WHERE ci.combo_id = c.id
      ) - c.price),
      'is_available', true,
      'items', (
        SELECT COALESCE(jsonb_agg(jsonb_build_object(
          'extra_id', e.id,
          'name_ar', COALESCE(e.name_ar, e.name),
          'name_en', COALESCE(e.name_en, e.name),
          'price', e.price,
          'quantity', ci.quantity
        ) ORDER BY e.name), '[]'::jsonb)
        FROM public.canteen_combo_items ci
        JOIN public.extras e ON e.id = ci.extra_id
        WHERE ci.combo_id = c.id
      )
    ) ORDER BY c.sort_order, c.name_ar), '[]'::jsonb)
  FROM public.canteen_combos c
  JOIN public.lounges l ON l.id = c.lounge_id
  WHERE c.lounge_id = p_lounge_id
    AND COALESCE(l.is_active, false)
    AND l.status = 'active'
    AND COALESCE(c.is_active, false)
    -- Some older live catalogues predate the deleted_at tombstone migration.
    -- A missing JSON key behaves as NULL; deployed tombstones stay hidden.
    AND (to_jsonb(c)->>'deleted_at') IS NULL
    AND private.canteen_combo_window_available(
      c, timezone(COALESCE(l.timezone, 'Africa/Cairo'), now())
    )
    AND EXISTS (SELECT 1 FROM public.canteen_combo_items ci WHERE ci.combo_id = c.id)
    AND NOT EXISTS (
      SELECT 1 FROM public.canteen_combo_items ci
      LEFT JOIN public.extras e ON e.id = ci.extra_id
      WHERE ci.combo_id = c.id AND (
        e.id IS NULL
        OR e.lounge_id IS DISTINCT FROM c.lounge_id
        OR COALESCE(e.is_active, false) IS FALSE
        OR COALESCE(e.is_available, false) IS FALSE
        OR (COALESCE(e.track_stock, false) AND COALESCE(e.stock_quantity, 0) < ci.quantity)
      )
    );
$function$
;
REVOKE ALL ON FUNCTION public.get_public_canteen_combos(uuid) FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.get_public_canteen_combos(uuid) TO anon, authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
