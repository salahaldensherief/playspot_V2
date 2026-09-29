BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- -----------------------------------------------------------------------------
-- 1. Combos & Upsell Schema
-- -----------------------------------------------------------------------------

-- Canteen Combos Header Table
CREATE TABLE IF NOT EXISTS public.canteen_combos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lounge_id uuid NOT NULL REFERENCES public.lounges(id) ON DELETE CASCADE,
  name_ar text NOT NULL,
  name_en text,
  description_ar text,
  description_en text,
  image_url text,
  price numeric(12,2) NOT NULL CHECK (price >= 0),
  days_of_week smallint[] CHECK (
    days_of_week IS NULL OR (
      days_of_week <@ array[0,1,2,3,4,5,6]::smallint[]
      AND cardinality(days_of_week) > 0
    )
  ),
  available_from time without time zone,
  available_to time without time zone,
  valid_from date,
  valid_to date,
  is_active boolean NOT NULL DEFAULT true,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_canteen_combos_lounge
  ON public.canteen_combos (lounge_id, is_active, sort_order ASC);

-- Canteen Combo Components Table
CREATE TABLE IF NOT EXISTS public.canteen_combo_items (
  combo_id uuid REFERENCES public.canteen_combos(id) ON DELETE CASCADE,
  extra_id uuid REFERENCES public.extras(id) ON DELETE CASCADE,
  quantity int NOT NULL CHECK (quantity > 0),
  PRIMARY KEY (combo_id, extra_id)
);

CREATE INDEX IF NOT EXISTS idx_canteen_combo_items_extra
  ON public.canteen_combo_items (extra_id);

-- Upsell Rules Table
CREATE TABLE IF NOT EXISTS public.upsell_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lounge_id uuid NOT NULL REFERENCES public.lounges(id) ON DELETE CASCADE,
  trigger_type text NOT NULL CHECK (
    trigger_type IN ('session_minutes_elapsed', 'time_of_day', 'cart_contains_category', 'room_type', 'session_start')
  ),
  trigger_params jsonb NOT NULL DEFAULT '{}'::jsonb,
  suggest_extra_id uuid REFERENCES public.extras(id) ON DELETE CASCADE,
  suggest_combo_id uuid REFERENCES public.canteen_combos(id) ON DELETE CASCADE,
  discount_percent numeric(5,2) CHECK (discount_percent IS NULL OR (discount_percent BETWEEN 0 AND 100)),
  max_impressions_per_booking int NOT NULL DEFAULT 2,
  priority int NOT NULL DEFAULT 100,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((suggest_extra_id IS NOT NULL) <> (suggest_combo_id IS NOT NULL))
);

CREATE INDEX IF NOT EXISTS idx_upsell_rules_lounge
  ON public.upsell_rules (lounge_id, is_active, priority DESC);

-- Upsell Events Audit Table
CREATE TABLE IF NOT EXISTS public.upsell_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lounge_id uuid NOT NULL REFERENCES public.lounges(id) ON DELETE CASCADE,
  rule_id uuid REFERENCES public.upsell_rules(id) ON DELETE SET NULL,
  booking_id uuid REFERENCES public.bookings(id) ON DELETE CASCADE,
  user_id uuid,
  event text NOT NULL CHECK (event IN ('shown', 'accepted', 'dismissed')),
  canteen_order_id uuid REFERENCES public.canteen_orders(id) ON DELETE SET NULL,
  amount numeric(12,2),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_upsell_events_booking
  ON public.upsell_events (booking_id, rule_id, event);

-- -----------------------------------------------------------------------------
-- 2. Alter Existing Tables
-- -----------------------------------------------------------------------------

