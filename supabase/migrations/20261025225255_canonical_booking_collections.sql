-- Draft foundation for verified, method-specific booking money movements.
-- Existing payments remain the historical aggregate/projection. No writer is
-- switched by this migration: collection and payout RPCs must be migrated in
-- one coordinated release before this table can become authoritative.
CREATE TABLE private.booking_money_movements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  operation_id uuid NOT NULL UNIQUE,
  booking_id uuid NOT NULL REFERENCES public.bookings(id),
  payment_id uuid NOT NULL REFERENCES public.payments(id),
  lounge_id uuid NOT NULL REFERENCES public.lounges(id),
  shift_id uuid NOT NULL REFERENCES public.shifts(id),
  shift_payment_id uuid UNIQUE REFERENCES public.shift_payments(id),
  movement_type text NOT NULL CHECK (movement_type IN ('collection', 'refund')),
  collection_purpose text NOT NULL CHECK (collection_purpose IN ('deposit', 'settlement', 'partial', 'refund')),
  payment_method text NOT NULL CHECK (payment_method IN
    ('cash', 'manual_transfer', 'card', 'vodafone_cash', 'fawry', 'instapay', 'app_wallet')),
  amount_minor bigint NOT NULL,
  commission_minor bigint NOT NULL,
  net_to_lounge_minor bigint GENERATED ALWAYS AS (amount_minor - commission_minor) STORED,
  funds_holder text NOT NULL CHECK (funds_holder IN ('platform', 'lounge')),
  evidence_reference text,
  reversal_of uuid REFERENCES private.booking_money_movements(id),
  verified_by uuid NOT NULL REFERENCES auth.users(id),
  verified_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT booking_money_movement_shape CHECK (
    (movement_type = 'collection' AND amount_minor > 0
      AND commission_minor >= 0 AND commission_minor <= amount_minor
      AND reversal_of IS NULL AND shift_payment_id IS NOT NULL
      AND collection_purpose <> 'refund')
    OR
    (movement_type = 'refund' AND amount_minor < 0
      AND commission_minor <= 0 AND commission_minor >= amount_minor
      AND reversal_of IS NOT NULL AND shift_payment_id IS NULL
      AND collection_purpose = 'refund')
  ),
  CONSTRAINT booking_money_movement_cash_custody CHECK (
    payment_method <> 'cash' OR funds_holder = 'lounge'
  ),
  CONSTRAINT booking_money_movement_evidence CHECK (
    (movement_type = 'collection' AND payment_method = 'cash')
    OR (evidence_reference IS NOT NULL
      AND length(trim(evidence_reference)) BETWEEN 1 AND 500)
  )
);

CREATE INDEX booking_money_movements_booking_time
  ON private.booking_money_movements (booking_id, verified_at, id);
CREATE INDEX booking_money_movements_lounge_time
  ON private.booking_money_movements (lounge_id, verified_at, id);
CREATE INDEX booking_money_movements_shift
  ON private.booking_money_movements (shift_id, verified_at, id);
CREATE INDEX booking_money_movements_payment
  ON private.booking_money_movements (payment_id, id);
CREATE INDEX booking_money_movements_reversal
  ON private.booking_money_movements (reversal_of) WHERE reversal_of IS NOT NULL;

ALTER TABLE private.booking_money_movements ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.booking_money_movements
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;

-- Payout allocation is separate so money movements stay immutable. An entry
-- can be retried after a failed/cancelled payout while retaining its history.
CREATE TABLE private.booking_movement_payout_entries (
  payout_id uuid NOT NULL REFERENCES public.payouts(id),
  movement_id uuid NOT NULL REFERENCES private.booking_money_movements(id),
  contribution_minor bigint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (payout_id, movement_id)
);
CREATE INDEX booking_movement_payout_entries_payout
  ON private.booking_movement_payout_entries (payout_id);
CREATE INDEX booking_movement_payout_entries_movement
  ON private.booking_movement_payout_entries (movement_id);
ALTER TABLE private.booking_movement_payout_entries ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.booking_movement_payout_entries
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;

