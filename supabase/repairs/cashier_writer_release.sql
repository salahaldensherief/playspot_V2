-- Review source only. Requires the deployed coordinated offline protocol.
-- Client must durably freeze new commands and drain its outbox before release.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
ALTER TABLE private.cashier_writer_authorities ADD COLUMN IF NOT EXISTS released_at timestamptz;
ALTER TABLE private.cashier_writer_authorities ADD COLUMN IF NOT EXISTS writer_generation uuid NOT NULL DEFAULT gen_random_uuid();
CREATE TABLE IF NOT EXISTS private.cashier_permit_generations (
  permit_id uuid PRIMARY KEY REFERENCES private.cashier_writer_permits(permit_id),
  writer_generation uuid NOT NULL
);
INSERT INTO private.cashier_permit_generations(permit_id,writer_generation)
  SELECT p.permit_id,w.writer_generation FROM private.cashier_writer_permits p
  JOIN private.cashier_writer_authorities w ON (p.lounge_id,p.actor_id,p.device_id)=(w.lounge_id,w.actor_id,w.device_id)
  ON CONFLICT(permit_id) DO NOTHING;
CREATE TABLE IF NOT EXISTS private.cashier_writer_release_receipts (
  permit_id uuid PRIMARY KEY REFERENCES private.cashier_writer_permits(permit_id),
  actor_id uuid NOT NULL,lounge_id uuid NOT NULL,device_id uuid NOT NULL,
  last_applied_sequence bigint NOT NULL,receipt jsonb NOT NULL
);
CREATE TABLE IF NOT EXISTS private.cashier_bootstrap_claim_context (
  transaction_id bigint NOT NULL,lounge_id uuid NOT NULL,actor_id uuid NOT NULL,device_id uuid NOT NULL,
  PRIMARY KEY(transaction_id,lounge_id)
);
ALTER TABLE private.cashier_permit_generations ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.cashier_writer_release_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.cashier_bootstrap_claim_context ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private.cashier_permit_generations,private.cashier_writer_release_receipts,
  private.cashier_bootstrap_claim_context FROM PUBLIC,anon,authenticated,service_role,supabase_auth_admin;
CREATE TRIGGER guard_cashier_permit_generation_immutability BEFORE UPDATE OR DELETE ON private.cashier_permit_generations
  FOR EACH ROW EXECUTE FUNCTION private.guard_cashier_permit_immutability();
CREATE TRIGGER guard_cashier_release_receipt_immutability BEFORE UPDATE OR DELETE ON private.cashier_writer_release_receipts
  FOR EACH ROW EXECUTE FUNCTION private.guard_cashier_permit_immutability();

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
  -- Only an explicit completed release permits a fresh writer claim.
  IF v_writer.released_at IS NOT NULL THEN
    IF NOT EXISTS(SELECT 1 FROM private.cashier_bootstrap_claim_context WHERE transaction_id=txid_current()
      AND lounge_id=p_lounge_id AND actor_id=v_actor AND device_id=p_device_id) THEN
      RAISE EXCEPTION 'CASHIER_RECLAIM_REQUIRES_BOOTSTRAP' USING ERRCODE='55000';
    END IF;
    -- A delayed heartbeat from the retired shift must not claim the writer
    -- again. Bootstrap of the next shift must have exactly one own open shift.
    IF (SELECT count(*) FROM public.shifts WHERE lounge_id=p_lounge_id
      AND coalesce(cashier_id,staff_user_id)=v_actor AND status='open' AND closed_at IS NULL)<>1 THEN
      RAISE EXCEPTION 'OFFLINE_BOOTSTRAP_REQUIRES_ONE_OWN_SHIFT' USING ERRCODE='55000';
    END IF;
    UPDATE private.cashier_writer_authorities SET actor_id=v_actor,device_id=p_device_id,
      writer_generation=gen_random_uuid(),permit_id=gen_random_uuid(),issued_at=v_now,permit_expires_at=v_now+interval '24 hours',
      heartbeat_expires_at=v_now,online_requested=false,released_at=NULL,updated_at=v_now
      WHERE lounge_id=p_lounge_id RETURNING * INTO v_writer;
    v_created:=true;
  END IF;
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
  INSERT INTO private.cashier_permit_generations(permit_id,writer_generation)
    VALUES(v_permit.permit_id,v_writer.writer_generation) ON CONFLICT(permit_id) DO NOTHING;
  IF NOT EXISTS(SELECT 1 FROM private.cashier_permit_generations WHERE permit_id=v_permit.permit_id
    AND writer_generation=v_writer.writer_generation) THEN
    RAISE EXCEPTION 'CASHIER_PERMIT_GENERATION_MISMATCH' USING ERRCODE='55000';
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
        writer.released_at IS NULL AND writer.online_requested IS TRUE
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

