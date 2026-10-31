BEGIN;

CREATE OR REPLACE FUNCTION public.award_tournament_prizes(p_tournament_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public','private','pg_temp'
AS $function$
DECLARE
  t public.tournaments%ROWTYPE;
  p public.tournament_prizes%ROWTYPE;
  pl public.tournament_placements%ROWTYPE;
  v_user_id uuid;
  v_inserted boolean;
  n integer := 0;
BEGIN
  SELECT * INTO t
  FROM public.tournaments
  WHERE id=p_tournament_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'tournament_not_found' USING ERRCODE='P0002';
  END IF;

  IF NOT (
    public.is_super_admin()
    OR private.is_lounge_manager(t.lounge_id)
  ) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501';
  END IF;

  IF t.status<>'completed' THEN
    RAISE EXCEPTION 'tournament_not_completed' USING ERRCODE='55000';
  END IF;

  FOR p IN
    SELECT *
    FROM public.tournament_prizes
    WHERE tournament_id=t.id
    ORDER BY placement
  LOOP
    SELECT *
    INTO pl
    FROM public.tournament_placements
    WHERE tournament_id=t.id
      AND placement=p.placement;

    IF pl.participant_id IS NULL THEN
      CONTINUE;
    END IF;

    SELECT tp.user_id
    INTO v_user_id
    FROM public.tournament_participants AS tp
    WHERE tp.id=pl.participant_id;

    IF v_user_id IS NULL THEN
      CONTINUE;
    END IF;

    IF (p.points+p.bonus)>0 THEN
      INSERT INTO public.points_transactions(
        user_id,points,type,reference_id,description,
        source_type,source_id,idempotency_key,metadata
      )
      VALUES(
        v_user_id,
        p.points+p.bonus,
        'tournament_prize',
        p.id,
        'Tournament prize: '||COALESCE(t.title_en,t.title_ar,'Tournament'),
        'tournament',
        t.id,
        'tournament:'||t.id::text||':placement:'||p.placement,
        jsonb_build_object(
          'placement',p.placement,
          'tournament',COALESCE(t.title_en,t.title_ar),
          'bonus',p.bonus
        )
      )
      ON CONFLICT(idempotency_key) DO NOTHING;

      v_inserted := FOUND;

      IF EXISTS (
        SELECT 1
        FROM public.points_transactions AS pt
        WHERE pt.idempotency_key =
          'tournament:'||t.id::text||':placement:'||p.placement
      ) THEN
        UPDATE public.tournament_prize_rewards
        SET is_delivered=true,
            delivered_at=COALESCE(delivered_at,now()),
            updated_at=now()
        WHERE prize_id=p.id
          AND reward_type='points'
          AND is_delivered IS FALSE;
      END IF;

      IF v_inserted THEN
        INSERT INTO public.notifications(
          user_id,lounge_id,title_ar,title_en,body_ar,body_en,type,metadata
        )
        VALUES(
          v_user_id,
          t.lounge_id,
          'مبروك! حصلت على جائزة البطولة 🏆',
          'Congratulations! You won a tournament prize 🏆',
          'تمت إضافة '||(p.points+p.bonus)||' نقطة إلى حسابك عن المركز '||p.placement||'.',
          'You received '||(p.points+p.bonus)||' points for placement '||p.placement||'.',
          'tournament_prize',
          jsonb_build_object(
            'tournament_id',t.id,
            'placement',p.placement,
            'points',p.points,
            'bonus',p.bonus
          )
        );
        n:=n+1;
      END IF;
    END IF;
  END LOOP;

  PERFORM public.tournament_audit(
    t.id,
    'tournament_prizes_awarded',
    NULL,
    NULL,
    NULL,
    jsonb_build_object('entries',n)
  );

  RETURN n;
END;
$function$;

REVOKE ALL ON FUNCTION public.award_tournament_prizes(uuid)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.award_tournament_prizes(uuid)
TO authenticated, service_role;

COMMIT;
