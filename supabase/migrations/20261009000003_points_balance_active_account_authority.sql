BEGIN;
SET LOCAL lock_timeout='5s';
CREATE OR REPLACE FUNCTION public.get_user_points_balance(p_user_id uuid)
RETURNS integer LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE
 v_actor uuid := auth.uid();
 v_target_user_id uuid := COALESCE(p_user_id,auth.uid());
 v_balance integer;
BEGIN
 IF v_actor IS NULL THEN
  RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.profiles p JOIN auth.users u ON u.id=p.id
  WHERE p.id=v_actor AND p.is_active IS TRUE AND p.is_banned IS FALSE) THEN
  RAISE EXCEPTION 'Account not eligible' USING ERRCODE='42501';
 END IF;
 IF v_target_user_id IS DISTINCT FROM v_actor AND public.is_super_admin() IS NOT TRUE THEN
  RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501';
 END IF;
 SELECT COALESCE(SUM(pt.points),0)::integer INTO v_balance
  FROM public.points_transactions pt WHERE pt.user_id=v_target_user_id;
 RETURN v_balance;
END; $$;
REVOKE ALL ON FUNCTION public.get_user_points_balance(uuid)
 FROM PUBLIC,anon,service_role,supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.get_user_points_balance(uuid) TO authenticated;
COMMIT;
