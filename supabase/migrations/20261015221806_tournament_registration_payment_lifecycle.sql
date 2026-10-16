BEGIN;

-- Cancellation already writes these states; align the constraint with that
-- existing refund-pending workflow. No payment or refund row is fabricated.
ALTER TABLE public.tournament_participants
  DROP CONSTRAINT tournament_participants_payment_status_check;
ALTER TABLE public.tournament_participants
  ADD CONSTRAINT tournament_participants_payment_status_check
  CHECK (payment_status IN ('unpaid', 'pending', 'paid', 'refund_pending', 'cancelled'));

CREATE OR REPLACE FUNCTION public.register_for_tournament(p_tournament_id uuid)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  t public.tournaments%ROWTYPE;
  p public.tournament_participants%ROWTYPE;
  occupied integer;
  position integer;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'authentication_required' USING ERRCODE = '28000'; END IF;
  PERFORM private.require_active_booking_actor();
  SELECT * INTO t FROM public.tournaments WHERE id = p_tournament_id FOR UPDATE;
  IF NOT FOUND OR t.status <> 'registration_open' OR now() < t.registration_opens_at
     OR now() >= t.registration_closes_at THEN
    RAISE EXCEPTION 'registration_closed' USING ERRCODE = '55000';
  END IF;
  IF t.entry_fee IS NULL OR t.entry_fee < 0 OR t.entry_fee::text IN ('NaN', 'Infinity', '-Infinity') THEN
    RAISE EXCEPTION 'invalid_entry_fee' USING ERRCODE = '22023';
  END IF;
  IF EXISTS (SELECT 1 FROM public.tournament_participants
    WHERE tournament_id = t.id AND user_id = auth.uid()) THEN
    RAISE EXCEPTION 'already_registered' USING ERRCODE = '23505';
  END IF;
  SELECT count(*) INTO occupied FROM public.tournament_participants
  WHERE tournament_id = t.id AND registration_status IN ('pending_payment', 'confirmed', 'checked_in');
  IF occupied >= t.max_participants THEN
    SELECT COALESCE(max(waitlist_position), 0) + 1 INTO position
    FROM public.tournament_participants WHERE tournament_id = t.id AND registration_status = 'waitlist';
    INSERT INTO public.tournament_participants(tournament_id, user_id, registration_status, waitlist_position)
    VALUES(t.id, auth.uid(), 'waitlist', position) RETURNING * INTO p;
  ELSE
    INSERT INTO public.tournament_participants(tournament_id, user_id, registration_status, payment_status, payment_deadline)
    VALUES(t.id, auth.uid(), CASE WHEN t.entry_fee = 0 THEN 'confirmed' ELSE 'pending_payment' END,
      CASE WHEN t.entry_fee = 0 THEN 'paid' ELSE 'unpaid' END,
      CASE WHEN t.entry_fee = 0 THEN NULL ELSE now() + make_interval(mins => t.payment_deadline_minutes) END)
    RETURNING * INTO p;
  END IF;
  PERFORM public.tournament_audit(t.id, CASE WHEN p.registration_status = 'waitlist' THEN 'waitlist_added' ELSE 'participant_registered' END,
    p.id, NULL, NULL, to_jsonb(p));
  RETURN row_to_json(p);
END;
$$;

CREATE OR REPLACE FUNCTION public.record_cash_tournament_payment(
  p_participant_id uuid, p_amount numeric, p_reference_note text DEFAULT NULL)
