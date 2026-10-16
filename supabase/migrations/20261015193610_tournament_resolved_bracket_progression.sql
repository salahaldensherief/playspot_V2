BEGIN;

-- A missing opponent is a bye only after both feeder branches are resolved.
-- Keep the helper restricted to server callers, matching the existing grants.
CREATE OR REPLACE FUNCTION public.apply_tournament_walkovers(p_tournament_id uuid)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  m public.tournament_matches%ROWTYPE;
  v_winner uuid;
  changed integer;
  total integer := 0;
BEGIN
  LOOP
    changed := 0;
    FOR m IN
      SELECT candidate.*
      FROM public.tournament_matches AS candidate
      WHERE candidate.tournament_id = p_tournament_id
        AND candidate.status = 'scheduled'
        AND (candidate.player1_id IS NULL OR candidate.player2_id IS NULL)
        AND (
          candidate.round_number = 1
          OR (
            (SELECT count(*) FROM public.tournament_matches AS feeder
             WHERE feeder.next_match_id = candidate.id
               AND feeder.tournament_id = candidate.tournament_id) = 2
            AND NOT EXISTS (
              SELECT 1 FROM public.tournament_matches AS feeder
              WHERE feeder.next_match_id = candidate.id
                AND feeder.tournament_id = candidate.tournament_id
                AND feeder.status NOT IN ('completed', 'walkover', 'no_show')
            )
          )
        )
      ORDER BY candidate.round_number, candidate.match_order
      FOR UPDATE OF candidate SKIP LOCKED
    LOOP
      v_winner := COALESCE(m.player1_id, m.player2_id);
      UPDATE public.tournament_matches
      SET winner_id = v_winner, status = 'walkover',
          completed_at = COALESCE(completed_at, now()), updated_at = now()
      WHERE id = m.id;
      -- Empty branches also become terminal, without inventing a winner.
      IF m.next_match_id IS NOT NULL AND v_winner IS NOT NULL THEN
        IF m.next_match_slot = 1 THEN
          UPDATE public.tournament_matches SET player1_id = v_winner, updated_at = now()
          WHERE id = m.next_match_id AND player1_id IS NULL;
        ELSE
          UPDATE public.tournament_matches SET player2_id = v_winner, updated_at = now()
          WHERE id = m.next_match_id AND player2_id IS NULL;
        END IF;
      END IF;
      PERFORM public.tournament_audit(p_tournament_id, 'match_walkover', v_winner,
        m.id, NULL, jsonb_build_object('winner_id', v_winner));
      changed := changed + 1;
      total := total + 1;
    END LOOP;
    EXIT WHEN changed = 0;
  END LOOP;
  RETURN total;
END;
$$;
REVOKE ALL ON FUNCTION public.apply_tournament_walkovers(uuid) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.publish_tournament(p_tournament_id uuid, p_open boolean)
RETURNS public.tournaments
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v public.tournaments%ROWTYPE;
  old jsonb;
  target_status text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000';
  END IF;
  SELECT * INTO v FROM public.tournaments WHERE id = p_tournament_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'tournament_not_found' USING ERRCODE = 'P0002';
  END IF;
  IF NOT (public.is_super_admin() IS TRUE OR private.is_lounge_manager(v.lounge_id) IS TRUE) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  IF p_open IS NULL THEN
    RAISE EXCEPTION 'invalid_publish_state' USING ERRCODE = '22023';
  END IF;
  IF v.status NOT IN ('draft', 'published', 'registration_open') THEN
    RAISE EXCEPTION 'publish_not_allowed' USING ERRCODE = '55000';
  END IF;
  target_status := CASE WHEN p_open THEN 'registration_open' ELSE 'published' END;
  IF v.status = target_status THEN RETURN v; END IF;
  old := to_jsonb(v);
  UPDATE public.tournaments SET status = target_status, updated_at = now()
  WHERE id = p_tournament_id RETURNING * INTO v;
  PERFORM public.tournament_audit(v.id, 'tournament_status_changed', NULL, NULL, old, to_jsonb(v));
  RETURN v;