CREATE FUNCTION private.reject_booking_money_movement_mutation()
RETURNS trigger LANGUAGE plpgsql SET search_path TO '' AS $function$
BEGIN
  RAISE EXCEPTION 'BOOKING_MONEY_MOVEMENTS_ARE_APPEND_ONLY' USING ERRCODE = '55000';
END;
$function$;
REVOKE ALL ON FUNCTION private.reject_booking_money_movement_mutation()
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;
CREATE TRIGGER booking_money_movements_append_only
BEFORE UPDATE OR DELETE ON private.booking_money_movements
FOR EACH ROW EXECUTE FUNCTION private.reject_booking_money_movement_mutation();

CREATE FUNCTION private.validate_booking_money_movement()
RETURNS trigger LANGUAGE plpgsql SET search_path TO '' AS $function$
DECLARE
  v_payment public.payments%ROWTYPE;
  v_shift_payment public.shift_payments%ROWTYPE;
  v_original private.booking_money_movements%ROWTYPE;
  v_refunded_minor bigint;
  v_refunded_commission_minor bigint;
BEGIN
  SELECT * INTO v_payment FROM public.payments WHERE id = NEW.payment_id;
  IF NOT FOUND OR v_payment.booking_id IS DISTINCT FROM NEW.booking_id
    OR v_payment.lounge_id IS DISTINCT FROM NEW.lounge_id THEN
    RAISE EXCEPTION 'MOVEMENT_PAYMENT_SCOPE_MISMATCH' USING ERRCODE = '23514';
  END IF;
  PERFORM 1 FROM public.bookings b WHERE b.id = NEW.booking_id
    AND b.lounge_id = NEW.lounge_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'MOVEMENT_BOOKING_SCOPE_MISMATCH' USING ERRCODE = '23514';
  END IF;
  PERFORM 1 FROM public.shifts s WHERE s.id = NEW.shift_id
    AND s.lounge_id = NEW.lounge_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'MOVEMENT_SHIFT_SCOPE_MISMATCH' USING ERRCODE = '23514';
  END IF;

  IF NEW.movement_type = 'collection' THEN
    SELECT * INTO v_shift_payment FROM public.shift_payments
    WHERE id = NEW.shift_payment_id;
    IF NOT FOUND OR v_shift_payment.booking_id IS DISTINCT FROM NEW.booking_id
      OR v_shift_payment.lounge_id IS DISTINCT FROM NEW.lounge_id
      OR v_shift_payment.shift_id IS DISTINCT FROM NEW.shift_id
      OR v_shift_payment.payment_method IS DISTINCT FROM NEW.payment_method
      OR v_shift_payment.amount * 100 IS DISTINCT FROM NEW.amount_minor THEN
      RAISE EXCEPTION 'MOVEMENT_SHIFT_EVIDENCE_MISMATCH' USING ERRCODE = '23514';
    END IF;
  ELSE
    -- Lock the original movement to serialize competing refund confirmations.
    SELECT * INTO v_original FROM private.booking_money_movements
    WHERE id = NEW.reversal_of FOR UPDATE;
    IF NOT FOUND OR v_original.movement_type <> 'collection'
      OR v_original.booking_id IS DISTINCT FROM NEW.booking_id
      OR v_original.payment_id IS DISTINCT FROM NEW.payment_id
      OR v_original.lounge_id IS DISTINCT FROM NEW.lounge_id THEN
      RAISE EXCEPTION 'REFUND_COLLECTION_SCOPE_MISMATCH' USING ERRCODE = '23514';
    END IF;
    SELECT COALESCE(-sum(amount_minor), 0), COALESCE(-sum(commission_minor), 0)
      INTO v_refunded_minor, v_refunded_commission_minor
    FROM private.booking_money_movements
    WHERE reversal_of = NEW.reversal_of;
    IF v_refunded_minor - NEW.amount_minor > v_original.amount_minor
      OR v_refunded_commission_minor - NEW.commission_minor > v_original.commission_minor THEN
      RAISE EXCEPTION 'REFUND_EXCEEDS_VERIFIED_COLLECTION' USING ERRCODE = '22023';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION private.validate_booking_money_movement()
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;
CREATE TRIGGER booking_money_movement_validate
BEFORE INSERT ON private.booking_money_movements
FOR EACH ROW EXECUTE FUNCTION private.validate_booking_money_movement();

