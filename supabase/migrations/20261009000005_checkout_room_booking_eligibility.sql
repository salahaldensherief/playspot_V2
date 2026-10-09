-- Match hold resource eligibility without replacing pricing/voucher logic or function grants.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
DO $migration$
DECLARE
  v_definition text;
  v_marker text := E'      AND r.is_active IS TRUE\n      AND COALESCE(r.status, ''available'') NOT IN (''maintenance'',''deleted'');';
  v_predicate text := E'      AND r.is_active IS TRUE\n      AND (r.is_available IS TRUE OR r.status = ''occupied'')\n      AND COALESCE(r.status, ''available'') NOT IN (''maintenance'',''deleted'');';
BEGIN
  v_definition := pg_get_functiondef('private.build_my_booking_checkout_quote(uuid,uuid,jsonb,jsonb,text)'::regprocedure);
  IF strpos(v_definition, E'\r\n') > 0 THEN
    v_marker := replace(v_marker, E'\n', E'\r\n');
    v_predicate := replace(v_predicate, E'\n', E'\r\n');
  END IF;
  IF strpos(v_definition, v_predicate) > 0 THEN RETURN; END IF;
  IF strpos(v_definition, v_marker) = 0 THEN
    RAISE EXCEPTION 'UNEXPECTED_CHECKOUT_ROOM_ELIGIBILITY_DEFINITION';
  END IF;
  EXECUTE replace(v_definition, v_marker, v_predicate);
END;
$migration$;
COMMIT;
