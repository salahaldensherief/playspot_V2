BEGIN;
CREATE TABLE IF NOT EXISTS private.cashier_operation_receipts (
  operation_id uuid PRIMARY KEY,
  permit_id uuid NOT NULL,
  sequence bigint NOT NULL CHECK(sequence>0),
  actor_id uuid NOT NULL,
  lounge_id uuid NOT NULL,
  request jsonb NOT NULL,
  result jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(permit_id,sequence)
);
ALTER TABLE private.cashier_operation_receipts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.cashier_operation_receipts FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.validate_cashier_operation(p_operation jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_id uuid;v_sequence numeric;v_time timestamptz;v_name text;
BEGIN
  IF p_operation IS NULL OR jsonb_typeof(p_operation)<>'object' OR length(p_operation::text)>65536
    OR jsonb_typeof(p_operation->'payload') IS DISTINCT FROM 'object'
    OR jsonb_typeof(p_operation->'sequence') IS DISTINCT FROM 'number' THEN
    RAISE EXCEPTION 'INVALID_OFFLINE_OPERATION' USING ERRCODE='22023';
  END IF;
  FOREACH v_name IN ARRAY ARRAY['id','actor_id','lounge_id','device_id','permit_id','booking_id','shift_id'] LOOP
    v_id:=(p_operation->>v_name)::uuid;
    IF v_id IS NULL THEN RAISE EXCEPTION 'INVALID_OFFLINE_OPERATION' USING ERRCODE='22023'; END IF;
  END LOOP;
  v_sequence:=(p_operation->>'sequence')::numeric;
  IF v_sequence<=0 OR v_sequence<>trunc(v_sequence) OR v_sequence>9007199254740991
    OR (p_operation->>'occurred_at') IS NULL
    OR (p_operation->>'occurred_at')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}T.*(Z|[+-][0-9]{2}:[0-9]{2})$' THEN
    RAISE EXCEPTION 'INVALID_OFFLINE_OPERATION' USING ERRCODE='22023';
  END IF;
  v_time:=(p_operation->>'occurred_at')::timestamptz;
  IF NOT isfinite(v_time) THEN RAISE EXCEPTION 'INVALID_OFFLINE_OPERATION' USING ERRCODE='22023'; END IF;
  IF p_operation->>'kind' IS DISTINCT FROM 'collectCash' THEN
    RAISE EXCEPTION 'OFFLINE_OPERATION_KIND_NOT_IMPLEMENTED' USING ERRCODE='0A000';
  END IF;
