BEGIN;
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
COMMIT;
