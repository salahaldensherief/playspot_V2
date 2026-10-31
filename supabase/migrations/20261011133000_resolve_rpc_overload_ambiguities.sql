-- Migration: 20261011133000_resolve_rpc_overload_ambiguities.sql
-- Description: Resolve PostgREST PGRST203 candidate ambiguity errors by dropping obsolete overloads
--              and consolidating multi-signature functions:
--              1. validate_voucher_by_code: drop 1-arg overload, keep optional 2-arg (p_code, p_user_id)
--              2. get_top_lounges_by_revenue: drop 0-arg overload, keep parameterized limit_count default 10
--              3. get_notifications: drop 1-arg overload, keep paginated 3-arg (p_lang, p_limit, p_offset)
--              4. confirm_cash_payment: drop 1-arg overload, keep full discount & shift overload
--              5. swap_booking_room: drop legacy text-parameter overload, keep UUID actor signature
--              6. start_tournament_match: consolidate into single signature with optional p_room_id

BEGIN;

-- 1. validate_voucher_by_code
DROP FUNCTION IF EXISTS public.validate_voucher_by_code(text);

-- 2. get_top_lounges_by_revenue
DROP FUNCTION IF EXISTS public.get_top_lounges_by_revenue();

-- 3. get_notifications
DROP FUNCTION IF EXISTS public.get_notifications(text);

-- 4. confirm_cash_payment
DROP FUNCTION IF EXISTS public.confirm_cash_payment(uuid);

-- 5. swap_booking_room
DROP FUNCTION IF EXISTS public.swap_booking_room(uuid, uuid, text, text);

-- 6. start_tournament_match
DROP FUNCTION IF EXISTS public.start_tournament_match(uuid);
CREATE OR REPLACE FUNCTION public.start_tournament_match(p_match_id uuid, p_room_id uuid DEFAULT NULL::uuid)
 RETURNS tournament_matches
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

  IF NOT (
    public.is_super_admin()
    OR private.is_lounge_manager(v_tournament.lounge_id)
  ) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;

  IF v_match.status <> 'scheduled'
     OR v_match.player1_id IS NULL
     OR v_match.player2_id IS NULL THEN
    RAISE EXCEPTION 'match_not_ready' USING ERRCODE = '55000';
  END IF;

  IF p_room_id IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM public.rooms AS r
    WHERE r.id = p_room_id
      AND r.lounge_id = v_tournament.lounge_id
      AND r.is_active IS TRUE
      AND r.status <> 'deleted'
  ) THEN
    RAISE EXCEPTION 'invalid_tournament_room' USING ERRCODE = '22023';
  END IF;

  UPDATE public.tournament_matches
  SET room_id = COALESCE(p_room_id, room_id),
      status = 'in_progress',
      started_at = COALESCE(started_at, now()),
      updated_at = now()
  WHERE id = v_match.id
  RETURNING *
  INTO v_match;

  PERFORM public.tournament_audit(
    v_tournament.id,
    'match_started',
    NULL,
    v_match.id,
    NULL,
    to_jsonb(v_match)
  );

  RETURN v_match;
END;
$function$;
REVOKE ALL ON FUNCTION public.start_tournament_match(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.start_tournament_match(uuid, uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
