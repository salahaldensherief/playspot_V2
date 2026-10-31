-- REVIEW ONLY. Not deployed and deliberately outside supabase/migrations.
-- Preserves the hosted signature, Cairo grouping and completed-payment basis.
-- Coordinate staging rollout with active_super_admin_boundary.sql.
BEGIN;
CREATE OR REPLACE FUNCTION public.get_revenue_over_time(
  p_lounge_id uuid DEFAULT NULL,
  p_period text DEFAULT 'month'
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
  v_is_super boolean;
  v_user_lounge_id uuid;
  v_target_lounge_id uuid;
  v_result jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;
  IF p_period IS NULL OR p_period NOT IN ('day', 'week', 'month', 'quarter', 'year') THEN
    RAISE EXCEPTION 'Unsupported revenue period' USING ERRCODE = '22023';
  END IF;

  SELECT public.is_super_admin(), profile.lounge_id
    INTO v_is_super, v_user_lounge_id
    FROM public.profiles AS profile
    JOIN auth.users AS identity ON identity.id = profile.id
    WHERE profile.id = auth.uid()
      AND profile.is_active IS TRUE AND profile.is_banned IS FALSE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active account required' USING ERRCODE = '42501';
  END IF;

  IF v_is_super IS TRUE THEN
    v_target_lounge_id := p_lounge_id;
  ELSE
    v_target_lounge_id := COALESCE(p_lounge_id, v_user_lounge_id);
    IF v_target_lounge_id IS NULL
       OR private.is_lounge_member(v_target_lounge_id) IS NOT TRUE THEN
      RAISE EXCEPTION 'Not authorized for this lounge' USING ERRCODE = '42501';
    END IF;
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'period', grouped.period, 'revenue', grouped.revenue
    ) ORDER BY grouped.period), '[]'::jsonb)
    INTO v_result
    FROM (
      SELECT date_trunc(p_period, payment.paid_at AT TIME ZONE 'Africa/Cairo') AS period,
             SUM(payment.amount)::numeric AS revenue
      FROM public.payments AS payment
      WHERE payment.status = 'completed'
        AND (v_target_lounge_id IS NULL OR payment.lounge_id = v_target_lounge_id)
      GROUP BY 1
    ) AS grouped;
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.get_revenue_over_time(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_revenue_over_time(uuid,text) TO authenticated, service_role;
COMMIT;
