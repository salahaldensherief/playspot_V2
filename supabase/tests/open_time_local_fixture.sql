-- LOCAL TEST DATABASE ONLY. Do not run against Supabase or existing databases.
-- Mirrors relevant live columns and three payment/price triggers; auth is mocked.
CREATE SCHEMA auth;
CREATE SCHEMA private;
CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE ROLE service_role;
CREATE TYPE public.booking_status AS ENUM ('pending','upcoming','in_progress','completed','cancelled','rejected');
CREATE TABLE public.bookings (id uuid, user_id uuid, room_id uuid, lounge_id uuid, date date, start_time time without time zone, end_time time without time zone, room_price numeric(12,2), addons_price numeric(12,2), total_price numeric(12,2), status booking_status, qr_code text, created_at timestamp with time zone, user_name text, user_phone text, room_name text, booking_period tsrange, duration_hours numeric, play_mode text, extra_controllers integer, payment_status text, shift_id uuid, duration_minutes integer, payment_method text, discount_amount numeric(12,2), discount_percentage numeric, discount_reason text, discount_approved_by uuid, actual_start_time timestamp with time zone, updated_at timestamp with time zone, extension_status text, requested_extension_minutes integer, start_at time without time zone, end_at time without time zone, receipt_url text, expires_at timestamp with time zone, sender_wallet_phone text, is_first_booking boolean, checked_in_at timestamp with time zone, cancellation_reason text, addons_total numeric, approved_at timestamp with time zone, approved_by uuid, cancelled_at timestamp with time zone, cancelled_by uuid, is_open_time boolean, open_time_started_at timestamp with time zone, open_time_closed_at timestamp with time zone, open_time_billing_minutes integer);
CREATE TABLE public.lounges (id uuid, owner_id uuid, name text, image_url text, images text[], location text, city text, maps_link text, rating numeric, total_reviews integer, available_rooms integer, is_open boolean, status text, created_at timestamp with time zone, location_point text, description_ar text, description_en text, address text, contact_phone text, opening_time time without time zone, closing_time time without time zone, is_active boolean, has_discount boolean, discount_percentage integer, discount_title_ar text, discount_title_en text, discount_expires_at timestamp with time zone, name_ar text, name_en text, city_id uuid, vodafone_cash_number text, instapay_account text, allow_cash_payment boolean, require_prepaid_first_time boolean, cash_grace_period_minutes integer, wallet_number text, instapay_handle text, suspension_reason text, brand_id uuid, branch_name character varying(255), is_main_branch boolean, parent_lounge_id uuid, allow_open_time_sessions boolean, open_time_rounding_minutes integer, open_time_minimum_minutes integer, open_time_max_minutes integer);
CREATE TABLE public.payments (id uuid, booking_id uuid, user_id uuid, lounge_id uuid, amount numeric(12,2), commission numeric, net_to_lounge numeric, payment_method text, status text, paid_at timestamp with time zone, payout_id uuid, discount_amount numeric, discount_percentage numeric, discount_reason text, discount_approved_by uuid, commission_rate numeric);
CREATE TABLE public.profiles (id uuid, lounge_id uuid, role text, full_name text, phone text, email text, is_active boolean, created_at timestamp with time zone, updated_at timestamp with time zone, avatar_url text, is_setup_completed boolean, fcm_token text, referral_code text, referred_by uuid, points integer, is_banned boolean, city_id uuid, latitude double precision, longitude double precision, completed_bookings_count integer, banned_reason text, notification_preferences jsonb);
CREATE TABLE public.rooms (id uuid, lounge_id uuid, name text, photo_url text, images text[], features text[], is_available boolean, controllers_count integer, screen_size text, status text, created_at timestamp with time zone, name_ar text, name_en text, features_ar text[], features_en text[], description_ar text, description_en text, extra_controller_price numeric, device_type text, room_type text, hourly_rate_single numeric, hourly_rate_multi numeric, max_capacity integer, description text, is_active boolean, updated_at timestamp with time zone, hourly_rate numeric, space_type_id uuid, control_type text, relay_channel integer, relay_ip character varying, relay_mac character varying);
CREATE TABLE public.shift_payments (id uuid, shift_id uuid, lounge_id uuid, booking_id uuid, payment_method text, category text, amount numeric, paid_at timestamp with time zone, created_at timestamp with time zone, canteen_order_id uuid);
CREATE TABLE public.shifts (id uuid, lounge_id uuid, staff_user_id uuid, opened_at timestamp with time zone, closed_at timestamp with time zone, status text, starting_cash numeric, expected_cash numeric, actual_cash_counted numeric, notes text, created_at timestamp with time zone, cashier_id uuid, start_time timestamp with time zone, end_time timestamp with time zone, difference numeric(10,2), total_cash_sales numeric(10,2), total_digital_sales numeric(10,2), total_expenses numeric(10,2), payment_method text, is_approved boolean, approved_by uuid, approved_at timestamp with time zone, manager_notes text);
ALTER TABLE public.bookings ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.payments ADD UNIQUE(booking_id);
CREATE TABLE public.lounge_staff(user_id uuid,lounge_id uuid);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$ SELECT nullif(current_setting('test.actor',true),'')::uuid $$;
CREATE FUNCTION public.is_super_admin() RETURNS boolean LANGUAGE sql AS $$ SELECT false $$;
CREATE FUNCTION public.has_lounge_permission(uuid,text) RETURNS boolean LANGUAGE sql AS $$ SELECT coalesce(current_setting('test.allowed',true),'false')::boolean $$;
CREATE FUNCTION private.is_lounge_member(uuid) RETURNS boolean LANGUAGE sql AS $$ SELECT coalesce(current_setting('test.allowed',true),'false')::boolean $$;
CREATE OR REPLACE FUNCTION public.enforce_cash_booking_approval()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
DECLARE
  v_authorized boolean := false;
