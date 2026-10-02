-- ============================================================================
-- Migration: 20260930200000_p2_growth_and_commercial_features.sql
-- Description: Phase 6 (P2) - Growth & Commercial Features:
--   1. Memberships & Hour Packages (membership_packages, user_membership_packages, package_hour_transactions)
--   2. Peak / Off-Peak Dynamic Pricing Rules & Calendar Overrides
--   3. No-Show Protection, Grace Periods & Forfeited Deposit Accounting
--   4. Owner Growth Dashboard & Revenue Intelligence Analytics RPC
--   5. CRM Segmentation, Promotional Win-back Engine & Dispatch Workers
--   6. Canteen Combos, Stock-aware Menus, and Checkout Upsell Engine
-- Source of Truth: salahaldensherief/playspot_V2
-- ============================================================================

-- ============================================================================
-- 1. Memberships & Hour Packages Tables
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.membership_packages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lounge_id uuid NOT NULL REFERENCES public.lounges(id) ON DELETE CASCADE,
  name_ar text NOT NULL,
  name_en text NOT NULL,
  description_ar text,
  description_en text,
  total_hours numeric(6,2) NOT NULL CHECK (total_hours > 0),
  price numeric(10,2) NOT NULL CHECK (price >= 0),
  validity_days integer NOT NULL DEFAULT 30 CHECK (validity_days > 0),
  allowed_resource_types text[] DEFAULT NULL,
  allowed_room_ids uuid[] DEFAULT NULL,
  peak_allowed boolean NOT NULL DEFAULT true,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_membership_packages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  package_id uuid NOT NULL REFERENCES public.membership_packages(id) ON DELETE RESTRICT,
  lounge_id uuid NOT NULL REFERENCES public.lounges(id) ON DELETE CASCADE,
  total_hours numeric(6,2) NOT NULL CHECK (total_hours > 0),
  remaining_hours numeric(6,2) NOT NULL CHECK (remaining_hours >= 0),
  purchased_price numeric(10,2) NOT NULL CHECK (purchased_price >= 0),
  expires_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'exhausted', 'expired', 'cancelled')),
  payment_method text DEFAULT 'cash',
  payment_status text NOT NULL DEFAULT 'completed' CHECK (payment_status IN ('pending', 'completed', 'refunded')),
  shift_id uuid REFERENCES public.shifts(id) ON DELETE SET NULL,
  purchased_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.package_hour_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_package_id uuid NOT NULL REFERENCES public.user_membership_packages(id) ON DELETE CASCADE,
  booking_id uuid REFERENCES public.bookings(id) ON DELETE SET NULL,
  delta_hours numeric(6,2) NOT NULL,
  balance_after numeric(6,2) NOT NULL CHECK (balance_after >= 0),
  transaction_type text NOT NULL CHECK (transaction_type IN ('purchase', 'booking_usage', 'booking_refund', 'admin_adjustment', 'expiration')),
  notes text,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_membership_packages_lounge ON public.membership_packages(lounge_id, is_active);
CREATE INDEX IF NOT EXISTS idx_user_membership_packages_user ON public.user_membership_packages(user_id, lounge_id, status);
CREATE INDEX IF NOT EXISTS idx_package_hour_transactions_pkg ON public.package_hour_transactions(user_package_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_package_hour_transactions_booking ON public.package_hour_transactions(booking_id);

-- Update shift_payments category check constraint to support package_sale and deposit_forfeited
DO $$
BEGIN
  ALTER TABLE public.shift_payments DROP CONSTRAINT IF EXISTS shift_payments_category_check;
  ALTER TABLE public.shift_payments ADD CONSTRAINT shift_payments_category_check 
    CHECK (category = ANY (ARRAY['gaming_time'::text, 'snacks'::text, 'extra_controllers'::text, 'package_sale'::text, 'deposit_forfeited'::text, 'other'::text]));
EXCEPTION WHEN OTHERS THEN
  NULL;
END;
$$;

-- Enable RLS on package tables
ALTER TABLE public.membership_packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_membership_packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.package_hour_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS membership_packages_select_policy ON public.membership_packages;
CREATE POLICY membership_packages_select_policy ON public.membership_packages
  FOR SELECT TO authenticated, anon
  USING (
    is_active = true
    OR public.is_super_admin()
    OR public.has_lounge_permission(lounge_id, 'billing_checkout')
    OR public.has_lounge_permission(lounge_id, 'lounges_manage_settings')
  );

DROP POLICY IF EXISTS membership_packages_manage_policy ON public.membership_packages;
CREATE POLICY membership_packages_manage_policy ON public.membership_packages
  FOR ALL TO authenticated
  USING (
    public.is_super_admin()
    OR public.has_lounge_permission(lounge_id, 'lounges_manage_settings')
  );

DROP POLICY IF EXISTS user_membership_packages_select_policy ON public.user_membership_packages;
CREATE POLICY user_membership_packages_select_policy ON public.user_membership_packages
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_super_admin()
    OR public.has_lounge_permission(lounge_id, 'billing_checkout')
  );

DROP POLICY IF EXISTS package_hour_transactions_select_policy ON public.package_hour_transactions;
CREATE POLICY package_hour_transactions_select_policy ON public.package_hour_transactions
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.user_membership_packages ump
      WHERE ump.id = package_hour_transactions.user_package_id
        AND (ump.user_id = auth.uid() OR public.is_super_admin() OR public.has_lounge_permission(ump.lounge_id, 'billing_checkout'))
    )
  );

-- ============================================================================
-- 2. Memberships & Hour Packages RPCs
-- ============================================================================

