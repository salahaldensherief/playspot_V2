CREATE OR REPLACE FUNCTION public._playspot_has_lounge_access(p_lounge_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'extensions', 'pg_temp'
AS $function$
  SELECT
    auth.uid() IS NOT NULL
    AND p_lounge_id IS NOT NULL
    AND (
      public._playspot_is_super_admin()

      OR EXISTS (
        SELECT 1
        FROM public.lounges l
        WHERE l.id = p_lounge_id
          AND l.owner_id = auth.uid()
      )

      OR EXISTS (
        SELECT 1
        FROM public.lounge_staff ls
        JOIN public.profiles p ON p.id = ls.user_id
        WHERE ls.lounge_id = p_lounge_id
          AND ls.user_id = auth.uid()
          AND COALESCE(p.is_active, true) = true
      )

      OR EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.id = auth.uid()
          AND p.lounge_id = p_lounge_id
          AND p.role IN (
            'owner', 'lounge_admin', 'admin',
            'manager', 'cashier', 'staff'
          )
          AND COALESCE(p.is_active, true) = true
      )
    );
$function$