BEGIN
  -- Cash bookings always start as pending and unpaid.
  IF TG_OP = 'INSERT' AND NEW.payment_method = 'cash' THEN
    NEW.status := 'pending'::public.booking_status;
    NEW.payment_status := 'unpaid';
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE'
     AND (NEW.payment_method = 'cash' OR OLD.payment_method = 'cash')
     AND (
       NEW.payment_status = 'paid'
       OR NEW.status IN ('upcoming'::public.booking_status, 'in_progress'::public.booking_status, 'completed'::public.booking_status)
     )
     AND (
       OLD.payment_status IS DISTINCT FROM NEW.payment_status
       OR OLD.status IS DISTINCT FROM NEW.status
       OR OLD.payment_method IS DISTINCT FROM NEW.payment_method
     ) THEN

    SELECT EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND p.is_active = true
        AND (
          p.role = 'super_admin'
          OR (p.lounge_id = NEW.lounge_id AND p.role IN ('owner', 'manager', 'lounge_admin', 'admin', 'cashier'))
        )
    )
    OR EXISTS (
      SELECT 1
      FROM public.lounge_staff ls
      WHERE ls.user_id = (SELECT auth.uid())
        AND ls.lounge_id = NEW.lounge_id
    )
    INTO v_authorized;

    IF NOT v_authorized
       AND current_user NOT IN ('postgres', 'service_role', 'supabase_admin') THEN
      RAISE EXCEPTION 'CASH_BOOKING_APPROVAL_REQUIRED'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END;
