BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- -----------------------------------------------------------------------------
-- 1. Ensure Supporting Tables Exist
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'space_types'
  ) THEN
    CREATE TABLE public.space_types (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      lounge_id uuid REFERENCES public.lounges(id) ON DELETE CASCADE,
      name_ar text NOT NULL,
      name_en text,
      created_at timestamptz NOT NULL DEFAULT now()
    );
    ALTER TABLE public.space_types ENABLE ROW LEVEL SECURITY;
    CREATE POLICY "space_types_read_policy" ON public.space_types FOR SELECT TO authenticated USING (true);
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 2. Pricing Rules Table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pricing_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lounge_id uuid NOT NULL REFERENCES public.lounges(id) ON DELETE CASCADE,
  room_id uuid REFERENCES public.rooms(id) ON DELETE CASCADE,
  space_type_id uuid REFERENCES public.space_types(id) ON DELETE CASCADE,
  name_ar text NOT NULL,
  name_en text,
  rule_type text NOT NULL CHECK (rule_type IN ('peak', 'off_peak', 'special_day')),
  days_of_week smallint[] NOT NULL CHECK (
    days_of_week <@ array[0,1,2,3,4,5,6]::smallint[]
    AND cardinality(days_of_week) > 0
  ),
  start_time time without time zone NOT NULL,
  end_time time without time zone NOT NULL,
  valid_from date,
  valid_to date,
  adjustment_type text NOT NULL CHECK (adjustment_type IN ('multiplier', 'percent_delta', 'fixed_rate')),
  adjustment_value numeric(10,3) NOT NULL CHECK (
    (adjustment_type = 'percent_delta') OR (adjustment_value > 0)
  ),
  applies_to_play_mode text CHECK (applies_to_play_mode IN ('single', 'multi')),
  priority int NOT NULL DEFAULT 100,
  is_active boolean NOT NULL DEFAULT true,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes for Fast Rule Evaluation
CREATE INDEX IF NOT EXISTS idx_pricing_rules_lookup
  ON public.pricing_rules (lounge_id, is_active, priority DESC);

CREATE INDEX IF NOT EXISTS idx_pricing_rules_room
  ON public.pricing_rules (room_id)
  WHERE room_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_pricing_rules_space_type
  ON public.pricing_rules (space_type_id)
  WHERE space_type_id IS NOT NULL;

-- Enable RLS
ALTER TABLE public.pricing_rules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "pricing_rules_read_policy" ON public.pricing_rules;
CREATE POLICY "pricing_rules_read_policy"
  ON public.pricing_rules FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "pricing_rules_write_policy" ON public.pricing_rules;
CREATE POLICY "pricing_rules_write_policy"
  ON public.pricing_rules FOR ALL
  TO authenticated
  USING (
    private.permission_role(auth.uid(), NULL) = 'super_admin'
    OR public.has_lounge_permission(lounge_id, 'pricing.manage')
  )
  WITH CHECK (
    private.permission_role(auth.uid(), NULL) = 'super_admin'
    OR public.has_lounge_permission(lounge_id, 'pricing.manage')
  );

-- -----------------------------------------------------------------------------
-- 3. Alter Bookings Table for Audit & Snapshots
-- -----------------------------------------------------------------------------
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS pricing_snapshot jsonb,
  ADD COLUMN IF NOT EXISTS pricing_rule_ids uuid[];

-- -----------------------------------------------------------------------------
-- 4. Event Catalog Seed for Pricing
-- -----------------------------------------------------------------------------
INSERT INTO public.event_catalog (
  code, entity_type, default_severity, label_key, title_ar, title_en, description
) VALUES
  ('pricing_rule_created', 'pricing_rule', 'info', 'events.pricing.created', 'إنشاء قاعدة تسعير', 'Pricing Rule Created', 'إضافة قاعدة ذروة أو تخفيض جديدة'),
  ('pricing_rule_updated', 'pricing_rule', 'warning', 'events.pricing.updated', 'تعديل قاعدة تسعير', 'Pricing Rule Updated', 'تعديل قيم أو مواعيد قاعدة تسعير'),
  ('pricing_rule_deactivated', 'pricing_rule', 'warning', 'events.pricing.deactivated', 'تعطيل قاعدة تسعير', 'Pricing Rule Deactivated', 'إيقاف تفعيل قاعدة تسعير')
