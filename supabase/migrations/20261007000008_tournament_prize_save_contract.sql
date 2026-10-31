BEGIN;

CREATE OR REPLACE FUNCTION public.save_tournament_prizes(
  p_tournament_id uuid,
  p_prizes jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_tournament public.tournaments%ROWTYPE;
  v_prize jsonb;
  v_reward jsonb;
  v_prize_id uuid;
  v_placement integer;
  v_reward_type text;
  v_amount numeric;
  v_points integer;
  v_saved integer := 0;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000';
  END IF;

  SELECT t.*
  INTO v_tournament
  FROM public.tournaments AS t
  WHERE t.id = p_tournament_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'tournament_not_found' USING ERRCODE='P0002';
  END IF;

  IF NOT (
    public.is_super_admin()
    OR private.can_operate_playspot_lounge(v_tournament.lounge_id)
    OR public.is_lounge_member_or_admin(v_tournament.lounge_id)
  ) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501';
  END IF;

  IF v_tournament.status IN ('in_progress','completed','cancelled') THEN
    RAISE EXCEPTION 'tournament_prizes_locked' USING ERRCODE='55000';
  END IF;

  IF p_prizes IS NULL OR jsonb_typeof(p_prizes) <> 'array' THEN
    RAISE EXCEPTION 'prizes_must_be_array' USING ERRCODE='22023';
  END IF;

  IF jsonb_array_length(p_prizes) > 64 THEN
    RAISE EXCEPTION 'too_many_prize_placements' USING ERRCODE='22023';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM (
      SELECT (x->>'placement')::integer AS placement
      FROM jsonb_array_elements(p_prizes) AS x
    ) AS placements
    GROUP BY placement
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'duplicate_prize_placement' USING ERRCODE='23505';
  END IF;

  DELETE FROM public.tournament_prizes
  WHERE tournament_id = p_tournament_id;

  FOR v_prize IN SELECT value FROM jsonb_array_elements(p_prizes)
  LOOP
    BEGIN
      v_placement := (v_prize->>'placement')::integer;
    EXCEPTION WHEN OTHERS THEN
      RAISE EXCEPTION 'invalid_prize_placement' USING ERRCODE='22023';
    END;

    IF v_placement < 1 THEN
      RAISE EXCEPTION 'invalid_prize_placement' USING ERRCODE='22023';
    END IF;

    v_points := 0;

    IF COALESCE(v_prize->'rewards','[]'::jsonb) IS NOT NULL
       AND jsonb_typeof(COALESCE(v_prize->'rewards','[]'::jsonb)) <> 'array' THEN
      RAISE EXCEPTION 'prize_rewards_must_be_array' USING ERRCODE='22023';
    END IF;

    FOR v_reward IN
      SELECT value
      FROM jsonb_array_elements(COALESCE(v_prize->'rewards','[]'::jsonb))
    LOOP
      v_reward_type := lower(btrim(COALESCE(
        v_reward->>'reward_type',
        v_reward->>'type',
        ''
      )));

      IF v_reward_type NOT IN ('trophy','cash','points','voucher','custom') THEN
        RAISE EXCEPTION 'invalid_prize_reward_type' USING ERRCODE='22023';
      END IF;

      BEGIN
        v_amount := NULLIF(
          COALESCE(v_reward->>'amount', v_reward->>'value', ''),
          ''
        )::numeric;
      EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'invalid_prize_reward_amount' USING ERRCODE='22023';
      END;

      IF v_reward_type IN ('cash','points')
         AND (v_amount IS NULL OR v_amount < 0) THEN
        RAISE EXCEPTION 'prize_reward_amount_required' USING ERRCODE='22023';
      END IF;

      IF v_reward_type = 'cash'
         AND NULLIF(btrim(COALESCE(v_reward->>'currency','')),'') IS NULL THEN
        RAISE EXCEPTION 'cash_reward_currency_required' USING ERRCODE='22023';
      END IF;

      IF v_reward_type = 'points' THEN
        v_points := v_points + floor(v_amount)::integer;
      END IF;
    END LOOP;

    INSERT INTO public.tournament_prizes (
      tournament_id,
      placement,
      points,
      bonus,
      metadata
    )
    VALUES (
      p_tournament_id,
      v_placement,
      v_points,
      0,
      COALESCE(v_prize->'metadata','{}'::jsonb)
    )
    RETURNING id INTO v_prize_id;

    FOR v_reward IN
      SELECT value
      FROM jsonb_array_elements(COALESCE(v_prize->'rewards','[]'::jsonb))
    LOOP
      v_reward_type := lower(btrim(COALESCE(
        v_reward->>'reward_type',
        v_reward->>'type',
        ''
      )));

      BEGIN
        v_amount := NULLIF(
          COALESCE(v_reward->>'amount', v_reward->>'value', ''),
          ''
        )::numeric;
      EXCEPTION WHEN OTHERS THEN
        v_amount := NULL;
      END;

      INSERT INTO public.tournament_prize_rewards (
        prize_id,
        reward_type,
        title_ar,
        title_en,
        description_ar,
        description_en,
        amount,
        currency,
        metadata,
        is_delivered
      )
      VALUES (
        v_prize_id,
        v_reward_type,
        NULLIF(btrim(COALESCE(v_reward->>'title_ar','')),''),
        NULLIF(btrim(COALESCE(v_reward->>'title_en','')),''),
        NULLIF(btrim(COALESCE(v_reward->>'description_ar','')),''),
        NULLIF(btrim(COALESCE(v_reward->>'description_en','')),''),
        v_amount,
        NULLIF(btrim(COALESCE(v_reward->>'currency','')),''),
        COALESCE(v_reward->'metadata','{}'::jsonb),
        false
      );
    END LOOP;

    v_saved := v_saved + 1;
  END LOOP;

  PERFORM public.tournament_audit(
    p_tournament_id,
    'tournament_prizes_saved',
    NULL,
    NULL,
    NULL,
    jsonb_build_object('placements', v_saved)
  );

  RETURN jsonb_build_object(
    'success', true,
    'tournament_id', p_tournament_id,
    'placements_saved', v_saved
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.save_tournament_prizes(uuid,jsonb)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_tournament_prizes(uuid,jsonb)
TO authenticated, service_role;

COMMIT;
