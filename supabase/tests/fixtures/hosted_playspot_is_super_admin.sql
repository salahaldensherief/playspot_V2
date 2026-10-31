CREATE OR REPLACE FUNCTION public._playspot_is_super_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'extensions', 'pg_temp'
AS $function$
  SELECT
    auth.uid() IS NOT NULL
    AND (
      EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.id = auth.uid()
          AND p.role = 'super_admin'
      )
      OR EXISTS (
        SELECT 1
        FROM public.platform_super_admins sa
        WHERE sa.user_id = auth.uid()
      )
    );
$function$
