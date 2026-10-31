-- Reviewed source rollback; restores the earlier account-eligibility vulnerability.
BEGIN;
SET LOCAL lock_timeout='5s';
-- Read-only hosted definition; synthetic authorization fixtures only.
CREATE OR REPLACE FUNCTION public.get_user_points_balance(p_user_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_target_user_id uuid := COALESCE(p_user_id, auth.uid());
  v_is_super_admin boolean;
  v_balance integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'super_admin'
  ) INTO v_is_super_admin;

  IF v_target_user_id <> auth.uid() AND NOT v_is_super_admin THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT COALESCE(SUM(pt.points), 0)::integer
  INTO v_balance
  FROM public.points_transactions pt
  WHERE pt.user_id = v_target_user_id;

  RETURN v_balance;
END;
$function$;

COMMIT;
