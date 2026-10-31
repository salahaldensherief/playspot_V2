BEGIN;

-- Expose the display names needed by a tournament roster without granting
-- managers SELECT on unrelated profile rows or returning email/phone data.
CREATE OR REPLACE FUNCTION public.get_tournament_participant_names(p_tournament_id uuid)
RETURNS TABLE(participant_id uuid, user_id uuid, user_name text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_lounge_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles AS actor
    WHERE actor.id = auth.uid() AND actor.is_active IS TRUE
      AND actor.is_banned IS NOT TRUE) THEN
    RAISE EXCEPTION 'inactive_account' USING ERRCODE = '42501';
  END IF;
  SELECT t.lounge_id INTO v_lounge_id FROM public.tournaments AS t
  WHERE t.id = p_tournament_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'tournament_not_found' USING ERRCODE = 'P0002';
  END IF;
  IF NOT (
    public.is_super_admin() IS TRUE
    OR private.is_lounge_manager(v_lounge_id) IS TRUE
    OR public.has_lounge_permission(v_lounge_id, 'tournaments_view') IS TRUE
    OR EXISTS (SELECT 1 FROM public.tournament_participants AS own
      WHERE own.tournament_id = p_tournament_id AND own.user_id = auth.uid())
  ) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT participant.id, participant.user_id, NULLIF(btrim(profile.full_name), '')
  FROM public.tournament_participants AS participant
  LEFT JOIN public.profiles AS profile ON profile.id = participant.user_id
  WHERE participant.tournament_id = p_tournament_id
  ORDER BY participant.created_at, participant.id;
END;
$$;
REVOKE ALL ON FUNCTION public.get_tournament_participant_names(uuid)
FROM PUBLIC, anon, service_role, supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.get_tournament_participant_names(uuid) TO authenticated;
NOTIFY pgrst, 'reload schema';

COMMIT;