-- Alter canteen_order_items with combo support
ALTER TABLE public.canteen_order_items
  ADD COLUMN IF NOT EXISTS combo_id uuid REFERENCES public.canteen_combos(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS combo_line_id uuid,
  ADD COLUMN IF NOT EXISTS line_kind text DEFAULT 'item' CHECK (line_kind IN ('item', 'combo_parent', 'combo_component'));

CREATE INDEX IF NOT EXISTS idx_canteen_order_items_combo
  ON public.canteen_order_items (combo_id)
  WHERE combo_id IS NOT NULL;

-- Alter extras with cost_price for margin analytics
ALTER TABLE public.extras
  ADD COLUMN IF NOT EXISTS cost_price numeric(12,2) CHECK (cost_price IS NULL OR cost_price >= 0);

-- -----------------------------------------------------------------------------
-- 3. Row Level Security & Policies
-- -----------------------------------------------------------------------------
ALTER TABLE public.canteen_combos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.canteen_combo_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.upsell_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.upsell_events ENABLE ROW LEVEL SECURITY;

-- Read policies (authenticated users)
DROP POLICY IF EXISTS "canteen_combos_read_policy" ON public.canteen_combos;
CREATE POLICY "canteen_combos_read_policy" ON public.canteen_combos FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "canteen_combo_items_read_policy" ON public.canteen_combo_items;
CREATE POLICY "canteen_combo_items_read_policy" ON public.canteen_combo_items FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "upsell_rules_read_policy" ON public.upsell_rules;
CREATE POLICY "upsell_rules_read_policy" ON public.upsell_rules FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "upsell_events_read_policy" ON public.upsell_events;
CREATE POLICY "upsell_events_read_policy" ON public.upsell_events FOR SELECT TO authenticated
  USING (
    private.permission_role(auth.uid(), NULL) = 'super_admin'
    OR public.has_lounge_access(lounge_id, 'cashier')
    OR user_id = auth.uid()
  );

-- Write policies (Manager/Owner or Super Admin)
DROP POLICY IF EXISTS "canteen_combos_write_policy" ON public.canteen_combos;
CREATE POLICY "canteen_combos_write_policy" ON public.canteen_combos FOR ALL TO authenticated
  USING (
    private.permission_role(auth.uid(), NULL) = 'super_admin'
    OR public.has_lounge_permission(lounge_id, 'canteen.combos.manage')
  )
  WITH CHECK (
    private.permission_role(auth.uid(), NULL) = 'super_admin'
    OR public.has_lounge_permission(lounge_id, 'canteen.combos.manage')
  );

DROP POLICY IF EXISTS "upsell_rules_write_policy" ON public.upsell_rules;
CREATE POLICY "upsell_rules_write_policy" ON public.upsell_rules FOR ALL TO authenticated
  USING (
    private.permission_role(auth.uid(), NULL) = 'super_admin'
    OR public.has_lounge_permission(lounge_id, 'campaigns.manage')
  )
  WITH CHECK (
    private.permission_role(auth.uid(), NULL) = 'super_admin'
    OR public.has_lounge_permission(lounge_id, 'campaigns.manage')
  );

DROP POLICY IF EXISTS "upsell_events_write_policy" ON public.upsell_events;
CREATE POLICY "upsell_events_write_policy" ON public.upsell_events FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid() OR public.has_lounge_access(lounge_id, 'cashier')
  );

