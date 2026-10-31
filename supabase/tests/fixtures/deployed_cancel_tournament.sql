-- Read-only snapshot of the preserved local baseline; no rows or credentials.
-- Definition MD5: 6af3d0237b8df0da55cb0552db1f9968
CREATE OR REPLACE FUNCTION public.cancel_tournament(p_tournament_id uuid, p_reason text)
 RETURNS tournaments
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
DECLARE
  v public.tournaments%ROWTYPE;
  old jsonb;
BEGIN
  SELECT * INTO v FROM public.tournaments WHERE id = p_tournament_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'tournament_not_found';
  END IF;

  IF NOT (is_super_admin() OR private.can_operate_playspot_lounge(v.lounge_id) OR is_lounge_member_or_admin(v.lounge_id)) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  IF v.status IN ('completed', 'cancelled') THEN
    RAISE EXCEPTION 'tournament_already_closed';
  END IF;

  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'cancel_reason_required';
  END IF;

  old := to_jsonb(v);

  UPDATE public.tournaments
  SET status = 'cancelled', updated_at = now()
  WHERE id = v.id
  RETURNING * INTO v;

  INSERT INTO public.tournament_refunds(tournament_id, participant_id, user_id, amount, reason)
  SELECT v.id, p.id, p.user_id, v.entry_fee, p_reason
  FROM public.tournament_participants p
  WHERE p.tournament_id = v.id AND p.user_id IS NOT NULL AND p.payment_status = 'paid'
  ON CONFLICT DO NOTHING;

  UPDATE public.tournament_participants
  SET registration_status = 'cancelled',
      payment_status = CASE WHEN payment_status = 'paid' THEN 'refund_pending' ELSE 'cancelled' END,
      updated_at = now()
  WHERE tournament_id = v.id;

  PERFORM public.tournament_audit(v.id, 'tournament_cancelled', NULL, NULL, old, to_jsonb(v), p_reason);

  RETURN v;
END;
$function$
