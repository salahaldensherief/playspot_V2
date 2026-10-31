BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE OR REPLACE FUNCTION private.pricing_rule_windows_overlap(
  p_existing public.pricing_rules, p_start time, p_end time, p_days integer[],
  p_start_date date, p_end_date date
)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE SET search_path TO '' AS $function$
DECLARE
  v_day integer;
  v_offset integer;
  v_start integer := extract(epoch FROM p_start)::integer;
  v_end integer := extract(epoch FROM p_end)::integer;
  v_existing_start integer := extract(epoch FROM p_existing.start_time)::integer;
  v_existing_end integer := extract(epoch FROM p_existing.end_time)::integer;
  v_low date;
  v_high date;
  v_first date;
BEGIN
  IF v_end <= v_start THEN v_end := v_end + 86400; END IF;
  IF v_existing_end <= v_existing_start THEN v_existing_end := v_existing_end + 86400; END IF;
  FOREACH v_day IN ARRAY p_existing.days_of_week LOOP
    FOR v_offset IN -1..1 LOOP
      IF ((v_day + v_offset + 6) % 7 + 1) = ANY(p_days)
         AND v_existing_start < v_end + v_offset * 86400
         AND v_start + v_offset * 86400 < v_existing_end THEN
        v_low := GREATEST(COALESCE(p_existing.start_date,'0001-01-01'::date),
          COALESCE(p_start_date - v_offset,'0001-01-01'::date));
        v_high := LEAST(COALESCE(p_existing.end_date,'9999-12-31'::date),
          COALESCE(p_end_date - v_offset,'9999-12-31'::date));
        v_first := v_low + ((v_day - extract(isodow FROM v_low)::integer + 7) % 7);
        IF v_first <= v_high THEN RETURN true; END IF;
      END IF;
    END LOOP;
  END LOOP;
  RETURN false;
END;
$function$;
REVOKE ALL ON FUNCTION private.pricing_rule_windows_overlap(public.pricing_rules,time,time,integer[],date,date) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.check_pricing_rule_conflicts_v2(
  p_lounge_id uuid, p_start_time time, p_end_time time, p_days integer[],
  p_space_type_id uuid DEFAULT NULL, p_room_id uuid DEFAULT NULL,
  p_exclude_rule_id uuid DEFAULT NULL, p_start_date date DEFAULT NULL, p_end_date date DEFAULT NULL
)
RETURNS SETOF public.pricing_rules LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $function$
  SELECT pr.* FROM public.pricing_rules pr
  WHERE pr.lounge_id = p_lounge_id AND pr.is_active IS TRUE
    AND (p_exclude_rule_id IS NULL OR pr.id <> p_exclude_rule_id)
    AND (p_room_id IS NULL OR pr.room_id IS NULL OR pr.room_id = p_room_id)
    AND (p_space_type_id IS NULL OR pr.space_type_id IS NULL OR pr.space_type_id = p_space_type_id)
    AND (p_room_id IS NULL OR pr.space_type_id IS NULL OR EXISTS(
      SELECT 1 FROM public.rooms r WHERE r.id = p_room_id AND r.space_type_id = pr.space_type_id))
    AND (pr.room_id IS NULL OR p_space_type_id IS NULL OR EXISTS(
      SELECT 1 FROM public.rooms r WHERE r.id = pr.room_id AND r.space_type_id = p_space_type_id))
    AND private.pricing_rule_windows_overlap(pr,p_start_time,p_end_time,p_days,p_start_date,p_end_date)
    AND (public.is_super_admin() OR public._playspot_has_lounge_access(p_lounge_id))
  ORDER BY pr.priority DESC,pr.created_at DESC;
$function$;
REVOKE ALL ON FUNCTION public.check_pricing_rule_conflicts_v2(uuid,time,time,integer[],uuid,uuid,uuid,date,date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_pricing_rule_conflicts_v2(uuid,time,time,integer[],uuid,uuid,uuid,date,date) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.check_pricing_rule_conflicts(
  p_lounge_id uuid, p_start_time time, p_end_time time, p_days integer[],
  p_space_type_id uuid DEFAULT NULL, p_room_id uuid DEFAULT NULL, p_exclude_rule_id uuid DEFAULT NULL
)
RETURNS SETOF public.pricing_rules LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $function$
  SELECT * FROM public.check_pricing_rule_conflicts_v2(p_lounge_id,p_start_time,p_end_time,p_days,
    p_space_type_id,p_room_id,p_exclude_rule_id,NULL,NULL);
$function$;
REVOKE ALL ON FUNCTION public.check_pricing_rule_conflicts(uuid,time,time,integer[],uuid,uuid,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_pricing_rule_conflicts(uuid,time,time,integer[],uuid,uuid,uuid) TO authenticated, service_role;
NOTIFY pgrst, 'reload schema';
COMMIT;
