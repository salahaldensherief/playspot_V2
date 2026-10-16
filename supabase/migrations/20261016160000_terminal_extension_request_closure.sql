-- Clear pending extension requests atomically when their booking turns terminal.
-- Does NOT rewrite historical rows, prices, ledger entries, or paid status.
BEGIN;

CREATE OR REPLACE FUNCTION private.expire_pending_extension_for_terminal_booking()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $fn$
BEGIN
  IF NEW.status IN (
    'completed'::public.booking_status,
    'cancelled'::public.booking_status,
    'rejected'::public.booking_status,
    'expired'::public.booking_status
  ) AND COALESCE(NEW.extension_status, 'none') = 'pending' THEN
    NEW.extension_status := 'expired';
    NEW.requested_extension_minutes := NULL;
  END IF;
  RETURN NEW;
END;
$fn$;

REVOKE ALL ON FUNCTION private.expire_pending_extension_for_terminal_booking()
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;

DROP TRIGGER IF EXISTS zz_expire_terminal_booking_extension ON public.bookings;

CREATE TRIGGER zz_expire_terminal_booking_extension
BEFORE INSERT OR UPDATE OF status, extension_status, requested_extension_minutes
ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION private.expire_pending_extension_for_terminal_booking();

COMMIT;
