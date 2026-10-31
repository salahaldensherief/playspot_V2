BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';
-- Holds must obey the same writer barrier as final online booking inserts.
-- Nonblocking lounge acquisition prevents room-first/lounge-first deadlocks.
CREATE OR REPLACE FUNCTION private.guard_cashier_online_hold()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_lounge uuid;
BEGIN
 IF NEW.released_at IS NOT NULL THEN RETURN NEW; END IF;
 SELECT lounge_id INTO v_lounge FROM public.rooms WHERE id=NEW.room_id;
 IF NOT FOUND OR NEW.lounge_id IS DISTINCT FROM v_lounge THEN
   RAISE EXCEPTION 'BOOKING_ROOM_SCOPE_MISMATCH' USING ERRCODE='42501';
 END IF;
 IF current_setting('transaction_isolation')<>'read committed' THEN
   RAISE EXCEPTION 'CASHIER_REQUIRES_READ_COMMITTED' USING ERRCODE='25001';
 END IF;
 IF NOT pg_catalog.pg_try_advisory_xact_lock(pg_catalog.hashtextextended('cashier-online:'||v_lounge::text,0)) THEN
   RAISE EXCEPTION 'CASHIER_WRITER_BUSY_RETRY' USING ERRCODE='55P03';
 END IF;
 PERFORM 1 FROM private.cashier_writer_authorities WHERE lounge_id=v_lounge FOR SHARE NOWAIT;
 IF EXISTS(SELECT 1 FROM private.cashier_writer_authorities WHERE lounge_id=v_lounge)
   AND public.get_lounge_online_availability(v_lounge) IS NOT TRUE THEN
   RAISE EXCEPTION 'LOUNGE_OFFLINE' USING ERRCODE='55000';
 END IF;
 RETURN NEW;
END; $$;
REVOKE ALL ON FUNCTION private.guard_cashier_online_hold() FROM PUBLIC,anon,authenticated,service_role,supabase_auth_admin;
CREATE TRIGGER guard_cashier_online_hold BEFORE INSERT OR UPDATE OF lounge_id,room_id,start_at,end_at,expires_at
 ON public.booking_holds FOR EACH ROW EXECUTE FUNCTION private.guard_cashier_online_hold();
COMMIT;
