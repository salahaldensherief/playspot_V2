-- The legacy destination RPC quotes the entire expected booking price after a
-- verified deposit. Do not offer a second transfer amount until the canonical
-- final-bill settlement contract is available to all clients.
DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.get_booking_payment_destination(uuid)'::regprocedure))
       <> '6cc8ac058e5ccff1f55e3e1d9c1488a7' THEN
    RAISE EXCEPTION 'PAYMENT_DESTINATION_CONTRACT_DRIFT';
  END IF;
END;
$guard$;

CREATE OR REPLACE FUNCTION public.get_booking_payment_destination(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_lounge public.lounges%ROWTYPE;
  v_has_open_shift boolean;
  v_amount_due numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  SELECT b.* INTO v_booking FROM public.bookings b WHERE b.id = p_booking_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_booking.user_id IS DISTINCT FROM auth.uid()
     AND NOT public.is_super_admin()
     AND NOT public.has_lounge_permission(v_booking.lounge_id, 'billing_checkout') THEN
    RAISE EXCEPTION 'Not authorized to view payment details for this booking' USING ERRCODE = '42501';
  END IF;

  SELECT l.* INTO v_lounge FROM public.lounges l WHERE l.id = v_booking.lounge_id;

  SELECT EXISTS (
    SELECT 1 FROM public.shifts s
    WHERE s.lounge_id = v_booking.lounge_id
      AND s.status = 'open'
      AND s.closed_at IS NULL
  ) INTO v_has_open_shift;

  IF v_booking.confirmation_status = 'pending_confirmation' OR v_has_open_shift IS FALSE THEN
    RETURN jsonb_build_object(
      'can_pay', false,
      'booking_id', p_booking_id,
      'confirmation_status', v_booking.confirmation_status,
      'has_open_shift', v_has_open_shift,
      'reason', 'SHIFT_NOT_OPEN_OR_NOT_CONFIRMED',
      'message_ar', 'لا يمكن تحويل الأموال أو إرسال الإيصال قبل فتح الشيفت وتأكيد الصالة للحجز',
      'message_en', 'Payment destination is withheld until the lounge opens a shift and confirms your booking request.'
    );
  END IF;

  IF v_booking.deposit_required AND v_booking.deposit_paid THEN
    RETURN jsonb_build_object(
      'can_pay', false,
      'booking_id', p_booking_id,
      'lounge_id', v_lounge.id,
      'deposit_required', true,
      'deposit_paid', true,
      'reason', 'DEPOSIT_ALREADY_COLLECTED_USE_CANONICAL_SETTLEMENT',
      'message_ar', 'تم تسجيل العربون. المبلغ النهائي يتحدد بعد انتهاء اللعب وتسوية الطلبات.',
      'message_en', 'The deposit is recorded. The final amount is determined after play and order settlement.'
    );
  END IF;

  IF v_booking.deposit_required THEN
    v_amount_due := v_booking.deposit_amount;
  ELSE
    v_amount_due := GREATEST(0, v_booking.total_price);
  END IF;

  RETURN jsonb_build_object(
    'can_pay', true,
    'booking_id', p_booking_id,
    'lounge_id', v_lounge.id,
    'lounge_name', v_lounge.name,
    'confirmation_status', v_booking.confirmation_status,
    'has_open_shift', true,
    'amount_due', v_amount_due,
    'deposit_required', v_booking.deposit_required,
    'instapay_account', v_lounge.instapay_account,
    'instapay_handle', v_lounge.instapay_handle,
    'vodafone_cash_number', v_lounge.vodafone_cash_number,
    'wallet_number', v_lounge.wallet_number
  );
END;
$function$;
