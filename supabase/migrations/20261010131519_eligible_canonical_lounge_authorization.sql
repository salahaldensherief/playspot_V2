-- Fail closed for retained JWTs after profile suspension or Auth deletion.

-- Preserve existing lounge membership and management scopes.

BEGIN;

CREATE OR REPLACE FUNCTION private.can_operate_playspot_lounge(p_lounge_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT p_lounge_id IS NOT NULL AND auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.profiles p JOIN auth.users u ON u.id = p.id
      WHERE p.id = auth.uid() AND p.is_active IS TRUE
        AND p.is_banned IS FALSE
        AND (
          public.is_super_admin()
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
      SELECT 1 FROM public.profiles p JOIN auth.users u ON u.id = p.id
      WHERE p.id = auth.uid() AND p.is_active IS TRUE
        AND p.is_banned IS FALSE
        AND (
          public.is_super_admin()
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
  FROM public.profiles AS p JOIN auth.users AS u ON u.id = p.id
  WHERE p.id = auth.uid() AND p.is_active IS TRUE AND p.is_banned IS FALSE
  LIMIT 1;
$function$
;

CREATE OR REPLACE FUNCTION private.is_lounge_member(p_lounge_id uuid)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
 AS $function$
 SELECT p_lounge_id IS NOT NULL AND auth.uid() IS NOT NULL AND EXISTS (
   SELECT 1 FROM public.profiles p JOIN auth.users u ON u.id = p.id
   WHERE p.id = auth.uid() AND p.is_active IS TRUE AND p.is_banned IS FALSE
     AND (public.is_super_admin()
       OR EXISTS (SELECT 1 FROM public.lounges l WHERE l.id=p_lounge_id AND l.owner_id=p.id)
       OR (p.lounge_id=p_lounge_id AND p.role IN ('owner','lounge_owner','lounge_admin','admin','manager','cashier','staff','super_admin'))
       OR EXISTS (SELECT 1 FROM public.lounge_staff ls WHERE ls.user_id=p.id AND ls.lounge_id=p_lounge_id))
 );
 $function$;

CREATE OR REPLACE FUNCTION public.is_lounge_member_or_admin(p_lounge_id uuid)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
 AS $function$
 SELECT p_lounge_id IS NOT NULL AND auth.uid() IS NOT NULL AND EXISTS (
   SELECT 1 FROM public.profiles p JOIN auth.users u ON u.id = p.id
   WHERE p.id = auth.uid() AND p.is_active IS TRUE AND p.is_banned IS FALSE
     AND (public.is_super_admin()
       OR EXISTS (SELECT 1 FROM public.lounges l WHERE l.id=p_lounge_id AND l.owner_id=p.id)
       OR (p.lounge_id=p_lounge_id )
       OR EXISTS (SELECT 1 FROM public.lounge_staff ls WHERE ls.user_id=p.id AND ls.lounge_id=p_lounge_id))
 );
 $function$;

CREATE OR REPLACE FUNCTION private.permission_role(p_user_id uuid, p_lounge_id uuid)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT CASE
    WHEN p.role IN ('super_admin','superadmin') OR EXISTS (SELECT 1 FROM public.platform_super_admins sa WHERE sa.user_id=p.id) THEN 'super_admin'
    WHEN p_lounge_id IS NULL THEN NULL
    WHEN EXISTS (SELECT 1 FROM public.lounges l WHERE l.id=p_lounge_id AND l.owner_id=p.id) THEN 'owner'
    WHEN ls.role = 'lounge_owner' THEN 'owner'
    WHEN ls.role IN ('manager','cashier') THEN ls.role
    WHEN p.lounge_id=p_lounge_id AND p.role IN ('owner','manager','cashier','staff') THEN p.role
    WHEN p.lounge_id=p_lounge_id AND p.role IN ('lounge_admin','admin') THEN 'manager'
    ELSE NULL END
  FROM public.profiles p JOIN auth.users u ON u.id=p.id
  LEFT JOIN public.lounge_staff ls ON ls.user_id=p.id AND ls.lounge_id=p_lounge_id
  WHERE p.id=p_user_id AND p.is_active IS TRUE AND p.is_banned IS FALSE
    AND (p.role IN ('super_admin','superadmin','owner','lounge_admin','admin','manager','cashier','staff') OR EXISTS (SELECT 1 FROM public.platform_super_admins sa WHERE sa.user_id=p.id));
$function$
;

COMMIT;
