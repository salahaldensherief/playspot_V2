BEGIN;

ALTER TABLE public.extras
  ADD COLUMN IF NOT EXISTS cost_price numeric;

ALTER TABLE public.extras
  DROP CONSTRAINT IF EXISTS extras_cost_price_nonnegative;
ALTER TABLE public.extras
  ADD CONSTRAINT extras_cost_price_nonnegative
  CHECK (cost_price IS NULL OR cost_price >= 0);

CREATE TABLE IF NOT EXISTS public.canteen_combos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lounge_id uuid NOT NULL REFERENCES public.lounges(id) ON DELETE CASCADE,
  name_ar text NOT NULL,
  name_en text,
  description_ar text,
  description_en text,
  image_url text,
  price numeric NOT NULL CHECK (price >= 0),
  days_of_week integer[],
  available_from time,
  available_to time,
  valid_from date,
  valid_to date,
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT canteen_combos_valid_date_range
    CHECK (valid_from IS NULL OR valid_to IS NULL OR valid_to >= valid_from),
  CONSTRAINT canteen_combos_days_range
    CHECK (
      days_of_week IS NULL
      OR days_of_week <@ ARRAY[0,1,2,3,4,5,6]::integer[]
    )
);

CREATE TABLE IF NOT EXISTS public.canteen_combo_items (
  combo_id uuid NOT NULL REFERENCES public.canteen_combos(id) ON DELETE CASCADE,
  extra_id uuid NOT NULL REFERENCES public.extras(id) ON DELETE RESTRICT,
  quantity integer NOT NULL DEFAULT 1 CHECK (quantity > 0),
  PRIMARY KEY (combo_id, extra_id)
);

CREATE TABLE IF NOT EXISTS public.upsell_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lounge_id uuid NOT NULL REFERENCES public.lounges(id) ON DELETE CASCADE,
  trigger_type text NOT NULL CHECK (
    trigger_type IN (
      'session_minutes_elapsed',
      'cart_contains_category',
      'session_start',
      'time_of_day'
    )
  ),
  trigger_params jsonb NOT NULL DEFAULT '{}'::jsonb,
  suggest_extra_id uuid REFERENCES public.extras(id) ON DELETE CASCADE,
  suggest_combo_id uuid REFERENCES public.canteen_combos(id) ON DELETE CASCADE,
  discount_percent numeric CHECK (
    discount_percent IS NULL
    OR (discount_percent >= 0 AND discount_percent <= 100)
  ),
  max_impressions_per_booking integer NOT NULL DEFAULT 2
    CHECK (max_impressions_per_booking BETWEEN 1 AND 20),
  priority integer NOT NULL DEFAULT 100,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT upsell_rules_single_target CHECK (
    (suggest_extra_id IS NOT NULL AND suggest_combo_id IS NULL)
    OR (suggest_extra_id IS NULL AND suggest_combo_id IS NOT NULL)
  )
);

CREATE TABLE IF NOT EXISTS public.canteen_upsell_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lounge_id uuid NOT NULL REFERENCES public.lounges(id) ON DELETE CASCADE,
  rule_id uuid REFERENCES public.upsell_rules(id) ON DELETE SET NULL,
  booking_id uuid REFERENCES public.bookings(id) ON DELETE SET NULL,
  event_type text NOT NULL CHECK (event_type IN ('impression','conversion')),
  revenue_generated numeric NOT NULL DEFAULT 0 CHECK (revenue_generated >= 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS canteen_combos_lounge_idx
  ON public.canteen_combos(lounge_id, is_active, sort_order, created_at DESC);
CREATE INDEX IF NOT EXISTS canteen_combo_items_extra_idx
  ON public.canteen_combo_items(extra_id);
CREATE INDEX IF NOT EXISTS upsell_rules_lounge_idx
  ON public.upsell_rules(lounge_id, is_active, priority DESC);
CREATE INDEX IF NOT EXISTS canteen_upsell_events_lounge_idx
  ON public.canteen_upsell_events(lounge_id, created_at DESC);
CREATE INDEX IF NOT EXISTS canteen_upsell_events_rule_idx
  ON public.canteen_upsell_events(rule_id, event_type);

ALTER TABLE public.canteen_combos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.canteen_combo_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.upsell_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.canteen_upsell_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS canteen_combos_read ON public.canteen_combos;
CREATE POLICY canteen_combos_read
ON public.canteen_combos
FOR SELECT
TO authenticated
USING (public._playspot_has_lounge_access(lounge_id));

DROP POLICY IF EXISTS canteen_combos_insert ON public.canteen_combos;
CREATE POLICY canteen_combos_insert
ON public.canteen_combos
FOR INSERT
TO authenticated
WITH CHECK (
  public.is_super_admin()
  OR public.has_lounge_permission(lounge_id,'menu_manage_items')
);

DROP POLICY IF EXISTS canteen_combos_update ON public.canteen_combos;
CREATE POLICY canteen_combos_update
ON public.canteen_combos
FOR UPDATE
TO authenticated
USING (
  public.is_super_admin()
  OR public.has_lounge_permission(lounge_id,'menu_manage_items')
)
WITH CHECK (
  public.is_super_admin()
  OR public.has_lounge_permission(lounge_id,'menu_manage_items')
);

DROP POLICY IF EXISTS canteen_combos_delete ON public.canteen_combos;
CREATE POLICY canteen_combos_delete
ON public.canteen_combos
FOR DELETE
TO authenticated
USING (
  public.is_super_admin()
  OR public.has_lounge_permission(lounge_id,'menu_manage_items')
);

DROP POLICY IF EXISTS canteen_combo_items_read ON public.canteen_combo_items;
CREATE POLICY canteen_combo_items_read
ON public.canteen_combo_items
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.canteen_combos AS c
    WHERE c.id = combo_id
      AND public._playspot_has_lounge_access(c.lounge_id)
  )
);

