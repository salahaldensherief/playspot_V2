BEGIN;

-- Match writers lock tournament, then match. Confirmation/resolution in the
-- preceding candidate use the same order; the deadline worker skips busy rows.
CREATE OR REPLACE FUNCTION public.start_tournament_match(p_match_id uuid, p_room_id uuid DEFAULT NULL)
RETURNS public.tournament_matches LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_tournament_id uuid;
  m public.tournament_matches%ROWTYPE;
  t public.tournaments%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000'; END IF;
  PERFORM private.require_active_booking_actor();
  SELECT tournament_id INTO v_tournament_id FROM public.tournament_matches WHERE id = p_match_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'match_not_found' USING ERRCODE = 'P0002'; END IF;
  SELECT * INTO t FROM public.tournaments WHERE id = v_tournament_id FOR NO KEY UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'tournament_not_found' USING ERRCODE = 'P0002'; END IF;
  IF NOT (public.is_super_admin() IS TRUE OR private.is_lounge_manager(t.lounge_id) IS TRUE) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO m FROM public.tournament_matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND OR m.tournament_id IS DISTINCT FROM t.id THEN
    RAISE EXCEPTION 'match_changed' USING ERRCODE = '40001';
  END IF;
  IF t.status NOT IN ('draw_completed', 'in_progress') THEN
    RAISE EXCEPTION 'tournament_not_startable' USING ERRCODE = '55000';
  END IF;
  IF t.tournament_starts_at IS NULL OR t.tournament_starts_at > now() THEN
    RAISE EXCEPTION 'tournament_not_started' USING ERRCODE = '55000';
  END IF;
  IF m.status <> 'scheduled' OR m.player1_id IS NULL OR m.player2_id IS NULL THEN
    RAISE EXCEPTION 'match_not_ready' USING ERRCODE = '55000';
  END IF;
  IF COALESCE(p_room_id, m.room_id) IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.rooms AS r WHERE r.id = COALESCE(p_room_id, m.room_id)
      AND r.lounge_id = t.lounge_id AND r.is_active IS TRUE AND r.status <> 'deleted') THEN
    RAISE EXCEPTION 'invalid_tournament_room' USING ERRCODE = '22023';
  END IF;
  UPDATE public.tournament_matches SET room_id = COALESCE(p_room_id, room_id),
    status = 'in_progress', started_at = COALESCE(started_at, now()), updated_at = now()
  WHERE id = m.id RETURNING * INTO m;
  IF t.status = 'draw_completed' THEN
    UPDATE public.tournaments SET status = 'in_progress', updated_at = now() WHERE id = t.id;
    PERFORM public.tournament_audit(t.id, 'tournament_status_changed', NULL, m.id,
      to_jsonb(t), jsonb_build_object('status', 'in_progress'));
  END IF;
  PERFORM public.tournament_audit(t.id, 'match_started', NULL, m.id, NULL, to_jsonb(m));
  RETURN m;
END;
$$;
REVOKE ALL ON FUNCTION public.start_tournament_match(uuid,uuid) FROM PUBLIC, anon, service_role, supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.start_tournament_match(uuid,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.submit_match_result(p_match_id uuid, p_score_player1 integer,
  p_score_player2 integer, p_proof_image_url text)
RETURNS public.tournament_matches LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_tournament_id uuid;
  m public.tournament_matches%ROWTYPE;
  t public.tournaments%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000'; END IF;
  PERFORM private.require_active_booking_actor();
  IF p_score_player1 IS NULL OR p_score_player2 IS NULL OR p_score_player1 < 0
     OR p_score_player2 < 0 OR p_score_player1 = p_score_player2 THEN
    RAISE EXCEPTION 'invalid_result' USING ERRCODE = '22023';
  END IF;
  SELECT tournament_id INTO v_tournament_id FROM public.tournament_matches WHERE id = p_match_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'match_not_found' USING ERRCODE = 'P0002'; END IF;
  SELECT * INTO t FROM public.tournaments WHERE id = v_tournament_id FOR NO KEY UPDATE;
  SELECT * INTO m FROM public.tournament_matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND OR m.tournament_id IS DISTINCT FROM t.id THEN
    RAISE EXCEPTION 'match_changed' USING ERRCODE = '40001';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.tournament_participants WHERE user_id = auth.uid()
    AND id IN (m.player1_id, m.player2_id)) THEN
    RAISE EXCEPTION 'not_match_participant' USING ERRCODE = '42501';
  END IF;
  IF t.status <> 'in_progress' OR t.tournament_starts_at IS NULL OR t.tournament_starts_at > now()
    OR m.status <> 'in_progress' OR m.player1_id IS NULL OR m.player2_id IS NULL THEN
    RAISE EXCEPTION 'match_not_in_progress' USING ERRCODE = '55000';
  END IF;
  UPDATE public.tournament_matches SET score_player1 = p_score_player1, score_player2 = p_score_player2,
    proof_image_url = p_proof_image_url, submitted_by = auth.uid(), result_submitted_at = now(),
    confirmation_deadline = now() + interval '5 minutes', status = 'pending_confirmation', updated_at = now()
  WHERE id = m.id RETURNING * INTO m;
  PERFORM public.tournament_audit(t.id, 'match_result_submitted', NULL, m.id, NULL, to_jsonb(m));
  RETURN m;