$function$
;
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
BEGIN
  IF COALESCE(NEW.duration_minutes, 0) <= 0
     OR NEW.duration_minutes > 1440 THEN
    RAISE EXCEPTION
      'Invalid booking duration: % minutes. Duration must be between 1 and 1440 minutes.',
      NEW.duration_minutes;
  END IF;

  IF NEW.room_id IS NULL THEN
    RAISE EXCEPTION
      'Cannot validate booking price: room_id is required.';
  END IF;

  SELECT
    COALESCE(
      CASE
        WHEN NEW.play_mode = 'multi'
             AND COALESCE(r.hourly_rate_multi, 0) > 0
        THEN r.hourly_rate_multi
        ELSE r.hourly_rate_single
      END,
      0
    ),
    GREATEST(0, COALESCE(NEW.extra_controllers, 0))
      * COALESCE(r.extra_controller_price, 0)
  INTO
    v_actual_hourly_rate,
    v_extra_controller_rate
  FROM public.rooms r
  WHERE r.id = NEW.room_id;

  IF v_actual_hourly_rate <= 0 THEN
    RAISE EXCEPTION
      'Cannot validate booking price: room % has no valid rate configured.',
      NEW.room_id;
  END IF;

  NEW.room_price :=
    (NEW.duration_minutes / 60.0)
    * (v_actual_hourly_rate + v_extra_controller_rate);

  v_addons := GREATEST(
    0,
    COALESCE(NEW.addons_price, NEW.addons_total, 0)
  );

  NEW.addons_price := v_addons;
  NEW.addons_total := v_addons;

  v_subtotal := NEW.room_price + v_addons;

  IF COALESCE(NEW.discount_amount, 0) > 0 THEN
    v_discount := LEAST(v_subtotal, NEW.discount_amount);
  ELSIF COALESCE(NEW.discount_percentage, 0) > 0 THEN
    v_discount := LEAST(
      v_subtotal,
      v_subtotal * (NEW.discount_percentage / 100.0)
    );
  ELSE
    v_discount := 0;
  END IF;

  NEW.discount_amount := v_discount;
  NEW.total_price := GREATEST(0, v_subtotal - v_discount);

  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.validate_booking_payment_policy()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_allow_cash boolean;
  v_require_first_prepaid boolean;
BEGIN
  SELECT allow_cash_payment, require_prepaid_first_time
    INTO v_allow_cash, v_require_first_prepaid
  FROM public.lounges
  WHERE id = NEW.lounge_id;

  IF NEW.payment_method = 'cash' AND COALESCE(v_allow_cash, false) = false THEN
    RAISE EXCEPTION 'Cash payment is disabled for this lounge';
  END IF;

  IF NEW.payment_method = 'cash'
     AND COALESCE(v_require_first_prepaid, true)
     AND NEW.is_first_booking THEN
    RAISE EXCEPTION 'First booking must use manual_transfer payment';
  END IF;

  IF NEW.payment_method = 'manual_transfer'
     AND NULLIF(btrim(NEW.sender_wallet_phone), '') IS NULL THEN
    RAISE EXCEPTION 'sender_wallet_phone is required for manual_transfer';
  END IF;

  RETURN NEW;
END;
$function$
;
CREATE FUNCTION private.assert_lounge_operator(uuid,boolean) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF NOT public.has_lounge_permission($1,'sessions_control') THEN RAISE EXCEPTION 'NOT_AUTHORIZED' USING ERRCODE='42501'; END IF; END $$;
CREATE FUNCTION public.calculate_booking_price(numeric,integer) RETURNS numeric LANGUAGE sql AS $$ SELECT round($1 * ($2::numeric / 60),2) $$;
CREATE FUNCTION public.set_booking_first_booking() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RETURN NEW; END $$;
CREATE TRIGGER trg_validate_and_clamp_booking_price BEFORE INSERT OR UPDATE ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.fn_validate_and_clamp_booking_price();
CREATE TRIGGER trg_enforce_cash_booking_approval BEFORE INSERT OR UPDATE OF payment_method,payment_status,status ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.enforce_cash_booking_approval();
CREATE TRIGGER trg_bookings_set_first_booking BEFORE INSERT ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.set_booking_first_booking();
CREATE TRIGGER trg_bookings_validate_payment_policy BEFORE INSERT OR UPDATE OF lounge_id,payment_method,sender_wallet_phone,is_first_booking ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.validate_booking_payment_policy();