CREATE OR REPLACE FUNCTION private.cashier_sync_permit_matches_writer(p_lounge_id uuid,p_actor_id uuid,p_permit_id uuid)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
  RETURN EXISTS(SELECT 1 FROM private.cashier_writer_authorities writer
    JOIN private.cashier_writer_permits permit ON permit.lounge_id=writer.lounge_id
      AND permit.actor_id=writer.actor_id AND permit.device_id=writer.device_id
    WHERE writer.released_at IS NULL AND writer.lounge_id=p_lounge_id AND writer.actor_id=p_actor_id AND permit.permit_id=p_permit_id
      AND EXISTS(SELECT 1 FROM private.cashier_permit_generations g WHERE g.permit_id=permit.permit_id
        AND g.writer_generation=writer.writer_generation));
END;
$$;
REVOKE ALL ON FUNCTION private.cashier_sync_permit_matches_writer(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated;

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
  IF NOT FOUND OR v_writer.released_at IS NOT NULL OR v_writer.actor_id IS DISTINCT FROM auth.uid()
    OR v_writer.device_id IS DISTINCT FROM (p_operation->>'device_id')::uuid THEN
    RAISE EXCEPTION 'OFFLINE_WRITER_MISMATCH' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_permit FROM private.cashier_writer_permits WHERE permit_id=(p_operation->>'permit_id')::uuid FOR SHARE;
  IF NOT FOUND OR (v_permit.lounge_id,v_permit.actor_id,v_permit.device_id)
    IS DISTINCT FROM (v_writer.lounge_id,v_writer.actor_id,v_writer.device_id) THEN
    RAISE EXCEPTION 'OFFLINE_WRITER_MISMATCH' USING ERRCODE='42501';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM private.cashier_permit_generations WHERE permit_id=v_permit.permit_id
    AND writer_generation=v_writer.writer_generation) THEN
    RAISE EXCEPTION 'OFFLINE_WRITER_GENERATION_MISMATCH' USING ERRCODE='42501';
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