END;
$$;
REVOKE ALL ON FUNCTION public.submit_match_result(uuid,integer,integer,text) FROM PUBLIC, anon, service_role, supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.submit_match_result(uuid,integer,integer,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.auto_confirm_tournament_results()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_tournament_id uuid;
  m public.tournament_matches%ROWTYPE;
  v_winner uuid;
  n integer := 0;
BEGIN
  FOR v_tournament_id IN
    SELECT DISTINCT tournament_id FROM public.tournament_matches
    WHERE status = 'pending_confirmation' AND confirmation_deadline <= now()
    ORDER BY tournament_id LIMIT 100
  LOOP
    EXIT WHEN n >= 500;
    PERFORM 1 FROM public.tournaments WHERE id = v_tournament_id
      AND status IN ('draw_completed', 'in_progress') FOR NO KEY UPDATE SKIP LOCKED;
    IF NOT FOUND THEN CONTINUE; END IF;
    FOR m IN
      SELECT * FROM public.tournament_matches WHERE tournament_id = v_tournament_id
        AND status = 'pending_confirmation' AND confirmation_deadline <= now()
        AND score_player1 IS NOT NULL AND score_player2 IS NOT NULL
        AND score_player1 >= 0 AND score_player2 >= 0 AND score_player1 <> score_player2
        AND player1_id IS NOT NULL AND player2_id IS NOT NULL
      ORDER BY confirmation_deadline, id LIMIT (500 - n) FOR UPDATE SKIP LOCKED
    LOOP
      v_winner := CASE WHEN m.score_player1 > m.score_player2 THEN m.player1_id ELSE m.player2_id END;
      UPDATE public.tournament_matches SET winner_id = v_winner, status = 'completed',
        completed_at = COALESCE(completed_at, now()), updated_at = now() WHERE id = m.id;
      IF m.next_match_id IS NOT NULL THEN
        IF m.next_match_slot = 1 THEN
          UPDATE public.tournament_matches SET player1_id = v_winner, updated_at = now()
          WHERE id = m.next_match_id AND player1_id IS NULL;
        ELSIF m.next_match_slot = 2 THEN
          UPDATE public.tournament_matches SET player2_id = v_winner, updated_at = now()
          WHERE id = m.next_match_id AND player2_id IS NULL;
        END IF;
      END IF;
      PERFORM public.tournament_audit(m.tournament_id, 'match_auto_confirmed', v_winner, m.id,
        NULL, jsonb_build_object('score_player1', m.score_player1, 'score_player2', m.score_player2,
                               'confirmation_deadline', m.confirmation_deadline));
      n := n + 1;
    END LOOP;
    PERFORM public.apply_tournament_walkovers(v_tournament_id);
  END LOOP;
  RETURN n;
END;
$$;
REVOKE ALL ON FUNCTION public.auto_confirm_tournament_results() FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;
-- Preserve the baseline's server-only callers; neither is a Flutter client role.
GRANT EXECUTE ON FUNCTION public.auto_confirm_tournament_results() TO service_role, supabase_auth_admin;
NOTIFY pgrst, 'reload schema';
COMMIT;
