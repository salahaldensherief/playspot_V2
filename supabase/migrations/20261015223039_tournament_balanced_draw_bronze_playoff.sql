BEGIN;

-- Historical brackets retain their rows and outcomes. Only new draws add a playoff.
ALTER TABLE public.tournament_matches ADD COLUMN match_type text NOT NULL DEFAULT 'bracket'
  CHECK (match_type IN ('bracket', 'third_place'));
CREATE UNIQUE INDEX tournament_one_bronze_match
  ON public.tournament_matches(tournament_id) WHERE match_type = 'third_place';

-- Internal progression writes bypass client RLS intentionally; never expose this helper.
CREATE OR REPLACE FUNCTION public.apply_tournament_walkovers(p_tournament_id uuid)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  m public.tournament_matches%ROWTYPE;
  bronze public.tournament_matches%ROWTYPE;
  v_winner uuid;
  v_loser1 uuid;
  v_loser2 uuid;
  changed integer;
  total integer := 0;
BEGIN
  LOOP
    changed := 0;
    FOR m IN
      SELECT candidate.* FROM public.tournament_matches AS candidate
      WHERE candidate.tournament_id = p_tournament_id
        AND candidate.match_type = 'bracket' AND candidate.status = 'scheduled'
        AND (candidate.player1_id IS NULL OR candidate.player2_id IS NULL)
        AND (candidate.round_number = 1 OR (
          (SELECT count(*) FROM public.tournament_matches AS feeder
           WHERE feeder.next_match_id = candidate.id AND feeder.tournament_id = candidate.tournament_id) = 2
          AND NOT EXISTS (SELECT 1 FROM public.tournament_matches AS feeder
            WHERE feeder.next_match_id = candidate.id AND feeder.tournament_id = candidate.tournament_id
              AND feeder.status NOT IN ('completed', 'walkover', 'no_show'))))
      ORDER BY candidate.round_number, candidate.match_order
      FOR UPDATE OF candidate SKIP LOCKED
    LOOP
      v_winner := COALESCE(m.player1_id, m.player2_id);
      UPDATE public.tournament_matches SET winner_id = v_winner, status = 'walkover',
        completed_at = COALESCE(completed_at, now()), updated_at = now() WHERE id = m.id;
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

  SELECT * INTO bronze FROM public.tournament_matches
  WHERE tournament_id = p_tournament_id AND match_type = 'third_place' FOR UPDATE;
  -- Waiting for BOTH semifinals avoids a premature bronze walkover/result.
  IF FOUND AND bronze.status = 'scheduled'
    AND (SELECT count(*) FROM public.tournament_matches WHERE tournament_id = p_tournament_id
         AND match_type = 'bracket' AND round_number = bronze.round_number - 1) = 2
    AND NOT EXISTS (SELECT 1 FROM public.tournament_matches WHERE tournament_id = p_tournament_id
         AND match_type = 'bracket' AND round_number = bronze.round_number - 1
         AND status NOT IN ('completed', 'walkover', 'no_show')) THEN
    SELECT CASE WHEN status = 'completed' AND winner_id = player1_id THEN player2_id
                WHEN status = 'completed' AND winner_id = player2_id THEN player1_id END
      INTO v_loser1 FROM public.tournament_matches
      WHERE tournament_id = p_tournament_id AND match_type = 'bracket'
        AND round_number = bronze.round_number - 1 AND match_order = 1;
    SELECT CASE WHEN status = 'completed' AND winner_id = player1_id THEN player2_id
                WHEN status = 'completed' AND winner_id = player2_id THEN player1_id END
      INTO v_loser2 FROM public.tournament_matches
      WHERE tournament_id = p_tournament_id AND match_type = 'bracket'
        AND round_number = bronze.round_number - 1 AND match_order = 2;
    UPDATE public.tournament_matches SET player1_id = v_loser1, player2_id = v_loser2,
      status = CASE WHEN v_loser1 IS NULL OR v_loser2 IS NULL THEN 'walkover' ELSE 'scheduled' END,
      winner_id = CASE WHEN v_loser1 IS NULL OR v_loser2 IS NULL THEN coalesce(v_loser1, v_loser2) END,
      completed_at = CASE WHEN v_loser1 IS NULL OR v_loser2 IS NULL THEN now() END,
      updated_at = now()
    WHERE id = bronze.id AND (player1_id IS DISTINCT FROM v_loser1
       OR player2_id IS DISTINCT FROM v_loser2 OR v_loser1 IS NULL OR v_loser2 IS NULL);
  END IF;
  RETURN total;
