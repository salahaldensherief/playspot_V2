-- Migration: 20261011130000_fix_cashier_writer_handover_and_online_availability.sql
-- Description: Fix cashier writer authority handover, permit expiry, and online availability:
--              1. Allow fresh cashier writer claim/bootstrap when previous writer permit has expired
--                 or previous actor no longer has an active open shift on the lounge.
--              2. Fix get_lounge_online_availability to treat released or expired writers as non-blocking.
--              3. Fix get_lounge_operating_status so faults are only triggered by currently active on-duty writers.
--              4. Release stale writer authorities upon shift closure in blind_close_shift.
--              5. Release existing stale expired writer authorities from historical sessions.

BEGIN;

-- 1. Update refresh_cashier_writer to permit shift handover and expired permit reclaim
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

  -- Reclaim writer if previously released, OR if the previous permit expired,
  -- OR if the previous actor no longer has an active open shift on this lounge:
  IF v_writer.released_at IS NOT NULL
     OR v_writer.permit_expires_at <= v_now
     OR (v_writer.actor_id <> v_actor AND NOT EXISTS (
       SELECT 1 FROM public.shifts s 
       WHERE s.lounge_id = p_lounge_id 
         AND coalesce(s.cashier_id, s.staff_user_id) = v_writer.actor_id 
         AND s.status = 'open' AND s.closed_at IS NULL
     )) THEN
    IF NOT EXISTS(SELECT 1 FROM private.cashier_bootstrap_claim_context WHERE transaction_id=txid_current()
      AND lounge_id=p_lounge_id AND actor_id=v_actor AND device_id=p_device_id) THEN
      RAISE EXCEPTION 'CASHIER_RECLAIM_REQUIRES_BOOTSTRAP' USING ERRCODE='55000';
    END IF;
    -- Bootstrap of the next shift must have exactly one own open shift.
    IF (SELECT count(*) FROM public.shifts WHERE lounge_id=p_lounge_id
      AND coalesce(cashier_id,staff_user_id)=v_actor AND status='open' AND closed_at IS NULL)<>1 THEN
      RAISE EXCEPTION 'OFFLINE_BOOTSTRAP_REQUIRES_ONE_OWN_SHIFT' USING ERRCODE='55000';
    END IF;
    UPDATE private.cashier_writer_authorities SET actor_id=v_actor,device_id=p_device_id,
      writer_generation=gen_random_uuid(),permit_id=gen_random_uuid(),issued_at=v_now,permit_expires_at=v_now+interval '24 hours',
      heartbeat_expires_at=CASE WHEN p_online THEN v_now+interval '90 seconds' ELSE v_now END,
      online_requested=p_online,released_at=NULL,updated_at=v_now
      WHERE lounge_id=p_lounge_id RETURNING * INTO v_writer;
    v_created:=true;
  END IF;

  IF NOT v_created AND v_writer.online_requested IS DISTINCT FROM p_online
    AND NOT EXISTS(SELECT 1 FROM private.cashier_bootstrap_claim_context
      WHERE transaction_id=txid_current() AND lounge_id=p_lounge_id
        AND actor_id=v_actor AND device_id=p_device_id) THEN
    RAISE EXCEPTION 'CASHIER_MODE_CHANGE_REQUIRES_BOOTSTRAP' USING ERRCODE='55000';
  END IF;

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
GRANT EXECUTE ON FUNCTION public.refresh_cashier_writer(uuid,uuid,boolean) TO authenticated;


