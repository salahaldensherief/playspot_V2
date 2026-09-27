BEGIN;

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
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000';
  END IF;

  SELECT *
  INTO v_match
  FROM public.tournament_matches
  WHERE id = p_match_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'match_not_found' USING ERRCODE = 'P0002';
  END IF;

  SELECT *
  INTO v_tournament
  FROM public.tournaments
  WHERE id = v_match.tournament_id
  FOR UPDATE;

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

  IF v_match.status <> 'pending_confirmation'
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

  RETURN v_match;
END;
$function$;

CREATE OR REPLACE FUNCTION public.dispute_match_result(
  p_match_id uuid,
  p_reason text
)
RETURNS public.tournament_matches
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_match public.tournament_matches%ROWTYPE;
  v_tournament public.tournaments%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000';
  END IF;

  IF NULLIF(btrim(p_reason), '') IS NULL THEN
    RAISE EXCEPTION 'dispute_reason_required' USING ERRCODE = '22023';
  END IF;

  SELECT *
  INTO v_match
  FROM public.tournament_matches
  WHERE id = p_match_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'match_not_found' USING ERRCODE = 'P0002';
  END IF;

  SELECT *
  INTO v_tournament
  FROM public.tournaments
  WHERE id = v_match.tournament_id;

  IF v_match.status <> 'pending_confirmation' THEN
    RAISE EXCEPTION 'result_not_pending' USING ERRCODE = '55000';
  END IF;

  IF v_match.submitted_by = auth.uid() THEN
    RAISE EXCEPTION 'result_submitter_cannot_dispute_own_submission'
      USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.tournament_participants AS p
    WHERE p.user_id = auth.uid()
      AND p.id IN (v_match.player1_id, v_match.player2_id)
  ) THEN
    RAISE EXCEPTION 'not_match_participant' USING ERRCODE = '42501';
  END IF;

  UPDATE public.tournament_matches
  SET status = 'disputed',
      dispute_reason = btrim(p_reason),
      disputed_by = auth.uid(),
      disputed_at = now(),
      updated_at = now()
  WHERE id = v_match.id
  RETURNING *
  INTO v_match;

  INSERT INTO public.notifications (
    user_id,
    lounge_id,
    title_ar,
    title_en,
    body_ar,
    body_en,
    type,
    metadata
  )
  SELECT DISTINCT
    recipient.user_id,
    v_tournament.lounge_id,
    'نزاع جديد في مباراة',
    'New tournament dispute',
    'يوجد نزاع يحتاج إلى مراجعة.',
    'A tournament dispute requires review.',
    'tournament_dispute',
    jsonb_build_object(
      'tournament_id', v_tournament.id,
      'match_id', v_match.id,
      'reason', btrim(p_reason)
    )
  FROM (
    SELECT ls.user_id
    FROM public.lounge_staff AS ls
    WHERE ls.lounge_id = v_tournament.lounge_id
      AND ls.role IN ('lounge_owner', 'manager')
    UNION
    SELECT p.id
    FROM public.profiles AS p
    WHERE p.lounge_id = v_tournament.lounge_id
      AND p.role IN ('lounge_admin', 'admin', 'owner', 'manager')
  ) AS recipient;

  PERFORM public.tournament_audit(
    v_tournament.id,
    'match_disputed',
    NULL,
    v_match.id,
    NULL,
    to_jsonb(v_match),
    btrim(p_reason)
  );

  RETURN v_match;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.confirm_match_result(uuid)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.confirm_match_result(uuid)
TO authenticated, service_role, supabase_auth_admin;

REVOKE EXECUTE ON FUNCTION public.dispute_match_result(uuid, text)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.dispute_match_result(uuid, text)
TO authenticated, service_role, supabase_auth_admin;

COMMIT;
