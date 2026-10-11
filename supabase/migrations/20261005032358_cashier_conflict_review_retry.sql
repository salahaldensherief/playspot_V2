-- Manager-authorized retry preserves original request, conflict and financial invariants.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';
CREATE TABLE private.cashier_conflict_reviews (
 id uuid PRIMARY KEY, operation_id uuid NOT NULL REFERENCES private.cashier_operation_receipts(operation_id),
 lounge_id uuid NOT NULL,reviewer_id uuid NOT NULL,reason text NOT NULL CHECK(length(reason) BETWEEN 10 AND 1000),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE private.cashier_conflict_outcomes (
 review_id uuid PRIMARY KEY REFERENCES private.cashier_conflict_reviews(id),result jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX cashier_conflict_reviews_operation_idx ON private.cashier_conflict_reviews(operation_id);
ALTER TABLE private.cashier_conflict_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.cashier_conflict_outcomes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.cashier_conflict_reviews,private.cashier_conflict_outcomes FROM PUBLIC,anon,authenticated,service_role,supabase_auth_admin;
CREATE TRIGGER immutable_cashier_conflict_review BEFORE UPDATE OR DELETE ON private.cashier_conflict_reviews
 FOR EACH ROW EXECUTE FUNCTION private.guard_cashier_permit_immutability();
CREATE TRIGGER immutable_cashier_conflict_outcome BEFORE UPDATE OR DELETE ON private.cashier_conflict_outcomes
 FOR EACH ROW EXECUTE FUNCTION private.guard_cashier_permit_immutability();
CREATE TRIGGER immutable_cashier_operation_receipt BEFORE UPDATE OR DELETE ON private.cashier_operation_receipts
 FOR EACH ROW EXECUTE FUNCTION private.guard_cashier_permit_immutability();
CREATE OR REPLACE FUNCTION private.assert_cashier_conflict_reviewer(p_lounge_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='28000'; END IF;
 PERFORM 1 FROM public.profiles p JOIN auth.users u ON u.id=p.id WHERE p.id=auth.uid()
  AND p.is_active IS TRUE AND p.is_banned IS FALSE FOR SHARE OF p,u;
 IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_NOT_ELIGIBLE' USING ERRCODE='42501'; END IF;
 IF public.is_super_admin() IS NOT TRUE AND
  (private.permission_role(auth.uid(),p_lounge_id) NOT IN ('owner','manager')
   OR private.permission_role(auth.uid(),p_lounge_id) IS NULL
   OR public.has_lounge_permission(p_lounge_id,'sessions_control') IS NOT TRUE
   OR public.has_lounge_permission(p_lounge_id,'billing_checkout') IS NOT TRUE) THEN
  RAISE EXCEPTION 'CASHIER_CONFLICT_REVIEW_DENIED' USING ERRCODE='42501';
 END IF;
 PERFORM 1 FROM public.lounges WHERE id=p_lounge_id AND is_active IS TRUE AND status='active' FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'LOUNGE_NOT_APPROVED' USING ERRCODE='42501'; END IF;
END; $$;
REVOKE ALL ON FUNCTION private.assert_cashier_conflict_reviewer(uuid) FROM PUBLIC,anon,authenticated,service_role,supabase_auth_admin;
CREATE OR REPLACE FUNCTION public.get_cashier_sync_conflicts(p_lounge_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM private.assert_cashier_conflict_reviewer(p_lounge_id);
 RETURN coalesce((SELECT jsonb_agg(jsonb_build_object('operation_id',r.operation_id,'sequence',r.sequence,
  'kind',r.request->>'kind','booking_id',r.request->>'booking_id','actor_id',r.actor_id,
  'code',coalesce(latest.result->>'code',r.result->>'code'),'request',r.request,
  'retry_pending',EXISTS(SELECT 1 FROM private.cashier_conflict_reviews a WHERE a.operation_id=r.operation_id
   AND NOT EXISTS(SELECT 1 FROM private.cashier_conflict_outcomes o WHERE o.review_id=a.id))) ORDER BY r.sequence)
 FROM private.cashier_operation_receipts r LEFT JOIN LATERAL
  (SELECT o.result FROM private.cashier_conflict_outcomes o JOIN private.cashier_conflict_reviews a ON a.id=o.review_id
   WHERE a.operation_id=r.operation_id ORDER BY o.created_at DESC LIMIT 1) latest ON true
 WHERE r.lounge_id=p_lounge_id AND r.result->>'status'='conflict'
  AND NOT EXISTS(SELECT 1 FROM private.cashier_conflict_reviews a JOIN private.cashier_conflict_outcomes o ON o.review_id=a.id
   WHERE a.operation_id=r.operation_id AND o.result->>'status'='applied')),'[]'::jsonb);
END; $$;
CREATE OR REPLACE FUNCTION public.approve_cashier_conflict_retry(p_lounge_id uuid,p_operation_id uuid,p_review_id uuid,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r private.cashier_operation_receipts%ROWTYPE;a private.cashier_conflict_reviews%ROWTYPE;
BEGIN
 PERFORM private.lock_cashier_lounge(p_lounge_id);
 PERFORM private.assert_cashier_conflict_reviewer(p_lounge_id);
 IF p_review_id IS NULL OR p_operation_id IS NULL OR p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 10 AND 1000 THEN
  RAISE EXCEPTION 'INVALID_CONFLICT_REVIEW' USING ERRCODE='22023'; END IF;
 SELECT * INTO a FROM private.cashier_conflict_reviews WHERE id=p_review_id;
 IF FOUND THEN
  IF (a.lounge_id,a.operation_id,a.reviewer_id,a.reason) IS DISTINCT FROM
   (p_lounge_id,p_operation_id,auth.uid(),btrim(p_reason)) THEN
   RAISE EXCEPTION 'CONFLICT_REVIEW_REPLAY_MISMATCH' USING ERRCODE='22023'; END IF;
  RETURN jsonb_build_object('review_id',a.id,'operation_id',a.operation_id,'lounge_id',a.lounge_id,'status','approved');
 END IF;
 SELECT * INTO r FROM private.cashier_operation_receipts WHERE operation_id=p_operation_id AND lounge_id=p_lounge_id;
 IF NOT FOUND OR r.result->>'status'<>'conflict' THEN RAISE EXCEPTION 'CONFLICT_NOT_FOUND' USING ERRCODE='P0002'; END IF;
 IF NOT EXISTS(SELECT 1 FROM private.cashier_writer_authorities w WHERE w.lounge_id=p_lounge_id
  AND w.last_applied_sequence+1=r.sequence AND w.released_at IS NULL) THEN
  RAISE EXCEPTION 'CONFLICT_SEQUENCE_NOT_CURRENT' USING ERRCODE='55000'; END IF;
 IF EXISTS(SELECT 1 FROM private.cashier_conflict_reviews x WHERE x.operation_id=p_operation_id
  AND NOT EXISTS(SELECT 1 FROM private.cashier_conflict_outcomes o WHERE o.review_id=x.id)) THEN
  RAISE EXCEPTION 'CONFLICT_RETRY_ALREADY_APPROVED' USING ERRCODE='55000'; END IF;
 INSERT INTO private.cashier_conflict_reviews(id,operation_id,lounge_id,reviewer_id,reason)
  VALUES(p_review_id,p_operation_id,p_lounge_id,auth.uid(),btrim(p_reason));
 RETURN jsonb_build_object('review_id',p_review_id,'operation_id',p_operation_id,'lounge_id',p_lounge_id,'status','approved');
END; $$;
REVOKE ALL ON FUNCTION public.get_cashier_sync_conflicts(uuid),public.approve_cashier_conflict_retry(uuid,uuid,uuid,text)
 FROM PUBLIC,anon,service_role,supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.get_cashier_sync_conflicts(uuid),public.approve_cashier_conflict_retry(uuid,uuid,uuid,text) TO authenticated;
CREATE OR REPLACE FUNCTION public.apply_offline_cashier_operation(p_operation jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  v_writer private.cashier_writer_authorities%ROWTYPE;
  v_receipt private.cashier_operation_receipts%ROWTYPE;
  v_review uuid;v_retry boolean:=false;v_result jsonb;v_code text;v_sequence bigint;v_id uuid;v_lounge uuid;
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
    IF v_receipt.result->>'status'='applied' THEN
      RETURN v_receipt.result||jsonb_build_object('status','replayed');
    END IF;
    SELECT o.result INTO v_result FROM private.cashier_conflict_outcomes o
      JOIN private.cashier_conflict_reviews r ON r.id=o.review_id
      WHERE r.operation_id=v_id AND o.result->>'status'='applied';
    IF FOUND THEN RETURN v_result||jsonb_build_object('status','replayed'); END IF;
    SELECT r.id INTO v_review FROM private.cashier_conflict_reviews r
      WHERE r.operation_id=v_id AND NOT EXISTS
        (SELECT 1 FROM private.cashier_conflict_outcomes o WHERE o.review_id=r.id)
      ORDER BY r.created_at DESC LIMIT 1;
    IF NOT FOUND THEN RETURN v_receipt.result; END IF;
    v_retry:=true;
  END IF;
  IF v_sequence<>v_writer.last_applied_sequence+1 THEN
    RETURN jsonb_build_object('operation_id',v_id,'lounge_id',v_lounge,'sequence',v_sequence,
      'status','conflict','code','OFFLINE_SEQUENCE_GAP');
  END IF;
  IF NOT v_retry AND EXISTS (SELECT 1 FROM private.cashier_operation_receipts
    WHERE lounge_id=v_lounge AND sequence=v_sequence) THEN
    RETURN jsonb_build_object('operation_id',v_id,'lounge_id',v_lounge,'sequence',v_sequence,
      'status','conflict','code','OFFLINE_SEQUENCE_BLOCKED');
  END IF;
  BEGIN
    IF p_operation->>'kind'='collectCash' THEN
      v_result:=jsonb_build_object('financial_receipt',private.apply_cashier_cash_operation(p_operation));
    ELSIF p_operation->>'kind'='addItems' THEN
      v_result:=jsonb_build_object('order_receipt',private.apply_cashier_order_operation(p_operation));
    ELSE
      v_result:=jsonb_build_object('session_receipt',private.apply_cashier_fixed_operation(p_operation));
    END IF;
    v_result:=v_result||jsonb_build_object('operation_id',v_id,'lounge_id',v_lounge,'sequence',v_sequence,'status','applied');
  EXCEPTION WHEN SQLSTATE '22023' OR SQLSTATE '55000' OR SQLSTATE '42501' OR SQLSTATE 'P0002' THEN
    GET STACKED DIAGNOSTICS v_code=MESSAGE_TEXT;
    v_result:=jsonb_build_object('operation_id',v_id,'lounge_id',v_lounge,'sequence',v_sequence,
      'status','conflict','code',v_code);
  WHEN exclusion_violation THEN
    v_result:=jsonb_build_object('operation_id',v_id,'lounge_id',v_lounge,'sequence',v_sequence,
      'status','conflict','code','OFFLINE_ROOM_CONFLICT');
  WHEN unique_violation THEN
    v_result:=jsonb_build_object('operation_id',v_id,'lounge_id',v_lounge,'sequence',v_sequence,
      'status','conflict','code','OFFLINE_RECORD_ID_CONFLICT');
  END;
  IF v_retry THEN
    INSERT INTO private.cashier_conflict_outcomes(review_id,result) VALUES(v_review,v_result);
  ELSE
    INSERT INTO private.cashier_operation_receipts(operation_id,permit_id,sequence,actor_id,lounge_id,request,result)
      VALUES(v_id,(p_operation->>'permit_id')::uuid,v_sequence,auth.uid(),v_lounge,p_operation,v_result);
  END IF;
  IF v_result->>'status'='applied' THEN
    UPDATE private.cashier_writer_authorities SET last_applied_sequence=v_sequence WHERE lounge_id=v_lounge;
  END IF;
  RETURN v_result;
END; $$;
REVOKE ALL ON FUNCTION public.apply_offline_cashier_operation(jsonb) FROM PUBLIC,anon,service_role,supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.apply_offline_cashier_operation(jsonb) TO authenticated;
COMMIT;