RETURNS public.tournament_participants
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  p public.tournament_participants%ROWTYPE;
  t public.tournaments%ROWTYPE;
  v_tournament_id uuid;
  occupied integer;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000'; END IF;
  PERFORM private.require_active_booking_actor();
  SELECT participant.tournament_id INTO v_tournament_id
  FROM public.tournament_participants AS participant WHERE participant.id = p_participant_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'participant_not_found' USING ERRCODE = 'P0002'; END IF;
  -- Registration/withdrawal lock tournament then participant; keep that order.
  SELECT * INTO t FROM public.tournaments WHERE id = v_tournament_id FOR UPDATE;
  SELECT * INTO p FROM public.tournament_participants WHERE id = p_participant_id FOR UPDATE;
  IF NOT FOUND OR p.tournament_id IS DISTINCT FROM t.id THEN
    RAISE EXCEPTION 'participant_changed' USING ERRCODE = '40001';
  END IF;
  IF NOT (public.is_super_admin() IS TRUE OR private.is_lounge_manager(t.lounge_id) IS TRUE
    OR public.has_lounge_permission(t.lounge_id, 'tournaments_manage') IS TRUE) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  IF t.status NOT IN ('registration_open', 'registration_closed', 'check_in_open')
     OR now() >= t.check_in_closes_at
     OR p.registration_status <> 'pending_payment' OR p.payment_status <> 'unpaid'
     OR p.payment_deadline IS NULL OR now() >= p.payment_deadline THEN
    RAISE EXCEPTION 'payment_not_allowed' USING ERRCODE = '55000';
  END IF;
  IF p_amount IS NULL OR p_amount < 0 OR p_amount <> round(p_amount, 2)
     OR p_amount::text IN ('NaN', 'Infinity', '-Infinity') OR p_amount <> t.entry_fee THEN
    RAISE EXCEPTION 'amount_mismatch' USING ERRCODE = '22023';
  END IF;
  SELECT count(*) INTO occupied FROM public.tournament_participants
  WHERE tournament_id = t.id AND registration_status IN ('confirmed', 'checked_in');
  IF occupied >= t.max_participants THEN RAISE EXCEPTION 'capacity_reached' USING ERRCODE = '55000'; END IF;
  UPDATE public.tournament_participants SET payment_status = 'paid', registration_status = 'confirmed',
    payment_method = 'cash', approved_by = auth.uid(), approved_at = now(),
    cash_received_by = auth.uid(), cash_received_at = now(), cash_reference_note = p_reference_note, updated_at = now()
  WHERE id = p.id RETURNING * INTO p;
  PERFORM public.tournament_audit(t.id, 'cash_payment_approved', p.id, NULL, NULL, to_jsonb(p), p_reference_note);
  RETURN p;
END;
$$;

CREATE OR REPLACE FUNCTION private.promote_tournament_waitlist_internal(p_tournament_id uuid)
RETURNS public.tournament_participants
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  t public.tournaments%ROWTYPE;
  p public.tournament_participants%ROWTYPE;
  occupied integer;
  old_position integer;
BEGIN
  SELECT * INTO t FROM public.tournaments WHERE id = p_tournament_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'tournament_not_found' USING ERRCODE = 'P0002'; END IF;
  IF t.status IN ('draw_completed', 'in_progress', 'completed', 'cancelled')
     OR now() >= t.check_in_closes_at THEN RETURN NULL; END IF;
  SELECT count(*) INTO occupied FROM public.tournament_participants
  WHERE tournament_id = t.id AND registration_status IN ('pending_payment', 'confirmed', 'checked_in');
  IF occupied >= t.max_participants THEN RETURN NULL; END IF;
  SELECT * INTO p FROM public.tournament_participants
  WHERE tournament_id = t.id AND registration_status = 'waitlist'
  ORDER BY waitlist_position, created_at, id FOR UPDATE SKIP LOCKED LIMIT 1;
  IF NOT FOUND THEN RETURN NULL; END IF;
  old_position := p.waitlist_position;
  UPDATE public.tournament_participants
  SET registration_status = CASE WHEN t.entry_fee = 0 THEN 'confirmed' ELSE 'pending_payment' END,
      payment_status = CASE WHEN t.entry_fee = 0 THEN 'paid' ELSE 'unpaid' END,
      payment_deadline = CASE WHEN t.entry_fee = 0 THEN NULL ELSE LEAST(t.check_in_closes_at, now() + make_interval(mins => t.payment_deadline_minutes)) END,
      waitlist_position = NULL, updated_at = now()
  WHERE id = p.id RETURNING * INTO p;
  UPDATE public.tournament_participants SET waitlist_position = waitlist_position - 1, updated_at = now()
  WHERE tournament_id = t.id AND registration_status = 'waitlist' AND waitlist_position > old_position;
  PERFORM public.tournament_audit(t.id, 'waitlist_promoted', p.id, NULL, NULL, to_jsonb(p),
    'Automatic promotion after a seat became available');
  RETURN p;
END;
$$;

REVOKE ALL ON FUNCTION public.register_for_tournament(uuid),
  public.record_cash_tournament_payment(uuid, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_for_tournament(uuid),
  public.record_cash_tournament_payment(uuid, numeric, text) TO authenticated;
REVOKE ALL ON FUNCTION private.promote_tournament_waitlist_internal(uuid)
FROM PUBLIC, anon, authenticated;
NOTIFY pgrst, 'reload schema';

COMMIT;