END;
$$;
REVOKE ALL ON FUNCTION public.apply_tournament_walkovers(uuid) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.draw_tournament_bracket(p_tournament_id uuid)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  t public.tournaments%ROWTYPE;
  ids uuid[];
  slots uuid[];
  eligible integer;
  rounds integer;
  r integer;
  i integer;
  bit_index integer;
  leaf integer;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000'; END IF;
  PERFORM private.require_active_booking_actor();
  SELECT * INTO t FROM public.tournaments WHERE id = p_tournament_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'tournament_not_found' USING ERRCODE = 'P0002'; END IF;
  IF NOT (public.is_super_admin() IS TRUE OR private.is_lounge_manager(t.lounge_id) IS TRUE) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  IF t.status NOT IN ('registration_closed', 'check_in_closed') OR EXISTS (
    SELECT 1 FROM public.tournament_matches WHERE tournament_id = t.id) THEN
    RAISE EXCEPTION 'draw_not_allowed' USING ERRCODE = '55000';
  END IF;
  SELECT array_agg(id ORDER BY random()), count(*) INTO ids, eligible
  FROM public.tournament_participants WHERE tournament_id = t.id
    AND payment_status = 'paid' AND is_checked_in IS TRUE AND registration_status = 'checked_in';
  IF coalesce(eligible, 0) < 2 OR eligible > t.bracket_size
    OR t.bracket_size NOT IN (8, 16, 32) THEN
    RAISE EXCEPTION 'eligible_count_invalid' USING ERRCODE = '22023';
  END IF;
  rounds := log(2, t.bracket_size)::integer;
  slots := array_fill(NULL::uuid, ARRAY[t.bracket_size]);
  -- Bit reversal spreads byes between halves, quarters, then individual pairs.
  FOR i IN 0..eligible - 1 LOOP
    leaf := 0;
    FOR bit_index IN 0..rounds - 1 LOOP
      leaf := leaf * 2 + ((i >> bit_index) & 1);
    END LOOP;
    slots[leaf + 1] := ids[i + 1];
  END LOOP;
  FOR r IN 1..rounds LOOP
    FOR i IN 1..(t.bracket_size / (2 ^ r)::integer) LOOP
      INSERT INTO public.tournament_matches(tournament_id, round_number, match_order, status, match_type)
      VALUES(t.id, r, i, 'scheduled', 'bracket');
    END LOOP;
  END LOOP;
  UPDATE public.tournament_matches AS a
  SET next_match_id = b.id, next_match_slot = CASE WHEN a.match_order % 2 = 1 THEN 1 ELSE 2 END
  FROM public.tournament_matches AS b WHERE a.tournament_id = t.id AND b.tournament_id = t.id
    AND a.match_type = 'bracket' AND b.match_type = 'bracket'
    AND b.round_number = a.round_number + 1 AND b.match_order = (a.match_order + 1) / 2;
  FOR i IN 1..t.bracket_size / 2 LOOP
    UPDATE public.tournament_matches SET player1_id = slots[i * 2 - 1], player2_id = slots[i * 2]
    WHERE tournament_id = t.id AND round_number = 1 AND match_order = i AND match_type = 'bracket';
  END LOOP;
  IF eligible >= 4 THEN
    INSERT INTO public.tournament_matches(tournament_id, round_number, match_order, status, match_type)
    VALUES(t.id, rounds, 2, 'scheduled', 'third_place');
  END IF;
  PERFORM public.apply_tournament_walkovers(t.id);
  UPDATE public.tournaments SET status = 'draw_completed', updated_at = now() WHERE id = t.id;
  PERFORM public.tournament_audit(t.id, 'bracket_draw_completed', NULL, NULL, NULL,
    jsonb_build_object('bracket_size', t.bracket_size, 'eligible_count', eligible, 'participants', ids,
                      'third_place_playoff', eligible >= 4));
  RETURN (SELECT count(*)::integer FROM public.tournament_matches WHERE tournament_id = t.id);
