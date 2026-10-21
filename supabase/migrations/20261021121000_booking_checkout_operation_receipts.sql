-- Add an opt-in checkout entry point. The seven-argument RPC stays available
-- for already deployed clients; this wrapper and its receipt commit atomically.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE TABLE IF NOT EXISTS private.booking_checkout_receipts (
  operation_id uuid PRIMARY KEY,
  actor_id uuid NOT NULL,
  hold_token uuid NOT NULL,
  request_payload jsonb NOT NULL,
  request_fingerprint text NOT NULL,
  lounge_id uuid REFERENCES public.lounges(id),
  result jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (request_fingerprint = md5(request_payload::text)),
  CHECK ((result IS NULL) = (lounge_id IS NULL))
);
CREATE INDEX IF NOT EXISTS booking_checkout_receipts_actor_idx
  ON private.booking_checkout_receipts(actor_id, created_at DESC);
ALTER TABLE private.booking_checkout_receipts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.booking_checkout_receipts FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.create_my_booking_checkout_v2(
  p_operation_id uuid,
  p_hold_token uuid,
  p_room_requests jsonb,
  p_extra_items jsonb DEFAULT '[]'::jsonb,
  p_voucher_code text DEFAULT NULL,
  p_payment_method text DEFAULT 'cash',
  p_sender_wallet_phone text DEFAULT NULL,
  p_receipt_url text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_payload jsonb;
  v_receipt private.booking_checkout_receipts%ROWTYPE;
  v_result jsonb;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE = '28000';
  END IF;
  IF p_operation_id IS NULL OR p_hold_token IS NULL THEN
    RAISE EXCEPTION 'CHECKOUT_OPERATION_ID_REQUIRED' USING ERRCODE = '22023';
  END IF;

  -- JSONB equality is the authoritative immutable comparison. The fingerprint
  -- is useful for diagnostics without exposing payment fields in logs.
  v_payload := jsonb_build_object(
    'hold_token', p_hold_token,
    'room_requests', p_room_requests,
    'extra_items', p_extra_items,
    'voucher_code', p_voucher_code,
    'payment_method', p_payment_method,
    'sender_wallet_phone', p_sender_wallet_phone,
    'receipt_url', p_receipt_url
  );
  INSERT INTO private.booking_checkout_receipts(
    operation_id, actor_id, hold_token, request_payload, request_fingerprint
  ) VALUES (p_operation_id, v_actor, p_hold_token, v_payload, md5(v_payload::text))
  ON CONFLICT (operation_id) DO NOTHING;

  SELECT * INTO STRICT v_receipt
  FROM private.booking_checkout_receipts
  WHERE operation_id = p_operation_id FOR UPDATE;
  IF v_receipt.actor_id IS DISTINCT FROM v_actor
     OR v_receipt.request_payload IS DISTINCT FROM v_payload THEN
    RAISE EXCEPTION 'CHECKOUT_OPERATION_REPLAY_CONFLICT' USING ERRCODE = '22023';
  END IF;
  IF v_receipt.result IS NOT NULL THEN
    RETURN v_receipt.result || jsonb_build_object('replayed', true);
  END IF;

  -- The original function owns price/version, hold, capacity, voucher and
  -- multi-room atomicity checks. No successful receipt exists unless all of
  -- those writes commit in this same transaction.
  v_result := public.create_my_booking_checkout(
    p_hold_token, p_room_requests, p_extra_items, p_voucher_code,
    p_payment_method, p_sender_wallet_phone, p_receipt_url
  );
  v_result := v_result || jsonb_build_object(
    'operation_id', p_operation_id, 'replayed', false
  );
  UPDATE private.booking_checkout_receipts
  SET lounge_id = (v_result->'quote'->>'lounge_id')::uuid,
      result = v_result
  WHERE operation_id = p_operation_id;
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.create_my_booking_checkout_v2(uuid,uuid,jsonb,jsonb,text,text,text,text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_my_booking_checkout_v2(uuid,uuid,jsonb,jsonb,text,text,text,text)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.recover_my_booking_checkout(p_operation_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_receipt private.booking_checkout_receipts%ROWTYPE;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE = '28000';
  END IF;
  IF p_operation_id IS NULL THEN
    RAISE EXCEPTION 'CHECKOUT_OPERATION_ID_REQUIRED' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO v_receipt FROM private.booking_checkout_receipts
  WHERE operation_id = p_operation_id;
  IF NOT FOUND THEN RETURN NULL; END IF;
  IF v_receipt.actor_id IS DISTINCT FROM v_actor THEN
    RAISE EXCEPTION 'CHECKOUT_RECEIPT_ACCESS_DENIED' USING ERRCODE = '42501';
  END IF;
  RETURN v_receipt.result || jsonb_build_object('replayed', true);
END;
$function$;
REVOKE ALL ON FUNCTION public.recover_my_booking_checkout(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recover_my_booking_checkout(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
