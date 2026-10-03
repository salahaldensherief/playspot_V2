-- Authorized live rollout 2026-10-03. Preserves business rows.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
-- client_table_management_privileges.sql
REVOKE TRUNCATE,REFERENCES,TRIGGER,MAINTAIN ON ALL TABLES IN SCHEMA public FROM PUBLIC,anon,authenticated;
ALTER DEFAULT PRIVILEGES REVOKE TRUNCATE,REFERENCES,TRIGGER,MAINTAIN ON TABLES FROM PUBLIC,anon,authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE TRUNCATE,REFERENCES,TRIGGER,MAINTAIN ON TABLES FROM PUBLIC,anon,authenticated;
-- active_super_admin_boundary.sql
-- Reviewed repair incorporated into the explicitly authorized live migration.
CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles AS profile
    JOIN auth.users AS auth_user ON auth_user.id = profile.id
    WHERE profile.id = auth.uid()
      AND profile.is_active IS TRUE
      AND profile.is_banned IS FALSE
      AND (profile.role IN ('super_admin', 'superadmin') OR EXISTS (
        SELECT 1 FROM public.platform_super_admins AS membership
        WHERE membership.user_id = profile.id
      ))
  );
$function$;
REVOKE ALL ON FUNCTION public.is_super_admin() FROM PUBLIC;
-- Existing anonymous RLS predicates can safely receive false for a NULL uid.
GRANT EXECUTE ON FUNCTION public.is_super_admin() TO anon, authenticated, service_role;
-- financial_client_privileges.sql
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shift_payments ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.payments,public.shift_payments FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.payments,public.shift_payments TO authenticated;

CREATE OR REPLACE FUNCTION private.can_read_financial_record(p_customer uuid,p_lounge uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
  SELECT auth.uid() IS NOT NULL
    AND EXISTS (SELECT 1 FROM public.profiles p JOIN auth.users u ON u.id=p.id
      WHERE p.id=auth.uid() AND p.is_active IS TRUE AND p.is_banned IS FALSE)
    AND (p_customer=auth.uid() OR public.is_super_admin() IS TRUE
      OR public.has_lounge_permission(p_lounge,'billing_checkout') IS TRUE);
$$;
REVOKE ALL ON FUNCTION private.can_read_financial_record(uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.can_read_financial_record(uuid,uuid) TO authenticated;

DROP POLICY IF EXISTS "Users can view own payments" ON public.payments;
DROP POLICY IF EXISTS "Super admin full access on payments" ON public.payments;
DROP POLICY IF EXISTS payments_read_verified_scope ON public.payments;
CREATE POLICY payments_read_verified_scope ON public.payments FOR SELECT TO authenticated
  USING(private.can_read_financial_record(user_id,lounge_id));
DROP POLICY IF EXISTS financial_read_scope_guard ON public.payments;
CREATE POLICY financial_read_scope_guard ON public.payments AS RESTRICTIVE FOR SELECT TO authenticated
  USING(private.can_read_financial_record(user_id,lounge_id));

DROP POLICY IF EXISTS "Staff view shift payments" ON public.shift_payments;
DROP POLICY IF EXISTS shift_payments_read_verified_scope ON public.shift_payments;
CREATE POLICY shift_payments_read_verified_scope ON public.shift_payments FOR SELECT TO authenticated
  USING(private.can_read_financial_record(NULL::uuid,lounge_id));
DROP POLICY IF EXISTS financial_read_scope_guard ON public.shift_payments;
CREATE POLICY financial_read_scope_guard ON public.shift_payments AS RESTRICTIVE FOR SELECT TO authenticated
  USING(private.can_read_financial_record(NULL::uuid,lounge_id));
-- slot_waitlist_view_boundary.sql
-- Invoker boundary repair; PostgreSQL 15+ required.
-- Preserve the legacy projection while enforcing the caller's base-table RLS.
ALTER VIEW public.slot_waitlist SET (security_invoker = true);
CREATE OR REPLACE FUNCTION public.fn_slot_waitlist_insert()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_time time without time zone := COALESCE(NEW.slot_time, '18:00:00'::time);
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;
  IF NEW.user_id IS NOT NULL AND NEW.user_id IS DISTINCT FROM v_actor THEN
    RAISE EXCEPTION 'Cannot create another customer request' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles AS actor
    WHERE actor.id = v_actor AND actor.is_active IS TRUE AND actor.is_banned IS FALSE) THEN
    RAISE EXCEPTION 'Active account required' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.rooms AS resource
    WHERE resource.id = NEW.room_id AND resource.lounge_id = NEW.lounge_id) THEN
    RAISE EXCEPTION 'Room does not belong to the lounge' USING ERRCODE = '42501';
  END IF;
  IF COALESCE(NEW.status, 'waiting') NOT IN ('waiting', 'active') THEN
    RAISE EXCEPTION 'Cannot create a claimed or completed request' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.booking_waitlist (
    user_id, lounge_id, room_id, requested_date, duration_minutes,
    preferred_start_time, start_at, end_at, status
  ) VALUES (
    v_actor, NEW.lounge_id, NEW.room_id, NEW.date, 60,
    v_time, NEW.date + v_time, NEW.date + v_time + interval '60 minutes',
    COALESCE(NEW.status, 'waiting')
  ) RETURNING id INTO NEW.id;
  NEW.user_id := v_actor;
  NEW.slot_time := v_time;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON public.slot_waitlist FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT ON public.slot_waitlist TO authenticated;