REVOKE ALL ON FUNCTION public.refresh_cashier_writer(uuid,uuid,boolean),
  public.get_lounge_online_availability(uuid),
  private.cashier_sync_permit_matches_writer(uuid,uuid,uuid),
  private.lock_cashier_operation_writer(jsonb) FROM service_role,supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.refresh_cashier_writer(uuid,uuid,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_lounge_online_availability(uuid) TO anon,authenticated;

CREATE OR REPLACE FUNCTION public.release_cashier_writer(
  p_lounge_id uuid,p_device_id uuid,p_permit_id uuid,p_last_applied_sequence bigint
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_actor uuid:=auth.uid();v_writer private.cashier_writer_authorities%ROWTYPE;v_saved private.cashier_writer_release_receipts%ROWTYPE;v_receipt jsonb;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='28000'; END IF;
  IF p_lounge_id IS NULL OR p_device_id IS NULL OR p_permit_id IS NULL
    OR p_last_applied_sequence IS NULL OR p_last_applied_sequence<0
    OR p_last_applied_sequence>9007199254740991 THEN
    RAISE EXCEPTION 'INVALID_CASHIER_RELEASE_REQUEST' USING ERRCODE='22023';
  END IF;
  PERFORM private.lock_cashier_lounge(p_lounge_id);
  PERFORM 1 FROM public.profiles p JOIN auth.users u ON u.id=p.id
    WHERE p.id=v_actor AND p.is_active IS TRUE AND p.is_banned IS FALSE FOR SHARE OF p,u;
  IF NOT FOUND OR (public.is_super_admin() IS NOT TRUE
    AND public.has_lounge_permission(p_lounge_id,'sessions_control') IS NOT TRUE) THEN
    RAISE EXCEPTION 'CASHIER_RELEASE_PERMISSION_DENIED' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_saved FROM private.cashier_writer_release_receipts WHERE permit_id=p_permit_id;
  IF FOUND THEN
    IF (v_saved.actor_id,v_saved.lounge_id,v_saved.device_id,v_saved.last_applied_sequence)
      IS DISTINCT FROM (v_actor,p_lounge_id,p_device_id,p_last_applied_sequence) THEN
      RAISE EXCEPTION 'CASHIER_RELEASE_REPLAY_MISMATCH' USING ERRCODE='42501';
    END IF;
    RETURN v_saved.receipt;
  END IF;
  SELECT * INTO v_writer FROM private.cashier_writer_authorities WHERE lounge_id=p_lounge_id FOR UPDATE;
  IF NOT FOUND OR (v_writer.actor_id,v_writer.device_id) IS DISTINCT FROM (v_actor,p_device_id)
    OR NOT EXISTS(SELECT 1 FROM private.cashier_permit_generations g
      JOIN private.cashier_writer_permits p ON p.permit_id=g.permit_id
      WHERE p.permit_id=p_permit_id AND g.writer_generation=v_writer.writer_generation
        AND (p.lounge_id,p.actor_id,p.device_id)=(p_lounge_id,v_actor,p_device_id)) THEN
    RAISE EXCEPTION 'CASHIER_RELEASE_WRITER_MISMATCH' USING ERRCODE='42501';
  END IF;
  IF v_writer.last_applied_sequence<>p_last_applied_sequence THEN
    RAISE EXCEPTION 'CASHIER_RELEASE_SEQUENCE_MISMATCH' USING ERRCODE='55000';
  END IF;
  IF v_writer.released_at IS NULL THEN
    -- Do not lock a shift after the writer: existing close RPCs may already
    -- own it. Read the committed state; a concurrent close can be retried.
    IF EXISTS(SELECT 1 FROM public.shifts WHERE lounge_id=p_lounge_id
      AND coalesce(cashier_id,staff_user_id)=v_actor AND status='open' AND closed_at IS NULL) THEN
      RAISE EXCEPTION 'CASHIER_RELEASE_CLOSE_OWN_SHIFT_FIRST' USING ERRCODE='55000';
    END IF;
    IF EXISTS(SELECT 1 FROM public.bookings WHERE lounge_id=p_lounge_id AND status='in_progress') THEN
      RAISE EXCEPTION 'CASHIER_RELEASE_ACTIVE_SESSION' USING ERRCODE='55000';
    END IF;
    IF EXISTS(SELECT 1 FROM private.cashier_operation_receipts WHERE lounge_id=p_lounge_id
      AND sequence>v_writer.last_applied_sequence AND result->>'status'='conflict') THEN
      RAISE EXCEPTION 'CASHIER_RELEASE_UNRESOLVED_CONFLICT' USING ERRCODE='55000';
    END IF;
    UPDATE private.cashier_writer_authorities SET released_at=clock_timestamp(),online_requested=false,
      heartbeat_expires_at=clock_timestamp(),updated_at=clock_timestamp() WHERE lounge_id=p_lounge_id
      RETURNING * INTO v_writer;
  END IF;
  v_receipt:=jsonb_build_object('protocol_version',2,'released',true,'lounge_id',p_lounge_id,
    'actor_id',v_actor,'device_id',p_device_id,'permit_id',p_permit_id,
    'last_applied_sequence',v_writer.last_applied_sequence,'released_at',v_writer.released_at);
  INSERT INTO private.cashier_writer_release_receipts VALUES(p_permit_id,v_actor,p_lounge_id,p_device_id,
    p_last_applied_sequence,v_receipt);
  RETURN v_receipt;
END; $$;
REVOKE ALL ON FUNCTION public.release_cashier_writer(uuid,uuid,uuid,bigint)
  FROM PUBLIC,anon,service_role,supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.release_cashier_writer(uuid,uuid,uuid,bigint) TO authenticated;

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
  IF v_actor IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='28000'; END IF;
  INSERT INTO private.cashier_bootstrap_claim_context VALUES(txid_current(),p_lounge_id,v_actor,p_device_id);
  v_authority := public.refresh_cashier_writer(p_lounge_id,p_device_id,p_online);
  DELETE FROM private.cashier_bootstrap_claim_context WHERE transaction_id=txid_current() AND lounge_id=p_lounge_id;
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
COMMIT;
