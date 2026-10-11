BEGIN;

-- Every still-replayable permit in the current writer generation reserves its
-- own coverage. A missing heartbeat does not reserve unrelated future dates.
CREATE OR REPLACE FUNCTION private.online_booking_outside_offline_coverage(p_lounge_id uuid,p_start timestamp without time zone)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
  SELECT COALESCE((SELECT (p_start AT TIME ZONE l.timezone)>=GREATEST(w.permit_expires_at,
    COALESCE((SELECT max(p.expires_at) FROM private.cashier_writer_permits p
      JOIN private.cashier_permit_generations g ON g.permit_id=p.permit_id
      WHERE p.lounge_id=w.lounge_id AND p.actor_id=w.actor_id AND p.device_id=w.device_id
        AND g.writer_generation=w.writer_generation),w.permit_expires_at))
    FROM private.cashier_writer_authorities w JOIN public.lounges l ON l.id=w.lounge_id
    WHERE w.lounge_id=p_lounge_id AND w.released_at IS NULL),false);
$$;
REVOKE ALL ON FUNCTION private.online_booking_outside_offline_coverage(uuid,timestamp without time zone)
  FROM PUBLIC,anon,authenticated,service_role,supabase_auth_admin;

CREATE OR REPLACE FUNCTION private.guard_cashier_online_hold()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_lounge uuid;
BEGIN
 IF NEW.released_at IS NOT NULL THEN RETURN NEW; END IF;
 SELECT lounge_id INTO v_lounge FROM public.rooms WHERE id=NEW.room_id;
 IF NOT FOUND OR NEW.lounge_id IS DISTINCT FROM v_lounge THEN
   RAISE EXCEPTION 'BOOKING_ROOM_SCOPE_MISMATCH' USING ERRCODE='42501';
 END IF;
 IF current_setting('transaction_isolation')<>'read committed' THEN
   RAISE EXCEPTION 'CASHIER_REQUIRES_READ_COMMITTED' USING ERRCODE='25001';
 END IF;
 IF NOT pg_catalog.pg_try_advisory_xact_lock(pg_catalog.hashtextextended('cashier-online:'||v_lounge::text,0)) THEN
   RAISE EXCEPTION 'CASHIER_WRITER_BUSY_RETRY' USING ERRCODE='55P03';
 END IF;
 PERFORM 1 FROM private.cashier_writer_authorities WHERE lounge_id=v_lounge FOR SHARE NOWAIT;
 IF EXISTS(SELECT 1 FROM private.cashier_writer_authorities WHERE lounge_id=v_lounge)
   AND public.get_lounge_online_availability(v_lounge) IS NOT TRUE
   AND private.online_booking_outside_offline_coverage(v_lounge,NEW.start_at) IS NOT TRUE THEN
   RAISE EXCEPTION 'LOUNGE_OFFLINE' USING ERRCODE='55000';
 END IF;
 RETURN NEW;
END; $function$;

REVOKE ALL ON FUNCTION private.guard_cashier_online_hold() FROM PUBLIC,anon,authenticated,service_role,supabase_auth_admin;

CREATE OR REPLACE FUNCTION private.guard_cashier_online_booking()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
     AND public.get_lounge_online_availability(NEW.lounge_id) IS NOT TRUE
     AND private.online_booking_outside_offline_coverage(NEW.lounge_id,NEW.date+NEW.start_time) IS NOT TRUE THEN
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

REVOKE ALL ON FUNCTION private.guard_cashier_online_booking() FROM PUBLIC,anon,authenticated,service_role,supabase_auth_admin;

