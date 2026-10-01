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

CREATE OR REPLACE FUNCTION public.refresh_cashier_writer(
  p_lounge_id uuid, p_device_id uuid, p_online boolean DEFAULT true
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_profile public.profiles%ROWTYPE;
  v_lounge public.lounges%ROWTYPE;
  v_writer private.cashier_writer_authorities%ROWTYPE;
  v_now timestamptz := statement_timestamp();
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='28000'; END IF;
  IF p_device_id IS NULL OR p_lounge_id IS NULL OR p_online IS NULL THEN
    RAISE EXCEPTION 'INVALID_CASHIER_WRITER_REQUEST' USING ERRCODE='22023';
  END IF;
  SELECT p.* INTO v_profile FROM public.profiles p JOIN auth.users u ON u.id=p.id WHERE p.id=v_actor;
  IF NOT FOUND OR v_profile.is_active IS NOT TRUE OR v_profile.is_banned IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'ACCOUNT_NOT_ELIGIBLE' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_lounge FROM public.lounges WHERE id=p_lounge_id FOR SHARE;
  IF NOT FOUND OR v_lounge.status IS DISTINCT FROM 'active' OR v_lounge.is_active IS NOT TRUE THEN
    RAISE EXCEPTION 'LOUNGE_NOT_APPROVED' USING ERRCODE='42501';
  END IF;
  IF public.is_super_admin() IS NOT TRUE AND public.has_lounge_permission(p_lounge_id,'sessions_control') IS NOT TRUE THEN
    RAISE EXCEPTION 'CASHIER_WRITER_PERMISSION_DENIED' USING ERRCODE='42501';
  END IF;
  INSERT INTO private.cashier_writer_authorities(lounge_id,actor_id,device_id,permit_expires_at,heartbeat_expires_at)
    VALUES(p_lounge_id,v_actor,p_device_id,v_now+interval '24 hours',v_now)
    ON CONFLICT(lounge_id) DO NOTHING;
  SELECT * INTO STRICT v_writer FROM private.cashier_writer_authorities WHERE lounge_id=p_lounge_id FOR UPDATE;
  -- Losing a heartbeat never authorizes another independent offline writer.
  IF v_writer.actor_id<>v_actor OR v_writer.device_id<>p_device_id THEN
    RAISE EXCEPTION 'CASHIER_WRITER_ALREADY_ASSIGNED' USING ERRCODE='55000';
  END IF;
  UPDATE private.cashier_writer_authorities SET
    permit_expires_at=v_now+interval '24 hours',
    heartbeat_expires_at=CASE WHEN p_online THEN v_now+interval '90 seconds' ELSE v_now END,
    online_requested=p_online, updated_at=v_now
  WHERE lounge_id=p_lounge_id RETURNING * INTO v_writer;
  RETURN jsonb_build_object(
    'actor_id',v_actor,'lounge_id',p_lounge_id,'device_id',p_device_id,'permit_id',v_writer.permit_id,
    'profile_active',true,'profile_banned',false,'lounge_status',v_lounge.status,'lounge_active',true,
    'offline_enabled',true,'issued_ms',floor(extract(epoch FROM v_writer.issued_at)*1000)::bigint,
    'expires_ms',floor(extract(epoch FROM v_writer.permit_expires_at)*1000)::bigint,
    'heartbeat_expires_at',v_writer.heartbeat_expires_at,
    'last_applied_sequence',v_writer.last_applied_sequence,
    'permissions',jsonb_build_object(
      'bookings.manage',public.has_lounge_permission(p_lounge_id,'bookings.manage') IS TRUE,
      'sessions_control',public.has_lounge_permission(p_lounge_id,'sessions_control') IS TRUE,
      'billing_checkout',public.has_lounge_permission(p_lounge_id,'billing_checkout') IS TRUE
    )
  );
END;
$function$;
REVOKE ALL ON FUNCTION public.refresh_cashier_writer(uuid,uuid,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.refresh_cashier_writer(uuid,uuid,boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_lounge_online_availability(p_lounge_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.lounges AS lounge
    LEFT JOIN private.cashier_writer_authorities AS writer ON writer.lounge_id=lounge.id
    WHERE lounge.id=p_lounge_id AND lounge.status='active'
      AND lounge.is_active IS TRUE AND lounge.is_open IS TRUE
      AND (writer.lounge_id IS NULL OR (
        writer.online_requested IS TRUE
        AND writer.heartbeat_expires_at>statement_timestamp()
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
  IF EXISTS (SELECT 1 FROM private.cashier_writer_authorities WHERE lounge_id=NEW.lounge_id)
     AND public.get_lounge_online_availability(NEW.lounge_id) IS NOT TRUE THEN
    IF NOT EXISTS (
      SELECT 1 FROM private.cashier_sync_context AS context
      JOIN private.cashier_writer_authorities AS writer ON writer.lounge_id=context.lounge_id
      JOIN public.profiles AS profile ON profile.id=context.actor_id
      JOIN auth.users AS identity ON identity.id=profile.id
      JOIN public.lounges AS lounge ON lounge.id=writer.lounge_id
      WHERE context.transaction_id=txid_current() AND context.actor_id=auth.uid()
        AND context.actor_id=writer.actor_id AND context.permit_id=writer.permit_id
        AND context.lounge_id=NEW.lounge_id AND profile.is_active IS TRUE
        AND profile.is_banned IS FALSE AND lounge.status='active' AND lounge.is_active IS TRUE
        AND public.has_lounge_permission(NEW.lounge_id,'bookings.manage') IS TRUE
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
