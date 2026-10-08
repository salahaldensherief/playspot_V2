-- Reviewed rollback only: reinstates the earlier cross-tab mode-change behavior.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $migration$
DECLARE
 v_definition text := pg_get_functiondef('public.refresh_cashier_writer(uuid,uuid,boolean)'::regprocedure);
 v_guard text := $guard$
  IF NOT v_created AND v_writer.online_requested IS DISTINCT FROM p_online
    AND NOT EXISTS(SELECT 1 FROM private.cashier_bootstrap_claim_context
      WHERE transaction_id=txid_current() AND lounge_id=p_lounge_id
        AND actor_id=v_actor AND device_id=p_device_id) THEN
    RAISE EXCEPTION 'CASHIER_MODE_CHANGE_REQUIRES_BOOTSTRAP' USING ERRCODE='55000';
  END IF;
$guard$;
BEGIN
 IF position(v_guard IN v_definition)=0 THEN
  RAISE EXCEPTION 'UNEXPECTED_CASHIER_REFRESH_DEFINITION' USING ERRCODE='55000';
 END IF;
 EXECUTE replace(v_definition,v_guard,'');
END; $migration$;
COMMIT;