CREATE FUNCTION private.validate_booking_movement_payout_entry()
RETURNS trigger LANGUAGE plpgsql SET search_path TO '' AS $function$
DECLARE
  v_movement private.booking_money_movements%ROWTYPE;
  v_lounge_id uuid;
  v_payout_status text;
  v_expected bigint;
BEGIN
  SELECT * INTO v_movement FROM private.booking_money_movements
    WHERE id = NEW.movement_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'PAYOUT_MOVEMENT_NOT_FOUND' USING ERRCODE = 'P0002';
  END IF;
  IF EXISTS (
    SELECT 1 FROM private.booking_movement_payout_entries e
    JOIN public.payouts p ON p.id = e.payout_id
    WHERE e.movement_id = NEW.movement_id
      AND p.status IN ('pending', 'approved', 'processing', 'paid', 'needs_review')
  ) THEN
    RAISE EXCEPTION 'MOVEMENT_ALREADY_IN_ACTIVE_PAYOUT' USING ERRCODE = '55000';
  END IF;
  SELECT lounge_id, status INTO v_lounge_id, v_payout_status FROM public.payouts
    WHERE id = NEW.payout_id;
  IF NOT FOUND OR v_lounge_id IS DISTINCT FROM v_movement.lounge_id
    OR v_payout_status IS DISTINCT FROM 'pending' THEN
    RAISE EXCEPTION 'PAYOUT_MOVEMENT_LOUNGE_MISMATCH' USING ERRCODE = '23514';
  END IF;
  v_expected := CASE WHEN v_movement.funds_holder = 'platform'
    THEN v_movement.net_to_lounge_minor ELSE -v_movement.commission_minor END;
  IF NEW.contribution_minor IS DISTINCT FROM v_expected THEN
    RAISE EXCEPTION 'PAYOUT_MOVEMENT_CONTRIBUTION_MISMATCH' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION private.validate_booking_movement_payout_entry()
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;
CREATE TRIGGER booking_movement_payout_entry_validate
BEFORE INSERT ON private.booking_movement_payout_entries
FOR EACH ROW EXECUTE FUNCTION private.validate_booking_movement_payout_entry();
CREATE TRIGGER booking_movement_payout_entries_append_only
BEFORE UPDATE OR DELETE ON private.booking_movement_payout_entries
FOR EACH ROW EXECUTE FUNCTION private.reject_booking_money_movement_mutation();

-- A private reconciliation surface for the migration cohort. The legacy
-- aggregate method is intentionally absent: reports must use the movements.
CREATE VIEW private.booking_money_coverage
WITH (security_invoker = true) AS
SELECT p.id AS payment_id, p.booking_id, p.lounge_id,
  (p.amount * 100)::bigint AS aggregate_gross_minor,
  COALESCE(sum(m.amount_minor) FILTER (WHERE m.movement_type = 'collection'), 0)::bigint
    AS movement_gross_minor,
  COALESCE(sum(m.amount_minor) FILTER (WHERE m.movement_type = 'refund'), 0)::bigint
    AS refunded_minor,
  count(m.id) FILTER (WHERE m.movement_type = 'collection')::integer
    AS collection_count,
  CASE
    WHEN count(m.id) = 0 THEN 'legacy_unclassified'
    WHEN COALESCE(sum(m.amount_minor) FILTER (WHERE m.movement_type = 'collection'), 0)
      IS DISTINCT FROM p.amount * 100 THEN 'requires_reconciliation'
    ELSE 'covered'
  END AS coverage_state
FROM public.payments p
LEFT JOIN private.booking_money_movements m ON m.payment_id = p.id
GROUP BY p.id, p.booking_id, p.lounge_id, p.amount;
REVOKE ALL ON private.booking_money_coverage
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;