-- -----------------------------------------------------------------------------
-- 4. Authoritative RPC: place_canteen_order (Combos + Inventory + Audit)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.place_canteen_order(
  p_booking_id uuid DEFAULT NULL,
  p_items jsonb DEFAULT '[]'::jsonb,
  p_note text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $f$
DECLARE
  v_actor uuid := auth.uid();
  v_booking public.bookings%ROWTYPE;
  v_lounge_id uuid;
  v_shift_id uuid;
  v_order_id uuid;
  v_note text := NULLIF(btrim(p_note), '');
  v_entry jsonb;
  v_extra_id uuid;
  v_combo_id uuid;
  v_quantity integer;
  v_extra record;
  v_combo record;
  v_comp record;
  v_parent_line_id uuid;
  v_total numeric(12,2) := 0;
  v_line_total numeric(12,2);
  v_formatted_items jsonb := '[]'::jsonb;
  v_out_of_stock_list jsonb := '[]'::jsonb;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) < 1 THEN
    RAISE EXCEPTION 'Items must be a non-empty JSON array' USING ERRCODE = '22023';
  END IF;

  -- 1. Validate Booking or Open Shift Context
  IF p_booking_id IS NOT NULL THEN
    SELECT * INTO v_booking
    FROM public.bookings
    WHERE id = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002';
    END IF;

    IF v_booking.status NOT IN ('pending', 'upcoming', 'in_progress') THEN
      RAISE EXCEPTION 'Canteen orders not allowed for current booking status' USING ERRCODE = '55000';
    END IF;

    IF v_actor <> v_booking.user_id AND NOT public.has_lounge_access(v_booking.lounge_id, 'cashier') THEN
      RAISE EXCEPTION 'Not authorized to place canteen order for this booking' USING ERRCODE = '42501';
    END IF;

    v_lounge_id := v_booking.lounge_id;
  ELSE
    -- Counter sale: must have single open cashier shift
    SELECT s.id, s.lounge_id INTO v_shift_id, v_lounge_id
    FROM public.shifts s
    WHERE s.status = 'open' AND s.cashier_id = v_actor
    LIMIT 1;

    IF v_shift_id IS NULL THEN
      RAISE EXCEPTION 'An open shift is required for counter sales' USING ERRCODE = '55000';
    END IF;
  END IF;

  v_order_id := gen_random_uuid();

  -- 2. Process Lines (Atomic Inventory Depletion & Validation)
  FOR v_entry IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_extra_id := NULLIF(v_entry->>'extra_id', '')::uuid;
    v_combo_id := NULLIF(v_entry->>'combo_id', '')::uuid;
    v_quantity := COALESCE(NULLIF(v_entry->>'quantity', '')::integer, 1);

    IF v_quantity < 1 THEN
      RAISE EXCEPTION 'Quantity must be at least 1' USING ERRCODE = '22023';
    END IF;

    -- Case A: Standard Extra Item
    IF v_extra_id IS NOT NULL THEN
      SELECT e.id, e.price, e.name_ar, e.name_en, e.track_stock, e.stock_quantity
      INTO v_extra
      FROM public.extras e
      WHERE e.id = v_extra_id AND e.lounge_id = v_lounge_id AND e.is_active = true
      FOR UPDATE;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'Extra not found or inactive: %', v_extra_id USING ERRCODE = '23514';
      END IF;

      -- Check Stock
      IF v_extra.track_stock IS TRUE AND COALESCE(v_extra.stock_quantity, 0) < v_quantity THEN
        v_out_of_stock_list := v_out_of_stock_list || jsonb_build_object(
          'id', v_extra.id, 'name', v_extra.name_ar, 'available', COALESCE(v_extra.stock_quantity, 0), 'requested', v_quantity
        );
      ELSE
        IF v_extra.track_stock IS TRUE THEN
          UPDATE public.extras
          SET stock_quantity = stock_quantity - v_quantity
          WHERE id = v_extra_id;
        END IF;

        v_line_total := v_extra.price * v_quantity;
        v_total := v_total + v_line_total;

        INSERT INTO public.canteen_order_items (
          order_id, extra_id, item_name, quantity, unit_price, total_price, line_kind, created_at
        ) VALUES (
          v_order_id, v_extra.id, v_extra.name_ar, v_quantity, v_extra.price, v_line_total, 'item', now()
        );

        v_formatted_items := v_formatted_items || jsonb_build_object(
          'extra_id', v_extra.id,
          'name', v_extra.name_ar,
          'quantity', v_quantity,
          'unit_price', v_extra.price,
          'total_price', v_line_total,
          'line_kind', 'item'
        );
      END IF;

    -- Case B: Canteen Combo
    ELSIF v_combo_id IS NOT NULL THEN
      SELECT c.id, c.price, c.name_ar, c.name_en, c.is_active
      INTO v_combo
      FROM public.canteen_combos c
      WHERE c.id = v_combo_id AND c.lounge_id = v_lounge_id AND c.is_active = true;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'Combo not found or inactive: %', v_combo_id USING ERRCODE = '23514';
      END IF;

      -- Check stock for all components
      FOR v_comp IN
        SELECT ci.extra_id, ci.quantity AS comp_qty, e.name_ar, e.track_stock, e.stock_quantity
        FROM public.canteen_combo_items ci
        JOIN public.extras e ON e.id = ci.extra_id
        WHERE ci.combo_id = v_combo_id
        FOR UPDATE OF e
      LOOP
        IF v_comp.track_stock IS TRUE AND COALESCE(v_comp.stock_quantity, 0) < (v_comp.comp_qty * v_quantity) THEN
          v_out_of_stock_list := v_out_of_stock_list || jsonb_build_object(
            'id', v_comp.extra_id, 'name', v_comp.name_ar, 'available', COALESCE(v_comp.stock_quantity, 0),
            'requested', (v_comp.comp_qty * v_quantity)
          );
        END IF;
      END LOOP;

      -- If no stock shortages, deduct and insert lines
      IF jsonb_array_length(v_out_of_stock_list) = 0 THEN
        v_parent_line_id := gen_random_uuid();
        v_line_total := v_combo.price * v_quantity;
        v_total := v_total + v_line_total;

        -- 1. Insert Parent Combo Line
        INSERT INTO public.canteen_order_items (
          id, order_id, combo_id, item_name, quantity, unit_price, total_price, line_kind, created_at
        ) VALUES (
          v_parent_line_id, v_order_id, v_combo.id, v_combo.name_ar, v_quantity, v_combo.price, v_line_total, 'combo_parent', now()
        );

        -- 2. Insert Component Lines (Price 0 for accurate inventory & sales)
        FOR v_comp IN
          SELECT ci.extra_id, ci.quantity AS comp_qty, e.name_ar, e.track_stock
          FROM public.canteen_combo_items ci
          JOIN public.extras e ON e.id = ci.extra_id
          WHERE ci.combo_id = v_combo_id
        LOOP
          IF v_comp.track_stock IS TRUE THEN
            UPDATE public.extras
            SET stock_quantity = stock_quantity - (v_comp.comp_qty * v_quantity)
            WHERE id = v_comp.extra_id;
          END IF;

          INSERT INTO public.canteen_order_items (
            order_id, extra_id, combo_id, combo_line_id, item_name, quantity, unit_price, total_price, line_kind, created_at
          ) VALUES (
            v_order_id, v_comp.extra_id, v_combo.id, v_parent_line_id, v_comp.name_ar, (v_comp.comp_qty * v_quantity), 0, 0, 'combo_component', now()
          );
        END LOOP;

        v_formatted_items := v_formatted_items || jsonb_build_object(
          'combo_id', v_combo.id,
          'name', v_combo.name_ar,
          'quantity', v_quantity,
          'unit_price', v_combo.price,
          'total_price', v_line_total,
          'line_kind', 'combo_parent'
        );
      END IF;
    END IF;
  END LOOP;

  -- 3. Abort if any item or component is OUT_OF_STOCK
  IF jsonb_array_length(v_out_of_stock_list) > 0 THEN
    RAISE EXCEPTION 'OUT_OF_STOCK'
      USING ERRCODE = 'P0001',
      DETAIL = jsonb_build_object('unavailable_items', v_out_of_stock_list)::text;
  END IF;

  -- 4. Create Master Order Record
  INSERT INTO public.canteen_orders (
    id, booking_id, lounge_id, user_id, shift_id, items, total_price, status, note, notes, created_at, updated_at
  ) VALUES (
    v_order_id, p_booking_id, v_lounge_id,
    CASE WHEN p_booking_id IS NULL THEN v_actor ELSE COALESCE(v_booking.user_id, v_actor) END,
    v_shift_id, v_formatted_items, v_total, 'pending', v_note, v_note, now(), now()
  );

  -- 5. Booking Addons Mirroring (Session balance update)
  IF p_booking_id IS NOT NULL THEN
    UPDATE public.bookings
    SET addons_price = COALESCE(addons_price, 0) + v_total,
        total_price = room_price + COALESCE(addons_price, 0) + v_total - COALESCE(discount_amount, 0),
        updated_at = now()
    WHERE id = p_booking_id;
  ELSE
    -- Counter Cash Sale
    INSERT INTO public.shift_payments (
      shift_id, lounge_id, payment_method, category, amount, paid_at, canteen_order_id, created_at
    ) VALUES (
      v_shift_id, v_lounge_id, 'cash', 'canteen', v_total, now(), v_order_id, now()
    );
  END IF;

  -- 6. Log Audit Event
  PERFORM private.log_audit_event(
    v_lounge_id, 'canteen_order', v_order_id::text, 'payment_collected', p_booking_id,
    v_actor, 'info', jsonb_build_object('order_id', v_order_id, 'total_price', v_total), now()
  );

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'lounge_id', v_lounge_id,
    'total_price', v_total
  );
