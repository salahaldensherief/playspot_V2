-- Review source only; release through coordinated migrations, never auto-apply.
BEGIN;
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
COMMIT;
