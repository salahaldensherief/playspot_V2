-- Migration: 20260331000001_checkout_voucher_pricing.sql
-- Description: RPC functions for validating vouchers and checking booking pricing server-side,
-- accounting for staff manual discounts and offline custom lounge offers.

DROP FUNCTION IF EXISTS public.validate_voucher_by_code(text);
DROP FUNCTION IF EXISTS public.consume_voucher_by_code(text, uuid);
DROP FUNCTION IF EXISTS public.calculate_booking_total(uuid, numeric, text, numeric, text);

-- 1. Function to validate voucher by code for current user
CREATE OR REPLACE FUNCTION public.validate_voucher_by_code(p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_voucher record;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('valid', false, 'error', 'Unauthenticated user');
  END IF;

  SELECT * INTO v_voucher
  FROM public.user_vouchers
  WHERE UPPER(TRIM(code)) = UPPER(TRIM(p_code))
    AND user_id = v_user_id
    AND is_used = false
    AND (expires_at IS NULL OR expires_at > NOW())
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('valid', false, 'error', 'Voucher is invalid, expired, or already used');
  END IF;

  RETURN jsonb_build_object(
    'valid', true,
    'voucher_id', v_voucher.id,
    'code', v_voucher.code,
    'reward_type', v_voucher.reward_type,
    'reward_value', v_voucher.reward_value,
    'min_spend', COALESCE(v_voucher.min_spend, 0)
  );
END;
$$;

-- 2. Function to consume voucher upon booking creation
CREATE OR REPLACE FUNCTION public.consume_voucher_by_code(p_code text, p_booking_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user';
  END IF;

  UPDATE public.user_vouchers
  SET is_used = true,
      used_at = NOW(),
      used_in_booking_id = p_booking_id
  WHERE UPPER(TRIM(code)) = UPPER(TRIM(p_code))
    AND user_id = v_user_id
    AND is_used = false;

  RETURN FOUND;
END;
$$;

-- 3. Function to calculate and verify booking total, allowing staff manual discounts and custom offline offers
CREATE OR REPLACE FUNCTION public.calculate_booking_total(
  p_room_id uuid,
  p_duration_hours numeric,
  p_voucher_code text DEFAULT NULL,
  p_manual_discount numeric DEFAULT 0,
  p_manual_discount_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_room record;
  v_base_subtotal numeric;
  v_voucher_discount numeric := 0;
  v_staff_discount numeric := COALESCE(p_manual_discount, 0);
  v_final_total numeric;
  v_voucher_res jsonb;
BEGIN
  SELECT * INTO v_room
  FROM public.rooms
  WHERE id = p_room_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Room not found';
  END IF;

  v_base_subtotal := COALESCE(v_room.hourly_rate_single, 0) * p_duration_hours;

  -- Apply voucher discount if valid code is supplied
  IF p_voucher_code IS NOT NULL AND TRIM(p_voucher_code) <> '' THEN
    v_voucher_res := public.validate_voucher_by_code(p_voucher_code);
    IF (v_voucher_res->>'valid')::boolean THEN
      IF (v_voucher_res->>'reward_type') = 'discount_fixed' THEN
        v_voucher_discount := (v_voucher_res->>'reward_value')::numeric;
      ELSIF (v_voucher_res->>'reward_type') = 'free_hour' THEN
        v_voucher_discount := COALESCE(v_room.hourly_rate_single, 0) * (v_voucher_res->>'reward_value')::numeric;
      END IF;
    END IF;
  END IF;

  -- Total price calculation respects both voucher discount and staff manual discount/offline offer
  v_final_total := GREATEST(0, v_base_subtotal - v_voucher_discount - v_staff_discount);

  RETURN jsonb_build_object(
    'base_subtotal', v_base_subtotal,
    'voucher_discount', v_voucher_discount,
    'staff_manual_discount', v_staff_discount,
    'manual_discount_reason', p_manual_discount_reason,
    'final_total', v_final_total
  );
END;
$$;