-- 2. Update get_lounge_online_availability
CREATE OR REPLACE FUNCTION public.get_lounge_online_availability(p_lounge_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_now timestamptz:=clock_timestamp();
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.lounges AS lounge
    LEFT JOIN private.cashier_writer_authorities AS writer ON writer.lounge_id=lounge.id
    WHERE lounge.id=p_lounge_id AND lounge.status='active'
      AND lounge.is_active IS TRUE AND lounge.is_open IS TRUE
      AND (
        -- No writer record exists
        writer.lounge_id IS NULL 
        -- Writer was explicitly released
        OR writer.released_at IS NOT NULL
        -- Writer's 24h permit expired
        OR writer.permit_expires_at <= v_now
        -- The cashier who claimed writer authority no longer has an open shift
        OR NOT EXISTS (
          SELECT 1 FROM public.shifts s 
          WHERE s.lounge_id=lounge.id 
            AND (s.cashier_id=writer.actor_id OR s.staff_user_id=writer.actor_id) 
            AND s.status='open' AND s.closed_at IS NULL
        )
        -- Writer is operating in online mode (not local offline mode)
        OR writer.online_requested IS TRUE
        -- Or writer is actively maintaining heartbeat
        OR (
          writer.released_at IS NULL 
          AND writer.heartbeat_expires_at > v_now
        )
      )
  );
