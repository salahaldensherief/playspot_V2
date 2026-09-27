BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE OR REPLACE FUNCTION private.can_manage_playspot_lounge(p_lounge_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
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
$function$;

CREATE OR REPLACE FUNCTION private.can_operate_playspot_lounge(p_lounge_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
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
$function$;

CREATE OR REPLACE FUNCTION public.get_my_profile(p_user_id uuid DEFAULT NULL::uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_profile json;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT row_to_json(p) INTO v_profile
  FROM (
    SELECT id, email, full_name, phone, role, lounge_id, avatar_url, is_setup_completed,
           is_active, is_banned, banned_reason, city_id, points, referral_code,
           created_at
    FROM public.profiles
    WHERE id = auth.uid()
  ) p;

  RETURN v_profile;
END;
$function$
;

COMMIT;
