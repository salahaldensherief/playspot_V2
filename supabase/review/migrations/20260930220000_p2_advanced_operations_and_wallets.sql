-- ============================================================================
-- Migration: 20260930220000_p2_advanced_operations_and_wallets.sql
-- Description: Phase 7 (P2) - Advanced Operations, Group Events, Wallets & Safety Layer:
--   1. Digital Wallet & Balance Ledger (user_wallets, wallet_transactions, topup, pay, refund)
--   2. Group Booking & Invite Friends (booking_group_invites, invite_friends, respond)
--   3. Corporate, Birthday & Event Booking Packages (event_packages, event_booking_requests)
--   4. Smart Offers & Coupon Budget Engine (promotions upgrades, promotion_usages, budget cap)
--   5. Financial Loss Prevention & Risk Audit Layer (financial_risk_audit_logs)
--   6. Tournament Payment Submission Hardening & Obsolete Overload Removal
--   7. PlaySpot Pass Inter-Lounge Roaming Agreement Framework
-- Source of Truth: salahaldensherief/playspot_V2
-- ============================================================================

-- ============================================================================
-- 1. Digital Wallet & Balance Ledger Tables
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.user_wallets (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  balance numeric(10,2) NOT NULL DEFAULT 0.00 CHECK (balance >= 0),
  currency text NOT NULL DEFAULT 'EGP',
  is_frozen boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.wallet_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  booking_id uuid REFERENCES public.bookings(id) ON DELETE SET NULL,
  shift_id uuid REFERENCES public.shifts(id) ON DELETE SET NULL,
  amount numeric(10,2) NOT NULL, -- Positive for credit, negative for debit
  balance_after numeric(10,2) NOT NULL CHECK (balance_after >= 0),
  transaction_type text NOT NULL CHECK (transaction_type IN ('topup', 'booking_payment', 'refund', 'admin_adjustment', 'cashback', 'referral_bonus')),
  idempotency_key text UNIQUE,
  notes text,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user ON public.wallet_transactions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_booking ON public.wallet_transactions(booking_id);

ALTER TABLE public.user_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_wallets_policy ON public.user_wallets;
CREATE POLICY user_wallets_policy ON public.user_wallets
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_super_admin());

DROP POLICY IF EXISTS wallet_transactions_policy ON public.wallet_transactions;
CREATE POLICY wallet_transactions_policy ON public.wallet_transactions
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_super_admin());