ON CONFLICT (code) DO UPDATE SET
  title_ar = EXCLUDED.title_ar,
  title_en = EXCLUDED.title_en,
  description = EXCLUDED.description;

-- -----------------------------------------------------------------------------
-- 5. RPC: quote_booking_price (Server Authority Price Calculator)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.quote_booking_price(
  p_room_id uuid,
  p_date date,
  p_start time without time zone,
  p_end time without time zone,
  p_play_mode text DEFAULT 'single',
  p_extra_controllers int DEFAULT 0,
  p_coupon_code text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $f$
DECLARE
  v_room record;
  v_lounge record;
  v_dow smallint;
  v_play_mode text;
  v_base_rate numeric(10,2);
  v_controller_rate numeric(10,2);
  v_total_minutes numeric;
  v_start_min numeric;
  v_end_min numeric;
  v_cur_min numeric;
  v_next_min numeric;
  v_rule record;
  v_seg_rate numeric(10,3);
  v_seg_amount numeric(12,4);
  v_room_subtotal numeric(12,4) := 0;
  v_controllers_amount numeric(12,4) := 0;
  v_discount_amount numeric(12,4) := 0;
  v_final_total numeric(12,2) := 0;
  v_has_peak boolean := false;
  v_segments jsonb := '[]'::jsonb;
  v_applied_rule_ids uuid[] := '{}';
  v_promo record;
  v_promo_discount numeric(12,4) := 0;
BEGIN
  -- 1. Validate Play Mode
  v_play_mode := lower(COALESCE(NULLIF(btrim(p_play_mode), ''), 'single'));
  IF v_play_mode NOT IN ('single', 'multi') THEN
    RAISE EXCEPTION 'Invalid play mode' USING ERRCODE = '22023';
  END IF;

  -- 2. Fetch Room & Lounge
  SELECT
    r.id, r.lounge_id, r.hourly_rate_single, r.hourly_rate_multi,
    r.extra_controller_price, r.is_active, r.is_available
  INTO v_room
  FROM public.rooms r
  WHERE r.id = p_room_id;

  IF v_room.id IS NULL THEN
    RAISE EXCEPTION 'Room not found' USING ERRCODE = 'P0002';
  END IF;

  SELECT l.id, l.timezone INTO v_lounge
  FROM public.lounges l
  WHERE l.id = v_room.lounge_id;

  -- 3. Base Hourly Rate Selection
  IF v_play_mode = 'multi' AND COALESCE(v_room.hourly_rate_multi, 0) > 0 THEN
    v_base_rate := v_room.hourly_rate_multi;
  ELSE
    v_base_rate := v_room.hourly_rate_single;
  END IF;

  IF COALESCE(v_base_rate, 0) <= 0 THEN
    RAISE EXCEPTION 'Room has no valid base rate' USING ERRCODE = '23514';
  END IF;

  -- 4. Calculate Time Interval in Minutes
  v_start_min := (EXTRACT(HOUR FROM p_start) * 60) + EXTRACT(MINUTE FROM p_start);
  v_end_min := (EXTRACT(HOUR FROM p_end) * 60) + EXTRACT(MINUTE FROM p_end);

  IF v_end_min <= v_start_min THEN
    v_end_min := v_end_min + 1440; -- Midnight crossing
  END IF;

  v_total_minutes := v_end_min - v_start_min;
  IF v_total_minutes <= 0 THEN
    RAISE EXCEPTION 'Invalid booking duration' USING ERRCODE = '22023';
  END IF;

  v_dow := EXTRACT(DOW FROM p_date)::smallint;

  -- 5. Segment Interval by Boundary Points
  v_cur_min := v_start_min;

  WHILE v_cur_min < v_end_min LOOP
    -- Default next step is end of booking
    v_next_min := v_end_min;

    -- Find the earliest rule boundary between v_cur_min and v_end_min
    FOR v_rule IN
      SELECT
        pr.id,
        pr.rule_type,
        pr.adjustment_type,
        pr.adjustment_value,
        ((EXTRACT(HOUR FROM pr.start_time) * 60) + EXTRACT(MINUTE FROM pr.start_time)) AS r_start,
        ((EXTRACT(HOUR FROM pr.end_time) * 60) + EXTRACT(MINUTE FROM pr.end_time)) AS r_end,
        pr.priority,
        pr.created_at,
        CASE
          WHEN pr.room_id IS NOT NULL THEN 3
          WHEN pr.space_type_id IS NOT NULL THEN 2
          ELSE 1
        END AS specificity
      FROM public.pricing_rules pr
      WHERE pr.lounge_id = v_room.lounge_id
        AND pr.is_active = true
        AND v_dow = ANY(pr.days_of_week)
        AND (pr.room_id IS NULL OR pr.room_id = p_room_id)
        AND (pr.applies_to_play_mode IS NULL OR pr.applies_to_play_mode = v_play_mode)
        AND (pr.valid_from IS NULL OR p_date >= pr.valid_from)
        AND (pr.valid_to IS NULL OR p_date <= pr.valid_to)
    LOOP
      -- Normalize midnight crossing rule times
      IF v_rule.r_end <= v_rule.r_start THEN
        v_rule.r_end := v_rule.r_end + 1440;
      END IF;

      -- Check if boundary splits current segment
      IF v_rule.r_start > (v_cur_min % 1440) AND v_rule.r_start < (v_next_min % 1440) THEN
        v_next_min := v_cur_min + (v_rule.r_start - (v_cur_min % 1440));
      END IF;
      IF v_rule.r_end > (v_cur_min % 1440) AND v_rule.r_end < (v_next_min % 1440) THEN
        v_next_min := v_cur_min + (v_rule.r_end - (v_cur_min % 1440));
      END IF;
    END LOOP;

    -- Ensure progress
    IF v_next_min <= v_cur_min THEN
      v_next_min := v_cur_min + 15;
    END IF;
    IF v_next_min > v_end_min THEN
      v_next_min := v_end_min;
    END IF;

    -- Find single winning rule for current segment [v_cur_min, v_next_min]
    SELECT
      pr.id,
      pr.rule_type,
      pr.adjustment_type,
      pr.adjustment_value
    INTO v_rule
    FROM public.pricing_rules pr
    WHERE pr.lounge_id = v_room.lounge_id
      AND pr.is_active = true
      AND v_dow = ANY(pr.days_of_week)
      AND (pr.room_id IS NULL OR pr.room_id = p_room_id)
      AND (pr.applies_to_play_mode IS NULL OR pr.applies_to_play_mode = v_play_mode)
      AND (pr.valid_from IS NULL OR p_date >= pr.valid_from)
      AND (pr.valid_to IS NULL OR p_date <= pr.valid_to)
      AND (
        CASE
          WHEN pr.end_time <= pr.start_time THEN
            ((v_cur_min % 1440) >= ((EXTRACT(HOUR FROM pr.start_time)*60) + EXTRACT(MINUTE FROM pr.start_time)))
            OR ((v_cur_min % 1440) < ((EXTRACT(HOUR FROM pr.end_time)*60) + EXTRACT(MINUTE FROM pr.end_time)))
          ELSE
            ((v_cur_min % 1440) >= ((EXTRACT(HOUR FROM pr.start_time)*60) + EXTRACT(MINUTE FROM pr.start_time)))
            AND ((v_cur_min % 1440) < ((EXTRACT(HOUR FROM pr.end_time)*60) + EXTRACT(MINUTE FROM pr.end_time)))
        END
      )
    ORDER BY
      (CASE WHEN pr.room_id IS NOT NULL THEN 3 WHEN pr.space_type_id IS NOT NULL THEN 2 ELSE 1 END) DESC,
      pr.priority DESC,
      pr.created_at DESC
    LIMIT 1;

    -- Calculate rate for segment
    IF v_rule.id IS NOT NULL THEN
      IF v_rule.rule_type = 'peak' THEN
        v_has_peak := true;
      END IF;

      CASE v_rule.adjustment_type
        WHEN 'multiplier' THEN
          v_seg_rate := v_base_rate * v_rule.adjustment_value;
        WHEN 'percent_delta' THEN
          v_seg_rate := v_base_rate * (1.0 + (v_rule.adjustment_value / 100.0));
        WHEN 'fixed_rate' THEN
          v_seg_rate := v_rule.adjustment_value;
        ELSE
          v_seg_rate := v_base_rate;
      END CASE;

      IF NOT (v_rule.id = ANY(v_applied_rule_ids)) THEN
        v_applied_rule_ids := array_append(v_applied_rule_ids, v_rule.id);
      END IF;
    ELSE
      v_seg_rate := v_base_rate;
    END IF;

    -- Calculate amount for minutes in segment
    v_seg_amount := (v_seg_rate / 60.0) * (v_next_min - v_cur_min);
    v_room_subtotal := v_room_subtotal + v_seg_amount;

    -- Append segment to JSON result
    v_segments := v_segments || jsonb_build_object(
      'from', to_char(('00:00:00'::time + (v_cur_min % 1440 || ' minutes')::interval), 'HH24:MI:SS'),
      'to', to_char(('00:00:00'::time + (v_next_min % 1440 || ' minutes')::interval), 'HH24:MI:SS'),
      'minutes', (v_next_min - v_cur_min),
      'base_rate', v_base_rate,
      'applied_rule_id', v_rule.id,
      'rule_type', COALESCE(v_rule.rule_type, 'standard'),
      'rate', ROUND(v_seg_rate, 2),
      'amount', ROUND(v_seg_amount, 2)
    );

    v_cur_min := v_next_min;
  END LOOP;

  -- 6. Extra Controllers (Exempt from pricing rules in v1)
  IF COALESCE(p_extra_controllers, 0) > 0 THEN
    v_controller_rate := COALESCE(v_room.extra_controller_price, 0);
    v_controllers_amount := (p_extra_controllers * v_controller_rate * (v_total_minutes / 60.0));
  END IF;

  -- 7. Promo / Coupon Evaluation (Largest discount wins, no stacking)
  IF p_coupon_code IS NOT NULL AND btrim(p_coupon_code) <> '' THEN
    SELECT p.discount_type, p.discount_value INTO v_promo
    FROM public.promotions p
    WHERE p.is_active = true
      AND (p.room_id IS NULL OR p.room_id = p_room_id)
      AND (lower(btrim(p.code)) = lower(btrim(p_coupon_code)))
      AND (p.expires_at IS NULL OR p.expires_at > now())
    LIMIT 1;

    IF v_promo.discount_type IS NOT NULL THEN
      IF v_promo.discount_type = 'percentage' THEN
        v_promo_discount := v_room_subtotal * (v_promo.discount_value / 100.0);
      ELSE
        v_promo_discount := v_promo.discount_value;
      END IF;
      v_discount_amount := LEAST(v_promo_discount, v_room_subtotal);
    END IF;
  END IF;

  -- 8. Final Total with Half-Up Rounding to Nearest 1.00 EGP
  v_final_total := ROUND(GREATEST(0, (v_room_subtotal + v_controllers_amount - v_discount_amount)), 0);

  RETURN jsonb_build_object(
    'segments', v_segments,
    'room_subtotal', ROUND(v_room_subtotal, 2),
    'extra_controllers_amount', ROUND(v_controllers_amount, 2),
    'discount_amount', ROUND(v_discount_amount, 2),
    'total', v_final_total,
    'currency', 'EGP',
    'has_peak', v_has_peak,
    'pricing_rule_ids', to_jsonb(v_applied_rule_ids),
    'pricing_version', 1
  );
END;
$f$;

REVOKE ALL ON FUNCTION public.quote_booking_price(uuid, date, time, time, text, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quote_booking_price(uuid, date, time, time, text, int, text) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 6. RPC: upsert_pricing_rule (With Overlap & Ambiguity Rejection)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.upsert_pricing_rule(
  p_lounge_id uuid,
  p_name_ar text,
  p_rule_type text,
  p_days_of_week smallint[],
  p_start_time time without time zone,
  p_end_time time without time zone,
  p_adjustment_type text,
  p_adjustment_value numeric,
  p_id uuid DEFAULT NULL,
  p_room_id uuid DEFAULT NULL,
  p_space_type_id uuid DEFAULT NULL,
  p_name_en text DEFAULT NULL,
  p_valid_from date DEFAULT NULL,
  p_valid_to date DEFAULT NULL,
  p_applies_to_play_mode text DEFAULT NULL,
  p_priority int DEFAULT 100,
  p_is_active boolean DEFAULT true
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $f$
DECLARE
  v_rule_id uuid;
  v_conflicting_rule record;
  v_owner_user_id uuid;
  v_owner_email text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT (
    private.permission_role(auth.uid(), NULL) = 'super_admin'
    OR public.has_lounge_permission(p_lounge_id, 'pricing.manage')
  ) THEN
    RAISE EXCEPTION 'Access denied to manage pricing rules' USING ERRCODE = '42501';
  END IF;

  -- Conflict Check: Reject overlapping rules with same scope & priority
  SELECT pr.id, pr.name_ar INTO v_conflicting_rule
  FROM public.pricing_rules pr
  WHERE pr.lounge_id = p_lounge_id
    AND pr.is_active = true
    AND (p_id IS NULL OR pr.id <> p_id)
    AND pr.priority = p_priority
    AND (pr.room_id IS NOT DISTINCT FROM p_room_id)
    AND (pr.space_type_id IS NOT DISTINCT FROM p_space_type_id)
    AND (pr.applies_to_play_mode IS NULL OR p_applies_to_play_mode IS NULL OR pr.applies_to_play_mode = p_applies_to_play_mode)
    AND (pr.days_of_week && p_days_of_week)
    AND (pr.valid_from IS NULL OR p_valid_to IS NULL OR pr.valid_from <= p_valid_to)
    AND (pr.valid_to IS NULL OR p_valid_from IS NULL OR pr.valid_to >= p_valid_from)
    AND (
      -- Check time overlap
      (pr.start_time, pr.end_time) OVERLAPS (p_start_time, p_end_time)
      OR (pr.end_time <= pr.start_time AND (p_start_time >= pr.start_time OR p_end_time <= pr.end_time))
      OR (p_end_time <= p_start_time AND (pr.start_time >= p_start_time OR pr.end_time <= p_end_time))
    )
  LIMIT 1;

  IF v_conflicting_rule.id IS NOT NULL THEN
    RAISE EXCEPTION 'PRICING_RULE_CONFLICT'
      USING ERRCODE = 'P0001',
      DETAIL = jsonb_build_object(
        'conflicting_rule_id', v_conflicting_rule.id,
        'conflicting_rule_name', v_conflicting_rule.name_ar
      )::text;
  END IF;

  v_rule_id := COALESCE(p_id, gen_random_uuid());

  INSERT INTO public.pricing_rules (
    id, lounge_id, room_id, space_type_id, name_ar, name_en, rule_type,
    days_of_week, start_time, end_time, valid_from, valid_to,
    adjustment_type, adjustment_value, applies_to_play_mode,
    priority, is_active, created_by, updated_at
  ) VALUES (
    v_rule_id, p_lounge_id, p_room_id, p_space_type_id, p_name_ar, p_name_en, p_rule_type,
    p_days_of_week, p_start_time, p_end_time, p_valid_from, p_valid_to,
    p_adjustment_type, p_adjustment_value, p_applies_to_play_mode,
    p_priority, p_is_active, auth.uid(), now()
  )
  ON CONFLICT (id) DO UPDATE SET
    room_id = EXCLUDED.room_id,
    space_type_id = EXCLUDED.space_type_id,
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    rule_type = EXCLUDED.rule_type,
    days_of_week = EXCLUDED.days_of_week,
    start_time = EXCLUDED.start_time,
    end_time = EXCLUDED.end_time,
    valid_from = EXCLUDED.valid_from,
    valid_to = EXCLUDED.valid_to,
    adjustment_type = EXCLUDED.adjustment_type,
    adjustment_value = EXCLUDED.adjustment_value,
    applies_to_play_mode = EXCLUDED.applies_to_play_mode,
    priority = EXCLUDED.priority,
    is_active = EXCLUDED.is_active,
    updated_at = now();

  -- Audit Log
  PERFORM private.log_audit_event(
    p_lounge_id, 'pricing_rule', v_rule_id::text,
    CASE WHEN p_id IS NULL THEN 'pricing_rule_created' ELSE 'pricing_rule_updated' END,
    NULL, auth.uid(), 'warning',
    jsonb_build_object(
      'name_ar', p_name_ar, 'rule_type', p_rule_type, 'adjustment_type', p_adjustment_type,
      'adjustment_value', p_adjustment_value, 'priority', p_priority, 'is_active', p_is_active
    ),
    now()
  );

  -- Confirmation Notification to Lounge Owner on Peak Activation
  IF p_rule_type = 'peak' AND p_is_active = true THEN
    SELECT ls.user_id INTO v_owner_user_id
    FROM public.lounge_staff ls
    WHERE ls.lounge_id = p_lounge_id AND ls.role = 'owner' AND ls.is_active = true
    LIMIT 1;

    IF v_owner_user_id IS NOT NULL THEN
      INSERT INTO public.notifications (
        user_id, lounge_id, type, title, body, created_at
      ) VALUES (
        v_owner_user_id, p_lounge_id, 'price_change',
        'تفعيل تسعير ذروة جديد',
        'تم تفعيل قاعدة تسعير ذروة جديدة: ' || p_name_ar,
        now()
      );
    END IF;
  END IF;

  RETURN v_rule_id;
END;
$f$;

REVOKE ALL ON FUNCTION public.upsert_pricing_rule(uuid, text, text, smallint[], time, time, text, numeric, uuid, uuid, uuid, text, date, date, text, int, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.upsert_pricing_rule(uuid, text, text, smallint[], time, time, text, numeric, uuid, uuid, uuid, text, date, date, text, int, boolean) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 7. RPC: get_room_slots_with_prices (Set-Based Slot Pricing)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_room_slots_with_prices(
  p_room_id uuid,
  p_date date
)
RETURNS TABLE(
  slot_start time without time zone,
  slot_end time without time zone,
  is_available boolean,
  hourly_rate numeric,
  rule_type text,
  is_peak boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $f$
DECLARE
  v_room record;
  v_lounge record;
  v_quote jsonb;
BEGIN
  SELECT r.id, r.lounge_id, r.hourly_rate_single, r.is_available, r.is_active
  INTO v_room
  FROM public.rooms r
  WHERE r.id = p_room_id;

  IF v_room.id IS NULL THEN
    RAISE EXCEPTION 'Room not found' USING ERRCODE = 'P0002';
  END IF;

  SELECT l.id, COALESCE(l.opening_time, '10:00:00'::time) AS op_time, COALESCE(l.closing_time, '02:00:00'::time) AS cl_time
  INTO v_lounge
  FROM public.lounges l
  WHERE l.id = v_room.lounge_id;

  RETURN QUERY
  WITH RECURSIVE time_slots AS (
    SELECT
      v_lounge.op_time AS s_start,
      (v_lounge.op_time + interval '1 hour')::time AS s_end,
      1 AS step
    UNION ALL
    SELECT
      s_end,
      (s_end + interval '1 hour')::time,
      step + 1
    FROM time_slots
    WHERE step < 16
  ),
  evaluated_slots AS (
    SELECT
      ts.s_start,
      ts.s_end,
      NOT EXISTS (
        SELECT 1 FROM public.bookings b
        WHERE b.room_id = p_room_id
          AND b.booking_date = p_date
          AND b.status IN ('upcoming', 'in_progress', 'completed')
          AND (b.start_time, b.end_time) OVERLAPS (ts.s_start, ts.s_end)
      ) AS avail,
      public.quote_booking_price(p_room_id, p_date, ts.s_start, ts.s_end, 'single', 0, NULL) AS q
    FROM time_slots ts
  )
  SELECT
    es.s_start AS slot_start,
    es.s_end AS slot_end,
    es.avail AS is_available,
    (es.q->>'total')::numeric AS hourly_rate,
    COALESCE(es.q->'segments'->0->>'rule_type', 'standard') AS rule_type,
    COALESCE((es.q->>'has_peak')::boolean, false) AS is_peak
  FROM evaluated_slots es;
END;
$f$;

REVOKE ALL ON FUNCTION public.get_room_slots_with_prices(uuid, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_room_slots_with_prices(uuid, date) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 8. RPC: get_lounge_price_range (Card "من X ج.م/ساعة" Display)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_lounge_price_range(
  p_lounge_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $f$
DECLARE
  v_min numeric;
  v_max numeric;
BEGIN
  -- Compute base min/max room rates
  SELECT
    MIN(LEAST(r.hourly_rate_single, COALESCE(NULLIF(r.hourly_rate_multi, 0), r.hourly_rate_single))),
    MAX(GREATEST(r.hourly_rate_single, COALESCE(r.hourly_rate_multi, r.hourly_rate_single)))
  INTO v_min, v_max
  FROM public.rooms r
  WHERE r.lounge_id = p_lounge_id
    AND r.is_active = true;

  RETURN jsonb_build_object(
    'min_hourly_rate', COALESCE(ROUND(v_min, 0), 0),
    'max_hourly_rate', COALESCE(ROUND(v_max, 0), 0),
    'currency', 'EGP'
  );
END;
$f$;

REVOKE ALL ON FUNCTION public.get_lounge_price_range(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_lounge_price_range(uuid) TO authenticated, service_role;

COMMIT;
