-- Close an unreviewed extension request when its booking becomes terminal.
-- Preserve already-approved/rejected history and leave active requests alone.
-- Existing historical rows are deliberately NOT modified by this migration.
BEGIN;

CREATE OR REPLACE FUNCTION private.normalize_terminal_booking_extension()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $function$
BEGIN
  IF NEW.status IN (
    'completed'::public.booking_status,
    'cancelled'::public.booking_status,
    'expired'::public.booking_status,
    'rejected'::public.booking_status
  ) AND NEW.extension_status = 'pending' THEN
    NEW.extension_status := 'none';
    NEW.requested_extension_minutes := NULL;
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.normalize_terminal_booking_extension()
FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;

-- The trigger normalizes both session-end status updates and stale
-- extension writes on already-terminal bookings.
CREATE TRIGGER normalize_terminal_booking_extension
BEFORE INSERT OR UPDATE OF status, extension_status, requested_extension_minutes
ON public.bookings
FOR EACH ROW EXECUTE FUNCTION private.normalize_terminal_booking_extension();

COMMIT;