-- RPC: Get or create user wallet idempotently
CREATE OR REPLACE FUNCTION public.get_or_create_user_wallet(p_user_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_target_user uuid := COALESCE(p_user_id, auth.uid());
  v_wallet public.user_wallets%ROWTYPE;
BEGIN
  IF v_target_user IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  INSERT INTO public.user_wallets (user_id, balance, currency)
  VALUES (v_target_user, 0.00, 'EGP')
  ON CONFLICT (user_id) DO UPDATE SET updated_at = now()
  RETURNING * INTO v_wallet;

  RETURN jsonb_build_object(
    'user_id', v_wallet.user_id,
    'balance', v_wallet.balance,
    'currency', v_wallet.currency,
    'is_frozen', v_wallet.is_frozen
  );
END;
$$;

-- RPC: Top-up User Wallet
CREATE OR REPLACE FUNCTION public.topup_user_wallet(
  p_amount numeric,
  p_payment_method text DEFAULT 'cash',
  p_lounge_id uuid DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_wallet public.user_wallets%ROWTYPE;
  v_new_balance numeric;
  v_shift_id uuid;
  v_txn_id uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Topup amount must be greater than zero' USING ERRCODE = '22023';
  END IF;

  -- Idempotency check
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id, balance_after INTO v_txn_id, v_new_balance
    FROM public.wallet_transactions
    WHERE idempotency_key = p_idempotency_key;

    IF FOUND THEN
      RETURN jsonb_build_object(
        'success', true,
        'idempotent', true,
        'transaction_id', v_txn_id,
        'balance', v_new_balance
      );
    END IF;
  END IF;

  -- Ensure wallet exists & lock row
  INSERT INTO public.user_wallets (user_id, balance, currency)
  VALUES (v_caller, 0.00, 'EGP')
  ON CONFLICT (user_id) DO NOTHING;

  SELECT * INTO v_wallet
  FROM public.user_wallets
  WHERE user_id = v_caller
  FOR UPDATE;

  IF v_wallet.is_frozen THEN
    RAISE EXCEPTION 'Wallet is frozen. Contact customer support.' USING ERRCODE = '55000';
  END IF;

  v_new_balance := ROUND(v_wallet.balance + p_amount, 2);

  UPDATE public.user_wallets
  SET balance = v_new_balance,
      updated_at = now()
  WHERE user_id = v_caller;

  -- Associate with active shift if topped up at lounge
  IF p_lounge_id IS NOT NULL THEN
    SELECT s.id INTO v_shift_id
    FROM public.shifts s
    WHERE s.lounge_id = p_lounge_id
      AND s.status = 'open'
      AND s.closed_at IS NULL
    ORDER BY s.opened_at DESC
    LIMIT 1;

    IF v_shift_id IS NOT NULL AND p_payment_method IN ('cash', 'manual_transfer', 'card', 'vodafone_cash', 'instapay') THEN
      INSERT INTO public.shift_payments (
        shift_id,
        lounge_id,
        payment_method,
        category,
        amount,
        paid_at
      ) VALUES (
        v_shift_id,
        p_lounge_id,
        p_payment_method,
        'other',
        p_amount,
        now()
      );
    END IF;
  END IF;

  INSERT INTO public.wallet_transactions (
    user_id,
    shift_id,
    amount,
    balance_after,
    transaction_type,
    idempotency_key,
    notes,
    created_by
  ) VALUES (
    v_caller,
    v_shift_id,
    p_amount,
    v_new_balance,
    'topup',
    p_idempotency_key,
    'Wallet top-up via ' || p_payment_method,
    v_caller
  )
  RETURNING id INTO v_txn_id;

  RETURN jsonb_build_object(
    'success', true,
    'transaction_id', v_txn_id,
    'amount_added', p_amount,
    'balance', v_new_balance,
    'currency', v_wallet.currency
  );
END;
$$;

-- RPC: Pay with Wallet (Atomic booking payment deduction)
CREATE OR REPLACE FUNCTION public.pay_with_wallet(
  p_booking_id uuid,
  p_amount numeric,
  p_idempotency_key text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_booking public.bookings%ROWTYPE;
  v_wallet public.user_wallets%ROWTYPE;
  v_new_balance numeric;
  v_txn_id uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Payment amount must be greater than zero' USING ERRCODE = '22023';
  END IF;

  -- Idempotency check
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id, balance_after INTO v_txn_id, v_new_balance
    FROM public.wallet_transactions
    WHERE idempotency_key = p_idempotency_key;

    IF FOUND THEN
      RETURN jsonb_build_object(
        'success', true,
        'idempotent', true,
        'transaction_id', v_txn_id,
        'balance', v_new_balance
      );
    END IF;
  END IF;

  SELECT * INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_booking.user_id <> v_caller AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Not authorized to pay for this booking' USING ERRCODE = '42501';
  END IF;

  IF v_booking.payment_status = 'paid' THEN
    RETURN jsonb_build_object('success', true, 'already_paid', true, 'booking_id', p_booking_id);
  END IF;

  SELECT * INTO v_wallet
  FROM public.user_wallets
  WHERE user_id = v_caller
  FOR UPDATE;

  IF NOT FOUND OR v_wallet.balance < p_amount THEN
    RAISE EXCEPTION 'INSUFFICIENT_WALLET_BALANCE: Balance is %, Required is %', COALESCE(v_wallet.balance, 0), p_amount USING ERRCODE = '55000';
  END IF;

  IF v_wallet.is_frozen THEN
    RAISE EXCEPTION 'Wallet is frozen. Contact support.' USING ERRCODE = '55000';
  END IF;

  v_new_balance := ROUND(v_wallet.balance - p_amount, 2);

  UPDATE public.user_wallets
  SET balance = v_new_balance,
      updated_at = now()
  WHERE user_id = v_caller;

  -- Update booking payment status
  UPDATE public.bookings
  SET payment_status = 'paid',
      payment_method = 'app_wallet',
      updated_at = now()
  WHERE id = p_booking_id;

  INSERT INTO public.wallet_transactions (
    user_id,
    booking_id,
    amount,
    balance_after,
    transaction_type,
    idempotency_key,
    notes,
    created_by
  ) VALUES (
    v_caller,
    p_booking_id,
    -p_amount,
    v_new_balance,
    'booking_payment',
    p_idempotency_key,
    'Payment for booking ' || p_booking_id::text,
    v_caller
  )
  RETURNING id INTO v_txn_id;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'transaction_id', v_txn_id,
    'amount_deducted', p_amount,
    'remaining_balance', v_new_balance,
    'payment_status', 'paid'
  );
END;
$$;

-- RPC: Refund to Wallet
CREATE OR REPLACE FUNCTION public.refund_to_wallet(
  p_booking_id uuid,
  p_amount numeric,
  p_reason text DEFAULT 'cancellation'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_booking public.bookings%ROWTYPE;
  v_wallet public.user_wallets%ROWTYPE;
  v_new_balance numeric;
  v_txn_id uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  SELECT * INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT public.is_super_admin()
     AND NOT public.has_lounge_permission(v_booking.lounge_id, 'billing_checkout') THEN
    RAISE EXCEPTION 'Not authorized to issue wallet refund' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.user_wallets (user_id, balance, currency)
  VALUES (v_booking.user_id, 0.00, 'EGP')
  ON CONFLICT (user_id) DO NOTHING;

  SELECT * INTO v_wallet
  FROM public.user_wallets
  WHERE user_id = v_booking.user_id
  FOR UPDATE;

  v_new_balance := ROUND(v_wallet.balance + p_amount, 2);

  UPDATE public.user_wallets
  SET balance = v_new_balance,
      updated_at = now()
  WHERE user_id = v_booking.user_id;

  UPDATE public.bookings
  SET payment_status = 'refunded',
      updated_at = now()
  WHERE id = p_booking_id;

  INSERT INTO public.wallet_transactions (
    user_id,
    booking_id,
    amount,
    balance_after,
    transaction_type,
    notes,
    created_by
  ) VALUES (
    v_booking.user_id,
    p_booking_id,
    p_amount,
    v_new_balance,
    'refund',
    'Refund: ' || COALESCE(p_reason, 'cancellation'),
    v_caller
  )
  RETURNING id INTO v_txn_id;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'transaction_id', v_txn_id,
    'refunded_amount', p_amount,
    'balance_after', v_new_balance
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_or_create_user_wallet(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_or_create_user_wallet(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.topup_user_wallet(numeric, text, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.topup_user_wallet(numeric, text, uuid, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.pay_with_wallet(uuid, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pay_with_wallet(uuid, numeric, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.refund_to_wallet(uuid, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.refund_to_wallet(uuid, numeric, text) TO authenticated, service_role;


-- ============================================================================
-- 2. Group Booking & Invite Friends
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.booking_group_invites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  inviter_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  invitee_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  invitee_phone text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled')),
  role text NOT NULL DEFAULT 'player' CHECK (role IN ('player', 'guest', 'spectator')),
  responded_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_group_invites_booking ON public.booking_group_invites(booking_id);
CREATE INDEX IF NOT EXISTS idx_group_invites_invitee ON public.booking_group_invites(invitee_id, status);

ALTER TABLE public.booking_group_invites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS group_invites_policy ON public.booking_group_invites;
CREATE POLICY group_invites_policy ON public.booking_group_invites
  FOR ALL TO authenticated
  USING (
    inviter_id = auth.uid()
    OR invitee_id = auth.uid()
    OR public.is_super_admin()
    OR EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = booking_group_invites.booking_id
        AND public.has_lounge_permission(b.lounge_id, 'sessions_control')
    )
  );

-- RPC: Invite friends to booking
CREATE OR REPLACE FUNCTION public.invite_friends_to_booking(
  p_booking_id uuid,
  p_invitee_ids uuid[] DEFAULT NULL,
  p_invitee_phones text[] DEFAULT NULL,
  p_role text DEFAULT 'player'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_booking public.bookings%ROWTYPE;
  v_room public.rooms%ROWTYPE;
  v_target_id uuid;
  v_phone text;
  v_count integer := 0;
  v_max_capacity integer := 8;
  v_current_count integer := 0;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  SELECT * INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_booking.user_id <> v_caller
     AND NOT public.is_super_admin()
     AND NOT public.has_lounge_permission(v_booking.lounge_id, 'sessions_control') THEN
    RAISE EXCEPTION 'Not authorized to invite guests to this booking' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_room FROM public.rooms WHERE id = v_booking.room_id;
  IF FOUND THEN
    v_max_capacity := COALESCE(v_room.controllers_count, 4) + 4; -- Allow reasonable guest headroom
  END IF;

  SELECT count(*) INTO v_current_count
  FROM public.booking_group_invites
  WHERE booking_id = p_booking_id AND status IN ('pending', 'accepted');

  -- Process UUID invitees
  IF p_invitee_ids IS NOT NULL THEN
    FOREACH v_target_id IN ARRAY p_invitee_ids
    LOOP
      IF v_target_id IS NOT NULL AND v_target_id <> v_caller THEN
        IF (v_current_count + v_count) >= v_max_capacity THEN
          EXIT;
        END IF;

        INSERT INTO public.booking_group_invites (
          booking_id,
          inviter_id,
          invitee_id,
          role,
          status
        ) VALUES (
          p_booking_id,
          v_caller,
          v_target_id,
          COALESCE(p_role, 'player'),
          'pending'
        );

        -- Send in-app notification
        INSERT INTO public.notifications (
          user_id,
          lounge_id,
          title_ar,
          title_en,
          body_ar,
          body_en,
          type,
          is_read,
          metadata
        ) VALUES (
          v_target_id,
          v_booking.lounge_id,
          'دعوة للعب 🎮',
          'Game Invite 🎮',
          'دعاك صديقك للانضمام إلى جلسة لعب!',
          'Your friend invited you to a game session!',
          'booking',
          false,
          jsonb_build_object('booking_id', p_booking_id, 'role', p_role)
        );

        v_count := v_count + 1;
      END IF;
    END LOOP;
  END IF;

  -- Process Phone invitees
  IF p_invitee_phones IS NOT NULL THEN
    FOREACH v_phone IN ARRAY p_invitee_phones
    LOOP
      IF v_phone IS NOT NULL AND btrim(v_phone) <> '' THEN
        IF (v_current_count + v_count) >= v_max_capacity THEN
          EXIT;
        END IF;

        -- Resolve registered user by phone if available
        SELECT id INTO v_target_id FROM public.profiles WHERE phone = btrim(v_phone) LIMIT 1;

        INSERT INTO public.booking_group_invites (
          booking_id,
          inviter_id,
          invitee_id,
          invitee_phone,
          role,
          status
        ) VALUES (
          p_booking_id,
          v_caller,
          v_target_id,
          btrim(v_phone),
          COALESCE(p_role, 'player'),
          'pending'
        );

        v_count := v_count + 1;
      END IF;
    END LOOP;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'invites_created', v_count
  );
END;
$$;

-- RPC: Respond to group booking invite
CREATE OR REPLACE FUNCTION public.respond_group_booking_invite(
  p_invite_id uuid,
  p_response text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_inv public.booking_group_invites%ROWTYPE;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF p_response NOT IN ('accepted', 'declined') THEN
    RAISE EXCEPTION 'Invalid response. Must be accepted or declined' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_inv FROM public.booking_group_invites WHERE id = p_invite_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invite not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_inv.invitee_id IS NOT NULL AND v_inv.invitee_id <> v_caller THEN
    RAISE EXCEPTION 'Not authorized to respond to this invite' USING ERRCODE = '42501';
  END IF;

  UPDATE public.booking_group_invites
  SET status = p_response,
      invitee_id = COALESCE(invitee_id, v_caller),
      responded_at = now()
  WHERE id = p_invite_id;

  RETURN jsonb_build_object(
    'success', true,
    'invite_id', p_invite_id,
    'status', p_response
  );
END;
$$;

-- RPC: Get booking participants
CREATE OR REPLACE FUNCTION public.get_booking_participants(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path TO ''
AS $$
DECLARE
  v_res jsonb;
BEGIN
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'invite_id', bgi.id,
        'user_id', bgi.invitee_id,
        'display_name', COALESCE(p.full_name, 'Guest Player'),
        'role', bgi.role,
        'status', bgi.status,
        'created_at', bgi.created_at,
        'responded_at', bgi.responded_at
      )
    ),
    '[]'::jsonb
  )
  INTO v_res
  FROM public.booking_group_invites bgi
  LEFT JOIN public.profiles p ON p.id = bgi.invitee_id
  WHERE bgi.booking_id = p_booking_id;

  RETURN v_res;
END;
$$;

REVOKE ALL ON FUNCTION public.invite_friends_to_booking(uuid, uuid[], text[], text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.invite_friends_to_booking(uuid, uuid[], text[], text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.respond_group_booking_invite(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.respond_group_booking_invite(uuid, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_booking_participants(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_booking_participants(uuid) TO authenticated, service_role;


-- ============================================================================
-- 3. Corporate, Birthday & Event Booking Packages
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.event_packages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lounge_id uuid NOT NULL REFERENCES public.lounges(id) ON DELETE CASCADE,
  title_ar text NOT NULL,
  title_en text NOT NULL,
  description_ar text,
  description_en text,
  min_attendees integer NOT NULL DEFAULT 5 CHECK (min_attendees > 0),
  max_attendees integer NOT NULL DEFAULT 50 CHECK (max_attendees >= min_attendees),
  base_price numeric(10,2) NOT NULL CHECK (base_price >= 0),
  per_person_price numeric(10,2) NOT NULL DEFAULT 0.0 CHECK (per_person_price >= 0),
  duration_hours numeric(4,2) NOT NULL DEFAULT 3.0 CHECK (duration_hours > 0),
  includes_canteen boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.event_booking_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lounge_id uuid NOT NULL REFERENCES public.lounges(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  package_id uuid REFERENCES public.event_packages(id) ON DELETE SET NULL,
  event_type text NOT NULL CHECK (event_type IN ('birthday', 'corporate', 'tournament_private', 'custom')),
  event_date date NOT NULL,
  start_time time NOT NULL,
  end_time time NOT NULL,
  attendees_count integer NOT NULL CHECK (attendees_count > 0),
  custom_requirements text,
  quoted_price numeric(10,2) DEFAULT NULL,
  deposit_required numeric(10,2) DEFAULT NULL,
  deposit_paid numeric(10,2) NOT NULL DEFAULT 0.0,
  status text NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted', 'under_review', 'quoted', 'confirmed', 'rejected', 'completed', 'cancelled')),
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  staff_notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_event_booking_lounge ON public.event_booking_requests(lounge_id, status);

ALTER TABLE public.event_packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_booking_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS event_packages_policy ON public.event_packages;
CREATE POLICY event_packages_policy ON public.event_packages
  FOR SELECT TO authenticated, anon
  USING (true);

DROP POLICY IF EXISTS event_booking_requests_policy ON public.event_booking_requests;
CREATE POLICY event_booking_requests_policy ON public.event_booking_requests
  FOR ALL TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_super_admin()
    OR public.has_lounge_permission(lounge_id, 'sessions_control')
  );

-- RPC: Submit event booking request
CREATE OR REPLACE FUNCTION public.submit_event_booking_request(
  p_lounge_id uuid,
  p_event_type text,
  p_event_date date,
  p_start_time time,
  p_end_time time,
  p_attendees_count integer,
  p_package_id uuid DEFAULT NULL,
  p_custom_requirements text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_pkg public.event_packages%ROWTYPE;
  v_estimated numeric := 0;
  v_req_id uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF p_package_id IS NOT NULL THEN
    SELECT * INTO v_pkg FROM public.event_packages WHERE id = p_package_id;
    IF FOUND THEN
      v_estimated := v_pkg.base_price + (GREATEST(0, p_attendees_count - v_pkg.min_attendees) * v_pkg.per_person_price);
    END IF;
  END IF;

  INSERT INTO public.event_booking_requests (
    lounge_id,
    user_id,
    package_id,
    event_type,
    event_date,
    start_time,
    end_time,
    attendees_count,
    custom_requirements,
    quoted_price,
    status
  ) VALUES (
    p_lounge_id,
    v_caller,
    p_package_id,
    p_event_type,
    p_event_date,
    p_start_time,
    p_end_time,
    p_attendees_count,
    p_custom_requirements,
    CASE WHEN v_estimated > 0 THEN v_estimated ELSE NULL END,
    'submitted'
  )
  RETURNING id INTO v_req_id;

  RETURN jsonb_build_object(
    'success', true,
    'request_id', v_req_id,
    'estimated_price', v_estimated,
    'status', 'submitted'
  );
END;
$$;

-- RPC: Review event booking request
CREATE OR REPLACE FUNCTION public.review_event_booking_request(
  p_request_id uuid,
  p_action text,
  p_quoted_price numeric DEFAULT NULL,
  p_deposit_required numeric DEFAULT NULL,
  p_staff_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_req public.event_booking_requests%ROWTYPE;
  v_new_status text;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  SELECT * INTO v_req FROM public.event_booking_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Event request not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT public.is_super_admin() AND NOT public.has_lounge_permission(v_req.lounge_id, 'sessions_control') THEN
    RAISE EXCEPTION 'Not authorized to review event requests' USING ERRCODE = '42501';
  END IF;

  CASE p_action
    WHEN 'quote' THEN v_new_status := 'quoted';
    WHEN 'confirm' THEN v_new_status := 'confirmed';
    WHEN 'reject' THEN v_new_status := 'rejected';
    WHEN 'complete' THEN v_new_status := 'completed';
    WHEN 'cancel' THEN v_new_status := 'cancelled';
    ELSE RAISE EXCEPTION 'Invalid review action: %', p_action USING ERRCODE = '22023';
  END CASE;

  UPDATE public.event_booking_requests
  SET status = v_new_status,
      quoted_price = COALESCE(p_quoted_price, quoted_price),
      deposit_required = COALESCE(p_deposit_required, deposit_required),
      staff_notes = COALESCE(p_staff_notes, staff_notes),
      reviewed_by = v_caller,
      reviewed_at = now()
  WHERE id = p_request_id;

  -- Notify user of status update
  INSERT INTO public.notifications (
    user_id,
    lounge_id,
    title_ar,
    title_en,
    body_ar,
    body_en,
    type,
    is_read,
    metadata
  ) VALUES (
    v_req.user_id,
    v_req.lounge_id,
    'تحديث طلب حفل / فعالية 🎉',
    'Event Request Update 🎉',
    'تم تحديث حالة طلبك إلى: ' || v_new_status,
    'Your event booking request status is now: ' || v_new_status,
    'system',
    false,
    jsonb_build_object('request_id', p_request_id, 'status', v_new_status)
  );

  RETURN jsonb_build_object(
    'success', true,
    'request_id', p_request_id,
    'status', v_new_status
  );
END;
$$;

REVOKE ALL ON FUNCTION public.submit_event_booking_request(uuid, text, date, time, time, integer, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_event_booking_request(uuid, text, date, time, time, integer, uuid, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.review_event_booking_request(uuid, text, numeric, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.review_event_booking_request(uuid, text, numeric, numeric, text) TO authenticated, service_role;


-- ============================================================================
-- 4. Smart Offers & Coupon Budget Engine
-- ============================================================================

-- Add missing and growth columns to public.promotions
ALTER TABLE public.promotions
  ADD COLUMN IF NOT EXISTS code text,
  ADD COLUMN IF NOT EXISTS max_total_budget numeric(10,2) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS current_budget_used numeric(10,2) NOT NULL DEFAULT 0.0,
  ADD COLUMN IF NOT EXISTS max_uses_per_user integer NOT NULL DEFAULT 1 CHECK (max_uses_per_user > 0),
  ADD COLUMN IF NOT EXISTS min_booking_amount numeric(10,2) NOT NULL DEFAULT 0.0 CHECK (min_booking_amount >= 0);

CREATE TABLE IF NOT EXISTS public.promotion_usages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  promotion_id uuid NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  booking_id uuid REFERENCES public.bookings(id) ON DELETE CASCADE,
  discount_applied numeric(10,2) NOT NULL CHECK (discount_applied >= 0),
  used_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_promotion_usages_user ON public.promotion_usages(promotion_id, user_id);

ALTER TABLE public.promotion_usages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS promotion_usages_policy ON public.promotion_usages;
CREATE POLICY promotion_usages_policy ON public.promotion_usages
  FOR ALL TO authenticated
  USING (user_id = auth.uid() OR public.is_super_admin());

-- RPC: Validate & Apply Promo Code with budget & user caps
CREATE OR REPLACE FUNCTION public.validate_and_apply_promo_code(
  p_lounge_id uuid,
  p_room_id uuid,
  p_code text,
  p_booking_amount numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path TO ''
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_promo public.promotions%ROWTYPE;
  v_user_uses integer := 0;
  v_discount numeric := 0;
  v_final numeric := 0;
BEGIN
  IF p_code IS NULL OR btrim(p_code) = '' THEN
    RETURN jsonb_build_object('valid', false, 'error', 'CODE_EMPTY');
  END IF;

  SELECT * INTO v_promo
  FROM public.promotions
  WHERE lower(btrim(code)) = lower(btrim(p_code))
    AND is_active = true
    AND (lounge_id IS NULL OR lounge_id = p_lounge_id)
    AND (room_id IS NULL OR room_id = p_room_id)
    AND (expires_at IS NULL OR expires_at > now())
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('valid', false, 'error', 'PROMO_NOT_FOUND_OR_EXPIRED');
  END IF;

  -- Minimum spend check
  IF p_booking_amount < COALESCE(v_promo.min_booking_amount, 0) THEN
    RETURN jsonb_build_object(
      'valid', false,
      'error', 'MINIMUM_AMOUNT_NOT_MET',
      'min_amount', v_promo.min_booking_amount
    );
  END IF;

  -- Per user usage limit
  IF v_caller IS NOT NULL THEN
    SELECT count(*) INTO v_user_uses
    FROM public.promotion_usages
    WHERE promotion_id = v_promo.id AND user_id = v_caller;

    IF v_user_uses >= COALESCE(v_promo.max_uses_per_user, 1) THEN
      RETURN jsonb_build_object('valid', false, 'error', 'USER_LIMIT_EXCEEDED');
    END IF;
  END IF;

  -- Calculate discount
  IF v_promo.discount_type = 'percentage' THEN
    v_discount := ROUND(p_booking_amount * (v_promo.discount_value / 100.0), 2);
  ELSE
    v_discount := LEAST(p_booking_amount, v_promo.discount_value);
  END IF;

  -- Total budget cap check
  IF v_promo.max_total_budget IS NOT NULL THEN
    IF (v_promo.current_budget_used + v_discount) > v_promo.max_total_budget THEN
      RETURN jsonb_build_object('valid', false, 'error', 'BUDGET_CAP_EXCEEDED');
    END IF;
  END IF;

  v_final := GREATEST(0, p_booking_amount - v_discount);

  RETURN jsonb_build_object(
    'valid', true,
    'promotion_id', v_promo.id,
    'code', v_promo.code,
    'discount_type', v_promo.discount_type,
    'discount_value', v_promo.discount_value,
    'discount_applied', v_discount,
    'final_amount', v_final
  );
END;
$$;

-- RPC: Record promotion usage
CREATE OR REPLACE FUNCTION public.record_promotion_usage(
  p_promotion_id uuid,
  p_booking_id uuid,
  p_discount_applied numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_caller uuid := auth.uid();
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  INSERT INTO public.promotion_usages (
    promotion_id,
    user_id,
    booking_id,
    discount_applied
  ) VALUES (
    p_promotion_id,
    v_caller,
    p_booking_id,
    p_discount_applied
  );

  UPDATE public.promotions
  SET current_budget_used = current_budget_used + p_discount_applied
  WHERE id = p_promotion_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

REVOKE ALL ON FUNCTION public.validate_and_apply_promo_code(uuid, uuid, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.validate_and_apply_promo_code(uuid, uuid, text, numeric) TO authenticated, anon, service_role;

REVOKE ALL ON FUNCTION public.record_promotion_usage(uuid, uuid, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_promotion_usage(uuid, uuid, numeric) TO authenticated, service_role;


-- ============================================================================
-- 5. Financial Loss Prevention & Risk Audit Layer
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.financial_risk_audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lounge_id uuid NOT NULL REFERENCES public.lounges(id) ON DELETE CASCADE,
  shift_id uuid REFERENCES public.shifts(id) ON DELETE SET NULL,
  actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  risk_level text NOT NULL CHECK (risk_level IN ('low', 'medium', 'high', 'critical')),
  action_type text NOT NULL CHECK (action_type IN ('cash_difference', 'excessive_void', 'session_override', 'manual_discount', 'no_show_override', 'price_override')),
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_risk_audit_lounge ON public.financial_risk_audit_logs(lounge_id, risk_level, created_at DESC);

ALTER TABLE public.financial_risk_audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS risk_audit_policy ON public.financial_risk_audit_logs;
CREATE POLICY risk_audit_policy ON public.financial_risk_audit_logs
  FOR ALL TO authenticated
  USING (
    public.is_super_admin()
    OR public.has_lounge_permission(lounge_id, 'billing_checkout')
  );

-- RPC: Log risk event
CREATE OR REPLACE FUNCTION public.log_financial_risk_event(
  p_lounge_id uuid,
  p_shift_id uuid,
  p_risk_level text,
  p_action_type text,
  p_details jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_log_id uuid;
BEGIN
  INSERT INTO public.financial_risk_audit_logs (
    lounge_id,
    shift_id,
    actor_id,
    risk_level,
    action_type,
    details
  ) VALUES (
    p_lounge_id,
    p_shift_id,
    v_caller,
    p_risk_level,
    p_action_type,
    COALESCE(p_details, '{}'::jsonb)
  )
  RETURNING id INTO v_log_id;

  RETURN jsonb_build_object('success', true, 'log_id', v_log_id);
END;
$$;

-- RPC: Get Lounge Loss Prevention Timeline
CREATE OR REPLACE FUNCTION public.get_lounge_loss_prevention_timeline(
  p_lounge_id uuid,
  p_start_date timestamptz DEFAULT (now() - interval '30 days'),
  p_end_date timestamptz DEFAULT now()
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path TO ''
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_res jsonb;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF NOT public.is_super_admin() AND NOT public.has_lounge_permission(p_lounge_id, 'billing_checkout') THEN
    RAISE EXCEPTION 'Not authorized to view loss prevention timeline' USING ERRCODE = '42501';
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'log_id', l.id,
        'shift_id', l.shift_id,
        'actor_name', COALESCE(p.full_name, 'Staff'),
        'risk_level', l.risk_level,
        'action_type', l.action_type,
        'details', l.details,
        'created_at', l.created_at
      )
      ORDER BY l.created_at DESC
    ),
    '[]'::jsonb
  )
  INTO v_res
  FROM public.financial_risk_audit_logs l
  LEFT JOIN public.profiles p ON p.id = l.actor_id
  WHERE l.lounge_id = p_lounge_id
    AND l.created_at BETWEEN p_start_date AND p_end_date;

  RETURN v_res;
END;
$$;

REVOKE ALL ON FUNCTION public.log_financial_risk_event(uuid, uuid, text, text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_financial_risk_event(uuid, uuid, text, text, jsonb) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_lounge_loss_prevention_timeline(uuid, timestamptz, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_lounge_loss_prevention_timeline(uuid, timestamptz, timestamptz) TO authenticated, service_role;


-- ============================================================================
-- 6. Tournament Payment Submission Hardening & Obsolete Overload Removal
-- ============================================================================

-- Drop the obsolete 6-parameter overload
DROP FUNCTION IF EXISTS public.submit_tournament_payment(uuid, uuid, uuid, numeric, text, text);

-- Harden the 4-parameter submit_tournament_payment
CREATE OR REPLACE FUNCTION public.submit_tournament_payment(
  p_participant_id uuid,
  p_amount numeric,
  p_payment_method text,
  p_receipt_url text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_p public.tournament_participants%ROWTYPE;
  v_t public.tournaments%ROWTYPE;
  v_s public.tournament_payment_submissions%ROWTYPE;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF p_participant_id IS NULL OR p_amount IS NULL OR p_payment_method IS NULL THEN
    RAISE EXCEPTION 'Missing required fields' USING ERRCODE = '22023';
  END IF;

  SELECT p.* INTO v_p
  FROM public.tournament_participants p
  WHERE p.id = p_participant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Participant not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_p.user_id IS DISTINCT FROM v_caller AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Not authorized: caller is not the registered participant' USING ERRCODE = '42501';
  END IF;

  SELECT t.* INTO v_t
  FROM public.tournaments t
  WHERE t.id = v_p.tournament_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tournament not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_p.registration_status <> 'pending_payment' OR v_p.payment_status <> 'unpaid' THEN
    RAISE EXCEPTION 'Payment submission not allowed for current registration status: %', v_p.registration_status USING ERRCODE = '55000';
  END IF;

  IF v_p.payment_deadline IS NOT NULL AND v_p.payment_deadline < now() THEN
    RAISE EXCEPTION 'Payment deadline has expired' USING ERRCODE = '55000';
  END IF;

  IF p_payment_method NOT IN ('instapay', 'vodafone_cash') OR p_receipt_url IS NULL OR btrim(p_receipt_url) = '' THEN
    RAISE EXCEPTION 'A valid receipt URL is required for manual payment verification' USING ERRCODE = '22023';
  END IF;

  IF p_amount <> v_t.entry_fee THEN
    RAISE EXCEPTION 'Payment amount mismatch. Expected: %, Got: %', v_t.entry_fee, p_amount USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.tournament_payment_submissions (
    participant_id,
    amount,
    payment_method,
    receipt_url,
    submitted_by
  ) VALUES (
    p_participant_id,
    p_amount,
    p_payment_method,
    p_receipt_url,
    v_caller
  )
  RETURNING * INTO v_s;

  UPDATE public.tournament_participants
  SET payment_status = 'pending',
      payment_method = p_payment_method,
      receipt_url = p_receipt_url,
      updated_at = now()
  WHERE id = p_participant_id
  RETURNING * INTO v_p;

  -- Log tournament audit if audit function exists
  BEGIN
    PERFORM public.tournament_audit(v_t.id, 'payment_submitted', p_participant_id, NULL, NULL, to_jsonb(v_s));
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN row_to_json(v_p);
END;
$$;

REVOKE ALL ON FUNCTION public.submit_tournament_payment(uuid, numeric, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_tournament_payment(uuid, numeric, text, text) TO authenticated, service_role;


-- ============================================================================
-- 7. PlaySpot Pass Roaming Framework
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.lounge_roaming_agreements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lounge_id uuid NOT NULL REFERENCES public.lounges(id) ON DELETE CASCADE,
  allows_roaming_pass boolean NOT NULL DEFAULT true,
  settlement_discount_rate numeric(4,2) NOT NULL DEFAULT 0.85, -- 85% reimbursement rate between lounges
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'terminated')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.lounge_roaming_agreements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS roaming_agreements_policy ON public.lounge_roaming_agreements;
CREATE POLICY roaming_agreements_policy ON public.lounge_roaming_agreements
  FOR SELECT TO authenticated, anon
  USING (true);

CREATE OR REPLACE FUNCTION public.check_roaming_pass_eligibility(
  p_lounge_id uuid,
  p_user_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path TO ''
AS $$
DECLARE
  v_target_user uuid := COALESCE(p_user_id, auth.uid());
  v_has_active_pass boolean := false;
  v_lounge_allows boolean := false;
BEGIN
  IF v_target_user IS NULL THEN
    RETURN jsonb_build_object('eligible', false, 'reason', 'AUTH_REQUIRED');
  END IF;

  SELECT allows_roaming_pass INTO v_lounge_allows
  FROM public.lounge_roaming_agreements
  WHERE lounge_id = p_lounge_id AND status = 'active';

  IF NOT COALESCE(v_lounge_allows, false) THEN
    RETURN jsonb_build_object('eligible', false, 'reason', 'LOUNGE_NOT_ROAMING_PARTNER');
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.user_membership_packages
    WHERE user_id = v_target_user
      AND status = 'active'
      AND remaining_hours > 0
      AND expires_at > now()
  ) INTO v_has_active_pass;

  RETURN jsonb_build_object(
    'eligible', v_has_active_pass,
    'lounge_id', p_lounge_id,
    'user_id', v_target_user
  );
END;
$$;

REVOKE ALL ON FUNCTION public.check_roaming_pass_eligibility(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_roaming_pass_eligibility(uuid, uuid) TO authenticated, service_role;