END;
$$;
REVOKE ALL ON FUNCTION public.publish_tournament(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.publish_tournament(uuid, boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.confirm_match_result(
  p_match_id uuid
)
RETURNS public.tournament_matches
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_match public.tournament_matches%ROWTYPE;
  v_next public.tournament_matches%ROWTYPE;
  v_tournament public.tournaments%ROWTYPE;
  v_winner uuid;
  v_slot smallint;
  v_is_manager boolean := false;
  v_is_participant boolean := false;
  v_tournament_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000';
  END IF;

  SELECT tournament_id INTO v_tournament_id FROM public.tournament_matches WHERE id = p_match_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'match_not_found' USING ERRCODE = 'P0002';
  END IF;

  SELECT *
  INTO v_tournament
  FROM public.tournaments
  WHERE id = v_tournament_id
  FOR NO KEY UPDATE;
  SELECT * INTO v_match FROM public.tournament_matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND OR v_match.tournament_id IS DISTINCT FROM v_tournament.id THEN
    RAISE EXCEPTION 'match_changed' USING ERRCODE = '40001';
  END IF;

  v_is_manager :=
    public.is_super_admin()
    OR private.is_lounge_manager(v_tournament.lounge_id);

  SELECT EXISTS (
    SELECT 1
    FROM public.tournament_participants AS p
    WHERE p.user_id = auth.uid()
      AND p.id IN (v_match.player1_id, v_match.player2_id)
  )
  INTO v_is_participant;

  IF NOT v_is_manager AND NOT v_is_participant THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;

  IF NOT v_is_manager
     AND v_match.submitted_by IS NOT NULL
     AND v_match.submitted_by = auth.uid() THEN
    RAISE EXCEPTION 'result_submitter_cannot_self_confirm'
      USING ERRCODE = '42501';
  END IF;

  IF v_tournament.status NOT IN ('draw_completed', 'in_progress')
     OR v_match.status <> 'pending_confirmation'
     OR v_match.score_player1 IS NULL
     OR v_match.score_player2 IS NULL
     OR v_match.score_player1 = v_match.score_player2 THEN
    RAISE EXCEPTION 'result_not_pending' USING ERRCODE = '55000';
  END IF;

  v_winner := CASE
    WHEN v_match.score_player1 > v_match.score_player2
      THEN v_match.player1_id
    ELSE v_match.player2_id
  END;

  UPDATE public.tournament_matches
  SET winner_id = v_winner,
      status = 'completed',
      completed_at = now(),
      updated_at = now()
  WHERE id = v_match.id
  RETURNING *
  INTO v_match;

  IF v_match.next_match_id IS NOT NULL THEN
    SELECT *
    INTO v_next
    FROM public.tournament_matches
    WHERE id = v_match.next_match_id
    FOR UPDATE;

    v_slot := v_match.next_match_slot;

    IF v_slot = 1 THEN
      UPDATE public.tournament_matches
      SET player1_id = v_winner,
          updated_at = now()
      WHERE id = v_next.id
        AND player1_id IS NULL;
    ELSE
      UPDATE public.tournament_matches
      SET player2_id = v_winner,
          updated_at = now()
      WHERE id = v_next.id
        AND player2_id IS NULL;
    END IF;
  END IF;

  PERFORM public.tournament_audit(
    v_tournament.id,
    'match_result_confirmed',
    v_winner,
    v_match.id,
    NULL,
    to_jsonb(v_match)
  );

  PERFORM public.apply_tournament_walkovers(v_tournament.id);

  RETURN v_match;
END;
$function$;

CREATE OR REPLACE FUNCTION public.resolve_tournament_dispute(
  p_match_id uuid, p_winner_id uuid, p_score_player1 integer,
  p_score_player2 integer, p_notes text)
RETURNS public.tournament_matches
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  m public.tournament_matches%ROWTYPE;
  t public.tournaments%ROWTYPE;
  expected_winner uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000';
  END IF;
  SELECT * INTO m FROM public.tournament_matches WHERE id = p_match_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'match_not_found' USING ERRCODE = 'P0002'; END IF;
  SELECT * INTO t FROM public.tournaments WHERE id = m.tournament_id FOR NO KEY UPDATE;
  SELECT * INTO m FROM public.tournament_matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND OR m.tournament_id IS DISTINCT FROM t.id THEN
    RAISE EXCEPTION 'match_changed' USING ERRCODE = '40001';
  END IF;
  IF NOT (public.is_super_admin() IS TRUE OR private.is_lounge_manager(t.lounge_id) IS TRUE) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  IF m.status <> 'disputed' OR t.status IN ('completed', 'cancelled') THEN
    RAISE EXCEPTION 'match_not_disputed' USING ERRCODE = '55000';
  END IF;
  IF p_score_player1 IS NULL OR p_score_player2 IS NULL
     OR p_score_player1 < 0 OR p_score_player2 < 0 OR p_score_player1 = p_score_player2
     OR p_notes IS NULL OR btrim(p_notes) = ''
     OR m.player1_id IS NULL OR m.player2_id IS NULL THEN
    RAISE EXCEPTION 'invalid_resolution' USING ERRCODE = '22023';
  END IF;
  expected_winner := CASE WHEN p_score_player1 > p_score_player2 THEN m.player1_id ELSE m.player2_id END;
  IF p_winner_id IS DISTINCT FROM expected_winner THEN
    RAISE EXCEPTION 'invalid_resolution_winner' USING ERRCODE = '22023';
  END IF;
  UPDATE public.tournament_matches
  SET winner_id = p_winner_id, score_player1 = p_score_player1, score_player2 = p_score_player2,
      status = 'completed', resolved_by = auth.uid(), resolved_at = now(),
      resolution_notes = btrim(p_notes), completed_at = now(), updated_at = now()
  WHERE id = m.id RETURNING * INTO m;
  IF m.next_match_id IS NOT NULL THEN
    IF m.next_match_slot = 1 THEN
      UPDATE public.tournament_matches SET player1_id = p_winner_id, updated_at = now()
      WHERE id = m.next_match_id AND player1_id IS NULL;
    ELSE
      UPDATE public.tournament_matches SET player2_id = p_winner_id, updated_at = now()
      WHERE id = m.next_match_id AND player2_id IS NULL;
    END IF;
  END IF;
  PERFORM public.apply_tournament_walkovers(t.id);
  PERFORM public.tournament_audit(t.id, 'dispute_resolved', p_winner_id, m.id, NULL, to_jsonb(m), btrim(p_notes));
  RETURN m;
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_tournament(p_tournament_id uuid)
RETURNS public.tournaments
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  t public.tournaments%ROWTYPE;
  f public.tournament_matches%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000';
  END IF;
  SELECT * INTO t FROM public.tournaments WHERE id = p_tournament_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'tournament_not_found' USING ERRCODE = 'P0002'; END IF;
  IF NOT (public.is_super_admin() IS TRUE OR private.is_lounge_manager(t.lounge_id) IS TRUE) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  IF t.status NOT IN ('draw_completed', 'in_progress', 'completed') THEN
    RAISE EXCEPTION 'completion_not_allowed' USING ERRCODE = '55000';
  END IF;
  SELECT * INTO f FROM public.tournament_matches
  WHERE tournament_id = t.id ORDER BY round_number DESC, match_order LIMIT 1;
  IF NOT FOUND OR f.status NOT IN ('completed', 'walkover') OR f.winner_id IS NULL
     OR EXISTS (SELECT 1 FROM public.tournament_matches WHERE tournament_id = t.id
                AND status NOT IN ('completed', 'walkover', 'no_show')) THEN
    RAISE EXCEPTION 'final_not_completed' USING ERRCODE = '55000';
  END IF;
  IF t.status = 'completed' THEN RETURN t; END IF;
  UPDATE public.tournaments SET status = 'completed', champion_participant_id = f.winner_id,
    updated_at = now() WHERE id = t.id RETURNING * INTO t;
  INSERT INTO public.tournament_placements(tournament_id, placement, participant_id)
  VALUES(t.id, 1, f.winner_id)
  ON CONFLICT(tournament_id, placement) DO UPDATE SET participant_id = EXCLUDED.participant_id;
  PERFORM public.tournament_audit(t.id, 'tournament_completed', f.winner_id, f.id, NULL, to_jsonb(t));
  RETURN t;
END;
$$;

REVOKE ALL ON FUNCTION public.resolve_tournament_dispute(uuid, uuid, integer, integer, text),
  public.complete_tournament(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.resolve_tournament_dispute(uuid, uuid, integer, integer, text),
  public.complete_tournament(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