END; $$;
REVOKE ALL ON FUNCTION private.validate_cashier_operation(jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.lock_cashier_operation_writer(p_operation jsonb)
RETURNS private.cashier_writer_authorities LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_writer private.cashier_writer_authorities%ROWTYPE;v_time timestamptz:=(p_operation->>'occurred_at')::timestamptz;
BEGIN
  IF auth.uid() IS DISTINCT FROM (p_operation->>'actor_id')::uuid THEN
    RAISE EXCEPTION 'OFFLINE_ACTOR_MISMATCH' USING ERRCODE='42501';
  END IF;
  PERFORM private.assert_cash_collector(auth.uid(),(p_operation->>'lounge_id')::uuid);
  SELECT * INTO v_writer FROM private.cashier_writer_authorities
    WHERE lounge_id=(p_operation->>'lounge_id')::uuid FOR UPDATE;
  IF NOT FOUND OR v_writer.actor_id IS DISTINCT FROM auth.uid()
    OR v_writer.device_id IS DISTINCT FROM (p_operation->>'device_id')::uuid
    OR v_writer.permit_id IS DISTINCT FROM (p_operation->>'permit_id')::uuid THEN
    RAISE EXCEPTION 'OFFLINE_WRITER_MISMATCH' USING ERRCODE='42501';
  END IF;
  IF v_time<v_writer.issued_at OR v_time>=v_writer.permit_expires_at
    OR v_time>statement_timestamp()+interval '5 minutes' THEN
    RAISE EXCEPTION 'OFFLINE_OPERATION_OUTSIDE_PERMIT' USING ERRCODE='22023';
  END IF;
  RETURN v_writer;
END; $$;
REVOKE ALL ON FUNCTION private.lock_cashier_operation_writer(jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.apply_cashier_cash_operation(p_operation jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_lounge uuid;
BEGIN
  SELECT lounge_id INTO v_lounge FROM public.bookings WHERE id=(p_operation->>'booking_id')::uuid;
  IF NOT FOUND OR v_lounge IS DISTINCT FROM (p_operation->>'lounge_id')::uuid THEN
    RAISE EXCEPTION 'OFFLINE_BOOKING_SCOPE_MISMATCH' USING ERRCODE='42501';
  END IF;
  RETURN public.collect_booking_cash_partial((p_operation->>'booking_id')::uuid,
    (p_operation->>'shift_id')::uuid,(p_operation->'payload'->>'amount_minor')::numeric,
    (p_operation->>'id')::uuid);
END; $$;
REVOKE ALL ON FUNCTION private.apply_cashier_cash_operation(jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.apply_offline_cashier_operation(p_operation jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  v_writer private.cashier_writer_authorities%ROWTYPE;
  v_receipt private.cashier_operation_receipts%ROWTYPE;
  v_result jsonb;v_code text;v_sequence bigint;v_id uuid;v_lounge uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='28000'; END IF;
  PERFORM private.validate_cashier_operation(p_operation);
  v_writer:=private.lock_cashier_operation_writer(p_operation);
  v_sequence:=(p_operation->>'sequence')::bigint;v_id:=(p_operation->>'id')::uuid;v_lounge:=v_writer.lounge_id;
  SELECT * INTO v_receipt FROM private.cashier_operation_receipts WHERE operation_id=v_id;
  IF FOUND THEN
    IF v_receipt.request IS DISTINCT FROM p_operation THEN
      RAISE EXCEPTION 'OFFLINE_OPERATION_REPLAY_CONFLICT' USING ERRCODE='22023';
    END IF;
    RETURN CASE WHEN v_receipt.result->>'status'='applied' THEN
      v_receipt.result||jsonb_build_object('status','replayed') ELSE v_receipt.result END;
  END IF;
  IF v_sequence<>v_writer.last_applied_sequence+1 THEN
    RETURN jsonb_build_object('operation_id',v_id,'lounge_id',v_lounge,'sequence',v_sequence,
      'status','conflict','code','OFFLINE_SEQUENCE_GAP');
  END IF;
  IF EXISTS (SELECT 1 FROM private.cashier_operation_receipts
    WHERE permit_id=v_writer.permit_id AND sequence=v_sequence) THEN
    RETURN jsonb_build_object('operation_id',v_id,'lounge_id',v_lounge,'sequence',v_sequence,
      'status','conflict','code','OFFLINE_SEQUENCE_BLOCKED');
  END IF;
  BEGIN
    v_result:=jsonb_build_object('operation_id',v_id,'lounge_id',v_lounge,'sequence',v_sequence,
      'status','applied','financial_receipt',private.apply_cashier_cash_operation(p_operation));
  EXCEPTION WHEN SQLSTATE '22023' OR SQLSTATE '55000' OR SQLSTATE '42501' OR SQLSTATE 'P0002' THEN
    GET STACKED DIAGNOSTICS v_code=MESSAGE_TEXT;
    v_result:=jsonb_build_object('operation_id',v_id,'lounge_id',v_lounge,'sequence',v_sequence,
      'status','conflict','code',v_code);
  END;
  INSERT INTO private.cashier_operation_receipts(operation_id,permit_id,sequence,actor_id,lounge_id,request,result)
    VALUES(v_id,v_writer.permit_id,v_sequence,auth.uid(),v_lounge,p_operation,v_result);
  IF v_result->>'status'='applied' THEN
    UPDATE private.cashier_writer_authorities SET last_applied_sequence=v_sequence WHERE lounge_id=v_lounge;
  END IF;
  RETURN v_result;
END; $$;
REVOKE ALL ON FUNCTION public.apply_offline_cashier_operation(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.apply_offline_cashier_operation(jsonb) TO authenticated;
COMMIT;
