-- Read-only catalog snapshot, 2026-10-01; exercised only in disposable local fixtures.
CREATE OR REPLACE FUNCTION public.fn_validate_and_clamp_booking_price()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actual_hourly_rate numeric := 0;
  v_extra_controller_rate numeric := 0;
  v_addons numeric := 0;
  v_subtotal numeric := 0;
  v_discount numeric := 0;
  v_snap jsonb;
BEGIN
  -- If this is an Open Time session in progress, do not clamp or fail on duration
  IF COALESCE(NEW.is_open_time, false) IS TRUE AND NEW.status = 'in_progress'::public.booking_status THEN
    NEW.duration_minutes := GREATEST(1, COALESCE(NEW.duration_minutes, 1));
    RETURN NEW;
  END IF;

  -- For standard bookings or completed sessions, validate duration
  IF COALESCE(NEW.duration_minutes, 0) <= 0 OR NEW.duration_minutes > 1440 THEN
    RAISE EXCEPTION 'Invalid booking duration: % minutes. Duration must be between 1 and 1440 minutes.',
      NEW.duration_minutes USING ERRCODE = '22023';
  END IF;

  IF NEW.room_id IS NULL THEN
    RAISE EXCEPTION 'Cannot validate booking price: room_id is required.' USING ERRCODE = '22023';
  END IF;

  -- If an Open Time session is completed with a pricing snapshot, honor the snapshot!
  IF COALESCE(NEW.is_open_time, false) IS TRUE AND NEW.open_time_pricing_snapshot IS NOT NULL AND NEW.open_time_pricing_snapshot <> '{}'::jsonb THEN
    v_snap := NEW.open_time_pricing_snapshot;
    v_actual_hourly_rate := COALESCE((v_snap->>'effective_hourly_rate')::numeric, (v_snap->>'base_hourly_rate')::numeric, 50);
  ELSE
    SELECT
      COALESCE(
        CASE
          WHEN NEW.play_mode = 'multi' AND COALESCE(r.hourly_rate_multi, 0) > 0 THEN r.hourly_rate_multi
          ELSE r.hourly_rate_single
        END,
        0
      ),
      GREATEST(0, COALESCE(NEW.extra_controllers, 0)) * COALESCE(r.extra_controller_price, 0)
    INTO
      v_actual_hourly_rate,
      v_extra_controller_rate
    FROM public.rooms r
    WHERE r.id = NEW.room_id;

    IF v_actual_hourly_rate <= 0 THEN
      RAISE EXCEPTION 'Cannot validate booking price: room % has no valid rate configured.', NEW.room_id
        USING ERRCODE = '23514';
    END IF;
  END IF;

  -- Compute room price
  IF COALESCE(NEW.is_open_time, false) IS FALSE OR NEW.status = 'completed'::public.booking_status THEN
    NEW.room_price := ROUND((NEW.duration_minutes / 60.0) * (v_actual_hourly_rate + v_extra_controller_rate), 2);
  END IF;

  v_addons := GREATEST(0, COALESCE(NEW.addons_price, NEW.addons_total, 0));
  NEW.addons_price := v_addons;
  NEW.addons_total := v_addons;

  v_subtotal := NEW.room_price + v_addons;

  IF COALESCE(NEW.discount_amount, 0) > 0 THEN
    v_discount := LEAST(v_subtotal, NEW.discount_amount);
  ELSIF COALESCE(NEW.discount_percentage, 0) > 0 THEN
    v_discount := LEAST(v_subtotal, v_subtotal * (NEW.discount_percentage / 100.0));
  ELSE
    v_discount := 0;
  END IF;

  NEW.discount_amount := v_discount;
  NEW.total_price := GREATEST(0, v_subtotal - v_discount);

  RETURN NEW;
END;
$function$;
CREATE TRIGGER trg_validate_and_clamp_booking_price BEFORE INSERT OR UPDATE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.fn_validate_and_clamp_booking_price();