CREATE OR REPLACE FUNCTION private.offline_booking_interval(p_operation jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_start numeric;v_end numeric;v_start_at timestamptz;v_end_at timestamptz;v_start_local timestamp;v_end_local timestamp;v_timezone text;v_permit private.cashier_writer_permits%ROWTYPE;
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
  SELECT * INTO v_permit FROM private.cashier_writer_permits
    WHERE permit_id=(p_operation->>'permit_id')::uuid
      AND lounge_id=(p_operation->>'lounge_id')::uuid
      AND actor_id=(p_operation->>'actor_id')::uuid AND device_id=(p_operation->>'device_id')::uuid;
  IF NOT FOUND OR v_start_at<v_permit.issued_at OR v_end_at>v_permit.expires_at THEN
    RAISE EXCEPTION 'OFFLINE_BOOKING_OUTSIDE_PERMIT_COVERAGE' USING ERRCODE='22023';
  END IF;
  v_start_local:=v_start_at AT TIME ZONE v_timezone;v_end_local:=v_end_at AT TIME ZONE v_timezone;
  IF v_start_local AT TIME ZONE v_timezone IS DISTINCT FROM v_start_at
    OR v_end_local AT TIME ZONE v_timezone IS DISTINCT FROM v_end_at
    OR v_end_local-v_start_local IS DISTINCT FROM v_end_at-v_start_at THEN
    RAISE EXCEPTION 'OFFLINE_DST_INTERVAL_REQUIRES_REVIEW' USING ERRCODE='22023';
  END IF;
  RETURN jsonb_build_object('start',v_start_local,'end',v_end_local,'timezone',v_timezone,'minutes',((v_end-v_start)/60000)::integer);
END; $function$;

REVOKE ALL ON FUNCTION private.offline_booking_interval(jsonb) FROM PUBLIC,anon,authenticated,service_role,supabase_auth_admin;
CREATE OR REPLACE FUNCTION public.get_lounge_operating_status(p_lounge_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_lounge public.lounges%ROWTYPE; v_online boolean; v_fault boolean;v_boundary timestamptz;v_future_date date;v_today date;
BEGIN
 SELECT * INTO v_lounge FROM public.lounges WHERE id=p_lounge_id AND status='active' AND is_active IS TRUE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','unavailable','can_book_online',false,'contact_phone',NULL); END IF;
 v_online:=public.get_lounge_online_availability(p_lounge_id);
 v_fault:=v_lounge.is_open IS TRUE AND NOT v_online
   AND EXISTS(SELECT 1 FROM public.shifts WHERE lounge_id=p_lounge_id AND status='open' AND closed_at IS NULL)
   AND EXISTS(SELECT 1 FROM private.cashier_writer_authorities w
     JOIN public.profiles p ON p.id=w.actor_id JOIN auth.users u ON u.id=p.id
     WHERE w.lounge_id=p_lounge_id AND p.is_active IS TRUE AND p.is_banned IS FALSE
       AND (w.online_requested IS FALSE OR w.heartbeat_expires_at<=clock_timestamp()));
 v_today := (now() AT TIME ZONE v_lounge.timezone)::date;
 IF v_lounge.allow_future_bookings IS TRUE AND (v_lounge.allow_request_without_shift IS TRUE
   OR EXISTS(SELECT 1 FROM public.shifts WHERE lounge_id=p_lounge_id AND status='open' AND closed_at IS NULL)) THEN
   SELECT greatest(w.permit_expires_at,COALESCE((SELECT max(p.expires_at)
     FROM private.cashier_writer_permits p JOIN private.cashier_permit_generations g ON g.permit_id=p.permit_id
     WHERE p.lounge_id=w.lounge_id AND p.actor_id=w.actor_id AND p.device_id=w.device_id
       AND g.writer_generation=w.writer_generation),w.permit_expires_at)) INTO v_boundary
     FROM private.cashier_writer_authorities w WHERE w.lounge_id=p_lounge_id AND w.released_at IS NULL;
   v_future_date := greatest(v_today+1,COALESCE((v_boundary AT TIME ZONE v_lounge.timezone)::date
     + CASE WHEN (v_boundary AT TIME ZONE v_lounge.timezone)::time>time '00:00' THEN 1 ELSE 0 END,v_today+1));
   IF v_future_date>v_today+COALESCE(v_lounge.future_booking_max_days_advance,14) THEN v_future_date:=NULL; END IF;
 END IF;
 RETURN jsonb_build_object('future_booking_date_from',v_future_date,'status',CASE WHEN v_online THEN 'open' WHEN v_fault THEN 'technical_issue' ELSE 'closed' END,
   'can_book_online',v_online,'contact_phone',CASE WHEN v_fault THEN nullif(btrim(v_lounge.contact_phone),'') ELSE NULL END);
END; $function$;

REVOKE ALL ON FUNCTION public.get_lounge_operating_status(uuid) FROM PUBLIC,service_role,supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.get_lounge_operating_status(uuid) TO anon,authenticated;
COMMIT;
