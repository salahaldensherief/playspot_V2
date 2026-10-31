-- Schema-only observed definitions; no customer rows.
CREATE OR REPLACE FUNCTION private.can_operate_playspot_lounge(p_lounge_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT p_lounge_id IS NOT NULL AND auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND COALESCE(p.is_active, true)
        AND NOT COALESCE(p.is_banned, false)
        AND (
          p.role = 'super_admin'
          OR EXISTS (SELECT 1 FROM public.lounges l
                     WHERE l.id = p_lounge_id AND l.owner_id = p.id)
          OR (p.lounge_id = p_lounge_id
              AND p.role IN ('owner', 'lounge_admin', 'admin', 'manager', 'cashier', 'staff'))
          OR EXISTS (SELECT 1 FROM public.lounge_staff ls
                     WHERE ls.user_id = p.id AND ls.lounge_id = p_lounge_id
                       AND ls.role IN ('lounge_owner', 'manager', 'cashier'))
        )
    );
$function$
;
CREATE OR REPLACE FUNCTION private.can_manage_playspot_lounge(p_lounge_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT p_lounge_id IS NOT NULL AND auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND COALESCE(p.is_active, true)
        AND NOT COALESCE(p.is_banned, false)
        AND (
          p.role = 'super_admin'
          OR EXISTS (SELECT 1 FROM public.lounges l
                     WHERE l.id = p_lounge_id AND l.owner_id = p.id)
          OR (p.lounge_id = p_lounge_id
              AND p.role IN ('owner', 'lounge_admin', 'admin', 'manager'))
          OR EXISTS (SELECT 1 FROM public.lounge_staff ls
                     WHERE ls.user_id = p.id AND ls.lounge_id = p_lounge_id
                       AND ls.role IN ('lounge_owner', 'manager'))
        )
    );
$function$
;
CREATE OR REPLACE FUNCTION private.current_user_role()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT p.role
  FROM public.profiles AS p
  WHERE p.id = auth.uid() AND COALESCE(p.is_active, true)
  LIMIT 1;
$function$
;
CREATE OR REPLACE FUNCTION private.is_lounge_member(p_lounge_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT auth.uid() IS NOT NULL
    AND p_lounge_id IS NOT NULL
    AND (
      EXISTS (
        SELECT 1 FROM public.lounges AS l
        WHERE l.id = p_lounge_id AND l.owner_id = auth.uid()
      )
      OR EXISTS (
        SELECT 1 FROM public.profiles AS p
        WHERE p.id = auth.uid()
          AND (p.lounge_id = p_lounge_id OR p.role = 'super_admin')
          AND COALESCE(p.is_active, true)
          AND p.role IN ('owner','lounge_owner','lounge_admin','admin','manager','cashier','staff','super_admin')
      )
      OR EXISTS (
        SELECT 1
        FROM public.lounge_staff AS ls
        JOIN public.profiles AS p ON p.id = ls.user_id
        WHERE ls.user_id = auth.uid()
          AND ls.lounge_id = p_lounge_id
          AND COALESCE(p.is_active, true)
      )
    );
$function$
;
CREATE OR REPLACE FUNCTION public.is_lounge_member_or_admin(p_lounge_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL OR p_lounge_id IS NULL THEN
    RETURN FALSE;
  END IF;

  RETURN public.is_super_admin()
    OR EXISTS (
        SELECT 1 FROM public.lounges
        WHERE id = p_lounge_id AND owner_id = auth.uid()
    )
    OR EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND lounge_id = p_lounge_id AND COALESCE(is_active, true) = true
    )
    OR EXISTS (
        SELECT 1 FROM public.lounge_staff ls
        JOIN public.profiles p ON p.id = ls.user_id
        WHERE ls.lounge_id = p_lounge_id AND ls.user_id = auth.uid() AND COALESCE(p.is_active, true) = true
    );
END;
$function$
;
CREATE OR REPLACE FUNCTION private.permission_role(p_user_id uuid, p_lounge_id uuid)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT CASE
    WHEN p.role = 'super_admin' THEN 'super_admin'
    WHEN p_lounge_id IS NULL THEN NULL
    WHEN EXISTS (SELECT 1 FROM public.lounges l WHERE l.id=p_lounge_id AND l.owner_id=p.id) THEN 'owner'
    WHEN ls.role = 'lounge_owner' THEN 'owner'
    WHEN ls.role IN ('manager','cashier') THEN ls.role
    WHEN p.lounge_id=p_lounge_id AND p.role IN ('owner','manager','cashier','staff') THEN p.role
    WHEN p.lounge_id=p_lounge_id AND p.role IN ('lounge_admin','admin') THEN 'manager'
    ELSE NULL END
  FROM public.profiles p
  LEFT JOIN public.lounge_staff ls ON ls.user_id=p.id AND ls.lounge_id=p_lounge_id
  WHERE p.id=p_user_id AND COALESCE(p.is_active,true) AND NOT COALESCE(p.is_banned,false)
    AND p.role IN ('super_admin','owner','lounge_admin','admin','manager','cashier','staff');
$function$
;
