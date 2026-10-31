-- Coordinated fixed-session offline protocol. No venue writer is assigned by this migration.
-- Reviewed immutable permits, single-writer authority, scoped bootstrap and ordered reconciliation.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- Reviewed section: offline_walk_in_customer_policy.sql
CREATE OR REPLACE FUNCTION public.set_booking_first_booking()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_completed_count integer;
BEGIN
  IF NEW.user_id IS NULL THEN
    IF auth.uid() IS NULL OR NOT EXISTS(SELECT 1 FROM public.profiles p JOIN auth.users u ON u.id=p.id
      WHERE p.id=auth.uid() AND p.is_active IS TRUE AND p.is_banned IS FALSE)
      OR NOT EXISTS(SELECT 1 FROM public.lounges WHERE id=NEW.lounge_id AND is_active IS TRUE AND status='active')
      OR (public.is_super_admin() IS NOT TRUE AND public.has_lounge_permission(NEW.lounge_id,'bookings.manage') IS NOT TRUE) THEN
      RAISE EXCEPTION 'WALK_IN_BOOKING_PERMISSION_DENIED' USING ERRCODE='42501';
    END IF;
    NEW.is_first_booking:=false;RETURN NEW;
  END IF;
  SELECT coalesce(completed_bookings_count,0) INTO v_completed_count FROM public.profiles WHERE id=NEW.user_id FOR UPDATE;
  NEW.is_first_booking:=(coalesce(v_completed_count,0)=0);
  RETURN NEW;
END; $$;
REVOKE ALL ON FUNCTION public.set_booking_first_booking() FROM PUBLIC,anon,authenticated;

-- Reviewed section: partial_cash_collection.sql
CREATE TABLE IF NOT EXISTS private.cash_collection_receipts (
  operation_id uuid PRIMARY KEY,
  actor_id uuid NOT NULL,
  booking_id uuid NOT NULL REFERENCES public.bookings(id),
  shift_id uuid NOT NULL REFERENCES public.shifts(id),
  amount_minor numeric NOT NULL CHECK (amount_minor>0 AND amount_minor=trunc(amount_minor)),
  result jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS cash_collection_receipts_booking ON private.cash_collection_receipts(booking_id);
ALTER TABLE private.cash_collection_receipts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.cash_collection_receipts FROM PUBLIC,anon,authenticated;

CREATE TABLE IF NOT EXISTS private.cash_collection_context (
  transaction_id bigint NOT NULL,
  booking_id uuid NOT NULL,
  PRIMARY KEY(transaction_id,booking_id)
);
ALTER TABLE private.cash_collection_context ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.cash_collection_context FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.guard_partial_cash_payment()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM private.cash_collection_receipts WHERE booking_id=NEW.booking_id)
    AND NOT EXISTS (SELECT 1 FROM private.cash_collection_context
      WHERE transaction_id=txid_current() AND booking_id=NEW.booking_id) THEN
    RAISE EXCEPTION 'CASH_LEDGER_REQUIRES_CANONICAL_COLLECTION' USING ERRCODE='55000';
  END IF;
  RETURN NEW;
END; $$;
REVOKE ALL ON FUNCTION private.guard_partial_cash_payment() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS guard_partial_cash_payment ON public.payments;
CREATE TRIGGER guard_partial_cash_payment BEFORE INSERT OR UPDATE ON public.payments
FOR EACH ROW EXECUTE FUNCTION private.guard_partial_cash_payment();