DROP POLICY IF EXISTS canteen_combo_items_write ON public.canteen_combo_items;
CREATE POLICY canteen_combo_items_write
ON public.canteen_combo_items
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.canteen_combos AS c
    WHERE c.id = combo_id
      AND (
        public.is_super_admin()
        OR public.has_lounge_permission(c.lounge_id,'menu_manage_items')
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.canteen_combos AS c
    JOIN public.extras AS e ON e.id = extra_id
    WHERE c.id = combo_id
      AND e.lounge_id = c.lounge_id
      AND (
        public.is_super_admin()
        OR public.has_lounge_permission(c.lounge_id,'menu_manage_items')
      )
  )
);

DROP POLICY IF EXISTS upsell_rules_read ON public.upsell_rules;
CREATE POLICY upsell_rules_read
ON public.upsell_rules
FOR SELECT
TO authenticated
USING (public._playspot_has_lounge_access(lounge_id));

DROP POLICY IF EXISTS upsell_rules_write ON public.upsell_rules;
CREATE POLICY upsell_rules_write
ON public.upsell_rules
FOR ALL
TO authenticated
USING (
  public.is_super_admin()
  OR public.has_lounge_permission(lounge_id,'menu_manage_items')
)
WITH CHECK (
  (
    public.is_super_admin()
    OR public.has_lounge_permission(lounge_id,'menu_manage_items')
  )
  AND (
    suggest_extra_id IS NULL
    OR EXISTS (
      SELECT 1 FROM public.extras AS e
      WHERE e.id = suggest_extra_id AND e.lounge_id = lounge_id
    )
  )
  AND (
    suggest_combo_id IS NULL
    OR EXISTS (
      SELECT 1 FROM public.canteen_combos AS c
      WHERE c.id = suggest_combo_id AND c.lounge_id = lounge_id
    )
  )
);

DROP POLICY IF EXISTS canteen_upsell_events_read ON public.canteen_upsell_events;
CREATE POLICY canteen_upsell_events_read
ON public.canteen_upsell_events
FOR SELECT
TO authenticated
USING (public._playspot_has_lounge_access(lounge_id));

DROP POLICY IF EXISTS canteen_upsell_events_insert ON public.canteen_upsell_events;
CREATE POLICY canteen_upsell_events_insert
ON public.canteen_upsell_events
FOR INSERT
TO authenticated
WITH CHECK (public._playspot_has_lounge_access(lounge_id));

GRANT SELECT,INSERT,UPDATE,DELETE ON public.canteen_combos TO authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.canteen_combo_items TO authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.upsell_rules TO authenticated;
GRANT SELECT,INSERT ON public.canteen_upsell_events TO authenticated;

CREATE OR REPLACE VIEW public.canteen_upsell_conversion_v
WITH (security_invoker = true)
AS
SELECT
  r.lounge_id,
  r.id AS rule_id,
  r.trigger_type,
  count(e.id) FILTER (WHERE e.event_type='impression')::bigint AS impressions,
  count(e.id) FILTER (WHERE e.event_type='conversion')::bigint AS conversions,
  CASE
    WHEN count(e.id) FILTER (WHERE e.event_type='impression') = 0 THEN 0::numeric
    ELSE round(
      100.0
      * count(e.id) FILTER (WHERE e.event_type='conversion')
      / count(e.id) FILTER (WHERE e.event_type='impression'),
      2
    )
  END AS conversion_rate_percent,
  COALESCE(
    sum(e.revenue_generated) FILTER (WHERE e.event_type='conversion'),
    0
  )::numeric AS revenue_generated
FROM public.upsell_rules AS r
LEFT JOIN public.canteen_upsell_events AS e
  ON e.rule_id = r.id
GROUP BY r.lounge_id, r.id, r.trigger_type;

CREATE OR REPLACE VIEW public.canteen_low_stock_alerts_v
WITH (security_invoker = true)
AS
SELECT
  e.lounge_id,
  e.id AS extra_id,
  COALESCE(e.name_ar,e.name) AS name_ar,
  COALESCE(e.name_en,e.name) AS name_en,
  e.category,
  COALESCE(e.stock_quantity,0) AS stock_quantity,
  COALESCE(e.min_stock_alert,5) AS min_stock_threshold
FROM public.extras AS e
WHERE COALESCE(e.is_active,true) IS TRUE
  AND COALESCE(e.track_stock,false) IS TRUE
  AND COALESCE(e.stock_quantity,0) <= COALESCE(e.min_stock_alert,5);

GRANT SELECT ON public.canteen_upsell_conversion_v TO authenticated;
GRANT SELECT ON public.canteen_low_stock_alerts_v TO authenticated;

COMMIT;
