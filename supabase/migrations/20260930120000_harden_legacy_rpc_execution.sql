BEGIN;

CREATE OR REPLACE FUNCTION public.submit_tournament_payment(
  p_participant_id uuid,
  p_tournament_id uuid,
  p_user_id uuid,
  p_amount numeric,
  p_payment_method text,
  p_receipt_url text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_curr_status text;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;
  IF p_user_id IS DISTINCT FROM v_actor THEN
    RAISE EXCEPTION 'User identity mismatch' USING ERRCODE = '42501';
  END IF;
  IF COALESCE(p_amount, 0) < 0
     OR NULLIF(btrim(p_payment_method), '') IS NULL
     OR NULLIF(btrim(p_receipt_url), '') IS NULL THEN
    RAISE EXCEPTION 'Invalid tournament payment submission' USING ERRCODE = '22023';
  END IF;

  SELECT tp.status::text INTO v_curr_status
  FROM public.tournament_participants AS tp
  WHERE tp.id = p_participant_id
    AND tp.tournament_id = p_tournament_id
    AND tp.user_id = v_actor
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tournament participant not found for current user'
      USING ERRCODE = '42501';
  END IF;
  IF v_curr_status IN ('payment_submitted', 'paid', 'confirmed') THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_submitted', true,
      'participant_id', p_participant_id
    );
  END IF;

  UPDATE public.tournament_participants
  SET status = 'payment_submitted',
      payment_method = btrim(p_payment_method),
      receipt_url = btrim(p_receipt_url),
      updated_at = now()
  WHERE id = p_participant_id;

  RETURN jsonb_build_object(
    'success', true,
    'already_submitted', false,
    'participant_id', p_participant_id
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.submit_tournament_payment(uuid, uuid, uuid, numeric, text, text)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_tournament_payment(uuid, uuid, uuid, numeric, text, text)
TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_my_profile(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_profile(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_staff_permissions(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_staff_permissions(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.has_permission(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_permission(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.validate_voucher_by_code(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.validate_voucher_by_code(text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.consume_voucher_by_code(text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.consume_voucher_by_code(text, uuid) TO authenticated;

-- Trigger/worker functions are not client API endpoints.
REVOKE EXECUTE ON FUNCTION public.attach_booking_to_active_shift()
FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_booking_notifications()
FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.check_and_send_booking_reminders()
FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_validate_and_clamp_booking_price()
FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_validate_and_clamp_mobile_booking_price()
FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_award_points_on_review()
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.check_and_send_booking_reminders()
TO service_role;

COMMIT;
