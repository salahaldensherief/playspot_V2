-- Migration: 20260331000004_validate_mobile_booking_price.sql
-- Description: Server-side price validation trigger and RPC fix for mobile bookings (zero-client trust pricing).

-- 1. Fix calculate_booking_total RPC to include extras/add-ons in subtotal calculations
CREATE OR REPLACE FUNCTION public.calculate_booking_total(
  p_room_id uuid,
  p_duration_hours numeric,
  p_voucher_code text DEFAULT NULL,
  p_manual_discount numeric DEFAULT 0,
  p_manual_discount_reason text DEFAULT NULL,
  p_play_mode text DEFAULT 'single',
  p_extras jsonb DEFAULT '[]'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_room record;
  v_hourly_rate numeric;
  v_room_subtotal numeric;
  v_extras_subtotal numeric := 0;
  v_base_subtotal numeric;
  v_voucher_discount numeric := 0;
  v_staff_discount numeric := COALESCE(p_manual_discount, 0);
  v_final_total numeric;
  v_voucher_res jsonb;
  v_extra_item jsonb;
  v_item_price numeric;
  v_item_qty integer;
BEGIN
  SELECT * INTO v_room
  FROM public.rooms
  WHERE id = p_room_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Room not found';
  END IF;

  -- Determine hourly rate based on play mode
  IF LOWER(COALESCE(p_play_mode, 'single')) = 'multi' AND v_room.hourly_rate_multi IS NOT NULL AND v_room.hourly_rate_multi > 0 THEN
    v_hourly_rate := v_room.hourly_rate_multi;
  ELSE
    v_hourly_rate := COALESCE(v_room.hourly_rate_single, 0);
  END IF;

  v_room_subtotal := v_hourly_rate * p_duration_hours;

  -- Sum extras / add-ons prices from submitted JSONB array
  IF p_extras IS NOT NULL AND jsonb_array_length(p_extras) > 0 THEN
    FOR v_extra_item IN SELECT * FROM jsonb_array_elements(p_extras)
    LOOP
      v_item_price := COALESCE((v_extra_item->>'unit_price')::numeric, (v_extra_item->>'price')::numeric, 0);
      v_item_qty := COALESCE((v_extra_item->>'quantity')::integer, 1);
      v_extras_subtotal := v_extras_subtotal + (v_item_price * v_item_qty);
    END LOOP;
  END IF;

  v_base_subtotal := v_room_subtotal + v_extras_subtotal;

  -- Apply voucher discount if valid code is supplied
  IF p_voucher_code IS NOT NULL AND TRIM(p_voucher_code) <> '' THEN
    v_voucher_res := public.validate_voucher_by_code(p_voucher_code);
    IF (v_voucher_res->>'valid')::boolean THEN
      IF (v_voucher_res->>'reward_type') = 'discount_fixed' THEN
        v_voucher_discount := (v_voucher_res->>'reward_value')::numeric;
      ELSIF (v_voucher_res->>'reward_type') = 'free_hour' THEN
        v_voucher_discount := v_hourly_rate * (v_voucher_res->>'reward_value')::numeric;
      END IF;
    END IF;
  END IF;

  -- Clamp discounts so they do not exceed subtotal
  v_voucher_discount := LEAST(v_voucher_discount, v_base_subtotal);
  v_staff_discount := LEAST(v_staff_discount, GREATEST(0, v_base_subtotal - v_voucher_discount));

  v_final_total := GREATEST(0, v_base_subtotal - v_voucher_discount - v_staff_discount);

  RETURN jsonb_build_object(
    'room_subtotal', v_room_subtotal,
    'extras_subtotal', v_extras_subtotal,
    'base_subtotal', v_base_subtotal,
    'voucher_discount', v_voucher_discount,
    'staff_manual_discount', v_staff_discount,
    'manual_discount_reason', p_manual_discount_reason,
    'final_total', v_final_total
  );
END;
$$;


-- 2. Trigger function to validate and clamp mobile booking price on BEFORE INSERT OR UPDATE
CREATE OR REPLACE FUNCTION public.fn_validate_and_clamp_mobile_booking_price()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_room record;
  v_hourly_rate numeric;
  v_duration_hrs numeric;
  v_computed_room_price numeric;
  v_addons_total numeric := 0;
  v_extras_jsonb jsonb;
  v_extra_item jsonb;
  v_item_price numeric;
  v_item_qty integer;
  v_discount numeric;
  v_computed_total numeric;
  v_needs_recalculation boolean := false;
BEGIN
  -- Determine if pricing recalculation is required
  IF TG_OP = 'INSERT' THEN
    v_needs_recalculation := true;
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.room_id IS DISTINCT FROM OLD.room_id
       OR NEW.duration_minutes IS DISTINCT FROM OLD.duration_minutes
       OR NEW.duration_hours IS DISTINCT FROM OLD.duration_hours
       OR NEW.play_mode IS DISTINCT FROM OLD.play_mode
       OR NEW.extras IS DISTINCT FROM OLD.extras
       OR NEW.add_ons IS DISTINCT FROM OLD.add_ons
       OR NEW.discount_amount IS DISTINCT FROM OLD.discount_amount THEN
      v_needs_recalculation := true;
    END IF;
  END IF;

  -- Preserves historical total_price on unrelated updates (e.g. status/payment updates)
  IF NOT v_needs_recalculation THEN
    RETURN NEW;
  END IF;

  -- Fetch target room
  SELECT * INTO v_room
  FROM public.rooms
  WHERE id = NEW.room_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invalid room_id: Room not found';
  END IF;

  -- Select hourly rate based on play mode (single vs multi)
  IF LOWER(COALESCE(NEW.play_mode, 'single')) = 'multi' AND v_room.hourly_rate_multi IS NOT NULL AND v_room.hourly_rate_multi > 0 THEN
    v_hourly_rate := v_room.hourly_rate_multi;
  ELSE
    v_hourly_rate := COALESCE(v_room.hourly_rate_single, 0);
  END IF;

  IF v_hourly_rate <= 0 THEN
    RAISE EXCEPTION 'Room hourly rate is zero or unconfigured for room %', NEW.room_id;
  END IF;

  -- Resolve duration in hours
  IF NEW.duration_hours IS NOT NULL AND NEW.duration_hours > 0 THEN
    v_duration_hrs := NEW.duration_hours;
  ELSIF NEW.duration_minutes IS NOT NULL AND NEW.duration_minutes > 0 THEN
    v_duration_hrs := NEW.duration_minutes / 60.0;
  ELSE
    v_duration_hrs := 1.0;
  END IF;

  v_computed_room_price := v_hourly_rate * v_duration_hrs;

  -- Recompute addons_total strictly from submitted items JSONB array (extras or add_ons column)
  v_extras_jsonb := COALESCE(NEW.extras, NEW.add_ons, '[]'::jsonb);

  IF v_extras_jsonb IS NOT NULL AND jsonb_typeof(v_extras_jsonb) = 'array' AND jsonb_array_length(v_extras_jsonb) > 0 THEN
    FOR v_extra_item IN SELECT * FROM jsonb_array_elements(v_extras_jsonb)
    LOOP
      v_item_price := COALESCE((v_extra_item->>'unit_price')::numeric, (v_extra_item->>'price')::numeric, 0);
      v_item_qty := COALESCE((v_extra_item->>'quantity')::integer, 1);
      v_addons_total := v_addons_total + (v_item_price * v_item_qty);
    END LOOP;
  ELSE
    v_addons_total := 0;
  END IF;

  -- Clamp discount so total price is non-negative
  v_discount := GREATEST(0, COALESCE(NEW.discount_amount, 0));
  v_discount := LEAST(v_discount, v_computed_room_price + v_addons_total);

  v_computed_total := GREATEST(0, (v_computed_room_price + v_addons_total) - v_discount);

  -- Enforce computed prices on the row
  NEW.discounted_room_price := v_computed_room_price;
  NEW.room_price := v_computed_room_price;
  NEW.room_subtotal := v_computed_room_price;
  NEW.addons_total := v_addons_total;
  NEW.discount_amount := v_discount;
  NEW.total_price := v_computed_total;

  RETURN NEW;
END;
$$;

-- Attach trigger to public.bookings
DROP TRIGGER IF EXISTS trg_validate_mobile_booking_price ON public.bookings;

CREATE TRIGGER trg_validate_mobile_booking_price
BEFORE INSERT OR UPDATE ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION public.fn_validate_and_clamp_mobile_booking_price();
