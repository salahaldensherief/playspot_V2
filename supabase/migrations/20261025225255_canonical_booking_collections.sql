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