END;
$function$;
REVOKE ALL ON FUNCTION public.get_lounge_online_availability(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_lounge_online_availability(uuid) TO anon,authenticated;


-- 3. Update get_lounge_operating_status
CREATE OR REPLACE FUNCTION public.get_lounge_operating_status(p_lounge_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_lounge public.lounges%ROWTYPE; v_online boolean; v_fault boolean;
BEGIN
 SELECT * INTO v_lounge FROM public.lounges WHERE id=p_lounge_id AND status='active' AND is_active IS TRUE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','unavailable','can_book_online',false,'contact_phone',NULL); END IF;
 v_online:=public.get_lounge_online_availability(p_lounge_id);
 v_fault:=v_lounge.is_open IS TRUE AND NOT v_online
   AND EXISTS(SELECT 1 FROM public.shifts WHERE lounge_id=p_lounge_id AND status='open' AND closed_at IS NULL)
   AND EXISTS(SELECT 1 FROM private.cashier_writer_authorities w
     JOIN public.profiles p ON p.id=w.actor_id JOIN auth.users u ON u.id=p.id
     WHERE w.lounge_id=p_lounge_id AND p.is_active IS TRUE AND p.is_banned IS FALSE
       AND w.released_at IS NULL
       AND w.permit_expires_at > clock_timestamp()
       AND EXISTS(SELECT 1 FROM public.shifts s WHERE s.lounge_id=p_lounge_id AND coalesce(s.cashier_id,s.staff_user_id)=w.actor_id AND s.status='open' AND s.closed_at IS NULL)
       AND w.online_requested IS FALSE);
 RETURN jsonb_build_object('status',CASE WHEN v_online THEN 'open' WHEN v_fault THEN 'technical_issue' ELSE 'closed' END,
   'can_book_online',v_online,'contact_phone',CASE WHEN v_fault THEN nullif(btrim(v_lounge.contact_phone),'') ELSE NULL END);
END; $function$;
REVOKE ALL ON FUNCTION public.get_lounge_operating_status(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_lounge_operating_status(uuid) TO anon,authenticated;


-- 4. Automatically release writer authority upon shift closure in blind_close_shift
CREATE OR REPLACE FUNCTION public.blind_close_shift(p_shift_id uuid, p_cashier_id uuid, p_counted_cash numeric, p_notes text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_shift public.shifts%ROWTYPE;
  v_cash_sales numeric;
  v_expenses numeric;
  v_expected numeric;
  v_difference numeric;
  v_manager boolean;
  v_actor uuid := auth.uid();
  v_now timestamptz := clock_timestamp();
BEGIN
  IF p_counted_cash IS NULL OR p_counted_cash < 0 THEN RAISE EXCEPTION 'Counted cash must be non-negative' USING ERRCODE = '22023'; END IF;
  SELECT s.* INTO v_shift FROM public.shifts s WHERE s.id = p_shift_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Shift not found' USING ERRCODE = 'P0002'; END IF;
  IF v_shift.status <> 'open' THEN RAISE EXCEPTION 'Shift is not open' USING ERRCODE = '55000'; END IF;
  IF v_shift.cashier_id IS DISTINCT FROM p_cashier_id THEN RAISE EXCEPTION 'Shift does not belong to the specified cashier' USING ERRCODE = '42501'; END IF;
  IF auth.role() IS DISTINCT FROM 'service_role' AND (
    NOT COALESCE(private.can_operate_playspot_lounge(v_shift.lounge_id), false)
    OR NOT COALESCE(public.has_lounge_permission(v_shift.lounge_id, 'shifts_blind_close'), false)
  ) THEN
    RAISE EXCEPTION 'Shift closure is not permitted for this actor' USING ERRCODE = '42501';
  END IF;
  v_manager := private.can_manage_playspot_lounge(v_shift.lounge_id);
  IF v_actor IS DISTINCT FROM p_cashier_id AND NOT v_manager AND auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'Only the shift cashier or an authorized manager may close this shift' USING ERRCODE = '42501';
  END IF;
  SELECT COALESCE(SUM(sp.amount), 0) INTO v_cash_sales FROM public.shift_payments sp
  WHERE sp.shift_id = p_shift_id AND sp.payment_method = 'cash';
  SELECT COALESCE(SUM(se.amount), 0) INTO v_expenses FROM public.shift_expenses se WHERE se.shift_id = p_shift_id;
  v_expected := COALESCE(v_shift.starting_cash, 0) + v_cash_sales - v_expenses;
  v_difference := p_counted_cash - v_expected;
  UPDATE public.shifts SET actual_cash_counted = p_counted_cash, expected_cash = v_expected,
    difference = v_difference, status = 'closed', closed_at = v_now, end_time = v_now,
    notes = COALESCE(p_notes, notes)
  WHERE id = p_shift_id;

  -- Release cashier writer authority if held by this cashier
  UPDATE private.cashier_writer_authorities
  SET released_at = v_now,
      online_requested = false,
      heartbeat_expires_at = v_now,
      updated_at = v_now
  WHERE lounge_id = v_shift.lounge_id
    AND actor_id = v_shift.cashier_id
    AND released_at IS NULL;

  INSERT INTO public.shift_audit_logs
    (lounge_id, shift_id, entity_type, entity_id, action, actor_user_id, old_data, new_data)
  VALUES
    (v_shift.lounge_id, p_shift_id, 'shift', p_shift_id, 'update', v_actor,
     jsonb_build_object('status', v_shift.status, 'expected_cash', v_shift.expected_cash,
                        'actual_cash_counted', v_shift.actual_cash_counted, 'difference', v_shift.difference),
     jsonb_build_object('status', 'closed', 'expected_cash', v_expected,
                        'actual_cash_counted', p_counted_cash, 'difference', v_difference,
                        'cash_sales', v_cash_sales, 'expenses', v_expenses, 'notes', p_notes));
  RETURN jsonb_build_object('success', true, 'shift_id', p_shift_id, 'status', 'closed',
    'actual_cash_counted', p_counted_cash,
    'expected_cash', CASE WHEN private.can_view_shift_financials(v_shift.lounge_id) THEN to_jsonb(v_expected) ELSE 'null'::jsonb END,
    'difference', CASE WHEN private.can_view_shift_financials(v_shift.lounge_id) THEN to_jsonb(v_difference) ELSE 'null'::jsonb END,
    'manager_report', private.can_view_shift_financials(v_shift.lounge_id), 'financials_visible', private.can_view_shift_financials(v_shift.lounge_id));
END;
$function$;


-- 5. Release stale expired historical writer records
UPDATE private.cashier_writer_authorities
SET released_at = clock_timestamp(),
    online_requested = false,
    updated_at = clock_timestamp()
WHERE released_at IS NULL
  AND (permit_expires_at <= clock_timestamp()
       OR NOT EXISTS (
         SELECT 1 FROM public.shifts s
         WHERE s.lounge_id = cashier_writer_authorities.lounge_id
           AND coalesce(s.cashier_id, s.staff_user_id) = cashier_writer_authorities.actor_id
           AND s.status = 'open' AND s.closed_at IS NULL
       ));

NOTIFY pgrst, 'reload schema';
COMMIT;