END;
$$;
REVOKE ALL ON FUNCTION public.draw_tournament_bracket(uuid) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.draw_tournament_bracket(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.complete_tournament(p_tournament_id uuid)
RETURNS public.tournaments LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  t public.tournaments%ROWTYPE;
  f public.tournament_matches%ROWTYPE;
  bronze public.tournament_matches%ROWTYPE;
  runner_up uuid;
  third uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000'; END IF;
  PERFORM private.require_active_booking_actor();
  SELECT * INTO t FROM public.tournaments WHERE id = p_tournament_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'tournament_not_found' USING ERRCODE = 'P0002'; END IF;
  IF NOT (public.is_super_admin() IS TRUE OR private.is_lounge_manager(t.lounge_id) IS TRUE) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  IF t.status NOT IN ('draw_completed', 'in_progress', 'completed') THEN
    RAISE EXCEPTION 'completion_not_allowed' USING ERRCODE = '55000';
  END IF;
  SELECT * INTO f FROM public.tournament_matches WHERE tournament_id = t.id AND match_type = 'bracket'
  ORDER BY round_number DESC, match_order LIMIT 1;
  IF NOT FOUND OR f.status NOT IN ('completed', 'walkover') OR f.winner_id IS NULL
    OR (f.winner_id IS DISTINCT FROM f.player1_id AND f.winner_id IS DISTINCT FROM f.player2_id)
    OR EXISTS (SELECT 1 FROM public.tournament_matches WHERE tournament_id = t.id
      AND status NOT IN ('completed', 'walkover', 'no_show')) THEN
    RAISE EXCEPTION 'final_not_completed' USING ERRCODE = '55000';
  END IF;
  IF t.status = 'completed' THEN RETURN t; END IF;
  runner_up := CASE WHEN f.status = 'completed' AND f.winner_id = f.player1_id THEN f.player2_id
                    WHEN f.status = 'completed' AND f.winner_id = f.player2_id THEN f.player1_id END;
  SELECT * INTO bronze FROM public.tournament_matches WHERE tournament_id = t.id AND match_type = 'third_place';
  IF FOUND THEN
    IF bronze.winner_id IS NOT NULL
      AND bronze.winner_id IS DISTINCT FROM bronze.player1_id
      AND bronze.winner_id IS DISTINCT FROM bronze.player2_id THEN
      RAISE EXCEPTION 'invalid_bronze_winner' USING ERRCODE = '55000';
    END IF;
    third := bronze.winner_id;
  ELSIF f.status = 'completed' AND (
    SELECT count(DISTINCT slot.participant_id)
    FROM public.tournament_matches AS initial
    CROSS JOIN LATERAL (VALUES (initial.player1_id), (initial.player2_id)) AS slot(participant_id)
    WHERE initial.tournament_id = t.id AND initial.match_type = 'bracket' AND initial.round_number = 1
  ) = 3 THEN
    -- Three entrants can have a single actual semifinal loser. Legacy ambiguous
    -- two-loser brackets remain without a third place; never invent a tiebreak.
    SELECT CASE WHEN count(*) = 1 THEN (array_agg(loser))[1] END INTO third FROM (
      SELECT CASE WHEN winner_id = player1_id THEN player2_id WHEN winner_id = player2_id THEN player1_id END AS loser
      FROM public.tournament_matches WHERE tournament_id = t.id AND match_type = 'bracket'
        AND round_number = f.round_number - 1 AND status = 'completed'
        AND player1_id IS NOT NULL AND player2_id IS NOT NULL AND winner_id IS NOT NULL
    ) AS actual_semifinal_losers;
  END IF;
  UPDATE public.tournaments SET status = 'completed', champion_participant_id = f.winner_id,
    updated_at = now() WHERE id = t.id RETURNING * INTO t;
  INSERT INTO public.tournament_placements(tournament_id, placement, participant_id)
    VALUES(t.id, 1, f.winner_id);
  IF runner_up IS NOT NULL THEN
    INSERT INTO public.tournament_placements(tournament_id, placement, participant_id) VALUES(t.id, 2, runner_up);
  END IF;
  IF third IS NOT NULL THEN
    INSERT INTO public.tournament_placements(tournament_id, placement, participant_id) VALUES(t.id, 3, third);
  END IF;
  PERFORM public.tournament_audit(t.id, 'tournament_completed', f.winner_id, f.id, NULL, to_jsonb(t));
  RETURN t;
END;
$$;
REVOKE ALL ON FUNCTION public.complete_tournament(uuid) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.complete_tournament(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
