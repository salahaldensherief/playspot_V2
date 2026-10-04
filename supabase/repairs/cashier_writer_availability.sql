-- Coordinated-release source only. Not applied to any hosted database.
BEGIN;
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
COMMIT;