CREATE OR REPLACE FUNCTION private.assert_cash_collector(p_actor uuid,p_lounge uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  PERFORM 1 FROM public.profiles p JOIN auth.users u ON u.id=p.id
    WHERE p.id=p_actor AND p.is_active IS TRUE AND p.is_banned IS FALSE FOR SHARE OF p,u;
  IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_NOT_ELIGIBLE' USING ERRCODE='42501'; END IF;
  IF public.is_super_admin() IS NOT TRUE
      AND public.has_lounge_permission(p_lounge,'billing_checkout') IS NOT TRUE THEN
    RAISE EXCEPTION 'CASH_COLLECTION_PERMISSION_DENIED' USING ERRCODE='42501';
  END IF;
  PERFORM 1 FROM public.lounges WHERE id=p_lounge AND is_active IS TRUE AND status='active' FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'LOUNGE_NOT_APPROVED' USING ERRCODE='42501'; END IF;
END; $$;
REVOKE ALL ON FUNCTION private.assert_cash_collector(uuid,uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.lock_cash_collection_booking(p_booking_id uuid)
RETURNS public.bookings LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_booking public.bookings%ROWTYPE;v_lounge_id uuid;
BEGIN
  SELECT lounge_id INTO v_lounge_id FROM public.bookings WHERE id=p_booking_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'BOOKING_NOT_FOUND' USING ERRCODE='P0002'; END IF;
  PERFORM private.assert_cash_collector(auth.uid(),v_lounge_id);
  SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND OR v_booking.lounge_id IS DISTINCT FROM v_lounge_id THEN
    RAISE EXCEPTION 'BOOKING_SCOPE_CHANGED' USING ERRCODE='55000';
  END IF;
  IF v_booking.status::text IN ('cancelled','rejected')
    OR (v_booking.is_open_time IS TRUE AND v_booking.status::text<>'completed') THEN
    RAISE EXCEPTION 'BOOKING_NOT_READY_FOR_COLLECTION' USING ERRCODE='55000';
  END IF;
  IF v_booking.total_price IS NULL OR v_booking.total_price<0
    OR v_booking.total_price::text IN ('NaN','Infinity','-Infinity')
    OR v_booking.total_price<>round(v_booking.total_price,2) THEN
    RAISE EXCEPTION 'INVALID_BOOKING_TOTAL' USING ERRCODE='22023';
  END IF;
  RETURN v_booking;
END; $$;
REVOKE ALL ON FUNCTION private.lock_cash_collection_booking(uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.lock_cash_collection_shift(p_shift_id uuid,p_lounge_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_shift public.shifts%ROWTYPE;
BEGIN
  SELECT * INTO v_shift FROM public.shifts WHERE id=p_shift_id FOR SHARE;
  IF NOT FOUND OR v_shift.lounge_id IS DISTINCT FROM p_lounge_id
    OR v_shift.status IS DISTINCT FROM 'open' OR v_shift.closed_at IS NOT NULL
    OR v_shift.cashier_id IS DISTINCT FROM auth.uid()
    OR (v_shift.staff_user_id IS NOT NULL AND v_shift.staff_user_id IS DISTINCT FROM auth.uid()) THEN
    RAISE EXCEPTION 'OWN_OPEN_SHIFT_REQUIRED' USING ERRCODE='55000';
  END IF;
END; $$;
REVOKE ALL ON FUNCTION private.lock_cash_collection_shift(uuid,uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.cash_collection_paid_amount(p_booking_id uuid,p_lounge_id uuid,p_payment_status text)
RETURNS numeric LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_payment public.payments%ROWTYPE;v_cash numeric;
BEGIN
  SELECT COALESCE(sum(amount),0) INTO v_cash FROM public.shift_payments
    WHERE booking_id=p_booking_id AND lounge_id=p_lounge_id AND payment_method='cash';
  SELECT * INTO v_payment FROM public.payments WHERE booking_id=p_booking_id FOR UPDATE;
  IF FOUND THEN
    IF v_payment.payment_method IS DISTINCT FROM 'cash' OR v_payment.status IS DISTINCT FROM 'completed'
      OR v_payment.lounge_id IS DISTINCT FROM p_lounge_id OR v_payment.payout_id IS NOT NULL
      OR v_payment.amount IS NULL OR v_payment.amount<0
      OR v_payment.amount::text IN ('NaN','Infinity','-Infinity')
      OR v_payment.amount<>round(v_payment.amount,2) OR v_payment.amount IS DISTINCT FROM v_cash THEN
      RAISE EXCEPTION 'PAYMENT_REQUIRES_RECONCILIATION' USING ERRCODE='55000';
    END IF;
    RETURN v_payment.amount;
  ELSIF p_payment_status IS DISTINCT FROM 'unpaid' OR v_cash<>0 THEN
    RAISE EXCEPTION 'PAYMENT_REQUIRES_RECONCILIATION' USING ERRCODE='55000';
  END IF;
  RETURN 0;
END; $$;
REVOKE ALL ON FUNCTION private.cash_collection_paid_amount(uuid,uuid,text) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.apply_partial_cash_collection(
  p_booking_id uuid,p_shift_id uuid,p_amount_minor numeric
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_amount numeric := p_amount_minor/100;
  v_paid numeric;
  v_rate numeric := private.platform_commission_rate();
  v_shift_payment uuid;
  v_final_total numeric;
BEGIN
  v_booking:=private.lock_cash_collection_booking(p_booking_id);
  PERFORM private.lock_cash_collection_shift(p_shift_id,v_booking.lounge_id);
  v_paid:=private.cash_collection_paid_amount(p_booking_id,v_booking.lounge_id,v_booking.payment_status);
  IF v_amount>v_booking.total_price-v_paid THEN
    RAISE EXCEPTION 'CASH_EXCEEDS_OUTSTANDING_BALANCE' USING ERRCODE='22023';
  END IF;
  IF v_rate IS NULL OR v_rate<0 OR v_rate>1 OR v_rate::text IN ('NaN','Infinity','-Infinity') THEN
    RAISE EXCEPTION 'INVALID_COMMISSION_POLICY' USING ERRCODE='55000';
  END IF;
  INSERT INTO private.cash_collection_context VALUES(txid_current(),p_booking_id) ON CONFLICT DO NOTHING;
  INSERT INTO public.payments(booking_id,user_id,lounge_id,amount,commission_rate,commission,
    net_to_lounge,payment_method,status,paid_at)
  VALUES(p_booking_id,v_booking.user_id,v_booking.lounge_id,v_paid+v_amount,v_rate,
    round((v_paid+v_amount)*v_rate,2),(v_paid+v_amount)-round((v_paid+v_amount)*v_rate,2),'cash','completed',now())
  ON CONFLICT(booking_id) DO UPDATE SET amount=EXCLUDED.amount,commission_rate=EXCLUDED.commission_rate,
    commission=EXCLUDED.commission,net_to_lounge=EXCLUDED.net_to_lounge,paid_at=EXCLUDED.paid_at;
  INSERT INTO public.shift_payments(shift_id,lounge_id,booking_id,payment_method,category,amount,paid_at)
  VALUES(p_shift_id,v_booking.lounge_id,p_booking_id,'cash','gaming_time',v_amount,now()) RETURNING id INTO v_shift_payment;
  UPDATE public.bookings SET payment_status=CASE WHEN v_paid+v_amount=total_price THEN 'paid' ELSE 'partial' END,
    payment_method='cash',updated_at=now() WHERE id=p_booking_id RETURNING total_price INTO v_final_total;
  IF v_final_total IS DISTINCT FROM v_booking.total_price THEN
    RAISE EXCEPTION 'BOOKING_PRICE_CHANGED_DURING_COLLECTION' USING ERRCODE='22023';
  END IF;
  DELETE FROM private.cash_collection_context WHERE transaction_id=txid_current() AND booking_id=p_booking_id;
  RETURN jsonb_build_object('booking_id',p_booking_id,'lounge_id',v_booking.lounge_id,
    'shift_id',p_shift_id,'shift_payment_id',v_shift_payment,'collected_minor',p_amount_minor,
    'paid_minor',(v_paid+v_amount)*100,'due_minor',(v_booking.total_price-v_paid-v_amount)*100,
    'payment_status',CASE WHEN v_paid+v_amount=v_booking.total_price THEN 'paid' ELSE 'partial' END);
END; $$;
REVOKE ALL ON FUNCTION private.apply_partial_cash_collection(uuid,uuid,numeric) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.collect_booking_cash_partial(
  p_booking_id uuid,p_shift_id uuid,p_amount_minor numeric,p_operation_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_receipt private.cash_collection_receipts%ROWTYPE; v_result jsonb;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='28000'; END IF;
  IF p_operation_id IS NULL OR p_booking_id IS NULL OR p_shift_id IS NULL OR p_amount_minor IS NULL
    OR p_amount_minor::text IN ('NaN','Infinity','-Infinity') OR p_amount_minor<=0
    OR p_amount_minor<>trunc(p_amount_minor) OR p_amount_minor>9007199254740991 THEN
    RAISE EXCEPTION 'INVALID_CASH_COLLECTION_REQUEST' USING ERRCODE='22023';
  END IF;
  INSERT INTO private.cash_collection_receipts(operation_id,actor_id,booking_id,shift_id,amount_minor)
    VALUES(p_operation_id,auth.uid(),p_booking_id,p_shift_id,p_amount_minor) ON CONFLICT DO NOTHING;
  SELECT * INTO STRICT v_receipt FROM private.cash_collection_receipts WHERE operation_id=p_operation_id FOR UPDATE;
  IF v_receipt.actor_id IS DISTINCT FROM auth.uid() OR v_receipt.booking_id IS DISTINCT FROM p_booking_id
    OR v_receipt.shift_id IS DISTINCT FROM p_shift_id OR v_receipt.amount_minor IS DISTINCT FROM p_amount_minor THEN
    RAISE EXCEPTION 'CASH_COLLECTION_REPLAY_CONFLICT' USING ERRCODE='22023';
  END IF;
  IF v_receipt.result IS NOT NULL THEN
    PERFORM private.assert_cash_collector(auth.uid(),(v_receipt.result->>'lounge_id')::uuid);
    RETURN v_receipt.result||jsonb_build_object('replayed',true);
  END IF;
  v_result:=private.apply_partial_cash_collection(p_booking_id,p_shift_id,p_amount_minor)
    ||jsonb_build_object('operation_id',p_operation_id,'replayed',false);
  UPDATE private.cash_collection_receipts SET result=v_result WHERE operation_id=p_operation_id;
  RETURN v_result;
END; $$;
REVOKE ALL ON FUNCTION public.collect_booking_cash_partial(uuid,uuid,numeric,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.collect_booking_cash_partial(uuid,uuid,numeric,uuid) TO authenticated;

-- Reviewed section: cashier_writer_permits.sql
CREATE SCHEMA IF NOT EXISTS private;
REVOKE CREATE ON SCHEMA private FROM PUBLIC,anon,authenticated;
CREATE TABLE IF NOT EXISTS private.cashier_writer_permits (
  permit_id uuid PRIMARY KEY,
  lounge_id uuid NOT NULL REFERENCES public.lounges(id),
  actor_id uuid NOT NULL,
  device_id uuid NOT NULL,
  issued_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL,
  permissions jsonb NOT NULL,
  CHECK(expires_at>issued_at AND expires_at-issued_at<=interval '24 hours'),
  CHECK(jsonb_typeof(permissions)='object' AND permissions ?& ARRAY['bookings.manage','sessions_control','billing_checkout']
    AND jsonb_typeof(permissions->'bookings.manage')='boolean'
    AND jsonb_typeof(permissions->'sessions_control')='boolean'
    AND jsonb_typeof(permissions->'billing_checkout')='boolean')
);
ALTER TABLE private.cashier_writer_permits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.cashier_writer_permits FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.guard_cashier_permit_immutability()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  RAISE EXCEPTION 'CASHIER_PERMITS_ARE_IMMUTABLE' USING ERRCODE='55000';
END; $$;
REVOKE ALL ON FUNCTION private.guard_cashier_permit_immutability() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS guard_cashier_permit_immutability ON private.cashier_writer_permits;
CREATE TRIGGER guard_cashier_permit_immutability BEFORE UPDATE OR DELETE ON private.cashier_writer_permits
FOR EACH ROW EXECUTE FUNCTION private.guard_cashier_permit_immutability();

CREATE OR REPLACE FUNCTION private.cashier_effective_permissions(p_lounge_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
  SELECT jsonb_build_object(
    'bookings.manage',public.is_super_admin() IS TRUE OR public.has_lounge_permission(p_lounge_id,'bookings.manage') IS TRUE,
    'sessions_control',public.is_super_admin() IS TRUE OR public.has_lounge_permission(p_lounge_id,'sessions_control') IS TRUE,
    'billing_checkout',public.is_super_admin() IS TRUE OR public.has_lounge_permission(p_lounge_id,'billing_checkout') IS TRUE);
$$;
REVOKE ALL ON FUNCTION private.cashier_effective_permissions(uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.cashier_sync_permit_matches_writer(p_lounge_id uuid,p_actor_id uuid,p_permit_id uuid)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
  RETURN EXISTS(SELECT 1 FROM private.cashier_writer_authorities writer
    JOIN private.cashier_writer_permits permit ON permit.lounge_id=writer.lounge_id
      AND permit.actor_id=writer.actor_id AND permit.device_id=writer.device_id
    WHERE writer.lounge_id=p_lounge_id AND writer.actor_id=p_actor_id AND permit.permit_id=p_permit_id);
END;
$$;
REVOKE ALL ON FUNCTION private.cashier_sync_permit_matches_writer(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated;

-- Reviewed section: cashier_writer_availability.sql
CREATE SCHEMA IF NOT EXISTS private;
REVOKE CREATE ON SCHEMA private FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS private.cashier_writer_authorities (
  lounge_id uuid PRIMARY KEY REFERENCES public.lounges(id),
  actor_id uuid NOT NULL,
  device_id uuid NOT NULL,
  permit_id uuid NOT NULL DEFAULT gen_random_uuid(),
  issued_at timestamptz NOT NULL DEFAULT now(),
  permit_expires_at timestamptz NOT NULL,
  heartbeat_expires_at timestamptz NOT NULL,
  online_requested boolean NOT NULL DEFAULT false,
  last_applied_sequence bigint NOT NULL DEFAULT 0 CHECK (last_applied_sequence>=0),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE private.cashier_writer_authorities ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.cashier_writer_authorities FROM PUBLIC, anon, authenticated;

-- Only the reviewed reconciliation RPC may create a transaction-bound proof.
CREATE TABLE IF NOT EXISTS private.cashier_sync_context (
  transaction_id bigint PRIMARY KEY,
  lounge_id uuid NOT NULL,
  actor_id uuid NOT NULL,
  permit_id uuid NOT NULL
);
ALTER TABLE private.cashier_sync_context ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.cashier_sync_context FROM PUBLIC,anon,authenticated;

CREATE TABLE IF NOT EXISTS private.cashier_booking_command_context (
  transaction_id bigint PRIMARY KEY,
  booking_id uuid NOT NULL,
  kind text NOT NULL CHECK(kind IN ('reserve','start','close'))
);
ALTER TABLE private.cashier_booking_command_context ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.cashier_booking_command_context FROM PUBLIC,anon,authenticated;

-- Serialize first claims too: a missing writer row cannot be row-locked.
-- All writer/booking/reconciliation paths acquire this before writer row locks.
CREATE OR REPLACE FUNCTION private.lock_cashier_lounge(p_lounge_id uuid)
RETURNS void LANGUAGE plpgsql VOLATILE STRICT SECURITY DEFINER SET search_path='' AS $function$
BEGIN
  IF current_setting('transaction_isolation')<>'read committed' THEN
    RAISE EXCEPTION 'CASHIER_REQUIRES_READ_COMMITTED' USING ERRCODE='25001';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('cashier-online:' || p_lounge_id::text,0)
  );
END;
$function$;
REVOKE ALL ON FUNCTION private.lock_cashier_lounge(uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.refresh_cashier_writer(
  p_lounge_id uuid, p_device_id uuid, p_online boolean DEFAULT true
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_profile public.profiles%ROWTYPE;
  v_lounge public.lounges%ROWTYPE;
  v_writer private.cashier_writer_authorities%ROWTYPE;
  v_permit private.cashier_writer_permits%ROWTYPE;
  v_now timestamptz := date_trunc('milliseconds',statement_timestamp());
  v_super_admin boolean;
  v_created boolean;
  v_permissions jsonb;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='28000'; END IF;
  IF p_device_id IS NULL OR p_lounge_id IS NULL OR p_online IS NULL THEN
    RAISE EXCEPTION 'INVALID_CASHIER_WRITER_REQUEST' USING ERRCODE='22023';
  END IF;
  PERFORM private.lock_cashier_lounge(p_lounge_id);
  SELECT p.* INTO v_profile FROM public.profiles p JOIN auth.users u ON u.id=p.id WHERE p.id=v_actor FOR SHARE OF p,u;
  IF NOT FOUND OR v_profile.is_active IS NOT TRUE OR v_profile.is_banned IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'ACCOUNT_NOT_ELIGIBLE' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_lounge FROM public.lounges WHERE id=p_lounge_id FOR SHARE;
  IF NOT FOUND OR v_lounge.status IS DISTINCT FROM 'active' OR v_lounge.is_active IS NOT TRUE THEN
    RAISE EXCEPTION 'LOUNGE_NOT_APPROVED' USING ERRCODE='42501';
  END IF;
  v_super_admin:=public.is_super_admin() IS TRUE;
  IF NOT v_super_admin AND public.has_lounge_permission(p_lounge_id,'sessions_control') IS NOT TRUE THEN
    RAISE EXCEPTION 'CASHIER_WRITER_PERMISSION_DENIED' USING ERRCODE='42501';
  END IF;
  v_permissions:=private.cashier_effective_permissions(p_lounge_id);
  INSERT INTO private.cashier_writer_authorities(lounge_id,actor_id,device_id,issued_at,permit_expires_at,heartbeat_expires_at)
    VALUES(p_lounge_id,v_actor,p_device_id,v_now,v_now+interval '24 hours',v_now)
    ON CONFLICT(lounge_id) DO NOTHING RETURNING * INTO v_writer;
  v_created:=FOUND;
  SELECT * INTO STRICT v_writer FROM private.cashier_writer_authorities WHERE lounge_id=p_lounge_id FOR UPDATE;
  -- Losing a heartbeat never authorizes another independent offline writer.
  IF v_writer.actor_id<>v_actor OR v_writer.device_id<>p_device_id THEN
    RAISE EXCEPTION 'CASHIER_WRITER_ALREADY_ASSIGNED' USING ERRCODE='55000';
  END IF;
  v_now:=date_trunc('milliseconds',clock_timestamp());
  IF NOT v_created THEN
    SELECT * INTO v_permit FROM private.cashier_writer_permits WHERE permit_id=v_writer.permit_id FOR SHARE;
    IF NOT FOUND OR (v_permit.lounge_id,v_permit.actor_id,v_permit.device_id,v_permit.issued_at,v_permit.expires_at)
      IS DISTINCT FROM (v_writer.lounge_id,v_writer.actor_id,v_writer.device_id,v_writer.issued_at,v_writer.permit_expires_at) THEN
      RAISE EXCEPTION 'CASHIER_PERMIT_RECORD_MISSING_OR_CHANGED' USING ERRCODE='55000';
    END IF;
  END IF;
  IF v_created OR v_now>=v_permit.expires_at OR v_permissions IS DISTINCT FROM v_permit.permissions THEN
    INSERT INTO private.cashier_writer_permits(permit_id,lounge_id,actor_id,device_id,issued_at,expires_at,permissions)
      VALUES(CASE WHEN v_created THEN v_writer.permit_id ELSE gen_random_uuid() END,
        p_lounge_id,v_actor,p_device_id,v_now,v_now+interval '24 hours',v_permissions) RETURNING * INTO v_permit;
  END IF;
  UPDATE private.cashier_writer_authorities SET
    permit_id=v_permit.permit_id,issued_at=v_permit.issued_at,permit_expires_at=v_permit.expires_at,
    heartbeat_expires_at=CASE WHEN p_online THEN v_now+interval '90 seconds' ELSE v_now END,
    online_requested=p_online, updated_at=v_now
  WHERE lounge_id=p_lounge_id RETURNING * INTO v_writer;
  RETURN jsonb_build_object(
    'protocol_version',2,'server_time_ms',floor(extract(epoch FROM v_now)*1000)::bigint,'online_requested',p_online,
    'actor_id',v_actor,'lounge_id',p_lounge_id,'device_id',p_device_id,'permit_id',v_writer.permit_id,
    'profile_active',true,'profile_banned',false,'lounge_status',v_lounge.status,'lounge_active',true,
    'offline_enabled',true,'issued_ms',floor(extract(epoch FROM v_writer.issued_at)*1000)::bigint,
    'expires_ms',floor(extract(epoch FROM v_writer.permit_expires_at)*1000)::bigint,
    'heartbeat_expires_at',v_writer.heartbeat_expires_at,
    'last_applied_sequence',v_writer.last_applied_sequence,'timezone',to_jsonb(v_lounge)->>'timezone',
    'permissions',v_permit.permissions
  );
END;
$function$;
REVOKE ALL ON FUNCTION public.refresh_cashier_writer(uuid,uuid,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.refresh_cashier_writer(uuid,uuid,boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_lounge_online_availability(p_lounge_id uuid)
RETURNS boolean LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $function$
DECLARE v_now timestamptz:=clock_timestamp();
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.lounges AS lounge
    LEFT JOIN private.cashier_writer_authorities AS writer ON writer.lounge_id=lounge.id
    WHERE lounge.id=p_lounge_id AND lounge.status='active'
      AND lounge.is_active IS TRUE AND lounge.is_open IS TRUE
      AND (writer.lounge_id IS NULL OR (
        writer.online_requested IS TRUE
        AND writer.heartbeat_expires_at>v_now
        AND EXISTS(SELECT 1 FROM private.cashier_writer_permits permit WHERE permit.permit_id=writer.permit_id
          AND (permit.lounge_id,permit.actor_id,permit.device_id,permit.issued_at,permit.expires_at)
            IS NOT DISTINCT FROM (writer.lounge_id,writer.actor_id,writer.device_id,writer.issued_at,writer.permit_expires_at)
          AND permit.expires_at>v_now)
        AND EXISTS (
          SELECT 1 FROM public.profiles AS profile
          JOIN auth.users AS identity ON identity.id=profile.id
          WHERE profile.id=writer.actor_id AND profile.is_active IS TRUE
            AND profile.is_banned IS FALSE
            AND (profile.role IN ('super_admin','superadmin')
              OR EXISTS (SELECT 1 FROM public.platform_super_admins AS admin WHERE admin.user_id=profile.id)
              OR private.user_permission_value(writer.actor_id,lounge.id,'sessions_control') IS TRUE)
        )
      ))
  );
END;
$function$;
REVOKE ALL ON FUNCTION public.get_lounge_online_availability(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_lounge_online_availability(uuid) TO anon,authenticated;

CREATE OR REPLACE FUNCTION private.guard_cashier_online_booking()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_room_lounge uuid;
BEGIN
  IF NEW.room_id IS NOT NULL THEN
    SELECT lounge_id INTO v_room_lounge FROM public.rooms WHERE id=NEW.room_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'ROOM_NOT_FOUND' USING ERRCODE='22023'; END IF;
    IF NEW.lounge_id IS NOT NULL AND NEW.lounge_id IS DISTINCT FROM v_room_lounge THEN
      RAISE EXCEPTION 'BOOKING_ROOM_SCOPE_MISMATCH' USING ERRCODE='42501';
    END IF;
    NEW.lounge_id:=v_room_lounge;
  END IF;
  IF TG_OP='UPDATE' AND NEW.status::text IN ('cancelled','rejected','completed') THEN
    RETURN NEW;
  END IF;
  -- A row trigger can run after an online RPC has already locked its booking
  -- or room. Waiting here would invert the reconciliation lounge-first order.
  -- Refuse a busy writer transaction with a retryable error instead of entering
  -- a deadlock or admitting an unverified online booking.
  IF current_setting('transaction_isolation')<>'read committed' THEN
    RAISE EXCEPTION 'CASHIER_REQUIRES_READ_COMMITTED' USING ERRCODE='25001';
  END IF;
  IF NOT pg_catalog.pg_try_advisory_xact_lock(
    pg_catalog.hashtextextended('cashier-online:' || NEW.lounge_id::text,0)) THEN
    RAISE EXCEPTION 'CASHIER_WRITER_BUSY_RETRY' USING ERRCODE='55P03';
  END IF;
  -- Also serialize administrative writer updates that do not use the RPC.
  PERFORM 1 FROM private.cashier_writer_authorities WHERE lounge_id=NEW.lounge_id FOR SHARE NOWAIT;
  IF EXISTS (SELECT 1 FROM private.cashier_writer_authorities WHERE lounge_id=NEW.lounge_id)
     AND public.get_lounge_online_availability(NEW.lounge_id) IS NOT TRUE THEN
    IF NOT EXISTS (
      SELECT 1 FROM private.cashier_sync_context AS context
      JOIN private.cashier_writer_authorities AS writer ON writer.lounge_id=context.lounge_id
      JOIN public.profiles AS profile ON profile.id=context.actor_id
      JOIN auth.users AS identity ON identity.id=profile.id
      JOIN public.lounges AS lounge ON lounge.id=writer.lounge_id
      WHERE context.transaction_id=txid_current() AND context.actor_id=auth.uid()
        AND context.actor_id=writer.actor_id
        AND private.cashier_sync_permit_matches_writer(context.lounge_id,context.actor_id,context.permit_id)
        AND context.lounge_id=NEW.lounge_id AND profile.is_active IS TRUE
        AND profile.is_banned IS FALSE AND lounge.status='active' AND lounge.is_active IS TRUE
        AND (public.is_super_admin() IS TRUE OR public.has_lounge_permission(NEW.lounge_id,'bookings.manage') IS TRUE
          OR (TG_OP='UPDATE' AND public.has_lounge_permission(NEW.lounge_id,'sessions_control') IS TRUE
            AND NEW.status::text='in_progress' AND OLD.status::text='upcoming'
            AND (NEW.room_id,NEW.lounge_id,NEW.user_id,NEW.date,NEW.start_time,NEW.end_time)
              IS NOT DISTINCT FROM (OLD.room_id,OLD.lounge_id,OLD.user_id,OLD.date,OLD.start_time,OLD.end_time)
            AND EXISTS(SELECT 1 FROM private.cashier_booking_command_context command
              WHERE command.transaction_id=txid_current() AND command.booking_id=NEW.id AND command.kind='start')))
    ) THEN RAISE EXCEPTION 'LOUNGE_OFFLINE' USING ERRCODE='55000'; END IF;
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION private.guard_cashier_online_booking() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS guard_cashier_online_booking ON public.bookings;
CREATE TRIGGER guard_cashier_online_booking
BEFORE INSERT OR UPDATE OF status,room_id,lounge_id,user_id,date,start_time,end_time ON public.bookings
FOR EACH ROW EXECUTE FUNCTION private.guard_cashier_online_booking();

-- Reviewed section: offline_fixed_session_capacity.sql
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS cashier_closed_at timestamptz;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS cashier_booking_timezone text;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS cashier_capacity_period tsrange GENERATED ALWAYS AS (
  tsrange(date+start_time,
    CASE WHEN status='completed'::public.booking_status AND cashier_closed_at IS NOT NULL AND cashier_booking_timezone IS NOT NULL
      THEN greatest(date+start_time,least((date+end_time)+CASE WHEN end_time<=start_time THEN interval '1 day' ELSE interval '0' END,
        cashier_closed_at AT TIME ZONE cashier_booking_timezone))
      ELSE (date+end_time)+CASE WHEN end_time<=start_time THEN interval '1 day' ELSE interval '0' END END,'[)')
) STORED;
ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS bookings_room_booking_period_excl;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_room_booking_period_excl EXCLUDE USING gist
  (room_id WITH =,cashier_capacity_period WITH &&)
  WHERE(status NOT IN ('cancelled'::public.booking_status,'rejected'::public.booking_status)
    AND room_id IS NOT NULL AND cashier_capacity_period IS NOT NULL);

CREATE OR REPLACE FUNCTION private.guard_cashier_capacity_fields()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_kind text;
BEGIN
  IF TG_OP='INSERT' AND NEW.cashier_closed_at IS NULL AND NEW.cashier_booking_timezone IS NULL THEN RETURN NEW; END IF;
  IF TG_OP='UPDATE' AND (NEW.cashier_closed_at,NEW.cashier_booking_timezone)
    IS NOT DISTINCT FROM (OLD.cashier_closed_at,OLD.cashier_booking_timezone) THEN RETURN NEW; END IF;
  SELECT command.kind INTO v_kind FROM private.cashier_booking_command_context command
    JOIN private.cashier_sync_context context USING(transaction_id)
    JOIN private.cashier_writer_authorities writer ON writer.lounge_id=context.lounge_id
    WHERE command.transaction_id=txid_current() AND command.booking_id=NEW.id
      AND context.actor_id=auth.uid() AND context.actor_id=writer.actor_id
      AND private.cashier_sync_permit_matches_writer(context.lounge_id,context.actor_id,context.permit_id)
      AND context.lounge_id=NEW.lounge_id;
  IF NOT FOUND OR (v_kind<>'close' AND NEW.cashier_closed_at IS NOT NULL)
    OR (v_kind='close' AND (TG_OP<>'UPDATE' OR NEW.status<>'completed'::public.booking_status
      OR NEW.cashier_booking_timezone IS DISTINCT FROM OLD.cashier_booking_timezone)) THEN
    RAISE EXCEPTION 'CASHIER_CAPACITY_FIELDS_SERVER_ONLY' USING ERRCODE='42501';
  END IF;
  IF NEW.cashier_booking_timezone IS NULL OR NOT EXISTS(SELECT 1 FROM pg_catalog.pg_timezone_names
    WHERE name=NEW.cashier_booking_timezone) THEN RAISE EXCEPTION 'INVALID_LOUNGE_TIMEZONE' USING ERRCODE='22023'; END IF;
  RETURN NEW;
END; $$;
REVOKE ALL ON FUNCTION private.guard_cashier_capacity_fields() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS guard_cashier_capacity_fields ON public.bookings;
CREATE TRIGGER guard_cashier_capacity_fields BEFORE INSERT OR UPDATE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION private.guard_cashier_capacity_fields();

-- Reviewed section: offline_fixed_session_reservation.sql
CREATE OR REPLACE FUNCTION private.offline_booking_interval(p_operation jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_start numeric;v_end numeric;v_start_at timestamptz;v_end_at timestamptz;v_start_local timestamp;v_end_local timestamp;v_timezone text;
BEGIN
  IF jsonb_typeof(p_operation->'payload'->'start_ms') IS DISTINCT FROM 'number'
    OR jsonb_typeof(p_operation->'payload'->'end_ms') IS DISTINCT FROM 'number' THEN
    RAISE EXCEPTION 'INVALID_OFFLINE_BOOKING_INTERVAL' USING ERRCODE='22023';
  END IF;
  v_start:=(p_operation->'payload'->>'start_ms')::numeric;v_end:=(p_operation->'payload'->>'end_ms')::numeric;
  IF v_start<0 OR v_end>253402300799000 OR mod(v_start,60000)<>0 OR mod(v_end,60000)<>0
    OR v_end<=v_start OR v_end-v_start>86400000
    OR v_start<floor(extract(epoch FROM (p_operation->>'occurred_at')::timestamptz)/60)*60000 THEN
    RAISE EXCEPTION 'INVALID_OFFLINE_BOOKING_INTERVAL' USING ERRCODE='22023';
  END IF;
  SELECT timezone INTO v_timezone FROM public.lounges WHERE id=(p_operation->>'lounge_id')::uuid;
  IF v_timezone IS NULL OR v_timezone IS DISTINCT FROM p_operation->'payload'->>'timezone'
    OR NOT EXISTS(SELECT 1 FROM pg_catalog.pg_timezone_names WHERE name=v_timezone) THEN
    RAISE EXCEPTION 'INVALID_LOUNGE_TIMEZONE' USING ERRCODE='22023';
  END IF;
  v_start_at:=to_timestamp((v_start/1000)::double precision);v_end_at:=to_timestamp((v_end/1000)::double precision);
  v_start_local:=v_start_at AT TIME ZONE v_timezone;v_end_local:=v_end_at AT TIME ZONE v_timezone;
  IF v_start_local AT TIME ZONE v_timezone IS DISTINCT FROM v_start_at
    OR v_end_local AT TIME ZONE v_timezone IS DISTINCT FROM v_end_at
    OR v_end_local-v_start_local IS DISTINCT FROM v_end_at-v_start_at THEN
    RAISE EXCEPTION 'OFFLINE_DST_INTERVAL_REQUIRES_REVIEW' USING ERRCODE='22023';
  END IF;
  RETURN jsonb_build_object('start',v_start_local,'end',v_end_local,'timezone',v_timezone,'minutes',((v_end-v_start)/60000)::integer);
END; $$;
REVOKE ALL ON FUNCTION private.offline_booking_interval(jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.lock_offline_booking_room(p_room_id uuid,p_lounge_id uuid)
RETURNS public.rooms LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_room public.rooms%ROWTYPE;
BEGIN
  SELECT * INTO v_room FROM public.rooms WHERE id=p_room_id FOR UPDATE;
  IF NOT FOUND OR v_room.lounge_id IS DISTINCT FROM p_lounge_id OR v_room.is_active IS NOT TRUE
    OR v_room.status NOT IN ('available','occupied') OR v_room.status IS NULL
    OR (v_room.is_available IS NOT TRUE AND v_room.status<>'occupied') THEN
    RAISE EXCEPTION 'OFFLINE_ROOM_UNAVAILABLE' USING ERRCODE='55000';
  END IF;
  RETURN v_room;
END; $$;
REVOKE ALL ON FUNCTION private.lock_offline_booking_room(uuid,uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.quote_offline_fixed_booking(p_operation jsonb,p_interval jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_quote jsonb;v_total numeric;
BEGIN
  IF p_operation->'payload'->>'play_mode' NOT IN ('single','multi') OR p_operation->'payload'->>'play_mode' IS NULL
    OR jsonb_typeof(p_operation->'quoted_total_minor') IS DISTINCT FROM 'number'
    OR jsonb_typeof(p_operation->'payload'->'customer_name') IS DISTINCT FROM 'string'
    OR (p_operation->'payload' ? 'customer_phone' AND p_operation->'payload'->'customer_phone'<>'null'::jsonb
      AND jsonb_typeof(p_operation->'payload'->'customer_phone') IS DISTINCT FROM 'string')
    OR nullif(btrim(p_operation->'payload'->>'customer_name'),'') IS NULL
    OR length(p_operation->'payload'->>'customer_name')>120
    OR length(coalesce(p_operation->'payload'->>'customer_phone',''))>32 THEN
    RAISE EXCEPTION 'INVALID_OFFLINE_BOOKING' USING ERRCODE='22023';
  END IF;
  v_total:=(p_operation->>'quoted_total_minor')::numeric;
  IF v_total<=0 OR v_total<>trunc(v_total) OR v_total>9007199254740991 THEN
    RAISE EXCEPTION 'INVALID_OFFLINE_BOOKING' USING ERRCODE='22023';
  END IF;
  v_quote:=public.quote_booking_price((p_operation->'payload'->>'room_id')::uuid,
    (p_interval->>'start')::timestamp::date,(p_interval->>'start')::timestamp::time,(p_interval->>'end')::timestamp::time,
    p_operation->'payload'->>'play_mode',0,NULL);
  IF (v_quote->>'final_total')::numeric*100 IS DISTINCT FROM v_total
    OR (v_quote->>'room_subtotal')::numeric IS DISTINCT FROM (v_quote->>'final_total')::numeric
    OR (v_quote->>'duration_minutes')::numeric IS DISTINCT FROM (p_interval->>'minutes')::numeric THEN
    RAISE EXCEPTION 'OFFLINE_BOOKING_PRICE_CHANGED' USING ERRCODE='22023';
  END IF;
  RETURN v_quote;
END; $$;
REVOKE ALL ON FUNCTION private.quote_offline_fixed_booking(jsonb,jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.apply_cashier_reservation_operation(p_operation jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_room public.rooms%ROWTYPE;v_interval jsonb;v_quote jsonb;v_booking public.bookings%ROWTYPE;
BEGIN
  v_interval:=private.offline_booking_interval(p_operation);
  IF NOT EXISTS(SELECT 1 FROM public.lounges WHERE id=(p_operation->>'lounge_id')::uuid AND allow_cash_payment IS TRUE) THEN
    RAISE EXCEPTION 'OFFLINE_CASH_BOOKING_DISABLED' USING ERRCODE='55000';
  END IF;
  v_room:=private.lock_offline_booking_room((p_operation->'payload'->>'room_id')::uuid,(p_operation->>'lounge_id')::uuid);
  PERFORM private.lock_cash_collection_shift((p_operation->>'shift_id')::uuid,v_room.lounge_id);
  IF EXISTS(SELECT 1 FROM public.tournament_matches WHERE room_id=v_room.id AND status<>'cancelled'
    AND scheduled_at IS NOT NULL AND scheduled_end_at IS NOT NULL
    AND tstzrange(scheduled_at,scheduled_end_at,'[)') && tstzrange(
      to_timestamp((p_operation->'payload'->>'start_ms')::double precision/1000),
      to_timestamp((p_operation->'payload'->>'end_ms')::double precision/1000),'[)')) THEN
    RAISE EXCEPTION 'OFFLINE_TOURNAMENT_ROOM_CONFLICT' USING ERRCODE='55000';
  END IF;
  v_quote:=private.quote_offline_fixed_booking(p_operation,v_interval);
  INSERT INTO public.bookings(id,user_id,lounge_id,room_id,date,start_time,end_time,start_at,end_at,room_price,total_price,
    status,user_name,user_phone,room_name,play_mode,duration_minutes,shift_id,payment_status,payment_method,created_at,cashier_booking_timezone)
    VALUES((p_operation->>'booking_id')::uuid,NULL,v_room.lounge_id,v_room.id,(v_interval->>'start')::timestamp::date,
      (v_interval->>'start')::timestamp::time,(v_interval->>'end')::timestamp::time,
      (v_interval->>'start')::timestamp::time,(v_interval->>'end')::timestamp::time,
      (v_quote->>'room_subtotal')::numeric,(v_quote->>'final_total')::numeric,'upcoming',
      btrim(p_operation->'payload'->>'customer_name'),p_operation->'payload'->>'customer_phone',v_room.name,
      p_operation->'payload'->>'play_mode',(v_interval->>'minutes')::integer,(p_operation->>'shift_id')::uuid,
      'unpaid','cash',(p_operation->>'occurred_at')::timestamptz,v_interval->>'timezone') RETURNING * INTO v_booking;
  IF v_booking.total_price*100 IS DISTINCT FROM (p_operation->>'quoted_total_minor')::numeric THEN
    RAISE EXCEPTION 'OFFLINE_BOOKING_PRICE_CHANGED' USING ERRCODE='22023';
  END IF;
  RETURN private.offline_fixed_session_receipt(v_booking.id);
END; $$;
REVOKE ALL ON FUNCTION private.apply_cashier_reservation_operation(jsonb) FROM PUBLIC,anon,authenticated;

-- Reviewed section: offline_fixed_session_transitions.sql
CREATE OR REPLACE FUNCTION private.offline_fixed_session_receipt(p_booking_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_booking public.bookings%ROWTYPE;v_paid numeric;v_timezone text;v_start timestamp;v_end timestamp;
BEGIN
  SELECT * INTO STRICT v_booking FROM public.bookings WHERE id=p_booking_id;
  SELECT coalesce(v_booking.cashier_booking_timezone,timezone) INTO v_timezone FROM public.lounges WHERE id=v_booking.lounge_id;
  v_paid:=private.cash_collection_paid_amount(v_booking.id,v_booking.lounge_id,v_booking.payment_status);
  v_start:=v_booking.date+v_booking.start_time;
  v_end:=v_booking.date+v_booking.end_time+CASE WHEN v_booking.end_time<=v_booking.start_time THEN interval '1 day' ELSE interval '0' END;
  RETURN jsonb_build_object('booking_id',v_booking.id,'lounge_id',v_booking.lounge_id,'room_id',v_booking.room_id,
    'shift_id',v_booking.shift_id,'status',v_booking.status::text,'timezone',v_timezone,
    'start_ms',extract(epoch FROM (v_start AT TIME ZONE v_timezone))*1000,
    'end_ms',extract(epoch FROM (v_end AT TIME ZONE v_timezone))*1000,
    'capacity_end_ms',floor(CASE WHEN isempty(v_booking.cashier_capacity_period) THEN extract(epoch FROM (v_start AT TIME ZONE v_timezone))*1000
      ELSE extract(epoch FROM (upper(v_booking.cashier_capacity_period) AT TIME ZONE v_timezone))*1000 END),
    'started_at',v_booking.actual_start_time,'closed_at',v_booking.cashier_closed_at,
    'total_minor',v_booking.total_price*100,'paid_minor',v_paid*100,'due_minor',(v_booking.total_price-v_paid)*100,
    'payment_status',v_booking.payment_status);
END; $$;
REVOKE ALL ON FUNCTION private.offline_fixed_session_receipt(uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.lock_offline_fixed_session(p_operation jsonb)
RETURNS public.bookings LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_room uuid;v_lounge uuid;v_booking public.bookings%ROWTYPE;v_total numeric;
BEGIN
  SELECT room_id,lounge_id INTO v_room,v_lounge FROM public.bookings WHERE id=(p_operation->>'booking_id')::uuid;
  IF NOT FOUND OR v_lounge IS DISTINCT FROM (p_operation->>'lounge_id')::uuid THEN
    RAISE EXCEPTION 'OFFLINE_BOOKING_SCOPE_MISMATCH' USING ERRCODE='42501';
  END IF;
  -- Existing online lifecycle RPCs lock the booking before its room. Match
  -- that order rather than retaining a room while waiting on their booking.
  SELECT * INTO STRICT v_booking FROM public.bookings WHERE id=(p_operation->>'booking_id')::uuid FOR UPDATE;
  IF v_booking.room_id IS DISTINCT FROM v_room OR v_booking.lounge_id IS DISTINCT FROM v_lounge OR v_booking.is_open_time IS TRUE THEN
    RAISE EXCEPTION 'OFFLINE_FIXED_SESSION_SCOPE_CHANGED' USING ERRCODE='55000';
  END IF;
  PERFORM 1 FROM public.rooms WHERE id=v_room AND lounge_id=v_lounge FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'OFFLINE_ROOM_UNAVAILABLE' USING ERRCODE='55000'; END IF;
  PERFORM private.lock_cash_collection_shift((p_operation->>'shift_id')::uuid,v_lounge);
  IF v_booking.shift_id IS DISTINCT FROM (p_operation->>'shift_id')::uuid THEN
    RAISE EXCEPTION 'OFFLINE_BOOKING_SHIFT_MISMATCH' USING ERRCODE='55000';
  END IF;
  IF jsonb_typeof(p_operation->'quoted_total_minor') IS DISTINCT FROM 'number' THEN
    RAISE EXCEPTION 'OFFLINE_BOOKING_QUOTE_REQUIRED' USING ERRCODE='22023';
  END IF;
  v_total:=(p_operation->>'quoted_total_minor')::numeric;
  IF v_total<0 OR v_total<>trunc(v_total) OR v_total>9007199254740991 OR v_booking.total_price*100 IS DISTINCT FROM v_total THEN
    RAISE EXCEPTION 'OFFLINE_BOOKING_PRICE_CHANGED' USING ERRCODE='22023';
  END IF;
  RETURN v_booking;
END; $$;
REVOKE ALL ON FUNCTION private.lock_offline_fixed_session(jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.apply_cashier_start_operation(p_operation jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_booking public.bookings%ROWTYPE;v_timezone text;v_at timestamptz:=(p_operation->>'occurred_at')::timestamptz;v_final numeric;
BEGIN
  v_booking:=private.lock_offline_fixed_session(p_operation);
  PERFORM private.lock_offline_booking_room(v_booking.room_id,v_booking.lounge_id);
  SELECT timezone INTO v_timezone FROM public.lounges WHERE id=v_booking.lounge_id;
  IF v_timezone IS NULL OR NOT EXISTS(SELECT 1 FROM pg_catalog.pg_timezone_names WHERE name=v_timezone)
    OR (v_booking.cashier_booking_timezone IS NOT NULL AND v_booking.cashier_booking_timezone<>v_timezone) THEN
    RAISE EXCEPTION 'INVALID_LOUNGE_TIMEZONE' USING ERRCODE='22023';
  END IF;
  IF v_booking.status<>'upcoming'::public.booking_status
    OR v_at<(v_booking.date+v_booking.start_time) AT TIME ZONE v_timezone
    OR v_at>=((v_booking.date+v_booking.end_time)+CASE WHEN v_booking.end_time<=v_booking.start_time THEN interval '1 day' ELSE interval '0' END)
      AT TIME ZONE v_timezone THEN RAISE EXCEPTION 'OFFLINE_SESSION_OUTSIDE_BOOKED_WINDOW' USING ERRCODE='55000'; END IF;
  IF EXISTS(SELECT 1 FROM public.bookings WHERE room_id=v_booking.room_id AND id<>v_booking.id AND status='in_progress'::public.booking_status) THEN
    RAISE EXCEPTION 'OFFLINE_ROOM_STILL_OCCUPIED' USING ERRCODE='55000';
  END IF;
  UPDATE public.bookings SET status='in_progress',checked_in_at=v_at,actual_start_time=v_at,
    cashier_booking_timezone=v_timezone,updated_at=now() WHERE id=v_booking.id RETURNING total_price INTO v_final;
  IF v_final*100 IS DISTINCT FROM (p_operation->>'quoted_total_minor')::numeric THEN
    RAISE EXCEPTION 'OFFLINE_BOOKING_PRICE_CHANGED' USING ERRCODE='22023';
  END IF;
  UPDATE public.rooms SET status='occupied',is_available=false,updated_at=now() WHERE id=v_booking.room_id;
  RETURN private.offline_fixed_session_receipt(v_booking.id);
END; $$;
REVOKE ALL ON FUNCTION private.apply_cashier_start_operation(jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.apply_cashier_close_operation(p_operation jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_booking public.bookings%ROWTYPE;v_at timestamptz:=(p_operation->>'occurred_at')::timestamptz;v_final numeric;
BEGIN
  v_booking:=private.lock_offline_fixed_session(p_operation);
  IF v_booking.status<>'in_progress'::public.booking_status OR v_booking.actual_start_time IS NULL
    OR v_at<v_booking.actual_start_time OR v_booking.cashier_booking_timezone IS NULL THEN
    RAISE EXCEPTION 'OFFLINE_SESSION_NOT_READY_TO_CLOSE' USING ERRCODE='55000';
  END IF;
  UPDATE public.bookings SET status='completed',cashier_closed_at=v_at,updated_at=now() WHERE id=v_booking.id RETURNING total_price INTO v_final;
  IF v_final*100 IS DISTINCT FROM (p_operation->>'quoted_total_minor')::numeric THEN
    RAISE EXCEPTION 'OFFLINE_BOOKING_PRICE_CHANGED' USING ERRCODE='22023';
  END IF;
  UPDATE public.rooms r SET status='available',is_available=true,updated_at=now()
    WHERE r.id=v_booking.room_id AND r.status='occupied' AND r.is_active IS TRUE
      AND NOT EXISTS(SELECT 1 FROM public.bookings WHERE room_id=r.id AND id<>v_booking.id AND status='in_progress'::public.booking_status);
  RETURN private.offline_fixed_session_receipt(v_booking.id);
END; $$;
REVOKE ALL ON FUNCTION private.apply_cashier_close_operation(jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.validate_offline_session_snapshot(p_operation jsonb,p_receipt jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_snapshot jsonb:=p_operation->'quoted_session';v_field text;v_started jsonb;
BEGIN
  IF jsonb_typeof(v_snapshot) IS DISTINCT FROM 'object'
    OR NOT v_snapshot ?& ARRAY['room_id','timezone','start_ms','end_ms','started_ms','paid_minor'] THEN
    RAISE EXCEPTION 'OFFLINE_SESSION_SNAPSHOT_REQUIRED' USING ERRCODE='22023';
  END IF;
  FOREACH v_field IN ARRAY ARRAY['room_id','timezone','start_ms','end_ms','paid_minor'] LOOP
    IF v_snapshot->v_field IS DISTINCT FROM p_receipt->v_field THEN
      RAISE EXCEPTION 'OFFLINE_SESSION_SNAPSHOT_CHANGED' USING ERRCODE='22023';
    END IF;
  END LOOP;
  v_started:=CASE WHEN p_receipt->>'started_at' IS NULL THEN 'null'::jsonb
    ELSE to_jsonb(floor(extract(epoch FROM (p_receipt->>'started_at')::timestamptz)*1000)) END;
  IF v_snapshot->'started_ms' IS DISTINCT FROM v_started THEN
    RAISE EXCEPTION 'OFFLINE_SESSION_SNAPSHOT_CHANGED' USING ERRCODE='22023';
  END IF;
END; $$;
REVOKE ALL ON FUNCTION private.validate_offline_session_snapshot(jsonb,jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.apply_cashier_fixed_operation(p_operation jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_result jsonb;
BEGIN
  INSERT INTO private.cashier_sync_context VALUES(txid_current(),(p_operation->>'lounge_id')::uuid,
    auth.uid(),(p_operation->>'permit_id')::uuid);
  INSERT INTO private.cashier_booking_command_context VALUES(txid_current(),(p_operation->>'booking_id')::uuid,p_operation->>'kind');
  CASE p_operation->>'kind'
    WHEN 'reserve' THEN v_result:=private.apply_cashier_reservation_operation(p_operation);
    WHEN 'start' THEN v_result:=private.apply_cashier_start_operation(p_operation);
    WHEN 'close' THEN v_result:=private.apply_cashier_close_operation(p_operation);
    ELSE RAISE EXCEPTION 'OFFLINE_OPERATION_KIND_NOT_IMPLEMENTED' USING ERRCODE='0A000';
  END CASE;
  PERFORM private.validate_offline_session_snapshot(p_operation,v_result);
  DELETE FROM private.cashier_booking_command_context WHERE transaction_id=txid_current();
  DELETE FROM private.cashier_sync_context WHERE transaction_id=txid_current();
  RETURN v_result;
END; $$;
REVOKE ALL ON FUNCTION private.apply_cashier_fixed_operation(jsonb) FROM PUBLIC,anon,authenticated;

-- Reviewed section: offline_canteen_reconciliation.sql
CREATE OR REPLACE FUNCTION private.validate_offline_order_lines(p_operation jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_items jsonb:=p_operation->'payload'->'items';v_quotes jsonb:=p_operation->'quoted_items';
  v_line jsonb;v_quote jsonb;v_index integer;v_id uuid;v_quantity numeric;v_price numeric;v_total numeric;
BEGIN
  IF jsonb_typeof(v_items) IS DISTINCT FROM 'array' OR jsonb_typeof(v_quotes) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'INVALID_OFFLINE_ORDER' USING ERRCODE='22023';
  END IF;
  IF jsonb_array_length(v_items) NOT BETWEEN 1 AND 50 OR jsonb_array_length(v_quotes)<>jsonb_array_length(v_items)
    OR jsonb_typeof(p_operation->'quoted_total_minor') IS DISTINCT FROM 'number' THEN
    RAISE EXCEPTION 'INVALID_OFFLINE_ORDER' USING ERRCODE='22023';
  END IF;
  v_total:=(p_operation->>'quoted_total_minor')::numeric;
  IF v_total<0 OR v_total<>trunc(v_total) OR v_total>9007199254740991 THEN
    RAISE EXCEPTION 'INVALID_OFFLINE_ORDER' USING ERRCODE='22023';
  END IF;
  FOR v_index IN 0..jsonb_array_length(v_items)-1 LOOP
    v_line:=v_items->v_index;v_quote:=v_quotes->v_index;v_id:=(v_line->>'product_id')::uuid;
    IF v_id IS NULL OR jsonb_typeof(v_line->'quantity') IS DISTINCT FROM 'number'
      OR jsonb_typeof(v_quote->'unit_price_minor') IS DISTINCT FROM 'number'
      OR v_quote->'product_id' IS DISTINCT FROM v_line->'product_id'
      OR v_quote->'quantity' IS DISTINCT FROM v_line->'quantity' THEN
      RAISE EXCEPTION 'INVALID_OFFLINE_ORDER' USING ERRCODE='22023';
    END IF;
    v_quantity:=(v_line->>'quantity')::numeric;v_price:=(v_quote->>'unit_price_minor')::numeric;
    IF v_quantity NOT BETWEEN 1 AND 100 OR v_quantity<>trunc(v_quantity)
      OR v_price<0 OR v_price<>trunc(v_price) OR v_price>9007199254740991 THEN
      RAISE EXCEPTION 'INVALID_OFFLINE_ORDER' USING ERRCODE='22023';
    END IF;
  END LOOP;
END; $$;
REVOKE ALL ON FUNCTION private.validate_offline_order_lines(jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.lock_offline_order_booking(p_operation jsonb)
RETURNS public.bookings LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_booking public.bookings%ROWTYPE;
BEGIN
  SELECT * INTO v_booking FROM public.bookings WHERE id=(p_operation->>'booking_id')::uuid FOR UPDATE;
  IF NOT FOUND OR v_booking.lounge_id IS DISTINCT FROM (p_operation->>'lounge_id')::uuid THEN
    RAISE EXCEPTION 'OFFLINE_BOOKING_SCOPE_MISMATCH' USING ERRCODE='42501';
  END IF;
  IF v_booking.status::text<>'in_progress' OR v_booking.is_open_time IS TRUE THEN
    RAISE EXCEPTION 'OFFLINE_ORDER_REQUIRES_FIXED_ACTIVE_SESSION' USING ERRCODE='55000';
  END IF;
  PERFORM private.lock_cash_collection_shift((p_operation->>'shift_id')::uuid,v_booking.lounge_id);
  IF v_booking.shift_id IS DISTINCT FROM (p_operation->>'shift_id')::uuid THEN
    RAISE EXCEPTION 'OFFLINE_BOOKING_SHIFT_MISMATCH' USING ERRCODE='55000';
  END IF;
  IF v_booking.total_price IS NULL OR v_booking.total_price<0
    OR v_booking.total_price::text IN ('NaN','Infinity','-Infinity')
    OR v_booking.total_price<>round(v_booking.total_price,2) THEN
    RAISE EXCEPTION 'INVALID_BOOKING_TOTAL' USING ERRCODE='22023';
  END IF;
  RETURN v_booking;
END; $$;
REVOKE ALL ON FUNCTION private.lock_offline_order_booking(jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.price_offline_order_lines(p_operation jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_line jsonb;v_extra public.extras%ROWTYPE;v_lines jsonb:='[]';v_quantity integer;v_requested integer;
BEGIN
  PERFORM 1 FROM public.extras WHERE id IN
    (SELECT (value->>'product_id')::uuid FROM jsonb_array_elements(p_operation->'quoted_items')) ORDER BY id FOR UPDATE;
  FOR v_line IN SELECT value FROM jsonb_array_elements(p_operation->'quoted_items') LOOP
    SELECT * INTO v_extra FROM public.extras WHERE id=(v_line->>'product_id')::uuid;
    IF NOT FOUND OR v_extra.lounge_id IS DISTINCT FROM (p_operation->>'lounge_id')::uuid
      OR v_extra.is_active IS NOT TRUE OR v_extra.is_available IS NOT TRUE THEN
      RAISE EXCEPTION 'OFFLINE_PRODUCT_UNAVAILABLE' USING ERRCODE='55000';
    END IF;
    IF v_extra.price<0 OR v_extra.price IS NULL OR v_extra.price::text IN ('NaN','Infinity','-Infinity')
      OR v_extra.price<>round(v_extra.price,2) OR v_extra.price*100 IS DISTINCT FROM (v_line->>'unit_price_minor')::numeric THEN
      RAISE EXCEPTION 'OFFLINE_PRODUCT_PRICE_CHANGED' USING ERRCODE='22023';
    END IF;
    v_quantity:=(v_line->>'quantity')::integer;
    SELECT sum((value->>'quantity')::integer) INTO v_requested FROM jsonb_array_elements(p_operation->'quoted_items')
      WHERE (value->>'product_id')::uuid=v_extra.id;
    IF v_extra.track_stock IS NULL OR (v_extra.track_stock AND
      (v_extra.stock_quantity IS NULL OR v_extra.stock_quantity<v_requested)) THEN
      RAISE EXCEPTION 'OFFLINE_INSUFFICIENT_STOCK' USING ERRCODE='55000';
    END IF;
    v_lines:=v_lines||jsonb_build_array(jsonb_build_object('product_id',v_extra.id,'extra_id',v_extra.id,
      'quantity',v_quantity,'price',v_extra.price,'unit_price',v_extra.price,
      'total_price',v_extra.price*v_quantity,'name',v_extra.name));
  END LOOP;
  RETURN v_lines;
END; $$;
REVOKE ALL ON FUNCTION private.price_offline_order_lines(jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.insert_offline_order_lines(p_operation jsonb,p_lines jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_line jsonb;v_extra_id uuid;v_quantity integer;v_price numeric;
BEGIN
  FOR v_line IN SELECT value FROM jsonb_array_elements(p_lines) LOOP
    v_extra_id:=(v_line->>'extra_id')::uuid;v_quantity:=(v_line->>'quantity')::integer;v_price:=(v_line->>'price')::numeric;
    UPDATE public.extras SET stock_quantity=stock_quantity-v_quantity WHERE id=v_extra_id AND track_stock IS TRUE;
    INSERT INTO public.canteen_order_items(order_id,extra_id,quantity,unit_price,total_price,item_name)
      VALUES((p_operation->>'id')::uuid,v_extra_id,v_quantity,v_price,v_price*v_quantity,v_line->>'name');
    INSERT INTO public.booking_items(booking_id,product_id,extra_id,quantity,unit_price,total_price,price,name,note,status)
      VALUES((p_operation->>'booking_id')::uuid,v_extra_id,v_extra_id,v_quantity,v_price,v_price*v_quantity,v_price,
        v_line->>'name',p_operation->'payload'->>'note','pending');
  END LOOP;
END; $$;
REVOKE ALL ON FUNCTION private.insert_offline_order_lines(jsonb,jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.apply_cashier_order_operation(p_operation jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_booking public.bookings%ROWTYPE;v_lines jsonb;v_total numeric;v_paid numeric;v_final numeric;v_status text;
BEGIN
  PERFORM private.validate_offline_order_lines(p_operation);
  v_booking:=private.lock_offline_order_booking(p_operation);
  v_paid:=private.cash_collection_paid_amount(v_booking.id,v_booking.lounge_id,v_booking.payment_status);
  v_lines:=private.price_offline_order_lines(p_operation);
  SELECT sum((value->>'total_price')::numeric) INTO v_total FROM jsonb_array_elements(v_lines);
  IF (v_booking.total_price+v_total)*100 IS DISTINCT FROM (p_operation->>'quoted_total_minor')::numeric THEN
    RAISE EXCEPTION 'OFFLINE_BOOKING_PRICE_CHANGED' USING ERRCODE='22023';
  END IF;
  INSERT INTO public.canteen_orders(id,booking_id,lounge_id,user_id,shift_id,items,total_price,note,status,created_at)
    VALUES((p_operation->>'id')::uuid,v_booking.id,v_booking.lounge_id,v_booking.user_id,
      (p_operation->>'shift_id')::uuid,v_lines,v_total,p_operation->'payload'->>'note','pending',
      (p_operation->>'occurred_at')::timestamptz);
  PERFORM private.insert_offline_order_lines(p_operation,v_lines);
  v_status:=CASE WHEN v_paid=v_booking.total_price+v_total THEN 'paid' WHEN v_paid>0 THEN 'partial' ELSE 'unpaid' END;
  UPDATE public.bookings SET addons_price=coalesce(addons_price,0)+v_total,addons_total=coalesce(addons_price,0)+v_total,
    total_price=v_booking.total_price+v_total,payment_status=v_status,updated_at=now() WHERE id=v_booking.id
    RETURNING total_price INTO v_final;
  IF v_final*100 IS DISTINCT FROM (p_operation->>'quoted_total_minor')::numeric THEN
    RAISE EXCEPTION 'OFFLINE_BOOKING_PRICE_CHANGED' USING ERRCODE='22023';
  END IF;
  RETURN jsonb_build_object('booking_id',v_booking.id,'order_id',(p_operation->>'id')::uuid,
    'lounge_id',v_booking.lounge_id,'items',v_lines,'order_total_minor',v_total*100,
    'total_minor',v_final*100,'paid_minor',v_paid*100,'due_minor',(v_final-v_paid)*100,'payment_status',v_status);
END; $$;
REVOKE ALL ON FUNCTION private.apply_cashier_order_operation(jsonb) FROM PUBLIC,anon,authenticated;

-- Reviewed section: offline_cash_reconciliation.sql
CREATE TABLE IF NOT EXISTS private.cashier_operation_receipts (
  operation_id uuid PRIMARY KEY,
  permit_id uuid NOT NULL,
  sequence bigint NOT NULL CHECK(sequence>0),
  actor_id uuid NOT NULL,
  lounge_id uuid NOT NULL,
  request jsonb NOT NULL,
  result jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(permit_id,sequence)
);
ALTER TABLE private.cashier_operation_receipts ENABLE ROW LEVEL SECURITY;
CREATE UNIQUE INDEX IF NOT EXISTS cashier_receipts_lounge_sequence_key ON private.cashier_operation_receipts(lounge_id,sequence);
REVOKE ALL ON private.cashier_operation_receipts FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.validate_cashier_operation(p_operation jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_id uuid;v_sequence numeric;v_time timestamptz;v_name text;
BEGIN
  IF p_operation IS NULL OR jsonb_typeof(p_operation)<>'object' OR length(p_operation::text)>65536
    OR jsonb_typeof(p_operation->'payload') IS DISTINCT FROM 'object'
    OR jsonb_typeof(p_operation->'sequence') IS DISTINCT FROM 'number' THEN
    RAISE EXCEPTION 'INVALID_OFFLINE_OPERATION' USING ERRCODE='22023';
  END IF;
  FOREACH v_name IN ARRAY ARRAY['id','actor_id','lounge_id','device_id','permit_id','booking_id','shift_id'] LOOP
    v_id:=(p_operation->>v_name)::uuid;
    IF v_id IS NULL THEN RAISE EXCEPTION 'INVALID_OFFLINE_OPERATION' USING ERRCODE='22023'; END IF;
  END LOOP;
  v_sequence:=(p_operation->>'sequence')::numeric;
  IF v_sequence<=0 OR v_sequence<>trunc(v_sequence) OR v_sequence>9007199254740991
    OR (p_operation->>'occurred_at') IS NULL
    OR (p_operation->>'occurred_at')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}T.*(Z|[+-][0-9]{2}:[0-9]{2})$' THEN
    RAISE EXCEPTION 'INVALID_OFFLINE_OPERATION' USING ERRCODE='22023';
  END IF;
  v_time:=(p_operation->>'occurred_at')::timestamptz;
  IF NOT isfinite(v_time) THEN RAISE EXCEPTION 'INVALID_OFFLINE_OPERATION' USING ERRCODE='22023'; END IF;
  IF p_operation->>'kind' IS NULL OR p_operation->>'kind' NOT IN ('collectCash','addItems','reserve','start','close') THEN
    RAISE EXCEPTION 'OFFLINE_OPERATION_KIND_NOT_IMPLEMENTED' USING ERRCODE='0A000';
  END IF;
END; $$;
REVOKE ALL ON FUNCTION private.validate_cashier_operation(jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.assert_offline_cashier_permission(p_operation jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_permission text:=CASE WHEN p_operation->>'kind'='reserve' THEN 'bookings.manage' ELSE 'sessions_control' END;
BEGIN
  IF p_operation->>'kind'='collectCash' THEN
    PERFORM private.assert_cash_collector(auth.uid(),(p_operation->>'lounge_id')::uuid);
    RETURN;
  END IF;
  PERFORM 1 FROM public.profiles p JOIN auth.users u ON u.id=p.id
    WHERE p.id=auth.uid() AND p.is_active IS TRUE AND p.is_banned IS FALSE FOR SHARE OF p,u;
  IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_NOT_ELIGIBLE' USING ERRCODE='42501'; END IF;
  IF public.is_super_admin() IS NOT TRUE AND
    public.has_lounge_permission((p_operation->>'lounge_id')::uuid,v_permission) IS NOT TRUE THEN
    RAISE EXCEPTION 'OFFLINE_SESSION_PERMISSION_DENIED' USING ERRCODE='42501';
  END IF;
  PERFORM 1 FROM public.lounges WHERE id=(p_operation->>'lounge_id')::uuid AND is_active IS TRUE AND status='active' FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'LOUNGE_NOT_APPROVED' USING ERRCODE='42501'; END IF;
END; $$;
REVOKE ALL ON FUNCTION private.assert_offline_cashier_permission(jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.lock_cashier_operation_writer(p_operation jsonb)
RETURNS private.cashier_writer_authorities LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_writer private.cashier_writer_authorities%ROWTYPE;v_permit private.cashier_writer_permits%ROWTYPE;
  v_time timestamptz:=(p_operation->>'occurred_at')::timestamptz;v_permission text;
BEGIN
  IF auth.uid() IS DISTINCT FROM (p_operation->>'actor_id')::uuid THEN
    RAISE EXCEPTION 'OFFLINE_ACTOR_MISMATCH' USING ERRCODE='42501';
  END IF;
  PERFORM private.lock_cashier_lounge((p_operation->>'lounge_id')::uuid);
  PERFORM private.assert_offline_cashier_permission(p_operation);
  SELECT * INTO v_writer FROM private.cashier_writer_authorities
    WHERE lounge_id=(p_operation->>'lounge_id')::uuid FOR UPDATE;
  IF NOT FOUND OR v_writer.actor_id IS DISTINCT FROM auth.uid()
    OR v_writer.device_id IS DISTINCT FROM (p_operation->>'device_id')::uuid THEN
    RAISE EXCEPTION 'OFFLINE_WRITER_MISMATCH' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_permit FROM private.cashier_writer_permits WHERE permit_id=(p_operation->>'permit_id')::uuid FOR SHARE;
  IF NOT FOUND OR (v_permit.lounge_id,v_permit.actor_id,v_permit.device_id)
    IS DISTINCT FROM (v_writer.lounge_id,v_writer.actor_id,v_writer.device_id) THEN
    RAISE EXCEPTION 'OFFLINE_WRITER_MISMATCH' USING ERRCODE='42501';
  END IF;
  v_permission:=CASE p_operation->>'kind' WHEN 'reserve' THEN 'bookings.manage'
    WHEN 'collectCash' THEN 'billing_checkout' ELSE 'sessions_control' END;
  IF v_permit.permissions->v_permission IS DISTINCT FROM 'true'::jsonb THEN
    RAISE EXCEPTION 'OFFLINE_PERMISSION_NOT_ISSUED' USING ERRCODE='42501';
  END IF;
  IF v_time<v_permit.issued_at OR v_time>=v_permit.expires_at
    OR v_time>statement_timestamp()+interval '5 minutes' THEN
    RAISE EXCEPTION 'OFFLINE_OPERATION_OUTSIDE_PERMIT' USING ERRCODE='22023';
  END IF;
  RETURN v_writer;
END; $$;
REVOKE ALL ON FUNCTION private.lock_cashier_operation_writer(jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.apply_cashier_cash_operation(p_operation jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_lounge uuid;
BEGIN
  SELECT lounge_id INTO v_lounge FROM public.bookings WHERE id=(p_operation->>'booking_id')::uuid;
  IF NOT FOUND OR v_lounge IS DISTINCT FROM (p_operation->>'lounge_id')::uuid THEN
    RAISE EXCEPTION 'OFFLINE_BOOKING_SCOPE_MISMATCH' USING ERRCODE='42501';
  END IF;
  RETURN public.collect_booking_cash_partial((p_operation->>'booking_id')::uuid,
    (p_operation->>'shift_id')::uuid,(p_operation->'payload'->>'amount_minor')::numeric,
    (p_operation->>'id')::uuid);
END; $$;
REVOKE ALL ON FUNCTION private.apply_cashier_cash_operation(jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.apply_offline_cashier_operation(p_operation jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  v_writer private.cashier_writer_authorities%ROWTYPE;
  v_receipt private.cashier_operation_receipts%ROWTYPE;
  v_result jsonb;v_code text;v_sequence bigint;v_id uuid;v_lounge uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='28000'; END IF;
  PERFORM private.validate_cashier_operation(p_operation);
  v_writer:=private.lock_cashier_operation_writer(p_operation);
  v_sequence:=(p_operation->>'sequence')::bigint;v_id:=(p_operation->>'id')::uuid;v_lounge:=v_writer.lounge_id;
  SELECT * INTO v_receipt FROM private.cashier_operation_receipts WHERE operation_id=v_id;
  IF FOUND THEN
    IF v_receipt.request IS DISTINCT FROM p_operation THEN
      RAISE EXCEPTION 'OFFLINE_OPERATION_REPLAY_CONFLICT' USING ERRCODE='22023';
    END IF;
    RETURN CASE WHEN v_receipt.result->>'status'='applied' THEN
      v_receipt.result||jsonb_build_object('status','replayed') ELSE v_receipt.result END;
  END IF;
  IF v_sequence<>v_writer.last_applied_sequence+1 THEN
    RETURN jsonb_build_object('operation_id',v_id,'lounge_id',v_lounge,'sequence',v_sequence,
      'status','conflict','code','OFFLINE_SEQUENCE_GAP');
  END IF;
  IF EXISTS (SELECT 1 FROM private.cashier_operation_receipts
    WHERE lounge_id=v_lounge AND sequence=v_sequence) THEN
    RETURN jsonb_build_object('operation_id',v_id,'lounge_id',v_lounge,'sequence',v_sequence,
      'status','conflict','code','OFFLINE_SEQUENCE_BLOCKED');
  END IF;
  BEGIN
    IF p_operation->>'kind'='collectCash' THEN
      v_result:=jsonb_build_object('financial_receipt',private.apply_cashier_cash_operation(p_operation));
    ELSIF p_operation->>'kind'='addItems' THEN
      v_result:=jsonb_build_object('order_receipt',private.apply_cashier_order_operation(p_operation));
    ELSE
      v_result:=jsonb_build_object('session_receipt',private.apply_cashier_fixed_operation(p_operation));
    END IF;
    v_result:=v_result||jsonb_build_object('operation_id',v_id,'lounge_id',v_lounge,'sequence',v_sequence,'status','applied');
  EXCEPTION WHEN SQLSTATE '22023' OR SQLSTATE '55000' OR SQLSTATE '42501' OR SQLSTATE 'P0002' THEN
    GET STACKED DIAGNOSTICS v_code=MESSAGE_TEXT;
    v_result:=jsonb_build_object('operation_id',v_id,'lounge_id',v_lounge,'sequence',v_sequence,
      'status','conflict','code',v_code);
  WHEN exclusion_violation THEN
    v_result:=jsonb_build_object('operation_id',v_id,'lounge_id',v_lounge,'sequence',v_sequence,
      'status','conflict','code','OFFLINE_ROOM_CONFLICT');
  WHEN unique_violation THEN
    v_result:=jsonb_build_object('operation_id',v_id,'lounge_id',v_lounge,'sequence',v_sequence,
      'status','conflict','code','OFFLINE_RECORD_ID_CONFLICT');
  END;
  INSERT INTO private.cashier_operation_receipts(operation_id,permit_id,sequence,actor_id,lounge_id,request,result)
    VALUES(v_id,(p_operation->>'permit_id')::uuid,v_sequence,auth.uid(),v_lounge,p_operation,v_result);
  IF v_result->>'status'='applied' THEN
    UPDATE private.cashier_writer_authorities SET last_applied_sequence=v_sequence WHERE lounge_id=v_lounge;
  END IF;
  RETURN v_result;
END; $$;
REVOKE ALL ON FUNCTION public.apply_offline_cashier_operation(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.apply_offline_cashier_operation(jsonb) TO authenticated;

-- Reviewed section: offline_cashier_bootstrap.sql
CREATE OR REPLACE FUNCTION private.offline_minor_amount(p_amount numeric)
RETURNS bigint LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF p_amount IS NULL OR p_amount::text IN ('NaN','Infinity','-Infinity')
    OR p_amount < 0 OR p_amount*100 <> trunc(p_amount*100)
    OR p_amount*100 > 9007199254740991 THEN
    RAISE EXCEPTION 'INVALID_OFFLINE_FINANCIAL_SNAPSHOT' USING ERRCODE='22023';
  END IF;
  RETURN (p_amount*100)::bigint;
END; $$;
REVOKE ALL ON FUNCTION private.offline_minor_amount(numeric)
  FROM PUBLIC,anon,authenticated,service_role,supabase_auth_admin;

CREATE OR REPLACE FUNCTION public.bootstrap_offline_cashier(
  p_lounge_id uuid, p_device_id uuid, p_online boolean DEFAULT true
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_authority jsonb;
  v_shift_id uuid;
  v_shift_count integer;
  v_timezone text;
  v_from bigint;
  v_until bigint;
  v_blind_cash boolean;
  v_menu_view boolean;
  v_snapshot jsonb;
BEGIN
  -- refresh performs canonical active/unbanned Auth and scoped permission checks,
  -- then acquires the same lounge mutex as booking/reconciliation mutations.
  -- An error later in bootstrap rolls back a first writer claim as well.
  v_authority := public.refresh_cashier_writer(p_lounge_id,p_device_id,p_online);
  IF public.is_super_admin() IS NOT TRUE
    AND public.has_lounge_permission(p_lounge_id,'bookings.view') IS NOT TRUE THEN
    RAISE EXCEPTION 'OFFLINE_BOOTSTRAP_READ_PERMISSION_DENIED' USING ERRCODE='42501';
  END IF;
  v_timezone := v_authority->>'timezone';
  IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_timezone_names WHERE name=v_timezone) THEN
    RAISE EXCEPTION 'INVALID_LOUNGE_TIMEZONE' USING ERRCODE='22023';
  END IF;
  SELECT count(*) INTO v_shift_count FROM public.shifts
    WHERE lounge_id=p_lounge_id AND coalesce(cashier_id,staff_user_id)=v_actor
      AND status='open' AND closed_at IS NULL;
  IF v_shift_count<>1 THEN
    RAISE EXCEPTION 'OFFLINE_BOOTSTRAP_REQUIRES_ONE_OWN_SHIFT' USING ERRCODE='55000';
  END IF;
  SELECT id INTO v_shift_id FROM public.shifts
    WHERE lounge_id=p_lounge_id AND coalesce(cashier_id,staff_user_id)=v_actor
      AND status='open' AND closed_at IS NULL FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'OFFLINE_BOOTSTRAP_REQUIRES_ONE_OWN_SHIFT' USING ERRCODE='55000';
  END IF;
  v_from := floor((v_authority->>'server_time_ms')::numeric/60000)::bigint*60000;
  v_until := (v_authority->>'expires_ms')::bigint;
  v_blind_cash := public.is_super_admin() IS TRUE OR
    public.has_lounge_permission(p_lounge_id,'shifts_view_blind_cash') IS TRUE;
  v_menu_view := public.is_super_admin() IS TRUE OR
    public.has_lounge_permission(p_lounge_id,'menu_view') IS TRUE;

  -- A single SQL statement gives resources, capacity and receipts one MVCC
  -- snapshot. Do not lock rooms then bookings: existing online start paths take
  -- booking locks first, so that would introduce a reverse-order deadlock.
  WITH room_rows AS MATERIALIZED (
    SELECT r.*, coalesce(r.hourly_rate_single,r.hourly_rate,50) AS single_rate,
      CASE WHEN coalesce(r.hourly_rate_multi,0)>0 THEN r.hourly_rate_multi
        ELSE coalesce(r.hourly_rate_single,r.hourly_rate,50) END AS multi_rate
    FROM public.rooms r WHERE r.lounge_id=p_lounge_id
  ), intervals AS MATERIALIZED (
    SELECT m.room_id,floor(extract(epoch FROM m.scheduled_at)*1000)::bigint AS start_ms,
      ceil(extract(epoch FROM m.scheduled_end_at)*1000)::bigint AS end_ms
    FROM public.tournament_matches m JOIN room_rows r ON r.id=m.room_id
    WHERE m.status<>'cancelled' AND m.scheduled_at IS NOT NULL
      AND m.scheduled_end_at>m.scheduled_at
      AND extract(epoch FROM m.scheduled_at)*1000<v_until
      AND extract(epoch FROM m.scheduled_end_at)*1000>v_from
    UNION ALL
    SELECT h.room_id,floor(extract(epoch FROM (h.start_at AT TIME ZONE v_timezone))*1000)::bigint,
      ceil(extract(epoch FROM (h.end_at AT TIME ZONE v_timezone))*1000)::bigint
    FROM public.booking_holds h JOIN room_rows r ON r.id=h.room_id
    WHERE h.lounge_id=p_lounge_id AND h.released_at IS NULL
      AND h.expires_at>statement_timestamp() AND h.end_at>h.start_at
      AND extract(epoch FROM (h.start_at AT TIME ZONE v_timezone))*1000<v_until
      AND extract(epoch FROM (h.end_at AT TIME ZONE v_timezone))*1000>v_from
  ), booking_rows AS MATERIALIZED (
    SELECT b.*, floor(extract(epoch FROM ((b.date+b.start_time) AT TIME ZONE v_timezone))*1000)::bigint AS start_ms,
      ceil(extract(epoch FROM (((b.date+b.end_time)+CASE WHEN b.end_time<=b.start_time
        THEN interval '1 day' ELSE interval '0' END) AT TIME ZONE v_timezone))*1000)::bigint AS end_ms,
      ceil(extract(epoch FROM (upper(b.cashier_capacity_period) AT TIME ZONE v_timezone))*1000)::bigint AS capacity_end_ms,
      coalesce(p.amount,0) AS paid_amount,
      (p.id IS NULL OR (p.status='completed' AND p.payment_method='cash'
        AND p.lounge_id=p_lounge_id AND p.payout_id IS NULL
        AND p.amount=(SELECT coalesce(sum(sp.amount),0) FROM public.shift_payments sp
          WHERE sp.booking_id=b.id AND sp.lounge_id=p_lounge_id AND sp.payment_method='cash')))
        AND (p.id IS NOT NULL OR b.payment_status='unpaid') AS payment_supported
    FROM public.bookings b JOIN room_rows r ON r.id=b.room_id
    LEFT JOIN public.payments p ON p.booking_id=b.id
    WHERE b.lounge_id=p_lounge_id AND b.date IS NOT NULL
      AND b.start_time IS NOT NULL AND b.end_time IS NOT NULL
      AND b.status NOT IN ('cancelled','rejected')
  ), scoped_bookings AS MATERIALIZED (
    SELECT * FROM booking_rows b WHERE b.status='in_progress'
      OR (b.start_ms<v_until AND b.end_ms>v_from)
      OR (b.shift_id=v_shift_id AND b.total_price>b.paid_amount)
  )
  SELECT jsonb_build_object(
    'protocol_version',2,'complete',true,'authority',v_authority,
    'coverage',jsonb_build_object('from_ms',v_from,'until_ms',v_until),
    'shift',jsonb_build_object('id',v_shift_id,'actor_id',v_actor,
      'lounge_id',p_lounge_id,'status','open','cash_total_visible',v_blind_cash,
      'collected_cash_minor',CASE WHEN v_blind_cash THEN private.offline_minor_amount(
        (SELECT coalesce(sum(amount),0) FROM public.shift_payments
          WHERE shift_id=v_shift_id AND lounge_id=p_lounge_id AND payment_method='cash')) ELSE 0 END),
    'rooms',coalesce((SELECT jsonb_object_agg(r.id::text,jsonb_build_object(
      'id',r.id,'lounge_id',r.lounge_id,'name',r.name,
      'is_active',r.is_active IS TRUE,'is_available',r.is_available IS TRUE,'status',r.status,
      'single_hour_minor',private.offline_minor_amount(r.single_rate),
      'multi_hour_minor',private.offline_minor_amount(r.multi_rate),
      'offline_supported',coalesce(r.pricing_model,'single_multi_hour')='single_multi_hour'
        AND r.single_rate>0 AND r.multi_rate>0,
      'blocked_intervals',coalesce((SELECT jsonb_agg(jsonb_build_object(
        'start_ms',i.start_ms,'end_ms',i.end_ms)) FROM intervals i WHERE i.room_id=r.id),'[]'::jsonb)
    )) FROM room_rows r),'{}'::jsonb),
    'products',coalesce((SELECT jsonb_object_agg(e.id::text,jsonb_build_object(
      'id',e.id,'lounge_id',e.lounge_id,'name',e.name,
      'is_active',e.is_active IS TRUE,'is_available',e.is_available IS TRUE,
      'track_stock',e.track_stock IS TRUE,'stock_quantity',e.stock_quantity,
      'unit_price_minor',private.offline_minor_amount(e.price)
    )) FROM public.extras e WHERE e.lounge_id=p_lounge_id AND v_menu_view),'{}'::jsonb),
    'bookings',coalesce((SELECT jsonb_object_agg(b.id::text,jsonb_build_object(
      'id',b.id,'lounge_id',b.lounge_id,'room_id',b.room_id,'shift_id',b.shift_id,
      'customer_name',b.user_name,'customer_phone',b.user_phone,'play_mode',b.play_mode,
      'timezone',v_timezone,'start_ms',b.start_ms,'end_ms',b.end_ms,
      'capacity_end_ms',coalesce(b.capacity_end_ms,b.start_ms),
      'started_ms',floor(extract(epoch FROM b.actual_start_time)*1000)::bigint,
      'total_minor',private.offline_minor_amount(b.total_price),
      'paid_minor',private.offline_minor_amount(b.paid_amount),
      'payment_status',CASE WHEN b.paid_amount=b.total_price THEN 'paid'
        WHEN b.paid_amount>0 THEN 'partial' ELSE 'unpaid' END,
      'status',b.status,'sync_status','synced',
      'offline_supported',b.is_open_time IS NOT TRUE AND b.payment_supported
        AND b.shift_id=v_shift_id AND b.play_mode IN ('single','multi')
        AND coalesce(b.extra_controllers,0)=0
        AND coalesce(b.discount_amount,0)=0 AND coalesce(b.discount_percentage,0)=0,
      'items',coalesce((SELECT jsonb_agg(jsonb_build_object('id',o.id,'items',o.items,
        'total_minor',private.offline_minor_amount(o.total_price)))
        FROM public.canteen_orders o WHERE o.booking_id=b.id AND o.lounge_id=p_lounge_id
          AND o.status<>'cancelled'),'[]'::jsonb)
    )) FROM scoped_bookings b),'{}'::jsonb)
  ) INTO v_snapshot;

  -- Never label a truncated oversized snapshot as complete.
  IF octet_length(v_snapshot::text)>8388608 THEN
    RAISE EXCEPTION 'OFFLINE_BOOTSTRAP_TOO_LARGE' USING ERRCODE='54000';
  END IF;
  RETURN v_snapshot;
END; $$;
REVOKE ALL ON FUNCTION public.bootstrap_offline_cashier(uuid,uuid,boolean)
  FROM PUBLIC,anon,service_role,supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.bootstrap_offline_cashier(uuid,uuid,boolean) TO authenticated;

-- Supabase default system-role grants must not expose the new internal protocol.
REVOKE ALL ON FUNCTION private.apply_cashier_cash_operation(jsonb),
  private.apply_cashier_close_operation(jsonb),
  private.apply_cashier_fixed_operation(jsonb),
  private.apply_cashier_order_operation(jsonb),
  private.apply_cashier_reservation_operation(jsonb),
  private.apply_cashier_start_operation(jsonb),
  private.apply_partial_cash_collection(uuid,uuid,numeric),
  private.assert_cash_collector(uuid,uuid),
  private.assert_offline_cashier_permission(jsonb),
  private.cash_collection_paid_amount(uuid,uuid,text),
  private.cashier_effective_permissions(uuid),
  private.cashier_sync_permit_matches_writer(uuid,uuid,uuid),
  private.guard_cashier_capacity_fields(),
  private.guard_cashier_online_booking(),
  private.guard_cashier_permit_immutability(),
  private.guard_partial_cash_payment(),
  private.insert_offline_order_lines(jsonb,jsonb),
  private.lock_cash_collection_booking(uuid),
  private.lock_cash_collection_shift(uuid,uuid),
  private.lock_cashier_lounge(uuid),
  private.lock_cashier_operation_writer(jsonb),
  private.lock_offline_booking_room(uuid,uuid),
  private.lock_offline_fixed_session(jsonb),
  private.lock_offline_order_booking(jsonb),
  private.offline_booking_interval(jsonb),
  private.offline_fixed_session_receipt(uuid),
  private.offline_minor_amount(numeric),
  private.price_offline_order_lines(jsonb),
  private.quote_offline_fixed_booking(jsonb,jsonb),
  private.validate_cashier_operation(jsonb),
  private.validate_offline_order_lines(jsonb),
  private.validate_offline_session_snapshot(jsonb,jsonb)
  FROM service_role,supabase_auth_admin;
REVOKE ALL ON TABLE private.cash_collection_context,
  private.cash_collection_receipts,
  private.cashier_booking_command_context,
  private.cashier_operation_receipts,
  private.cashier_sync_context,
  private.cashier_writer_authorities,
  private.cashier_writer_permits
  FROM service_role,supabase_auth_admin;
REVOKE ALL ON FUNCTION public.refresh_cashier_writer(uuid,uuid,boolean),
  public.apply_offline_cashier_operation(jsonb),
  public.collect_booking_cash_partial(uuid,uuid,numeric,uuid),
  public.get_lounge_online_availability(uuid)
  FROM service_role,supabase_auth_admin;
NOTIFY pgrst,'reload schema';
COMMIT;
