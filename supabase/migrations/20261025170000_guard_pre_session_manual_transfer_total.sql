-- The legacy approval RPC settles the entire expected price even when the
-- booking requires only a reservation deposit. Keep that unsafe transition
-- closed until a verified deposit and mixed-method ledger is deployed.
DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.approve_manual_booking(uuid,uuid)'::regprocedure))
       <> '7ddf3f2bd80fbb013ee008747d72c61b'
     OR md5(pg_get_functiondef('public.complete_booking_payment(uuid,text,numeric)'::regprocedure))
       <> 'b2cea5fe275757100336f2b57f3ce53b' THEN
    RAISE EXCEPTION 'MANUAL_TRANSFER_CONTRACT_DRIFT';
  END IF;
END;
$guard$;

CREATE FUNCTION private.guard_pre_session_manual_transfer_total()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE
  v_status public.booking_status;
  v_total numeric;
BEGIN
  IF NEW.status <> 'completed' OR NEW.payment_method <> 'manual_transfer'
     OR NEW.booking_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT status, total_price INTO v_status, v_total
  FROM public.bookings WHERE id = NEW.booking_id;
  IF FOUND AND v_status IN ('pending', 'upcoming', 'in_progress')
     AND v_total > 0 AND NEW.amount >= v_total THEN
    RAISE EXCEPTION 'PRE_SESSION_MANUAL_TRANSFER_REQUIRES_VERIFIED_DEPOSIT_CONTRACT'
      USING ERRCODE = '55000';
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.guard_pre_session_manual_transfer_total()
  FROM PUBLIC, anon, authenticated;
CREATE TRIGGER guard_pre_session_manual_transfer_total
BEFORE INSERT OR UPDATE OF amount, payment_method, status ON public.payments
FOR EACH ROW EXECUTE FUNCTION private.guard_pre_session_manual_transfer_total();
