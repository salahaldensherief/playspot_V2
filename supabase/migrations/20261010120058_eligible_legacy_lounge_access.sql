BEGIN;

-- Keep existing RLS callers while using the canonical active Auth boundary.
CREATE OR REPLACE FUNCTION public._playspot_is_super_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $function$
  SELECT public.is_super_admin() IS TRUE;
$function$;

CREATE OR REPLACE FUNCTION public._playspot_has_lounge_access(p_lounge_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $function$
  SELECT p_lounge_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.profiles p JOIN auth.users u ON u.id = p.id
      WHERE p.id = auth.uid() AND p.is_active IS TRUE AND p.is_banned IS FALSE
    )
    AND (
      public._playspot_is_super_admin()
      OR EXISTS (SELECT 1 FROM public.lounges l
                 WHERE l.id = p_lounge_id AND l.owner_id = auth.uid())
      OR EXISTS (SELECT 1 FROM public.lounge_staff ls
                 WHERE ls.lounge_id = p_lounge_id AND ls.user_id = auth.uid())
      OR EXISTS (SELECT 1 FROM public.profiles p
                 WHERE p.id = auth.uid() AND p.lounge_id = p_lounge_id
                   AND p.role IN ('owner','lounge_admin','admin','manager','cashier','staff'))
    );
$function$;

-- CREATE OR REPLACE preserves the deployed ACL; these helpers remain usable
-- by existing authenticated RLS policies without granting new API access.
COMMIT;