END;
$f$;

REVOKE ALL ON FUNCTION public.place_canteen_order(uuid, jsonb, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.place_canteen_order(uuid, jsonb, text, text) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 5. RPC: get_canteen_menu (Extras + Combos by Time & Availability)
-- -----------------------------------------------------------------------------
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

  -- Fetch Active & Available Combos
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', c.id,
        'name_ar', c.name_ar,
        'name_en', c.name_en,
        'description_ar', c.description_ar,
        'price', c.price,
        'image_url', c.image_url,
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

-- -----------------------------------------------------------------------------
-- 6. RPC: get_upsell_suggestions & record_upsell_event
-- -----------------------------------------------------------------------------
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

CREATE OR REPLACE FUNCTION public.record_upsell_event(
  p_booking_id uuid,
  p_rule_id uuid,
  p_event text,
  p_canteen_order_id uuid DEFAULT NULL,
  p_amount numeric DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $f$
DECLARE
  v_booking record;
  v_event_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  SELECT id, lounge_id, user_id INTO v_booking
  FROM public.bookings WHERE id = p_booking_id;

  IF v_booking.id IS NULL THEN
    RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO public.upsell_events (
    lounge_id, rule_id, booking_id, user_id, event, canteen_order_id, amount, created_at
  ) VALUES (
    v_booking.lounge_id, p_rule_id, p_booking_id, auth.uid(), p_event, p_canteen_order_id, p_amount, now()
  ) RETURNING id INTO v_event_id;

  RETURN v_event_id;
END;
$f$;

REVOKE ALL ON FUNCTION public.record_upsell_event(uuid, uuid, text, uuid, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_upsell_event(uuid, uuid, text, uuid, numeric) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 7. Growth & Intelligence Analytical Views
-- -----------------------------------------------------------------------------

-- View 1: Canteen Attach Rate (% of bookings that placed canteen orders)
CREATE OR REPLACE VIEW public.canteen_attach_rate_v AS
SELECT
  b.lounge_id,
  count(DISTINCT b.id) AS total_bookings,
  count(DISTINCT co.booking_id) AS canteen_bookings,
  ROUND(
    (count(DISTINCT co.booking_id)::numeric / NULLIF(count(DISTINCT b.id), 0)::numeric) * 100.0,
    2
  ) AS attach_rate_percentage
FROM public.bookings b
LEFT JOIN public.canteen_orders co ON co.booking_id = b.id AND co.status IN ('delivered', 'completed')
WHERE b.status IN ('completed', 'in_progress')
GROUP BY b.lounge_id;

-- View 2: Canteen Average Order Value (AOV) per Session
CREATE OR REPLACE VIEW public.canteen_aov_v AS
SELECT
  co.lounge_id,
  count(co.id) AS total_delivered_orders,
  COALESCE(SUM(coi.total_price), 0) AS total_canteen_revenue,
  ROUND(
    COALESCE(SUM(coi.total_price), 0) / NULLIF(count(DISTINCT co.id), 0),
    2
  ) AS average_order_value
FROM public.canteen_orders co
JOIN public.canteen_order_items coi ON coi.order_id = co.id AND coi.line_kind IN ('item', 'combo_parent')
WHERE co.status IN ('delivered', 'completed')
GROUP BY co.lounge_id;

-- View 3: Top Selling Combos
CREATE OR REPLACE VIEW public.canteen_top_combos_v AS
SELECT
  cc.lounge_id,
  cc.id AS combo_id,
  cc.name_ar,
  cc.name_en,
  SUM(coi.quantity) AS total_sold_quantity,
  SUM(coi.total_price) AS total_revenue
FROM public.canteen_order_items coi
JOIN public.canteen_combos cc ON cc.id = coi.combo_id
JOIN public.canteen_orders co ON co.id = coi.order_id
WHERE coi.line_kind = 'combo_parent'
  AND co.status IN ('delivered', 'completed')
GROUP BY cc.lounge_id, cc.id, cc.name_ar, cc.name_en
ORDER BY total_revenue DESC;

-- View 4: Upsell Conversion Analytics
CREATE OR REPLACE VIEW public.canteen_upsell_conversion_v AS
SELECT
  ue.lounge_id,
  ue.rule_id,
  ur.trigger_type,
  count(*) FILTER (WHERE ue.event = 'shown') AS impressions,
  count(*) FILTER (WHERE ue.event = 'accepted') AS conversions,
  ROUND(
    (count(*) FILTER (WHERE ue.event = 'accepted')::numeric /
     NULLIF(count(*) FILTER (WHERE ue.event = 'shown'), 0)::numeric) * 100.0,
    2
  ) AS conversion_rate_percent,
  COALESCE(SUM(ue.amount) FILTER (WHERE ue.event = 'accepted'), 0) AS revenue_generated
FROM public.upsell_events ue
LEFT JOIN public.upsell_rules ur ON ur.id = ue.rule_id
GROUP BY ue.lounge_id, ue.rule_id, ur.trigger_type;

-- View 5: Low Stock Alerts
CREATE OR REPLACE VIEW public.canteen_low_stock_alerts_v AS
SELECT
  e.lounge_id,
  e.id AS extra_id,
  e.name_ar,
  e.name_en,
  e.category,
  e.stock_quantity,
  COALESCE(e.min_stock_alert, 5) AS min_stock_threshold
FROM public.extras e
WHERE e.is_active = true
  AND e.track_stock = true
  AND e.stock_quantity <= COALESCE(e.min_stock_alert, 5);

COMMIT;
