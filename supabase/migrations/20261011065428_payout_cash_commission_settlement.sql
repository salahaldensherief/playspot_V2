BEGIN;

-- Custody is evidence about who received the money, not a payment-method alias.
CREATE TABLE private.payment_funds_custody (
  sequence bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  payment_id uuid NOT NULL REFERENCES public.payments(id),
  payment_fingerprint jsonb NOT NULL,
  funds_holder text NOT NULL CHECK (funds_holder IN ('platform','lounge')),
  payment_method text NOT NULL,
  evidence_reference text NOT NULL CHECK (length(trim(evidence_reference)) BETWEEN 1 AND 500),
  recorded_by uuid NOT NULL,
  recorded_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX payment_funds_custody_latest ON private.payment_funds_custody(payment_id,sequence DESC);
CREATE TABLE private.payout_settlement_entries (
  payout_id uuid NOT NULL REFERENCES public.payouts(id),
  payment_id uuid NOT NULL REFERENCES public.payments(id),
  lounge_id uuid NOT NULL,
  funds_holder text NOT NULL CHECK (funds_holder IN ('platform','lounge')),
  payment_method text NOT NULL,
  amount numeric NOT NULL,
  commission numeric NOT NULL,
  net_to_lounge numeric NOT NULL,
  contribution numeric NOT NULL,
  PRIMARY KEY(payout_id,payment_id)
);
CREATE INDEX payout_settlement_entries_payment ON private.payout_settlement_entries(payment_id);
CREATE INDEX payment_funds_custody_actor ON private.payment_funds_custody(recorded_by);
CREATE INDEX payments_unsettled_cairo_date ON public.payments
  (lounge_id,((paid_at AT TIME ZONE 'Africa/Cairo')::date),id)
  WHERE status='completed' AND payout_id IS NULL;
ALTER TABLE private.payment_funds_custody ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.payout_settlement_entries ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.payment_funds_custody,private.payout_settlement_entries FROM PUBLIC,anon,authenticated,service_role,supabase_auth_admin;

CREATE OR REPLACE FUNCTION private.assert_payout_admin()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  PERFORM 1 FROM public.profiles p JOIN auth.users u ON u.id=p.id
    WHERE p.id=auth.uid() AND p.is_active IS TRUE AND p.is_banned IS FALSE
      AND (u.banned_until IS NULL OR u.banned_until<=now()) FOR SHARE OF p,u;
  IF NOT FOUND THEN RAISE EXCEPTION 'PAYOUT_ADMIN_REQUIRED' USING ERRCODE='42501'; END IF;
  IF auth.uid() IS NULL OR public.is_super_admin() IS NOT TRUE THEN
    RAISE EXCEPTION 'PAYOUT_ADMIN_REQUIRED' USING ERRCODE='42501';
  END IF;
END; $$;

CREATE OR REPLACE FUNCTION private.payment_custody_fingerprint(p_payment public.payments)
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $$
  SELECT jsonb_build_object('lounge_id',p_payment.lounge_id,'amount',p_payment.amount,'commission',p_payment.commission,
    'commission_rate',p_payment.commission_rate,'net_to_lounge',p_payment.net_to_lounge,
    'payment_method',p_payment.payment_method,'status',p_payment.status,
    'paid_at_epoch',extract(epoch FROM p_payment.paid_at));
$$;
REVOKE ALL ON FUNCTION private.payment_custody_fingerprint(public.payments) FROM PUBLIC,anon,authenticated,service_role,supabase_auth_admin;

CREATE OR REPLACE FUNCTION private.payment_has_valid_financials(p_payment public.payments)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path='' AS $$
  SELECT COALESCE(p_payment.amount>=0 AND p_payment.amount=round(p_payment.amount,2)
    AND p_payment.amount::text NOT IN ('NaN','Infinity','-Infinity')
    AND p_payment.commission>=0 AND p_payment.commission<=p_payment.amount
    AND p_payment.commission::text NOT IN ('NaN','Infinity','-Infinity')
    AND p_payment.commission_rate BETWEEN 0 AND 1
    AND p_payment.commission_rate::text NOT IN ('NaN','Infinity','-Infinity')
    AND p_payment.commission=round(p_payment.amount*p_payment.commission_rate,2)
    AND p_payment.net_to_lounge=p_payment.amount-p_payment.commission,false);
$$;
REVOKE ALL ON FUNCTION private.payment_has_valid_financials(public.payments)
  FROM PUBLIC,anon,authenticated,service_role,supabase_auth_admin;

CREATE VIEW private.payment_settlement_values AS
SELECT p.*,private.payment_has_valid_financials(p) AS financials_valid,CASE WHEN p.payment_method='cash' THEN 'lounge'
  WHEN c.payment_fingerprint=private.payment_custody_fingerprint(p) THEN c.funds_holder END AS funds_holder,
  (p.paid_at AT TIME ZONE 'Africa/Cairo')::date AS settlement_date
FROM public.payments p LEFT JOIN LATERAL (
  SELECT c.funds_holder,c.payment_fingerprint FROM private.payment_funds_custody c
  WHERE c.payment_id=p.id ORDER BY c.sequence DESC LIMIT 1
) c ON true;
REVOKE ALL ON private.payment_settlement_values FROM PUBLIC,anon,authenticated,service_role,supabase_auth_admin;

CREATE OR REPLACE FUNCTION public.record_payment_funds_custody(
  p_payment_id uuid,p_funds_holder text,p_evidence_reference text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_payment public.payments%ROWTYPE;v_record private.payment_funds_custody%ROWTYPE;
BEGIN
  PERFORM private.assert_payout_admin();
  IF p_funds_holder IS NULL OR p_funds_holder NOT IN ('platform','lounge')
    OR p_evidence_reference IS NULL OR length(trim(p_evidence_reference)) NOT BETWEEN 1 AND 500 THEN
    RAISE EXCEPTION 'INVALID_FUNDS_CUSTODY_EVIDENCE' USING ERRCODE='22023';
  END IF;
  SELECT * INTO v_payment FROM public.payments WHERE id=p_payment_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'PAYMENT_NOT_FOUND' USING ERRCODE='P0002'; END IF;
  IF private.payment_has_valid_financials(v_payment) IS NOT TRUE THEN
    RAISE EXCEPTION 'PAYMENT_FINANCIALS_REQUIRE_RECONCILIATION' USING ERRCODE='55000';
  END IF;
  IF v_payment.payment_method='cash' AND p_funds_holder<>'lounge' THEN
    RAISE EXCEPTION 'CASH_IS_RECEIVED_BY_LOUNGE' USING ERRCODE='22023';
  END IF;
  SELECT * INTO v_record FROM private.payment_funds_custody WHERE payment_id=p_payment_id ORDER BY sequence DESC LIMIT 1;
  IF FOUND AND v_record.payment_fingerprint=private.payment_custody_fingerprint(v_payment) THEN
    IF v_record.funds_holder IS DISTINCT FROM p_funds_holder
      OR v_record.payment_method IS DISTINCT FROM v_payment.payment_method
      OR v_record.evidence_reference IS DISTINCT FROM trim(p_evidence_reference) THEN
      RAISE EXCEPTION 'FUNDS_CUSTODY_REPLAY_CONFLICT' USING ERRCODE='55000';
    END IF;
    RETURN jsonb_build_object('success',true,'replayed',true);
  END IF;
  IF v_payment.payout_id IS NOT NULL OR v_payment.status IS DISTINCT FROM 'completed' THEN
    RAISE EXCEPTION 'PAYMENT_NOT_AVAILABLE_FOR_CUSTODY_REVIEW' USING ERRCODE='55000';
  END IF;
  INSERT INTO private.payment_funds_custody(payment_id,payment_fingerprint,funds_holder,payment_method,evidence_reference,recorded_by)
    VALUES(p_payment_id,private.payment_custody_fingerprint(v_payment),p_funds_holder,v_payment.payment_method,trim(p_evidence_reference),auth.uid());
  RETURN jsonb_build_object('success',true,'replayed',false);
END; $$;

CREATE OR REPLACE FUNCTION public.get_payment_funds_review(p_limit integer DEFAULT 50,p_offset integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_result jsonb;
BEGIN
  PERFORM private.assert_payout_admin();
  IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 OR p_offset IS NULL OR p_offset<0 THEN
    RAISE EXCEPTION 'INVALID_REVIEW_PAGE' USING ERRCODE='22023';
  END IF;
  SELECT COALESCE(jsonb_agg(to_jsonb(q)),'[]') INTO v_result FROM (
    SELECT p.id,p.booking_id,p.lounge_id,p.amount,p.commission,p.net_to_lounge,p.payment_method,p.paid_at,
      COALESCE(l.name_ar,l.name_en,l.name,p.lounge_id::text) AS lounge_name
    FROM private.payment_settlement_values p LEFT JOIN public.lounges l ON l.id=p.lounge_id
    WHERE p.funds_holder IS NULL AND p.status='completed' AND p.payout_id IS NULL
    ORDER BY p.paid_at,p.id LIMIT p_limit OFFSET p_offset
  ) q;
  RETURN v_result;
END; $$;

-- Changing only the settlement link must not bypass or obstruct cash collection.
CREATE OR REPLACE FUNCTION private.guard_partial_cash_payment()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF TG_OP='UPDATE' AND (to_jsonb(NEW)-'payout_id')=(to_jsonb(OLD)-'payout_id') THEN RETURN NEW; END IF;
  IF EXISTS (SELECT 1 FROM private.cash_collection_receipts WHERE booking_id=NEW.booking_id)
    AND NOT EXISTS (SELECT 1 FROM private.cash_collection_context
      WHERE transaction_id=txid_current() AND booking_id=NEW.booking_id) THEN
    RAISE EXCEPTION 'CASH_LEDGER_REQUIRES_CANONICAL_COLLECTION' USING ERRCODE='55000';
  END IF;
  RETURN NEW;
END; $$;

CREATE OR REPLACE FUNCTION private.assert_payout_settlement(p_payout_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_payout public.payouts%ROWTYPE;v_total numeric;v_count bigint;
BEGIN
  PERFORM private.assert_payout_admin();
  SELECT * INTO v_payout FROM public.payouts WHERE id=p_payout_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'PAYOUT_NOT_FOUND' USING ERRCODE='P0002'; END IF;
  PERFORM 1 FROM public.payments WHERE payout_id=p_payout_id ORDER BY id FOR UPDATE;
  SELECT count(*),sum(contribution) INTO v_count,v_total
    FROM private.payout_settlement_entries WHERE payout_id=p_payout_id;
  IF v_count=0 OR v_total<=0 OR v_total IS DISTINCT FROM v_payout.total_amount THEN
    RAISE EXCEPTION 'PAYOUT_REQUIRES_RECONCILIATION' USING ERRCODE='55000';
  END IF;
  IF EXISTS (
    SELECT 1 FROM private.payout_settlement_entries e
    LEFT JOIN private.payment_settlement_values p ON p.id=e.payment_id
    WHERE e.payout_id=p_payout_id AND (p.id IS NULL OR p.payout_id IS DISTINCT FROM p_payout_id
      OR p.status IS DISTINCT FROM 'completed' OR p.lounge_id IS DISTINCT FROM v_payout.lounge_id
      OR p.funds_holder IS DISTINCT FROM e.funds_holder OR p.payment_method IS DISTINCT FROM e.payment_method
      OR p.amount IS DISTINCT FROM e.amount OR p.commission IS DISTINCT FROM e.commission
      OR p.net_to_lounge IS DISTINCT FROM e.net_to_lounge)
  ) OR v_count<>(SELECT count(*) FROM public.payments WHERE payout_id=p_payout_id) THEN
    RAISE EXCEPTION 'PAYOUT_PAYMENT_EVIDENCE_CHANGED' USING ERRCODE='55000';
  END IF;
END; $$;

CREATE OR REPLACE FUNCTION public.get_pending_payouts_overview()
RETURNS TABLE(lounge_id uuid,lounge_name text,pending_amount numeric,total_transactions bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  PERFORM private.assert_payout_admin();
  RETURN QUERY SELECT p.lounge_id,COALESCE(l.name_ar,l.name_en,l.name)::text,
    sum(CASE WHEN p.funds_holder='platform' THEN p.net_to_lounge ELSE -p.commission END),count(*)
  FROM private.payment_settlement_values p JOIN public.lounges l ON l.id=p.lounge_id
  WHERE p.status='completed' AND p.payout_id IS NULL
    AND NOT EXISTS (SELECT 1 FROM private.cash_collection_receipts r JOIN public.bookings b ON b.id=r.booking_id
      WHERE r.booking_id=p.booking_id AND (b.status::text<>'completed' OR b.payment_status IS DISTINCT FROM 'paid'))
  GROUP BY p.lounge_id,COALESCE(l.name_ar,l.name_en,l.name)
  HAVING bool_and(p.financials_valid) AND count(*) FILTER(WHERE p.funds_holder IS NULL)=0
    AND sum(CASE WHEN p.funds_holder='platform' THEN p.net_to_lounge ELSE -p.commission END)>0;
END; $$;

CREATE OR REPLACE FUNCTION public.create_payout(p_lounge_id uuid,p_period_start date,p_period_end date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_payout uuid;v_total numeric;v_count bigint;v_ids uuid[];
BEGIN
  PERFORM private.assert_payout_admin();
  IF p_lounge_id IS NULL OR p_period_start IS NULL OR p_period_end IS NULL OR p_period_start>p_period_end THEN
    RAISE EXCEPTION 'INVALID_PAYOUT_PERIOD' USING ERRCODE='22023';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(p_lounge_id::text,0));
  IF EXISTS (SELECT 1 FROM public.payouts WHERE lounge_id=p_lounge_id
    AND status IN ('pending','approved','processing','paid','needs_review')
    AND daterange(period_start,period_end,'[]') && daterange(p_period_start,p_period_end,'[]')) THEN
    RAISE EXCEPTION 'OVERLAPPING_ACTIVE_PAYOUT' USING ERRCODE='55000';
  END IF;
  -- A canonical collector locks bookings before payments. Preserve that lock order.
  PERFORM 1 FROM public.bookings b WHERE EXISTS(SELECT 1 FROM public.payments p
    WHERE p.booking_id=b.id AND p.lounge_id=p_lounge_id AND p.payout_id IS NULL
      AND p.status='completed' AND (p.paid_at AT TIME ZONE 'Africa/Cairo')::date<=p_period_end)
    ORDER BY b.id FOR UPDATE;
  PERFORM 1 FROM public.payments WHERE lounge_id=p_lounge_id AND payout_id IS NULL
    AND status='completed' AND (paid_at AT TIME ZONE 'Africa/Cairo')::date<=p_period_end ORDER BY id FOR UPDATE;
  IF EXISTS(SELECT 1 FROM private.payment_settlement_values WHERE lounge_id=p_lounge_id
    AND status='completed' AND payout_id IS NULL AND settlement_date<=p_period_end AND financials_valid IS NOT TRUE) THEN
    RAISE EXCEPTION 'PAYMENT_FINANCIALS_REQUIRE_RECONCILIATION' USING ERRCODE='55000';
  END IF;
  IF EXISTS(SELECT 1 FROM private.payment_settlement_values WHERE lounge_id=p_lounge_id
    AND status='completed' AND payout_id IS NULL AND settlement_date<=p_period_end AND funds_holder IS NULL) THEN
    RAISE EXCEPTION 'PAYMENT_FUNDS_CUSTODY_REQUIRED' USING ERRCODE='55000';
  END IF;
  SELECT array_agg(p.id ORDER BY p.id),count(*),sum(CASE WHEN p.funds_holder='platform' THEN p.net_to_lounge ELSE -p.commission END)
    INTO v_ids,v_count,v_total FROM private.payment_settlement_values p
    WHERE p.lounge_id=p_lounge_id AND p.status='completed' AND p.payout_id IS NULL
      AND p.settlement_date<=p_period_end AND (p.funds_holder='lounge' OR p.settlement_date>=p_period_start)
      AND NOT EXISTS (SELECT 1 FROM private.cash_collection_receipts r JOIN public.bookings b ON b.id=r.booking_id
        WHERE r.booking_id=p.booking_id AND (b.status::text<>'completed' OR b.payment_status IS DISTINCT FROM 'paid'));
  IF v_count=0 OR v_total<=0 THEN
    RETURN jsonb_build_object('success',false,'error','NO_POSITIVE_SETTLEMENT_BALANCE');
  END IF;
  INSERT INTO public.payouts(lounge_id,period_start,period_end,total_amount,status,created_by)
    VALUES(p_lounge_id,p_period_start,p_period_end,v_total,'pending',auth.uid()) RETURNING id INTO v_payout;
  INSERT INTO private.payout_settlement_entries
    SELECT v_payout,id,lounge_id,funds_holder,payment_method,amount,commission,net_to_lounge,
      CASE WHEN funds_holder='platform' THEN net_to_lounge ELSE -commission END
    FROM private.payment_settlement_values WHERE id=ANY(v_ids);
  UPDATE public.payments SET payout_id=v_payout WHERE id=ANY(v_ids);
  PERFORM private.assert_payout_settlement(v_payout);
  RETURN jsonb_build_object('success',true,'payout_id',v_payout,'amount',v_total,'payment_count',v_count);
END; $$;

-- Table transitions are guarded too: direct updates cannot bypass the RPC check.
CREATE OR REPLACE FUNCTION private.guard_payout_settlement_transition()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF (OLD.paid_at IS NOT NULL OR EXISTS(SELECT 1 FROM private.payout_settlement_entries WHERE payout_id=OLD.id))
    AND (NEW.total_amount IS DISTINCT FROM OLD.total_amount OR NEW.lounge_id IS DISTINCT FROM OLD.lounge_id
      OR NEW.period_start IS DISTINCT FROM OLD.period_start OR NEW.period_end IS DISTINCT FROM OLD.period_end) THEN
    RAISE EXCEPTION 'PAYOUT_SETTLEMENT_SCOPE_CHANGED' USING ERRCODE='55000';
  END IF;
  IF NEW.status IN ('approved','processing','paid') AND NEW.status IS DISTINCT FROM OLD.status THEN
    PERFORM private.assert_payout_settlement(OLD.id);
    IF NEW.total_amount IS DISTINCT FROM OLD.total_amount OR NEW.lounge_id IS DISTINCT FROM OLD.lounge_id THEN
      RAISE EXCEPTION 'PAYOUT_SETTLEMENT_SCOPE_CHANGED' USING ERRCODE='55000';
    END IF;
    IF NEW.status='paid' AND (NULLIF(trim(NEW.transfer_reference),'') IS NULL
      OR NEW.transfer_method IS NULL OR NEW.transfer_method NOT IN ('bank_transfer','instapay','vodafone_cash','cash','other')) THEN
      RAISE EXCEPTION 'PAYOUT_TRANSFER_EVIDENCE_REQUIRED' USING ERRCODE='55000';
    END IF;
  END IF;
  RETURN NEW;
END; $$;
CREATE TRIGGER guard_payout_settlement_transition BEFORE UPDATE ON public.payouts
  FOR EACH ROW EXECUTE FUNCTION private.guard_payout_settlement_transition();

CREATE OR REPLACE FUNCTION public.approve_payout(p_payout_id uuid, p_notes text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_owner_id UUID;
  v_amount NUMERIC;
BEGIN
  PERFORM private.assert_payout_settlement(p_payout_id);

  UPDATE public.payouts
  SET status = 'approved', approved_by = auth.uid(), approved_at = NOW(), notes = COALESCE(p_notes, notes)
  WHERE id = p_payout_id AND status = 'pending'
  RETURNING created_by, total_amount INTO v_owner_id, v_amount;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payout not found or not pending';
  END IF;

  -- In-App Notification (Type strictly matching CHECK constraint 'payout')
  IF v_owner_id IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, title, title_ar, title_en, body, body_ar, body_en, type, metadata)
    VALUES (
      v_owner_id,
      'Payout Request Approved',
      'تم اعتماد طلب سحب الأرباح',
      'Payout Request Approved',
      'تمت الموافقة على طلب سحب الأرباح بقيمة ' || v_amount || ' ج.م',
      'تمت الموافقة على طلب سحب الأرباح بقيمة ' || v_amount || ' ج.م',
      'Your payout request for EGP ' || v_amount || ' has been approved.',
      'payout',
      jsonb_build_object('payout_id', p_payout_id, 'status', 'approved', 'amount', v_amount)
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'payout_id', p_payout_id, 'status', 'approved');
END;
$function$;


CREATE OR REPLACE FUNCTION public.start_payout_processing(p_payout_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM private.assert_payout_settlement(p_payout_id);
  UPDATE public.payouts
  SET status = 'processing', processing_started_by = auth.uid(), processing_started_at = now()
  WHERE id = p_payout_id AND status = 'approved';
  IF NOT FOUND THEN RAISE EXCEPTION 'Payout not found or not approved'; END IF;
  RETURN jsonb_build_object('success', true, 'payout_id', p_payout_id, 'status', 'processing');
END;
$function$;


CREATE OR REPLACE FUNCTION public.complete_payout(p_payout_id uuid, p_transfer_method text, p_transfer_reference text, p_receipt_url text DEFAULT NULL::text, p_notes text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM private.assert_payout_settlement(p_payout_id);
  IF p_transfer_method IS NULL OR p_transfer_method NOT IN ('bank_transfer','instapay','vodafone_cash','cash','other') THEN
    RAISE EXCEPTION 'Invalid transfer method';
  END IF;
  IF NULLIF(trim(p_transfer_reference), '') IS NULL THEN RAISE EXCEPTION 'Transfer reference is required'; END IF;

  UPDATE public.payouts
  SET status = 'paid',
      paid_at = now(),
      paid_by = auth.uid(),
      transfer_method = p_transfer_method,
      transfer_reference = p_transfer_reference,
      receipt_url = p_receipt_url,
      notes = COALESCE(p_notes, notes)
  WHERE id = p_payout_id AND status IN ('approved','processing');

  IF NOT FOUND THEN RAISE EXCEPTION 'Payout not found or not ready to be paid'; END IF;
  RETURN jsonb_build_object('success', true, 'payout_id', p_payout_id, 'status', 'paid');
END;
$function$;


CREATE OR REPLACE FUNCTION public.mark_payout_paid(p_payout_id uuid, p_notes text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM private.assert_payout_settlement(p_payout_id);
  UPDATE public.payouts
  SET status = 'paid', paid_at = now(), paid_by = auth.uid(), notes = COALESCE(p_notes, notes)
  WHERE id = p_payout_id AND status IN ('approved','processing');
  IF NOT FOUND THEN RAISE EXCEPTION 'Payout not found or not ready to be paid'; END IF;
END;
$function$;


CREATE OR REPLACE FUNCTION public.cancel_payout(p_payout_id uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM private.assert_payout_admin();

  UPDATE public.payouts
  SET status = 'cancelled', cancelled_by = auth.uid(), cancelled_at = now(), cancelled_reason = p_reason
  WHERE id = p_payout_id AND status IN ('pending','approved','failed','needs_review');

  IF NOT FOUND THEN RAISE EXCEPTION 'Payout not found or cannot be cancelled'; END IF;

  UPDATE public.payments
  SET payout_id = NULL
  WHERE payout_id = p_payout_id;

  RETURN jsonb_build_object('success', true, 'payout_id', p_payout_id, 'status', 'cancelled');
END;
$function$;


CREATE OR REPLACE FUNCTION public.resolve_payout_review(p_payout_id uuid, p_resolution text, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_lounge_id uuid;
  v_amount numeric;
  v_owner_id uuid;
  v_lounge_name text;
BEGIN
  PERFORM private.assert_payout_admin();
  IF p_resolution NOT IN ('approve','cancel') THEN RAISE EXCEPTION 'Invalid resolution'; END IF;
  IF NULLIF(trim(p_reason), '') IS NULL THEN RAISE EXCEPTION 'Review reason is required'; END IF;

  IF p_resolution = 'approve' THEN
    PERFORM private.assert_payout_settlement(p_payout_id);
    UPDATE public.payouts
    SET status = 'pending', notes = concat_ws(E'\n', notes, 'Review resolved: ' || p_reason)
    WHERE id = p_payout_id AND status = 'needs_review';
    IF NOT FOUND THEN RAISE EXCEPTION 'Payout not found or not awaiting review'; END IF;
  ELSE
    UPDATE public.payouts
    SET status = 'cancelled', cancelled_by = auth.uid(), cancelled_at = now(), cancelled_reason = p_reason
    WHERE id = p_payout_id AND status = 'needs_review'
    RETURNING lounge_id, total_amount INTO v_lounge_id, v_amount;
    IF NOT FOUND THEN RAISE EXCEPTION 'Payout not found or not awaiting review'; END IF;
    UPDATE public.payments SET payout_id=NULL WHERE payout_id=p_payout_id;

    IF v_lounge_id IS NOT NULL THEN
      SELECT owner_id, COALESCE(name_ar, name_en, name, 'الصالة') INTO v_owner_id, v_lounge_name
      FROM public.lounges WHERE id = v_lounge_id;

      IF v_owner_id IS NOT NULL THEN
        INSERT INTO public.notifications (
          user_id, lounge_id, title_ar, title_en, body_ar, body_en, type, is_read, metadata
        ) VALUES (
          v_owner_id, v_lounge_id,
          'تم رفض/إلغاء طلب سحب الأرباح ⚠️', 'Payout Request Cancelled ⚠️',
          'تم رفض طلب سحب أرباح صالة ' || v_lounge_name || ' بمبلغ ' || v_amount || ' ج.م. السبب: ' || p_reason,
          'Payout request of ' || v_amount || ' EGP for ' || v_lounge_name || ' was rejected. Reason: ' || p_reason,
          'payout', false,
          jsonb_build_object('payout_id', p_payout_id, 'reason', p_reason, 'amount', v_amount)
        );
      END IF;
    END IF;
  END IF;

  RETURN jsonb_build_object('success', true, 'payout_id', p_payout_id, 'status', CASE WHEN p_resolution = 'approve' THEN 'pending' ELSE 'cancelled' END);
END;
$function$;


CREATE OR REPLACE FUNCTION public.get_payout_details(p_payout_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  PERFORM private.assert_payout_admin();

  SELECT jsonb_build_object(
    'payout', to_jsonb(po),
    'lounge', jsonb_build_object('id', l.id, 'name', l.name, 'name_ar', l.name_ar, 'name_en', l.name_en),
    'payments', COALESCE((
      SELECT jsonb_agg(to_jsonb(p) ORDER BY p.paid_at, p.id)
      FROM private.payment_settlement_values p
      WHERE p.payout_id = po.id
    ), '[]'::jsonb),
    'reconciliation', jsonb_build_object(
      'has_settlement_snapshot', EXISTS(SELECT 1 FROM private.payout_settlement_entries e WHERE e.payout_id=po.id),
      'unknown_custody_count', (SELECT count(*) FROM private.payment_settlement_values p WHERE p.payout_id=po.id AND p.funds_holder IS NULL),
      'payment_count', (SELECT COUNT(*) FROM private.payment_settlement_values p WHERE p.payout_id = po.id),
      'completed_count', (SELECT COUNT(*) FROM private.payment_settlement_values p WHERE p.payout_id = po.id AND p.status = 'completed'),
      'refunded_count', (SELECT COUNT(*) FROM private.payment_settlement_values p WHERE p.payout_id = po.id AND p.status = 'refunded'),
      'calculated_net', COALESCE((SELECT SUM(CASE WHEN p.funds_holder='platform' THEN p.net_to_lounge WHEN p.funds_holder='lounge' THEN -p.commission ELSE NULL END) FROM private.payment_settlement_values p WHERE p.payout_id = po.id AND p.status = 'completed'), 0),
      'difference', po.total_amount - COALESCE((SELECT SUM(CASE WHEN p.funds_holder='platform' THEN p.net_to_lounge WHEN p.funds_holder='lounge' THEN -p.commission ELSE NULL END) FROM private.payment_settlement_values p WHERE p.payout_id = po.id AND p.status = 'completed'), 0)
    )
  ) INTO v_result
  FROM public.payouts po
  JOIN public.lounges l ON l.id = po.lounge_id
  WHERE po.id = p_payout_id;

  IF v_result IS NULL THEN RAISE EXCEPTION 'Payout not found'; END IF;
  RETURN v_result;
END;
$function$;


REVOKE ALL ON FUNCTION private.assert_payout_admin() FROM PUBLIC,anon,authenticated,service_role,supabase_auth_admin;
REVOKE ALL ON FUNCTION private.assert_payout_settlement(uuid) FROM PUBLIC,anon,authenticated,service_role,supabase_auth_admin;
REVOKE ALL ON FUNCTION private.guard_partial_cash_payment() FROM PUBLIC,anon,authenticated,service_role,supabase_auth_admin;
REVOKE ALL ON FUNCTION private.guard_payout_settlement_transition() FROM PUBLIC,anon,authenticated,service_role,supabase_auth_admin;
REVOKE ALL ON FUNCTION public.record_payment_funds_custody(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.record_payment_funds_custody(uuid,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.get_payment_funds_review(integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_payment_funds_review(integer,integer) TO authenticated;
REVOKE ALL ON FUNCTION public.create_payout(uuid,date,date) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.create_payout(uuid,date,date) TO authenticated;
REVOKE ALL ON FUNCTION public.get_pending_payouts_overview() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_pending_payouts_overview() TO authenticated;
REVOKE ALL ON FUNCTION public.get_payout_details(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_payout_details(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.approve_payout(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.approve_payout(uuid,text) TO authenticated;
REVOKE ALL ON FUNCTION public.start_payout_processing(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.start_payout_processing(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.complete_payout(uuid,text,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.complete_payout(uuid,text,text,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.mark_payout_paid(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.mark_payout_paid(uuid,text) TO authenticated;
REVOKE ALL ON FUNCTION public.cancel_payout(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.cancel_payout(uuid,text) TO authenticated;
REVOKE ALL ON FUNCTION public.resolve_payout_review(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.resolve_payout_review(uuid,text,text) TO authenticated;
CREATE OR REPLACE FUNCTION public.fail_payout(p_payout_id uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM private.assert_payout_admin();

  UPDATE public.payouts
  SET status = 'failed', failure_reason = p_reason
  WHERE id = p_payout_id AND status IN ('approved','processing');

  IF NOT FOUND THEN RAISE EXCEPTION 'Payout not found or not processing'; END IF;

  UPDATE public.payments
  SET payout_id = NULL
  WHERE payout_id = p_payout_id;

  RETURN jsonb_build_object('success', true, 'payout_id', p_payout_id, 'status', 'failed');
END;
$function$;


REVOKE ALL ON FUNCTION public.fail_payout(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.fail_payout(uuid,text) TO authenticated;
COMMIT;