-- Staff attests that the transfer has actually arrived. The submitted receipt
-- remains only evidence until this authorized transaction commits.
CREATE FUNCTION public.verify_booking_deposit_transfer(
  p_booking_id uuid, p_shift_id uuid, p_operation_id uuid,
  p_evidence_reference text, p_funds_holder text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_booking public.bookings%ROWTYPE;
  v_existing private.booking_money_movements%ROWTYPE;
  v_payment public.payments%ROWTYPE;
  v_shift_payment uuid;
  v_amount numeric;
  v_amount_minor bigint;
  v_rate numeric;
  v_commission numeric;
  v_commission_minor bigint;
  v_method text;
  v_result jsonb;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE = '28000';
  END IF;
  IF p_booking_id IS NULL OR p_shift_id IS NULL OR p_operation_id IS NULL
    OR p_funds_holder NOT IN ('platform','lounge')
    OR p_funds_holder IS NULL OR p_evidence_reference IS NULL
    OR length(trim(p_evidence_reference)) NOT BETWEEN 1 AND 500 THEN
    RAISE EXCEPTION 'INVALID_DEPOSIT_VERIFICATION_REQUEST' USING ERRCODE = '22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_booking_id::text,0));
  SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'BOOKING_NOT_FOUND' USING ERRCODE = 'P0002';
  END IF;
  PERFORM private.assert_cash_collector(v_actor,v_booking.lounge_id);
  SELECT * INTO v_existing FROM private.booking_money_movements
    WHERE operation_id=p_operation_id;
  IF FOUND THEN
    IF v_existing.booking_id IS DISTINCT FROM p_booking_id
      OR v_existing.shift_id IS DISTINCT FROM p_shift_id
      OR v_existing.verified_by IS DISTINCT FROM v_actor
      OR v_existing.collection_purpose IS DISTINCT FROM 'deposit'
      OR v_existing.evidence_reference IS DISTINCT FROM trim(p_evidence_reference)
      OR v_existing.funds_holder IS DISTINCT FROM p_funds_holder THEN
      RAISE EXCEPTION 'DEPOSIT_VERIFICATION_REPLAY_CONFLICT' USING ERRCODE = '22023';
    END IF;
    RETURN jsonb_build_object('operation_id',p_operation_id,
      'movement_id',v_existing.id,'booking_id',p_booking_id,
      'shift_id',p_shift_id,'payment_method',v_existing.payment_method,
      'collected_minor',v_existing.amount_minor,
      'commission_minor',v_existing.commission_minor,'replayed',true);
  END IF;
  PERFORM private.lock_cash_collection_shift(p_shift_id,v_booking.lounge_id);
  v_method := v_booking.payment_method;
  IF v_booking.confirmation_status IS DISTINCT FROM 'confirmed'
    OR v_booking.status::text NOT IN ('pending','upcoming')
    OR v_booking.deposit_required IS NOT TRUE
    OR v_booking.deposit_paid IS TRUE
    OR v_method IS NULL
    OR v_method NOT IN ('manual_transfer','instapay','vodafone_cash','app_wallet')
    OR NULLIF(trim(COALESCE(v_booking.receipt_url,'')),'') IS NULL THEN
    RAISE EXCEPTION 'BOOKING_NOT_READY_FOR_VERIFIED_DEPOSIT' USING ERRCODE = '55000';
  END IF;
  v_amount := v_booking.deposit_amount;
  IF v_booking.total_price IS NULL
    OR v_booking.total_price::text IN ('NaN','Infinity','-Infinity')
    OR v_amount IS NULL OR v_amount::text IN ('NaN','Infinity','-Infinity')
    OR v_amount <= 0 OR v_amount >= v_booking.total_price
    OR v_amount <> round(v_amount,2) THEN
    RAISE EXCEPTION 'INVALID_SERVER_DEPOSIT_AMOUNT' USING ERRCODE = '22023';
  END IF;
  v_amount_minor := (v_amount*100)::bigint;
  IF EXISTS (SELECT 1 FROM public.shift_payments
      WHERE booking_id=p_booking_id)
    OR EXISTS (SELECT 1 FROM private.booking_money_movements
      WHERE booking_id=p_booking_id) THEN
    RAISE EXCEPTION 'DEPOSIT_REQUIRES_RECONCILIATION' USING ERRCODE = '55000';
  END IF;
  SELECT * INTO v_payment FROM public.payments
    WHERE booking_id=p_booking_id FOR UPDATE;
  IF FOUND AND (v_payment.status='completed'
    OR v_payment.payout_id IS NOT NULL
    OR v_payment.lounge_id IS DISTINCT FROM v_booking.lounge_id) THEN
    RAISE EXCEPTION 'DEPOSIT_REQUIRES_RECONCILIATION' USING ERRCODE = '55000';
  END IF;
  v_rate := private.platform_commission_rate();
  IF v_rate IS NULL OR v_rate NOT BETWEEN 0 AND 1
    OR v_rate::text IN ('NaN','Infinity','-Infinity') THEN
    RAISE EXCEPTION 'INVALID_COMMISSION_POLICY' USING ERRCODE = '55000';
  END IF;
  v_commission := round(v_amount*v_rate,2);
  v_commission_minor := (v_commission*100)::bigint;
  INSERT INTO public.payments(booking_id,user_id,lounge_id,amount,
    commission_rate,commission,net_to_lounge,payment_method,status,paid_at)
  VALUES(p_booking_id,v_booking.user_id,v_booking.lounge_id,v_amount,
    v_rate,v_commission,v_amount-v_commission,v_method,'completed',now())
  ON CONFLICT(booking_id) DO UPDATE SET
    amount=EXCLUDED.amount,commission_rate=EXCLUDED.commission_rate,
    commission=EXCLUDED.commission,net_to_lounge=EXCLUDED.net_to_lounge,
    payment_method=EXCLUDED.payment_method,status=EXCLUDED.status,
    paid_at=EXCLUDED.paid_at
  RETURNING * INTO v_payment;
  INSERT INTO public.shift_payments(shift_id,lounge_id,booking_id,
    payment_method,category,amount,paid_at)
  VALUES(p_shift_id,v_booking.lounge_id,p_booking_id,v_method,
    'gaming_time',v_amount,now()) RETURNING id INTO v_shift_payment;
  INSERT INTO private.booking_money_movements(operation_id,booking_id,
    payment_id,lounge_id,shift_id,shift_payment_id,movement_type,
    collection_purpose,payment_method,amount_minor,commission_minor,
    funds_holder,evidence_reference,verified_by)
  VALUES(p_operation_id,p_booking_id,v_payment.id,v_booking.lounge_id,
    p_shift_id,v_shift_payment,'collection','deposit',v_method,
    v_amount_minor,v_commission_minor,p_funds_holder,
    trim(p_evidence_reference),v_actor)
  RETURNING * INTO v_existing;
  UPDATE public.bookings SET deposit_paid=true,payment_status='partial',
    updated_at=now() WHERE id=p_booking_id;
  v_result := jsonb_build_object('operation_id',p_operation_id,
    'movement_id',v_existing.id,'booking_id',p_booking_id,
    'shift_id',p_shift_id,'payment_method',v_method,
    'collected_minor',v_amount_minor,
    'commission_minor',v_commission_minor,'replayed',false);
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.verify_booking_deposit_transfer(uuid,uuid,uuid,text,text)
  FROM PUBLIC, anon, service_role, supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.verify_booking_deposit_transfer(uuid,uuid,uuid,text,text)
  TO authenticated;

-- The aggregate payment method becomes an explicit compatibility marker once
-- more than one method has actually been collected for a booking. Payout and
-- reporting must use booking_money_movements for these rows.
ALTER TABLE public.payments DROP CONSTRAINT payments_payment_method_check;
ALTER TABLE public.payments ADD CONSTRAINT payments_payment_method_check
  CHECK (payment_method IN ('cash','manual_transfer','card','vodafone_cash',
    'fawry','instapay','app_wallet','mixed'));
ALTER TABLE public.bookings DROP CONSTRAINT bookings_payment_method_check;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_payment_method_check
  CHECK (payment_method IN ('cash','manual_transfer','card','vodafone_cash',
    'fawry','instapay','app_wallet','mixed'));

CREATE OR REPLACE FUNCTION private.cash_collection_paid_amount(
  p_booking_id uuid,p_lounge_id uuid,p_payment_status text)
RETURNS numeric LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
DECLARE
  v_payment public.payments%ROWTYPE;
  v_cash numeric;
  v_shift_gross numeric;
  v_movement_gross bigint;
  v_movement_count bigint;
BEGIN
  SELECT * INTO v_payment FROM public.payments
    WHERE booking_id=p_booking_id FOR UPDATE;
  SELECT count(*),COALESCE(sum(amount_minor),0)
    INTO v_movement_count,v_movement_gross
  FROM private.booking_money_movements
  WHERE booking_id=p_booking_id AND movement_type='collection';
  IF v_movement_count>0 THEN
    SELECT COALESCE(sum(amount),0) INTO v_shift_gross
    FROM public.shift_payments
    WHERE booking_id=p_booking_id AND lounge_id=p_lounge_id
      AND category='gaming_time';
    IF v_payment.id IS NULL OR v_payment.status IS DISTINCT FROM 'completed'
      OR v_payment.lounge_id IS DISTINCT FROM p_lounge_id
      OR v_payment.payout_id IS NOT NULL
      OR v_payment.amount IS NULL OR v_payment.amount<0
      OR v_payment.amount::text IN ('NaN','Infinity','-Infinity')
      OR v_payment.amount<>round(v_payment.amount,2)
      OR v_payment.amount*100 IS DISTINCT FROM v_movement_gross
      OR v_shift_gross*100 IS DISTINCT FROM v_movement_gross
      OR EXISTS (SELECT 1 FROM private.booking_money_movements
        WHERE booking_id=p_booking_id AND movement_type='refund') THEN
      RAISE EXCEPTION 'PAYMENT_REQUIRES_RECONCILIATION' USING ERRCODE='55000';
    END IF;
    RETURN v_payment.amount;
  END IF;
  SELECT COALESCE(sum(amount),0) INTO v_cash FROM public.shift_payments
    WHERE booking_id=p_booking_id AND lounge_id=p_lounge_id
      AND payment_method='cash';
  IF v_payment.id IS NOT NULL THEN
    IF v_payment.payment_method IS DISTINCT FROM 'cash'
      OR v_payment.status IS DISTINCT FROM 'completed'
      OR v_payment.lounge_id IS DISTINCT FROM p_lounge_id
      OR v_payment.payout_id IS NOT NULL OR v_payment.amount IS NULL
      OR v_payment.amount<0 OR v_payment.amount::text IN ('NaN','Infinity','-Infinity')
      OR v_payment.amount<>round(v_payment.amount,2)
      OR v_payment.amount IS DISTINCT FROM v_cash THEN
      RAISE EXCEPTION 'PAYMENT_REQUIRES_RECONCILIATION' USING ERRCODE='55000';
    END IF;
    RETURN v_payment.amount;
  ELSIF p_payment_status IS DISTINCT FROM 'unpaid' OR v_cash<>0 THEN
    RAISE EXCEPTION 'PAYMENT_REQUIRES_RECONCILIATION' USING ERRCODE='55000';
  END IF;
  RETURN 0;
END;
$function$;

CREATE OR REPLACE FUNCTION private.apply_partial_cash_collection_with_movement(
  p_booking_id uuid,p_shift_id uuid,p_amount_minor numeric,p_operation_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
DECLARE
  v_lounge_id uuid;
  v_allow_cash boolean;
  v_old_payment public.payments%ROWTYPE;
  v_payment public.payments%ROWTYPE;
  v_has_movements boolean;
  v_has_electronic boolean;
  v_shift_payment_id uuid;
  v_movement_id uuid;
  v_rate numeric;
  v_new_commission_minor bigint;
  v_prior_commission_minor bigint;
  v_booking public.bookings%ROWTYPE;
  v_paid numeric;
  v_amount numeric;
BEGIN
  SELECT lounge_id INTO v_lounge_id FROM public.bookings WHERE id=p_booking_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'BOOKING_NOT_FOUND' USING ERRCODE='P0002';
  END IF;
  SELECT allow_cash_payment INTO v_allow_cash FROM public.lounges
    WHERE id=v_lounge_id;
  IF v_allow_cash IS NOT TRUE THEN
    RAISE EXCEPTION 'CASH_COLLECTION_DISABLED' USING ERRCODE='42501';
  END IF;
  SELECT EXISTS(SELECT 1 FROM private.booking_money_movements
    WHERE booking_id=p_booking_id AND movement_type='collection'),
    EXISTS(SELECT 1 FROM private.booking_money_movements
    WHERE booking_id=p_booking_id AND movement_type='collection'
      AND payment_method<>'cash')
    INTO v_has_movements,v_has_electronic;
  SELECT * INTO v_old_payment FROM public.payments
    WHERE booking_id=p_booking_id FOR UPDATE;
  -- Historical cash rows without movement evidence remain on their existing
  -- writer. Do not backfill a partial history by pretending it is complete.
  IF v_old_payment.id IS NOT NULL AND v_has_movements IS FALSE THEN
    RETURN private.apply_partial_cash_collection(p_booking_id,p_shift_id,p_amount_minor);
  END IF;
  v_rate:=private.platform_commission_rate();
  IF v_rate IS NULL OR v_rate NOT BETWEEN 0 AND 1
    OR v_rate::text IN ('NaN','Infinity','-Infinity')
    OR (v_has_movements AND v_old_payment.commission_rate IS DISTINCT FROM v_rate) THEN
    RAISE EXCEPTION 'MIXED_COMMISSION_POLICY_REQUIRES_RECONCILIATION'
      USING ERRCODE='55000';
  END IF;
  v_new_commission_minor:=
    (round((p_amount_minor/100)*v_rate,2)*100)::bigint;
  SELECT COALESCE(sum(commission_minor),0) INTO v_prior_commission_minor
  FROM private.booking_money_movements
  WHERE booking_id=p_booking_id AND movement_type='collection';
  v_booking:=private.lock_cash_collection_booking(p_booking_id);
  PERFORM private.lock_cash_collection_shift(p_shift_id,v_booking.lounge_id);
  v_paid:=private.cash_collection_paid_amount(
    p_booking_id,v_booking.lounge_id,v_booking.payment_status);
  v_amount:=p_amount_minor/100;
  IF v_amount>v_booking.total_price-v_paid THEN
    RAISE EXCEPTION 'CASH_EXCEEDS_OUTSTANDING_BALANCE' USING ERRCODE='22023';
  END IF;
  INSERT INTO private.cash_collection_context(transaction_id,booking_id)
    VALUES(txid_current(),p_booking_id) ON CONFLICT DO NOTHING;
  INSERT INTO public.payments(booking_id,user_id,lounge_id,amount,
    commission_rate,commission,net_to_lounge,payment_method,status,paid_at)
  VALUES(p_booking_id,v_booking.user_id,v_booking.lounge_id,v_paid+v_amount,
    v_rate,round((v_paid+v_amount)*v_rate,2),
    v_paid+v_amount-round((v_paid+v_amount)*v_rate,2),
    CASE WHEN v_has_electronic THEN 'mixed' ELSE 'cash' END,
    'completed',now())
  ON CONFLICT(booking_id) DO UPDATE SET amount=EXCLUDED.amount,
    commission_rate=EXCLUDED.commission_rate,
    commission=EXCLUDED.commission,net_to_lounge=EXCLUDED.net_to_lounge,
    payment_method=EXCLUDED.payment_method,paid_at=EXCLUDED.paid_at;
  INSERT INTO public.shift_payments(shift_id,lounge_id,booking_id,
    payment_method,category,amount,paid_at)
  VALUES(p_shift_id,v_booking.lounge_id,p_booking_id,'cash',
    'gaming_time',v_amount,now()) RETURNING id INTO v_shift_payment_id;
  UPDATE public.bookings SET
    payment_status=CASE WHEN v_paid+v_amount=total_price THEN 'paid'
      ELSE 'partial' END,
    payment_method=CASE WHEN v_has_electronic THEN 'mixed' ELSE 'cash' END,
    updated_at=now() WHERE id=p_booking_id;
  DELETE FROM private.cash_collection_context
    WHERE transaction_id=txid_current() AND booking_id=p_booking_id;
  SELECT * INTO STRICT v_payment FROM public.payments
    WHERE booking_id=p_booking_id;
  IF v_payment.commission*100 IS DISTINCT FROM
      v_prior_commission_minor+v_new_commission_minor THEN
    RAISE EXCEPTION 'MIXED_COMMISSION_ALLOCATION_CONFLICT' USING ERRCODE='55000';
  END IF;
  INSERT INTO private.booking_money_movements(operation_id,booking_id,
    payment_id,lounge_id,shift_id,shift_payment_id,movement_type,
    collection_purpose,payment_method,amount_minor,commission_minor,
    funds_holder,verified_by)
  VALUES(p_operation_id,p_booking_id,v_payment.id,v_lounge_id,p_shift_id,
    v_shift_payment_id,'collection','settlement','cash',p_amount_minor::bigint,
    v_new_commission_minor,'lounge',auth.uid())
  RETURNING id INTO v_movement_id;
  RETURN jsonb_build_object('booking_id',p_booking_id,'lounge_id',
    v_booking.lounge_id,'shift_id',p_shift_id,
    'shift_payment_id',v_shift_payment_id,'collected_minor',p_amount_minor,
    'paid_minor',(v_paid+v_amount)*100,
    'due_minor',(v_booking.total_price-v_paid-v_amount)*100,
    'payment_status',CASE WHEN v_paid+v_amount=v_booking.total_price
      THEN 'paid' ELSE 'partial' END,'movement_id',v_movement_id);
END;
$function$;
REVOKE ALL ON FUNCTION private.apply_partial_cash_collection_with_movement(
  uuid,uuid,numeric,uuid) FROM PUBLIC,anon,authenticated,service_role,supabase_auth_admin;

CREATE OR REPLACE FUNCTION public.collect_booking_cash_partial(
  p_booking_id uuid,p_shift_id uuid,p_amount_minor numeric,p_operation_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
DECLARE v_receipt private.cash_collection_receipts%ROWTYPE;v_result jsonb;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='28000'; END IF;
  IF p_operation_id IS NULL OR p_booking_id IS NULL OR p_shift_id IS NULL OR p_amount_minor IS NULL
    OR p_amount_minor::text IN ('NaN','Infinity','-Infinity') OR p_amount_minor<=0
    OR p_amount_minor<>trunc(p_amount_minor) OR p_amount_minor>9007199254740991 THEN
    RAISE EXCEPTION 'INVALID_CASH_COLLECTION_REQUEST' USING ERRCODE='22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_booking_id::text,0));
  INSERT INTO private.cash_collection_receipts(operation_id,actor_id,booking_id,shift_id,amount_minor)
    VALUES(p_operation_id,auth.uid(),p_booking_id,p_shift_id,p_amount_minor) ON CONFLICT DO NOTHING;
  SELECT * INTO STRICT v_receipt FROM private.cash_collection_receipts
    WHERE operation_id=p_operation_id FOR UPDATE;
  IF v_receipt.actor_id IS DISTINCT FROM auth.uid() OR v_receipt.booking_id IS DISTINCT FROM p_booking_id
    OR v_receipt.shift_id IS DISTINCT FROM p_shift_id OR v_receipt.amount_minor IS DISTINCT FROM p_amount_minor THEN
    RAISE EXCEPTION 'CASH_COLLECTION_REPLAY_CONFLICT' USING ERRCODE='22023';
  END IF;
  IF v_receipt.result IS NOT NULL THEN
    PERFORM private.assert_cash_collector(auth.uid(),(v_receipt.result->>'lounge_id')::uuid);
    RETURN v_receipt.result||jsonb_build_object('replayed',true);
  END IF;
  v_result:=private.apply_partial_cash_collection_with_movement(
    p_booking_id,p_shift_id,p_amount_minor,p_operation_id)
    ||jsonb_build_object('operation_id',p_operation_id,'replayed',false);
  UPDATE private.cash_collection_receipts SET result=v_result
    WHERE operation_id=p_operation_id;
  RETURN v_result;
END;
$function$;
