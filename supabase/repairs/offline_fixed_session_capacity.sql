BEGIN;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS cashier_closed_at timestamptz;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS cashier_booking_timezone text;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS cashier_capacity_period tsrange GENERATED ALWAYS AS (
  tsrange(date+start_time,
    CASE WHEN status='completed'::public.booking_status AND cashier_closed_at IS NOT NULL AND cashier_booking_timezone IS NOT NULL
      THEN greatest(date+start_time,least((date+end_time)+CASE WHEN end_time<=start_time THEN interval '1 day' ELSE interval '0' END,
        cashier_closed_at AT TIME ZONE cashier_booking_timezone))
      ELSE (date+end_time)+CASE WHEN end_time<=start_time THEN interval '1 day' ELSE interval '0' END END,'[)')
) STORED;
ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS bookings_room_booking_period_excl;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_room_booking_period_excl EXCLUDE USING gist
  (room_id WITH =,cashier_capacity_period WITH &&)
  WHERE(status NOT IN ('cancelled'::public.booking_status,'rejected'::public.booking_status)
    AND room_id IS NOT NULL AND cashier_capacity_period IS NOT NULL);

CREATE OR REPLACE FUNCTION private.guard_cashier_capacity_fields()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_kind text;
BEGIN
  IF TG_OP='INSERT' AND NEW.cashier_closed_at IS NULL AND NEW.cashier_booking_timezone IS NULL THEN RETURN NEW; END IF;
  IF TG_OP='UPDATE' AND (NEW.cashier_closed_at,NEW.cashier_booking_timezone)
    IS NOT DISTINCT FROM (OLD.cashier_closed_at,OLD.cashier_booking_timezone) THEN RETURN NEW; END IF;
  SELECT command.kind INTO v_kind FROM private.cashier_booking_command_context command
    JOIN private.cashier_sync_context context USING(transaction_id)
    JOIN private.cashier_writer_authorities writer ON writer.lounge_id=context.lounge_id
    WHERE command.transaction_id=txid_current() AND command.booking_id=NEW.id
      AND context.actor_id=auth.uid() AND context.actor_id=writer.actor_id
      AND context.permit_id=writer.permit_id AND context.lounge_id=NEW.lounge_id;
  IF NOT FOUND OR (v_kind<>'close' AND NEW.cashier_closed_at IS NOT NULL)
    OR (v_kind='close' AND (TG_OP<>'UPDATE' OR NEW.status<>'completed'::public.booking_status
      OR NEW.cashier_booking_timezone IS DISTINCT FROM OLD.cashier_booking_timezone)) THEN
    RAISE EXCEPTION 'CASHIER_CAPACITY_FIELDS_SERVER_ONLY' USING ERRCODE='42501';
  END IF;
  IF NEW.cashier_booking_timezone IS NULL OR NOT EXISTS(SELECT 1 FROM pg_catalog.pg_timezone_names
    WHERE name=NEW.cashier_booking_timezone) THEN RAISE EXCEPTION 'INVALID_LOUNGE_TIMEZONE' USING ERRCODE='22023'; END IF;
  RETURN NEW;
END; $$;
REVOKE ALL ON FUNCTION private.guard_cashier_capacity_fields() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS guard_cashier_capacity_fields ON public.bookings;
CREATE TRIGGER guard_cashier_capacity_fields BEFORE INSERT OR UPDATE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION private.guard_cashier_capacity_fields();
COMMIT;