-- platform_revenue_actor_contract.sql
-- Reviewed platform revenue contract incorporated into this live migration.
-- Preserves the hosted signature, Cairo grouping and completed-payment basis.
-- Coordinate staging rollout with active_super_admin_boundary.sql.
CREATE OR REPLACE FUNCTION public.get_revenue_over_time(
  p_lounge_id uuid DEFAULT NULL,
  p_period text DEFAULT 'month'
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
  v_is_super boolean;
  v_user_lounge_id uuid;
  v_target_lounge_id uuid;
  v_result jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;
  IF p_period IS NULL OR p_period NOT IN ('day', 'week', 'month', 'quarter', 'year') THEN
    RAISE EXCEPTION 'Unsupported revenue period' USING ERRCODE = '22023';
  END IF;

  SELECT public.is_super_admin(), profile.lounge_id
    INTO v_is_super, v_user_lounge_id
    FROM public.profiles AS profile
    JOIN auth.users AS identity ON identity.id = profile.id
    WHERE profile.id = auth.uid()
      AND profile.is_active IS TRUE AND profile.is_banned IS FALSE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active account required' USING ERRCODE = '42501';
  END IF;

  IF v_is_super IS TRUE THEN
    v_target_lounge_id := p_lounge_id;
  ELSE
    v_target_lounge_id := COALESCE(p_lounge_id, v_user_lounge_id);
    IF v_target_lounge_id IS NULL
       OR private.is_lounge_member(v_target_lounge_id) IS NOT TRUE THEN
      RAISE EXCEPTION 'Not authorized for this lounge' USING ERRCODE = '42501';
    END IF;
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'period', grouped.period, 'revenue', grouped.revenue
    ) ORDER BY grouped.period), '[]'::jsonb)
    INTO v_result
    FROM (
      SELECT date_trunc(p_period, payment.paid_at AT TIME ZONE 'Africa/Cairo') AS period,
             SUM(payment.amount)::numeric AS revenue
      FROM public.payments AS payment
      WHERE payment.status = 'completed'
        AND (v_target_lounge_id IS NULL OR payment.lounge_id = v_target_lounge_id)
      GROUP BY 1
    ) AS grouped;
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.get_revenue_over_time(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_revenue_over_time(uuid,text) TO authenticated, service_role;
NOTIFY pgrst, 'reload schema';
COMMIT;