CREATE OR REPLACE FUNCTION public.purchase_membership_package(
  p_package_id uuid,
  p_payment_method text DEFAULT 'cash',
  p_user_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_target_user uuid;
  v_pkg public.membership_packages%ROWTYPE;
  v_shift_id uuid;
  v_user_pkg_id uuid;
  v_expires_at timestamptz;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  v_target_user := COALESCE(p_user_id, v_caller);

  SELECT * INTO v_pkg
  FROM public.membership_packages
  WHERE id = p_package_id AND is_active = true
  FOR SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Membership package not found or inactive' USING ERRCODE = 'P0002';
  END IF;

  -- If purchasing for someone else, must be lounge staff with billing permission
  IF v_target_user <> v_caller THEN
    IF NOT public.is_super_admin() AND NOT public.has_lounge_permission(v_pkg.lounge_id, 'billing_checkout') THEN
      RAISE EXCEPTION 'Not authorized to issue package for other customers' USING ERRCODE = '42501';
    END IF;
  END IF;

  -- Check for active shift of this lounge
  SELECT s.id INTO v_shift_id
  FROM public.shifts s
  WHERE s.lounge_id = v_pkg.lounge_id
    AND s.status = 'open'
    AND s.closed_at IS NULL
  ORDER BY s.opened_at DESC
  LIMIT 1;

  v_expires_at := now() + make_interval(days => v_pkg.validity_days);

  INSERT INTO public.user_membership_packages (
    user_id,
    package_id,
    lounge_id,
    total_hours,
    remaining_hours,
    purchased_price,
    expires_at,
    status,
    payment_method,
    payment_status,
    shift_id,
    purchased_at
  ) VALUES (
    v_target_user,
    v_pkg.id,
    v_pkg.lounge_id,
    v_pkg.total_hours,
    v_pkg.total_hours,
    v_pkg.price,
    v_expires_at,
    'active',
    p_payment_method,
    'completed',
    v_shift_id,
    now()
  )
  RETURNING id INTO v_user_pkg_id;

  -- Record initial purchase transaction
  INSERT INTO public.package_hour_transactions (
    user_package_id,
    delta_hours,
    balance_after,
    transaction_type,
    notes,
    created_by
  ) VALUES (
    v_user_pkg_id,
    v_pkg.total_hours,
    v_pkg.total_hours,
    'purchase',
    'Initial package purchase: ' || v_pkg.name_en,
    v_caller
  );

  -- Record in shift payments if active shift exists and paid at lounge
  IF v_shift_id IS NOT NULL AND p_payment_method IN ('cash', 'manual_transfer', 'card', 'vodafone_cash', 'instapay') THEN
    INSERT INTO public.shift_payments (
      shift_id,
      lounge_id,
      payment_method,
      category,
      amount,
      paid_at
    ) VALUES (
      v_shift_id,
      v_pkg.lounge_id,
      p_payment_method,
      'package_sale',
      v_pkg.price,
      now()
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'user_package_id', v_user_pkg_id,
    'package_id', v_pkg.id,
    'lounge_id', v_pkg.lounge_id,
    'user_id', v_target_user,
    'total_hours', v_pkg.total_hours,
    'remaining_hours', v_pkg.total_hours,
    'price', v_pkg.price,
    'expires_at', v_expires_at,
    'shift_id', v_shift_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.deduct_package_hours(
  p_user_package_id uuid,
  p_booking_id uuid,
  p_hours numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_user_pkg public.user_membership_packages%ROWTYPE;
  v_balance_after numeric;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF p_hours <= 0 THEN
    RAISE EXCEPTION 'Hours to deduct must be greater than zero' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_user_pkg
  FROM public.user_membership_packages
  WHERE id = p_user_package_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User package not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_user_pkg.user_id <> v_caller
     AND NOT public.is_super_admin()
     AND NOT public.has_lounge_permission(v_user_pkg.lounge_id, 'billing_checkout') THEN
    RAISE EXCEPTION 'Not authorized to use this package' USING ERRCODE = '42501';
  END IF;

  IF v_user_pkg.status <> 'active' OR v_user_pkg.expires_at <= now() THEN
    RAISE EXCEPTION 'Package is expired or inactive' USING ERRCODE = '55000';
  END IF;

  IF v_user_pkg.remaining_hours < p_hours THEN
    RAISE EXCEPTION 'Insufficient package hours. Remaining: %, Requested: %', v_user_pkg.remaining_hours, p_hours USING ERRCODE = '55000';
  END IF;

  v_balance_after := ROUND(v_user_pkg.remaining_hours - p_hours, 2);

  UPDATE public.user_membership_packages
  SET remaining_hours = v_balance_after,
      status = CASE WHEN v_balance_after = 0 THEN 'exhausted' ELSE 'active' END
  WHERE id = v_user_pkg.id;

  INSERT INTO public.package_hour_transactions (
    user_package_id,
    booking_id,
    delta_hours,
    balance_after,
    transaction_type,
    notes,
    created_by
  ) VALUES (
    v_user_pkg.id,
    p_booking_id,
    -p_hours,
    v_balance_after,
    'booking_usage',
    'Hours deducted for booking ' || COALESCE(p_booking_id::text, ''),
    v_caller
  );

  RETURN jsonb_build_object(
    'success', true,
    'user_package_id', v_user_pkg.id,
    'deducted_hours', p_hours,
    'remaining_hours', v_balance_after,
    'status', CASE WHEN v_balance_after = 0 THEN 'exhausted' ELSE 'active' END
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.refund_package_hours(
  p_booking_id uuid,
  p_reason text DEFAULT 'cancellation'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_txn RECORD;
  v_user_pkg public.user_membership_packages%ROWTYPE;
  v_refunded_total numeric := 0;
  v_balance_after numeric;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  -- Find usage transactions for this booking
  FOR v_txn IN
    SELECT user_package_id, ABS(SUM(delta_hours)) AS hours_used
    FROM public.package_hour_transactions
    WHERE booking_id = p_booking_id
      AND transaction_type = 'booking_usage'
    GROUP BY user_package_id
  LOOP
    SELECT * INTO v_user_pkg
    FROM public.user_membership_packages
    WHERE id = v_txn.user_package_id
    FOR UPDATE;

    IF FOUND THEN
      v_balance_after := ROUND(v_user_pkg.remaining_hours + v_txn.hours_used, 2);
      
      UPDATE public.user_membership_packages
      SET remaining_hours = v_balance_after,
          status = CASE WHEN expires_at > now() THEN 'active' ELSE status END
      WHERE id = v_user_pkg.id;

      INSERT INTO public.package_hour_transactions (
        user_package_id,
        booking_id,
        delta_hours,
        balance_after,
        transaction_type,
        notes,
        created_by
      ) VALUES (
        v_user_pkg.id,
        p_booking_id,
        v_txn.hours_used,
        v_balance_after,
        'booking_refund',
        'Refund of hours: ' || COALESCE(p_reason, 'cancellation'),
        v_caller
      );

      v_refunded_total := v_refunded_total + v_txn.hours_used;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'refunded_hours', v_refunded_total
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_user_available_packages(
  p_lounge_id uuid,
  p_room_id uuid DEFAULT NULL,
  p_target_time timestamptz DEFAULT now()
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path TO ''
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_res jsonb;
BEGIN
  IF v_caller IS NULL THEN
    RETURN '[]'::jsonb;
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'user_package_id', ump.id,
        'package_id', mp.id,
        'name_ar', mp.name_ar,
        'name_en', mp.name_en,
        'total_hours', ump.total_hours,
        'remaining_hours', ump.remaining_hours,
        'expires_at', ump.expires_at,
        'peak_allowed', mp.peak_allowed,
        'allowed_resource_types', mp.allowed_resource_types
      )
    ),
    '[]'::jsonb
  )
  INTO v_res
  FROM public.user_membership_packages ump
  JOIN public.membership_packages mp ON mp.id = ump.package_id
  WHERE ump.user_id = v_caller
    AND ump.lounge_id = p_lounge_id
    AND ump.status = 'active'
    AND ump.remaining_hours > 0
    AND ump.expires_at > COALESCE(p_target_time, now())
    AND (
      p_room_id IS NULL 
      OR mp.allowed_room_ids IS NULL 
      OR p_room_id = ANY(mp.allowed_room_ids)
    );

  RETURN v_res;
END;
$$;

REVOKE ALL ON FUNCTION public.purchase_membership_package(uuid, text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.purchase_membership_package(uuid, text, uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.deduct_package_hours(uuid, uuid, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.deduct_package_hours(uuid, uuid, numeric) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.refund_package_hours(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.refund_package_hours(uuid, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_user_available_packages(uuid, uuid, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_user_available_packages(uuid, uuid, timestamptz) TO authenticated, service_role;


-- ============================================================================
-- 3. Dynamic Pricing Rules & Special Dates Tables
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.lounge_pricing_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lounge_id uuid NOT NULL REFERENCES public.lounges(id) ON DELETE CASCADE,
  room_id uuid REFERENCES public.rooms(id) ON DELETE CASCADE,
  name text NOT NULL,
  day_of_week integer[] NOT NULL, -- 0=Sunday, 1=Monday ... 6=Saturday
  start_time time NOT NULL,
  end_time time NOT NULL,
  rate_multiplier numeric(4,2) NOT NULL DEFAULT 1.00 CHECK (rate_multiplier > 0),
  fixed_rate_override numeric(10,2) DEFAULT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.lounge_special_pricing_dates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lounge_id uuid NOT NULL REFERENCES public.lounges(id) ON DELETE CASCADE,
  room_id uuid REFERENCES public.rooms(id) ON DELETE CASCADE,
  name text NOT NULL,
  target_date date NOT NULL,
  start_time time DEFAULT '00:00:00',
  end_time time DEFAULT '23:59:59',
  rate_multiplier numeric(4,2) NOT NULL DEFAULT 1.00 CHECK (rate_multiplier > 0),
  fixed_rate_override numeric(10,2) DEFAULT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_lounge_pricing_rules_active ON public.lounge_pricing_rules(lounge_id, is_active);
CREATE INDEX IF NOT EXISTS idx_lounge_special_dates_active ON public.lounge_special_pricing_dates(lounge_id, target_date, is_active);

ALTER TABLE public.lounge_pricing_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lounge_special_pricing_dates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS lounge_pricing_rules_select_policy ON public.lounge_pricing_rules;
CREATE POLICY lounge_pricing_rules_select_policy ON public.lounge_pricing_rules
  FOR SELECT TO authenticated, anon
  USING (true);

DROP POLICY IF EXISTS lounge_pricing_rules_manage_policy ON public.lounge_pricing_rules;
CREATE POLICY lounge_pricing_rules_manage_policy ON public.lounge_pricing_rules
  FOR ALL TO authenticated
  USING (
    public.is_super_admin()
    OR public.has_lounge_permission(lounge_id, 'rooms_manage')
  );

DROP POLICY IF EXISTS lounge_special_dates_select_policy ON public.lounge_special_pricing_dates;
CREATE POLICY lounge_special_dates_select_policy ON public.lounge_special_pricing_dates
  FOR SELECT TO authenticated, anon
  USING (true);

DROP POLICY IF EXISTS lounge_special_dates_manage_policy ON public.lounge_special_pricing_dates;
CREATE POLICY lounge_special_dates_manage_policy ON public.lounge_special_pricing_dates
  FOR ALL TO authenticated
  USING (
    public.is_super_admin()
    OR public.has_lounge_permission(lounge_id, 'rooms_manage')
  );

-- Upgrade quote_booking_price to seamlessly incorporate dynamic peak & special date pricing
CREATE OR REPLACE FUNCTION public.quote_booking_price(
  p_room_id uuid,
  p_date date,
  p_start time,
  p_end time,
  p_play_mode text DEFAULT 'single',
  p_extra_controllers integer DEFAULT 0,
  p_coupon_code text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path TO ''
AS $$
DECLARE
  v_room public.rooms%ROWTYPE;
  v_lounge public.lounges%ROWTYPE;
  v_start_min integer;
  v_end_min integer;
  v_duration_min integer;
  v_base_rate numeric;
  v_effective_rate numeric;
  v_multiplier numeric := 1.00;
  v_fixed_override numeric := NULL;
  v_has_peak boolean := false;
  v_pricing_tier text := 'standard';
  v_rule_name text := NULL;
  v_controller_rate numeric := 0;
  v_controllers_amount numeric := 0;
  v_room_subtotal numeric := 0;
  v_promo_discount numeric := 0;
  v_final_total numeric := 0;
  v_play_mode text := lower(COALESCE(NULLIF(btrim(p_play_mode), ''), 'single'));
  v_currency text := 'EGP';
  v_dow integer;
BEGIN
  IF p_room_id IS NULL OR p_date IS NULL OR p_start IS NULL OR p_end IS NULL THEN
    RAISE EXCEPTION 'Missing required arguments for price quote' USING ERRCODE = '22023';
  END IF;

  SELECT r.* INTO v_room FROM public.rooms r WHERE r.id = p_room_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Room not found' USING ERRCODE = 'P0002';
  END IF;

  SELECT l.* INTO v_lounge FROM public.lounges l WHERE l.id = v_room.lounge_id;

  v_start_min := (EXTRACT(HOUR FROM p_start) * 60 + EXTRACT(MINUTE FROM p_start))::integer;
  v_end_min := (EXTRACT(HOUR FROM p_end) * 60 + EXTRACT(MINUTE FROM p_end))::integer;

  -- Handle midnight crossing
  IF v_end_min <= v_start_min THEN
    v_end_min := v_end_min + 1440;
  END IF;

  v_duration_min := v_end_min - v_start_min;
  IF v_duration_min <= 0 OR v_duration_min > 1440 THEN
    RAISE EXCEPTION 'Invalid booking duration' USING ERRCODE = '22023';
  END IF;

  v_base_rate := CASE
    WHEN v_play_mode = 'multi' AND COALESCE(v_room.hourly_rate_multi, 0) > 0 THEN v_room.hourly_rate_multi
    ELSE COALESCE(v_room.hourly_rate_single, v_room.hourly_rate, 50)
  END;

  -- 1. Check Special Pricing Dates (Holidays / Events)
  SELECT rate_multiplier, fixed_rate_override, name
  INTO v_multiplier, v_fixed_override, v_rule_name
  FROM public.lounge_special_pricing_dates
  WHERE lounge_id = v_room.lounge_id
    AND (room_id IS NULL OR room_id = p_room_id)
    AND target_date = p_date
    AND is_active = true
    AND (p_start < end_time AND p_end > start_time)
  ORDER BY (room_id IS NOT NULL) DESC, rate_multiplier DESC
  LIMIT 1;

  IF FOUND THEN
    v_has_peak := true;
    v_pricing_tier := 'special_date';
  ELSE
    -- 2. Check Recurring Peak Pricing Rules
    v_dow := EXTRACT(DOW FROM p_date)::integer;
    SELECT rate_multiplier, fixed_rate_override, name
    INTO v_multiplier, v_fixed_override, v_rule_name
    FROM public.lounge_pricing_rules
    WHERE lounge_id = v_room.lounge_id
      AND (room_id IS NULL OR room_id = p_room_id)
      AND v_dow = ANY(day_of_week)
      AND is_active = true
      AND (
        (start_time < end_time AND p_start < end_time AND p_end > start_time)
        OR
        (start_time >= end_time AND (p_start >= start_time OR p_end <= end_time OR p_start < end_time))
      )
    ORDER BY (room_id IS NOT NULL) DESC, rate_multiplier DESC
    LIMIT 1;

    IF FOUND THEN
      v_has_peak := true;
      v_pricing_tier := CASE WHEN COALESCE(v_multiplier, 1.0) > 1.0 THEN 'peak' ELSE 'off_peak' END;
    ELSE
      v_multiplier := 1.00;
      v_fixed_override := NULL;
    END IF;
  END IF;

  IF v_fixed_override IS NOT NULL AND v_fixed_override > 0 THEN
    v_effective_rate := v_fixed_override;
  ELSE
    v_effective_rate := ROUND(v_base_rate * COALESCE(v_multiplier, 1.00), 2);
  END IF;

  v_room_subtotal := ROUND((v_effective_rate / 60.0) * v_duration_min, 2);

  -- Extra controllers
  IF COALESCE(p_extra_controllers, 0) > 0 THEN
    v_controller_rate := COALESCE(v_room.extra_controller_price, 0);
    v_controllers_amount := ROUND((p_extra_controllers * v_controller_rate * (v_duration_min / 60.0)), 2);
  END IF;

  -- Coupon check
  IF p_coupon_code IS NOT NULL AND btrim(p_coupon_code) <> '' THEN
    SELECT
      CASE
        WHEN p.discount_type = 'percentage' THEN ROUND((v_room_subtotal * (p.discount_value / 100.0)), 2)
        WHEN p.discount_type = 'fixed' THEN LEAST(v_room_subtotal, p.discount_value)
        ELSE 0
      END
    INTO v_promo_discount
    FROM public.promotions p
    WHERE p.is_active = true
      AND (p.room_id IS NULL OR p.room_id = p_room_id)
      AND lower(btrim(p.code)) = lower(btrim(p_coupon_code))
      AND (p.expires_at IS NULL OR p.expires_at > now())
    LIMIT 1;

    v_promo_discount := COALESCE(v_promo_discount, 0);
  END IF;

  v_final_total := GREATEST(0, (v_room_subtotal + v_controllers_amount) - v_promo_discount);

  RETURN jsonb_build_object(
    'room_id', p_room_id,
    'lounge_id', v_room.lounge_id,
    'date', p_date,
    'start_time', to_char(p_start, 'HH24:MI:SS'),
    'end_time', to_char(p_end, 'HH24:MI:SS'),
    'duration_minutes', v_duration_min,
    'play_mode', v_play_mode,
    'base_rate', v_base_rate,
    'effective_hourly_rate', v_effective_rate,
    'rate_multiplier', COALESCE(v_multiplier, 1.00),
    'pricing_tier', v_pricing_tier,
    'pricing_rule_name', v_rule_name,
    'has_peak_rates', v_has_peak,
    'room_subtotal', v_room_subtotal,
    'extra_controllers', COALESCE(p_extra_controllers, 0),
    'controllers_amount', v_controllers_amount,
    'addons_amount', 0,
    'discount_amount', v_promo_discount,
    'subtotal', v_room_subtotal + v_controllers_amount,
    'final_total', v_final_total,
    'currency', v_currency,
    'segments', jsonb_build_array(
      jsonb_build_object(
        'from', to_char(p_start, 'HH24:MI:SS'),
        'to', to_char(p_end, 'HH24:MI:SS'),
        'minutes', v_duration_min,
        'rate', v_effective_rate,
        'amount', v_room_subtotal
      )
    )
  );
END;
$$;


-- ============================================================================
-- 4. No-Show Protection, Grace Periods & Deposit Accounting
-- ============================================================================

-- Add deposit policy columns to lounges
ALTER TABLE public.lounges
  ADD COLUMN IF NOT EXISTS deposit_policy_type text NOT NULL DEFAULT 'none' CHECK (deposit_policy_type IN ('none', 'fixed', 'percentage', 'first_hour')),
  ADD COLUMN IF NOT EXISTS deposit_amount numeric(10,2) NOT NULL DEFAULT 0 CHECK (deposit_amount >= 0),
  ADD COLUMN IF NOT EXISTS no_show_grace_minutes integer NOT NULL DEFAULT 20 CHECK (no_show_grace_minutes >= 0),
  ADD COLUMN IF NOT EXISTS auto_cancel_no_show boolean NOT NULL DEFAULT false;

-- Add deposit tracking columns to bookings
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS deposit_required numeric(10,2) NOT NULL DEFAULT 0 CHECK (deposit_required >= 0),
  ADD COLUMN IF NOT EXISTS deposit_paid numeric(10,2) NOT NULL DEFAULT 0 CHECK (deposit_paid >= 0),
  ADD COLUMN IF NOT EXISTS deposit_status text NOT NULL DEFAULT 'none' CHECK (deposit_status IN ('none', 'pending', 'paid', 'forfeited', 'refunded')),
  ADD COLUMN IF NOT EXISTS is_no_show boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS no_show_at timestamptz,
  ADD COLUMN IF NOT EXISTS marked_no_show_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS notes text;

CREATE OR REPLACE FUNCTION public.mark_booking_no_show(
  p_booking_id uuid,
  p_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_booking public.bookings%ROWTYPE;
  v_shift_id uuid;
  v_forfeited numeric := 0;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  SELECT * INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT public.is_super_admin()
     AND NOT public.has_lounge_permission(v_booking.lounge_id, 'sessions_control')
     AND NOT public.has_lounge_permission(v_booking.lounge_id, 'billing_checkout') THEN
    RAISE EXCEPTION 'Not authorized to mark no-show' USING ERRCODE = '42501';
  END IF;

  IF v_booking.status NOT IN ('pending'::public.booking_status, 'upcoming'::public.booking_status) THEN
    RAISE EXCEPTION 'Only pending or upcoming bookings can be marked no-show. Current status: %', v_booking.status USING ERRCODE = '55000';
  END IF;

  IF v_booking.deposit_paid > 0 THEN
    v_forfeited := v_booking.deposit_paid;
  END IF;

  -- Mark booking cancelled with no_show reason & flags
  UPDATE public.bookings
  SET status = 'cancelled'::public.booking_status,
      cancellation_reason = 'no_show',
      is_no_show = true,
      no_show_at = now(),
      marked_no_show_by = v_caller,
      deposit_status = CASE WHEN v_forfeited > 0 THEN 'forfeited' ELSE deposit_status END,
      notes = CASE WHEN p_notes IS NOT NULL THEN COALESCE(notes || E'\n', '') || '[No-Show]: ' || p_notes ELSE notes END,
      updated_at = now()
  WHERE id = v_booking.id;

  -- Release room occupancy status if room was reserved
  IF v_booking.room_id IS NOT NULL THEN
    UPDATE public.rooms
    SET status = 'available',
        is_available = true,
        updated_at = now()
    WHERE id = v_booking.room_id AND status = 'occupied';
  END IF;

  -- Record forfeited deposit revenue into active shift
  IF v_forfeited > 0 THEN
    SELECT s.id INTO v_shift_id
    FROM public.shifts s
    WHERE s.lounge_id = v_booking.lounge_id
      AND s.status = 'open'
      AND s.closed_at IS NULL
    ORDER BY s.opened_at DESC
    LIMIT 1;

    IF v_shift_id IS NOT NULL THEN
      INSERT INTO public.shift_payments (
        shift_id,
        lounge_id,
        booking_id,
        payment_method,
        category,
        amount,
        paid_at
      ) VALUES (
        v_shift_id,
        v_booking.lounge_id,
        v_booking.id,
        COALESCE(v_booking.payment_method, 'cash'),
        'deposit_forfeited',
        v_forfeited,
        now()
      );
    END IF;
  END IF;

  -- Trigger waitlist processing so any waiting user gets the freed slot immediately
  BEGIN
    PERFORM public.process_booking_waitlist();
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', v_booking.id,
    'status', 'cancelled',
    'is_no_show', true,
    'deposit_forfeited', v_forfeited
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.process_expired_no_shows(
  p_lounge_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_rec RECORD;
  v_processed integer := 0;
BEGIN
  FOR v_rec IN
    SELECT b.id
    FROM public.bookings b
    JOIN public.lounges l ON l.id = b.lounge_id
    WHERE (p_lounge_id IS NULL OR b.lounge_id = p_lounge_id)
      AND b.status IN ('pending'::public.booking_status, 'upcoming'::public.booking_status)
      AND l.auto_cancel_no_show = true
      AND now() > (b.date::date + b.start_time::time + make_interval(mins => COALESCE(l.no_show_grace_minutes, 20)))
    FOR UPDATE OF b SKIP LOCKED
  LOOP
    BEGIN
      PERFORM public.mark_booking_no_show(v_rec.id, 'Auto cancelled by no-show grace period expiry');
      v_processed := v_processed + 1;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END LOOP;

  RETURN jsonb_build_object('success', true, 'processed_count', v_processed);
END;
$$;

REVOKE ALL ON FUNCTION public.mark_booking_no_show(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_booking_no_show(uuid, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.process_expired_no_shows(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.process_expired_no_shows(uuid) TO authenticated, service_role;


-- ============================================================================
-- 5. Owner Growth Dashboard & Revenue Intelligence Analytics RPC
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_lounge_revenue_intelligence(
  p_lounge_id uuid,
  p_start_date timestamptz DEFAULT (now() - interval '30 days'),
  p_end_date timestamptz DEFAULT now()
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path TO ''
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_gaming_rev numeric := 0;
  v_canteen_rev numeric := 0;
  v_packages_rev numeric := 0;
  v_deposits_rev numeric := 0;
  v_total_gross numeric := 0;
  v_refunds numeric := 0;
  v_total_net numeric := 0;
  v_cash_sales numeric := 0;
  v_digital_sales numeric := 0;

  v_total_rooms integer := 0;
  v_operating_days integer := 1;
  v_capacity_hours numeric := 0;
  v_booked_hours numeric := 0;
  v_occupancy_rate numeric := 0;
  v_idle_lost_hours numeric := 0;

  v_total_bookings integer := 0;
  v_completed_bookings integer := 0;
  v_cancelled_bookings integer := 0;
  v_no_show_bookings integer := 0;
  v_unique_customers integer := 0;
  v_arpu numeric := 0;
  v_avg_booking_spend numeric := 0;

  v_top_rooms jsonb;
  v_daily_trend jsonb;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF NOT public.is_super_admin()
     AND NOT public.has_lounge_permission(p_lounge_id, 'analytics_view_lounge')
     AND NOT public.has_lounge_permission(p_lounge_id, 'billing_checkout') THEN
    RAISE EXCEPTION 'Not authorized to view revenue intelligence' USING ERRCODE = '42501';
  END IF;

  -- 1. Gaming Revenue
  SELECT COALESCE(SUM(total_price), 0)
  INTO v_gaming_rev
  FROM public.bookings
  WHERE lounge_id = p_lounge_id
    AND status IN ('completed'::public.booking_status, 'in_progress'::public.booking_status)
    AND payment_status = 'paid'
    AND (created_at BETWEEN p_start_date AND p_end_date OR actual_start_time BETWEEN p_start_date AND p_end_date);

  -- 2. Canteen Revenue
  SELECT COALESCE(SUM(total_price), 0)
  INTO v_canteen_rev
  FROM public.canteen_orders
  WHERE lounge_id = p_lounge_id
    AND status IN ('delivered', 'completed', 'resolved')
    AND created_at BETWEEN p_start_date AND p_end_date;

  -- 3. Packages Revenue
  SELECT COALESCE(SUM(purchased_price), 0)
  INTO v_packages_rev
  FROM public.user_membership_packages
  WHERE lounge_id = p_lounge_id
    AND payment_status = 'completed'
    AND purchased_at BETWEEN p_start_date AND p_end_date;

  -- 4. Deposits Forfeited Revenue
  SELECT COALESCE(SUM(deposit_paid), 0)
  INTO v_deposits_rev
  FROM public.bookings
  WHERE lounge_id = p_lounge_id
    AND is_no_show = true
    AND deposit_status = 'forfeited'
    AND (no_show_at BETWEEN p_start_date AND p_end_date OR updated_at BETWEEN p_start_date AND p_end_date);

  v_total_gross := v_gaming_rev + v_canteen_rev + v_packages_rev + v_deposits_rev;

  -- Cash vs Digital from shift payments
  SELECT
    COALESCE(SUM(CASE WHEN payment_method = 'cash' THEN amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN payment_method <> 'cash' THEN amount ELSE 0 END), 0)
  INTO v_cash_sales, v_digital_sales
  FROM public.shift_payments
  WHERE lounge_id = p_lounge_id
    AND (paid_at BETWEEN p_start_date AND p_end_date OR created_at BETWEEN p_start_date AND p_end_date);

  -- 5. Operational Metrics & Occupancy
  SELECT count(*) INTO v_total_rooms
  FROM public.rooms
  WHERE lounge_id = p_lounge_id AND is_active = true;

  v_operating_days := GREATEST(1, ROUND(EXTRACT(EPOCH FROM (p_end_date - p_start_date)) / 86400.0)::integer);
  -- Assuming average 14 operating hours per day
  v_capacity_hours := v_total_rooms * v_operating_days * 14.0;

  SELECT COALESCE(SUM(
    COALESCE(duration_hours, duration_minutes / 60.0, open_time_billing_minutes / 60.0, 1.0)
  ), 0)
  INTO v_booked_hours
  FROM public.bookings
  WHERE lounge_id = p_lounge_id
    AND status IN ('completed'::public.booking_status, 'in_progress'::public.booking_status)
    AND (created_at BETWEEN p_start_date AND p_end_date OR actual_start_time BETWEEN p_start_date AND p_end_date);

  v_occupancy_rate := CASE WHEN v_capacity_hours > 0 THEN ROUND((v_booked_hours / v_capacity_hours) * 100.0, 2) ELSE 0 END;
  v_idle_lost_hours := GREATEST(0, ROUND(v_capacity_hours - v_booked_hours, 2));

  -- 6. Booking KPIs
  SELECT
    count(*),
    count(*) FILTER (WHERE status = 'completed'::public.booking_status),
    count(*) FILTER (WHERE status = 'cancelled'::public.booking_status AND is_no_show IS FALSE),
    count(*) FILTER (WHERE is_no_show IS TRUE),
    count(DISTINCT user_id)
  INTO
    v_total_bookings,
    v_completed_bookings,
    v_cancelled_bookings,
    v_no_show_bookings,
    v_unique_customers
  FROM public.bookings
  WHERE lounge_id = p_lounge_id
    AND (created_at BETWEEN p_start_date AND p_end_date OR date BETWEEN p_start_date::date AND p_end_date::date);

  v_arpu := CASE WHEN v_unique_customers > 0 THEN ROUND(v_total_gross / v_unique_customers, 2) ELSE 0 END;
  v_avg_booking_spend := CASE WHEN v_completed_bookings > 0 THEN ROUND(v_gaming_rev / v_completed_bookings, 2) ELSE 0 END;

  -- 7. Top Performing Rooms
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'room_id', sub.room_id,
        'room_name', sub.name,
        'total_revenue', sub.room_rev,
        'bookings_count', sub.cnt
      )
    ),
    '[]'::jsonb
  )
  INTO v_top_rooms
  FROM (
    SELECT r.id AS room_id, r.name, COALESCE(SUM(b.total_price), 0) AS room_rev, count(b.id) AS cnt
    FROM public.rooms r
    LEFT JOIN public.bookings b ON b.room_id = r.id
      AND b.status = 'completed'::public.booking_status
      AND (b.created_at BETWEEN p_start_date AND p_end_date)
    WHERE r.lounge_id = p_lounge_id
    GROUP BY r.id, r.name
    ORDER BY room_rev DESC
    LIMIT 5
  ) sub;

  -- 8. Daily Trend (last 14 days or grouped)
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'date', d.day::date,
        'revenue', COALESCE(daily_rev.rev, 0),
        'bookings_count', COALESCE(daily_rev.cnt, 0)
      )
      ORDER BY d.day::date
    ),
    '[]'::jsonb
  )
  INTO v_daily_trend
  FROM generate_series(p_start_date::date, p_end_date::date, '1 day'::interval) d(day)
  LEFT JOIN (
    SELECT b.date::date AS b_day, SUM(b.total_price) AS rev, count(*) AS cnt
    FROM public.bookings b
    WHERE b.lounge_id = p_lounge_id AND b.status = 'completed'::public.booking_status
    GROUP BY b.date::date
  ) daily_rev ON daily_rev.b_day = d.day::date;

  RETURN jsonb_build_object(
    'lounge_id', p_lounge_id,
    'period', jsonb_build_object('start_date', p_start_date, 'end_date', p_end_date),
    'revenue', jsonb_build_object(
      'gaming_revenue', v_gaming_rev,
      'canteen_revenue', v_canteen_rev,
      'packages_revenue', v_packages_rev,
      'deposits_forfeited_revenue', v_deposits_rev,
      'total_gross_revenue', v_total_gross,
      'total_net_revenue', v_total_gross,
      'cash_sales', v_cash_sales,
      'digital_sales', v_digital_sales
    ),
    'operations', jsonb_build_object(
      'total_rooms', v_total_rooms,
      'operating_days', v_operating_days,
      'capacity_hours', v_capacity_hours,
      'booked_hours', ROUND(v_booked_hours, 2),
      'occupancy_rate_pct', v_occupancy_rate,
      'idle_lost_hours', v_idle_lost_hours
    ),
    'kpis', jsonb_build_object(
      'total_bookings', v_total_bookings,
      'completed_bookings', v_completed_bookings,
      'cancelled_bookings', v_cancelled_bookings,
      'no_show_bookings', v_no_show_bookings,
      'cancellation_rate_pct', CASE WHEN v_total_bookings > 0 THEN ROUND((v_cancelled_bookings::numeric / v_total_bookings) * 100.0, 2) ELSE 0 END,
      'no_show_rate_pct', CASE WHEN v_total_bookings > 0 THEN ROUND((v_no_show_bookings::numeric / v_total_bookings) * 100.0, 2) ELSE 0 END,
      'unique_customers', v_unique_customers,
      'arpu', v_arpu,
      'avg_spend_per_booking', v_avg_booking_spend
    ),
    'top_rooms', v_top_rooms,
    'daily_trend', v_daily_trend
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_lounge_revenue_intelligence(uuid, timestamptz, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_lounge_revenue_intelligence(uuid, timestamptz, timestamptz) TO authenticated, service_role;


-- ============================================================================
-- 6. CRM Segmentation, Promotional Win-back Engine & Dispatch Workers
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.user_marketing_preferences (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  allow_promotions boolean NOT NULL DEFAULT true,
  allow_push boolean NOT NULL DEFAULT true,
  allow_sms boolean NOT NULL DEFAULT false,
  opt_out_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.crm_campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lounge_id uuid NOT NULL REFERENCES public.lounges(id) ON DELETE CASCADE,
  title text NOT NULL,
  message_ar text NOT NULL,
  message_en text NOT NULL,
  segment_type text NOT NULL CHECK (segment_type IN ('all', 'vip_loyal', 'churn_risk', 'inactive_30d', 'inactive_60d', 'new_users')),
  promo_code text,
  discount_percent numeric(5,2) DEFAULT NULL,
  target_count integer NOT NULL DEFAULT 0,
  sent_count integer NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'scheduled', 'processing', 'completed', 'cancelled')),
  scheduled_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.crm_dispatches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL REFERENCES public.crm_campaigns(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed', 'skipped_optout')),
  retry_count integer NOT NULL DEFAULT 0,
  error_message text,
  sent_at timestamptz,
  converted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_crm_campaigns_lounge ON public.crm_campaigns(lounge_id, status);
CREATE INDEX IF NOT EXISTS idx_crm_dispatches_pending ON public.crm_dispatches(status, campaign_id);

ALTER TABLE public.user_marketing_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_dispatches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_marketing_pref_policy ON public.user_marketing_preferences;
CREATE POLICY user_marketing_pref_policy ON public.user_marketing_preferences
  FOR ALL TO authenticated
  USING (user_id = auth.uid() OR public.is_super_admin());

DROP POLICY IF EXISTS crm_campaigns_policy ON public.crm_campaigns;
CREATE POLICY crm_campaigns_policy ON public.crm_campaigns
  FOR ALL TO authenticated
  USING (
    public.is_super_admin()
    OR public.has_lounge_permission(lounge_id, 'marketing_manage')
  );

DROP POLICY IF EXISTS crm_dispatches_policy ON public.crm_dispatches;
CREATE POLICY crm_dispatches_policy ON public.crm_dispatches
  FOR ALL TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_super_admin()
    OR EXISTS (
      SELECT 1 FROM public.crm_campaigns c
      WHERE c.id = crm_dispatches.campaign_id
        AND public.has_lounge_permission(c.lounge_id, 'marketing_manage')
    )
  );

CREATE OR REPLACE FUNCTION public.get_lounge_customer_segments(p_lounge_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path TO ''
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_vip_count integer := 0;
  v_churn_count integer := 0;
  v_inactive_60_count integer := 0;
  v_new_count integer := 0;
  v_total_count integer := 0;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF NOT public.is_super_admin()
     AND NOT public.has_lounge_permission(p_lounge_id, 'marketing_manage')
     AND NOT public.has_lounge_permission(p_lounge_id, 'analytics_view_lounge') THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
  END IF;

  WITH user_stats AS (
    SELECT
      b.user_id,
      count(*) AS bookings_count,
      COALESCE(SUM(b.total_price), 0) AS total_spend,
      min(b.created_at) AS first_visit,
      max(b.created_at) AS last_visit
    FROM public.bookings b
    WHERE b.lounge_id = p_lounge_id AND b.user_id IS NOT NULL
    GROUP BY b.user_id
  )
  SELECT
    count(*),
    count(*) FILTER (WHERE bookings_count >= 5 OR total_spend >= 1000),
    count(*) FILTER (WHERE bookings_count >= 2 AND last_visit BETWEEN (now() - interval '60 days') AND (now() - interval '30 days')),
    count(*) FILTER (WHERE last_visit < (now() - interval '60 days')),
    count(*) FILTER (WHERE first_visit >= (now() - interval '14 days'))
  INTO
    v_total_count,
    v_vip_count,
    v_churn_count,
    v_inactive_60_count,
    v_new_count
  FROM user_stats;

  RETURN jsonb_build_object(
    'lounge_id', p_lounge_id,
    'all_customers', v_total_count,
    'vip_loyal', v_vip_count,
    'churn_risk', v_churn_count,
    'inactive_60d', v_inactive_60_count,
    'new_users', v_new_count
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.create_crm_campaign(
  p_lounge_id uuid,
  p_title text,
  p_message_ar text,
  p_message_en text,
  p_segment_type text,
  p_promo_code text DEFAULT NULL,
  p_discount_percent numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_campaign_id uuid;
  v_target_user_id uuid;
  v_count integer := 0;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF NOT public.is_super_admin() AND NOT public.has_lounge_permission(p_lounge_id, 'marketing_manage') THEN
    RAISE EXCEPTION 'Not authorized to create marketing campaigns' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.crm_campaigns (
    lounge_id,
    title,
    message_ar,
    message_en,
    segment_type,
    promo_code,
    discount_percent,
    created_by,
    status
  ) VALUES (
    p_lounge_id,
    p_title,
    p_message_ar,
    p_message_en,
    p_segment_type,
    p_promo_code,
    p_discount_percent,
    v_caller,
    'scheduled'
  )
  RETURNING id INTO v_campaign_id;

  -- Identify segment users
  FOR v_target_user_id IN
    WITH user_stats AS (
      SELECT
        b.user_id,
        count(*) AS bookings_count,
        COALESCE(SUM(b.total_price), 0) AS total_spend,
        min(b.created_at) AS first_visit,
        max(b.created_at) AS last_visit
      FROM public.bookings b
      WHERE b.lounge_id = p_lounge_id AND b.user_id IS NOT NULL
      GROUP BY b.user_id
    )
    SELECT us.user_id
    FROM user_stats us
    LEFT JOIN public.user_marketing_preferences pref ON pref.user_id = us.user_id
    WHERE COALESCE(pref.allow_promotions, true) = true
      AND (
        p_segment_type = 'all'
        OR (p_segment_type = 'vip_loyal' AND (us.bookings_count >= 5 OR us.total_spend >= 1000))
        OR (p_segment_type = 'churn_risk' AND us.bookings_count >= 2 AND us.last_visit BETWEEN (now() - interval '60 days') AND (now() - interval '30 days'))
        OR (p_segment_type = 'inactive_30d' AND us.last_visit < (now() - interval '30 days'))
        OR (p_segment_type = 'inactive_60d' AND us.last_visit < (now() - interval '60 days'))
        OR (p_segment_type = 'new_users' AND us.first_visit >= (now() - interval '14 days'))
      )
  LOOP
    INSERT INTO public.crm_dispatches (campaign_id, user_id, status)
    VALUES (v_campaign_id, v_target_user_id, 'pending');
    v_count := v_count + 1;
  END LOOP;

  UPDATE public.crm_campaigns
  SET target_count = v_count,
      status = CASE WHEN v_count = 0 THEN 'completed' ELSE 'scheduled' END
  WHERE id = v_campaign_id;

  RETURN jsonb_build_object(
    'success', true,
    'campaign_id', v_campaign_id,
    'target_count', v_count
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.process_pending_crm_dispatches(p_batch_size integer DEFAULT 50)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_disp RECORD;
  v_processed integer := 0;
  v_sent integer := 0;
  v_failed integer := 0;
BEGIN
  FOR v_disp IN
    SELECT d.id, d.campaign_id, d.user_id, c.title, c.message_ar, c.message_en, c.promo_code, c.lounge_id
    FROM public.crm_dispatches d
    JOIN public.crm_campaigns c ON c.id = d.campaign_id
    WHERE d.status = 'pending'
    ORDER BY d.created_at ASC
    LIMIT p_batch_size
    FOR UPDATE OF d SKIP LOCKED
  LOOP
    BEGIN
      -- Create in-app notification
      INSERT INTO public.notifications (
        user_id,
        lounge_id,
        title_ar,
        title_en,
        body_ar,
        body_en,
        type,
        is_read,
        metadata
      ) VALUES (
        v_disp.user_id,
        v_disp.lounge_id,
        v_disp.title,
        v_disp.title,
        v_disp.message_ar,
        v_disp.message_en,
        'offer',
        false,
        jsonb_build_object(
          'campaign_id', v_disp.campaign_id,
          'promo_code', v_disp.promo_code
        )
      );

      UPDATE public.crm_dispatches
      SET status = 'sent', sent_at = now()
      WHERE id = v_disp.id;

      UPDATE public.crm_campaigns
      SET sent_count = sent_count + 1
      WHERE id = v_disp.campaign_id;

      v_sent := v_sent + 1;
    EXCEPTION WHEN OTHERS THEN
      UPDATE public.crm_dispatches
      SET status = 'failed', retry_count = retry_count + 1, error_message = SQLERRM
      WHERE id = v_disp.id;
      v_failed := v_failed + 1;
    END;
    v_processed := v_processed + 1;
  END LOOP;

  -- Mark campaigns completed if all dispatches processed
  UPDATE public.crm_campaigns c
  SET status = 'completed', completed_at = now()
  WHERE status IN ('scheduled', 'processing')
    AND NOT EXISTS (
      SELECT 1 FROM public.crm_dispatches d
      WHERE d.campaign_id = c.id AND d.status = 'pending'
    );

  RETURN jsonb_build_object(
    'processed', v_processed,
    'sent', v_sent,
    'failed', v_failed
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_lounge_customer_segments(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_lounge_customer_segments(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.create_crm_campaign(uuid, text, text, text, text, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_crm_campaign(uuid, text, text, text, text, text, numeric) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.process_pending_crm_dispatches(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.process_pending_crm_dispatches(integer) TO authenticated, service_role;


-- ============================================================================
-- 7. Canteen Combos & Upsell Engine
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.canteen_combos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lounge_id uuid NOT NULL REFERENCES public.lounges(id) ON DELETE CASCADE,
  name_ar text NOT NULL,
  name_en text,
  description_ar text,
  description_en text,
  price numeric(10,2) NOT NULL CHECK (price >= 0),
  image_url text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.canteen_combo_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  combo_id uuid NOT NULL REFERENCES public.canteen_combos(id) ON DELETE CASCADE,
  extra_id uuid NOT NULL REFERENCES public.extras(id) ON DELETE CASCADE,
  quantity integer NOT NULL DEFAULT 1 CHECK (quantity > 0),
  CONSTRAINT canteen_combo_items_unique_extra UNIQUE (combo_id, extra_id)
);

CREATE TABLE IF NOT EXISTS public.canteen_upsell_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lounge_id uuid NOT NULL REFERENCES public.lounges(id) ON DELETE CASCADE,
  rule_name text NOT NULL,
  trigger_type text NOT NULL CHECK (trigger_type IN ('active_session', 'checkout', 'duration_threshold')),
  min_duration_hours numeric(4,2) DEFAULT NULL,
  target_type text NOT NULL CHECK (target_type IN ('combo', 'extra')),
  combo_id uuid REFERENCES public.canteen_combos(id) ON DELETE CASCADE,
  extra_id uuid REFERENCES public.extras(id) ON DELETE CASCADE,
  discount_percent numeric(5,2) NOT NULL DEFAULT 0.0 CHECK (discount_percent >= 0 AND discount_percent <= 100),
  priority integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.canteen_upsell_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_id uuid REFERENCES public.canteen_upsell_rules(id) ON DELETE SET NULL,
  booking_id uuid REFERENCES public.bookings(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  event_type text NOT NULL CHECK (event_type IN ('impression', 'dismiss', 'accept', 'converted')),
  canteen_order_id uuid REFERENCES public.canteen_orders(id) ON DELETE SET NULL,
  amount numeric(10,2) DEFAULT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_canteen_combos_lounge ON public.canteen_combos(lounge_id, is_active);
CREATE INDEX IF NOT EXISTS idx_canteen_combo_items_combo ON public.canteen_combo_items(combo_id);
CREATE INDEX IF NOT EXISTS idx_canteen_upsell_rules_lounge ON public.canteen_upsell_rules(lounge_id, is_active);

ALTER TABLE public.canteen_combos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.canteen_combo_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.canteen_upsell_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.canteen_upsell_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS canteen_combos_select_policy ON public.canteen_combos;
CREATE POLICY canteen_combos_select_policy ON public.canteen_combos
  FOR SELECT TO authenticated, anon
  USING (true);

DROP POLICY IF EXISTS canteen_combos_manage_policy ON public.canteen_combos;
CREATE POLICY canteen_combos_manage_policy ON public.canteen_combos
  FOR ALL TO authenticated
  USING (
    public.is_super_admin()
    OR public.has_lounge_permission(lounge_id, 'menu_manage_items')
  );

DROP POLICY IF EXISTS canteen_combo_items_select_policy ON public.canteen_combo_items;
CREATE POLICY canteen_combo_items_select_policy ON public.canteen_combo_items
  FOR SELECT TO authenticated, anon
  USING (true);

DROP POLICY IF EXISTS canteen_upsell_rules_select_policy ON public.canteen_upsell_rules;
CREATE POLICY canteen_upsell_rules_select_policy ON public.canteen_upsell_rules
  FOR SELECT TO authenticated, anon
  USING (true);

DROP POLICY IF EXISTS canteen_upsell_events_policy ON public.canteen_upsell_events;
CREATE POLICY canteen_upsell_events_policy ON public.canteen_upsell_events
  FOR ALL TO authenticated
  USING (true);

-- RPC: get_canteen_menu (Matches Flutter CanteenMenuData & CanteenComboModel)
CREATE OR REPLACE FUNCTION public.get_canteen_menu(p_lounge_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path TO ''
AS $$
DECLARE
  v_extras jsonb;
  v_combos jsonb;
BEGIN
  -- Extras
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', e.id,
        'lounge_id', e.lounge_id,
        'name', e.name,
        'name_ar', e.name_ar,
        'name_en', e.name_en,
        'price', e.price,
        'category', e.category,
        'icon', e.icon,
        'icon_key', e.icon_key,
        'image_url', e.image_url,
        'is_available', (COALESCE(e.is_available, true) AND (COALESCE(e.track_stock, false) IS FALSE OR COALESCE(e.stock_quantity, 0) > 0)),
        'stock_quantity', e.stock_quantity,
        'track_stock', e.track_stock
      )
    ),
    '[]'::jsonb
  )
  INTO v_extras
  FROM public.extras e
  WHERE e.lounge_id = p_lounge_id
    AND COALESCE(e.is_active, true) = true;

  -- Combos with constituent items & savings calculation
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', c.id,
        'name_ar', c.name_ar,
        'name_en', c.name_en,
        'description_ar', c.description_ar,
        'description_en', c.description_en,
        'price', c.price,
        'separate_items_price', COALESCE(ci.items_price, c.price),
        'savings', GREATEST(0, COALESCE(ci.items_price, c.price) - c.price),
        'image_url', c.image_url,
        'is_available', (c.is_active AND COALESCE(ci.all_in_stock, true)),
        'items', COALESCE(ci.items_list, '[]'::jsonb)
      )
    ),
    '[]'::jsonb
  )
  INTO v_combos
  FROM public.canteen_combos c
  LEFT JOIN (
    SELECT
      cci.combo_id,
      SUM(e.price * cci.quantity) AS items_price,
      bool_and(COALESCE(e.track_stock, false) IS FALSE OR COALESCE(e.stock_quantity, 0) >= cci.quantity) AS all_in_stock,
      jsonb_agg(
        jsonb_build_object(
          'extra_id', e.id,
          'name_ar', e.name_ar,
          'name_en', e.name_en,
          'price', e.price,
          'quantity', cci.quantity
        )
      ) AS items_list
    FROM public.canteen_combo_items cci
    JOIN public.extras e ON e.id = cci.extra_id
    GROUP BY cci.combo_id
  ) ci ON ci.combo_id = c.id
  WHERE c.lounge_id = p_lounge_id AND c.is_active = true;

  RETURN jsonb_build_object(
    'extras', v_extras,
    'combos', v_combos
  );
END;
$$;

-- RPC: get_upsell_suggestions (Matches Flutter UpsellSuggestionModel)
CREATE OR REPLACE FUNCTION public.get_upsell_suggestions(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path TO ''
AS $$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_res jsonb;
BEGIN
  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
  IF NOT FOUND THEN
    RETURN '[]'::jsonb;
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'rule_id', r.id,
        'suggestion_type', r.target_type,
        'target_id', COALESCE(r.combo_id, r.extra_id),
        'name_ar', COALESCE(c.name_ar, e.name_ar, ''),
        'name_en', COALESCE(c.name_en, e.name_en),
        'original_price', COALESCE(c.price, e.price, 0),
        'discount_percent', r.discount_percent,
        'final_price', ROUND(COALESCE(c.price, e.price, 0) * (1.0 - (r.discount_percent / 100.0)), 2),
        'image_url', COALESCE(c.image_url, e.image_url)
      )
      ORDER BY r.priority DESC, r.created_at ASC
    ),
    '[]'::jsonb
  )
  INTO v_res
  FROM public.canteen_upsell_rules r
  LEFT JOIN public.canteen_combos c ON c.id = r.combo_id AND c.is_active = true
  LEFT JOIN public.extras e ON e.id = r.extra_id AND COALESCE(e.is_active, true) = true
  WHERE r.lounge_id = v_booking.lounge_id
    AND r.is_active = true
    AND (r.combo_id IS NOT NULL OR r.extra_id IS NOT NULL);

  RETURN v_res;
END;
$$;

-- RPC: record_upsell_event
CREATE OR REPLACE FUNCTION public.record_upsell_event(
  p_rule_id uuid,
  p_booking_id uuid,
  p_event text,
  p_canteen_order_id uuid DEFAULT NULL,
  p_amount numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  INSERT INTO public.canteen_upsell_events (
    rule_id,
    booking_id,
    user_id,
    event_type,
    canteen_order_id,
    amount
  ) VALUES (
    p_rule_id,
    p_booking_id,
    auth.uid(),
    p_event,
    p_canteen_order_id,
    p_amount
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

-- RPC: place_canteen_order (Full atomic ordering with stock checking & shift association)
CREATE OR REPLACE FUNCTION public.place_canteen_order(
  p_booking_id uuid,
  p_items jsonb,
  p_lounge_id uuid DEFAULT NULL,
  p_user_id uuid DEFAULT NULL,
  p_total_price numeric DEFAULT NULL,
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_booking public.bookings%ROWTYPE;
  v_lounge_id uuid;
  v_user_id uuid;
  v_shift_id uuid;
  v_order_id uuid;
  v_item jsonb;
  v_extra_id uuid;
  v_combo_id uuid;
  v_qty integer;
  v_unit_price numeric;
  v_item_total numeric;
  v_calculated_total numeric := 0;
  v_extra public.extras%ROWTYPE;
  v_combo public.canteen_combos%ROWTYPE;
  v_comp RECORD;
  v_item_name text;
BEGIN
  IF v_caller IS NULL AND p_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF p_booking_id IS NOT NULL THEN
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR SHARE;
    IF FOUND THEN
      v_lounge_id := v_booking.lounge_id;
      v_user_id := COALESCE(v_caller, p_user_id, v_booking.user_id);
    END IF;
  END IF;

  v_lounge_id := COALESCE(v_lounge_id, p_lounge_id);
  v_user_id := COALESCE(v_caller, p_user_id);

  IF v_lounge_id IS NULL THEN
    RAISE EXCEPTION 'Lounge ID must be provided' USING ERRCODE = '22023';
  END IF;

  -- Find active shift for this lounge
  SELECT s.id INTO v_shift_id
  FROM public.shifts s
  WHERE s.lounge_id = v_lounge_id
    AND s.status = 'open'
    AND s.closed_at IS NULL
  ORDER BY s.opened_at DESC
  LIMIT 1;

  -- Create order header
  INSERT INTO public.canteen_orders (
    booking_id,
    lounge_id,
    user_id,
    items,
    total_price,
    note,
    status,
    shift_id,
    created_at
  ) VALUES (
    p_booking_id,
    v_lounge_id,
    v_user_id,
    p_items,
    0, -- Will update with authoritative calculated total
    p_note,
    'pending',
    v_shift_id,
    now()
  )
  RETURNING id INTO v_order_id;

  -- Process line items & verify/decrement stock
  FOR v_item IN SELECT * FROM jsonb_array_elements(COALESCE(p_items, '[]'::jsonb))
  LOOP
    v_extra_id := NULLIF(COALESCE(v_item->>'extra_id', v_item->>'product_id', v_item->>'id'), '')::uuid;
    v_combo_id := NULLIF(COALESCE(v_item->>'combo_id', ''), '')::uuid;
    v_qty := GREATEST(1, COALESCE((v_item->>'quantity')::integer, 1));

    -- 1. Check if item is a Combo
    IF v_combo_id IS NOT NULL OR (v_extra_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.canteen_combos WHERE id = v_extra_id)) THEN
      v_combo_id := COALESCE(v_combo_id, v_extra_id);
      
      SELECT * INTO v_combo FROM public.canteen_combos WHERE id = v_combo_id AND is_active = true;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'Combo not found or inactive: %', v_combo_id USING ERRCODE = 'P0002';
      END IF;

      -- Check and decrement constituent extras stock
      FOR v_comp IN
        SELECT cci.extra_id, cci.quantity AS comp_qty, e.name_ar, e.track_stock, e.stock_quantity
        FROM public.canteen_combo_items cci
        JOIN public.extras e ON e.id = cci.extra_id
        WHERE cci.combo_id = v_combo.id
        FOR UPDATE OF e
      LOOP
        IF COALESCE(v_comp.track_stock, false) IS TRUE THEN
          IF COALESCE(v_comp.stock_quantity, 0) < (v_comp.comp_qty * v_qty) THEN
            RAISE EXCEPTION 'OUT_OF_STOCK: Combo item % is out of stock', v_comp.name_ar USING ERRCODE = '55000';
          END IF;

          UPDATE public.extras
          SET stock_quantity = stock_quantity - (v_comp.comp_qty * v_qty)
          WHERE id = v_comp.extra_id;
        END IF;
      END LOOP;

      v_unit_price := v_combo.price;
      v_item_total := v_unit_price * v_qty;
      v_calculated_total := v_calculated_total + v_item_total;
      v_item_name := v_combo.name_ar;

      INSERT INTO public.canteen_order_items (
        order_id,
        extra_id,
        quantity,
        unit_price,
        total_price,
        item_name
      ) VALUES (
        v_order_id,
        NULL,
        v_qty,
        v_unit_price,
        v_item_total,
        v_item_name
      );

    -- 2. Regular Extra Item
    ELSIF v_extra_id IS NOT NULL THEN
      SELECT * INTO v_extra FROM public.extras WHERE id = v_extra_id FOR UPDATE;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'Item not found: %', v_extra_id USING ERRCODE = 'P0002';
      END IF;

      IF COALESCE(v_extra.track_stock, false) IS TRUE THEN
        IF COALESCE(v_extra.stock_quantity, 0) < v_qty THEN
          RAISE EXCEPTION 'OUT_OF_STOCK: Item % is out of stock', v_extra.name_ar USING ERRCODE = '55000';
        END IF;

        UPDATE public.extras
        SET stock_quantity = stock_quantity - v_qty
        WHERE id = v_extra.id;
      END IF;

      v_unit_price := v_extra.price;
      v_item_total := v_unit_price * v_qty;
      v_calculated_total := v_calculated_total + v_item_total;
      v_item_name := v_extra.name_ar;

      INSERT INTO public.canteen_order_items (
        order_id,
        extra_id,
        quantity,
        unit_price,
        total_price,
        item_name
      ) VALUES (
        v_order_id,
        v_extra.id,
        v_qty,
        v_unit_price,
        v_item_total,
        v_item_name
      );
    END IF;
  END LOOP;

  -- Update order header with verified total
  UPDATE public.canteen_orders
  SET total_price = v_calculated_total
  WHERE id = v_order_id;

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'booking_id', p_booking_id,
    'lounge_id', v_lounge_id,
    'total_price', v_calculated_total,
    'shift_id', v_shift_id,
    'status', 'pending'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_canteen_menu(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_canteen_menu(uuid) TO authenticated, anon, service_role;

REVOKE ALL ON FUNCTION public.get_upsell_suggestions(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_upsell_suggestions(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.record_upsell_event(uuid, uuid, text, uuid, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_upsell_event(uuid, uuid, text, uuid, numeric) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.place_canteen_order(uuid, jsonb, uuid, uuid, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.place_canteen_order(uuid, jsonb, uuid, uuid, numeric, text) TO authenticated, service_role;
