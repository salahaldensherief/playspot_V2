import {createFixtureDatabase} from './runtime/database.mjs';
import {installLatestFunctions} from './runtime/latest_contracts.mjs';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {lockedRace} from './runtime/locked_race.mjs';

const db = await createFixtureDatabase();

const superAdmin = randomUUID();
const owner = randomUUID();
const cashier = randomUUID();
const customer = randomUUID();
const outsider = randomUUID();

const lounge = randomUUID();
const foreignLounge = randomUUID();
const room = randomUUID();
const shift = randomUUID();

let passed = 0;

async function asActor(id = superAdmin) {
  await db.exec(`RESET ROLE; SET test.actor='${id}'; SET ROLE authenticated;`);
}

async function admin(sql, args = []) {
  await db.exec('RESET ROLE');
  if (args.length > 0) {
    return await db.query(sql, args);
  }
  return await db.exec(sql);
}

async function check(name, body) {
  await body();
  passed++;
  console.log('PASS ' + name);
}

async function expectReject(name, fn, expectedCode, actorId = superAdmin) {
  await asActor(actorId);
  await assert.rejects(fn, (err) => {
    assert.equal(
      err.code,
      expectedCode,
      `Expected SQLSTATE ${expectedCode} for "${name}", got ${err.code} (${err.message})`
    );
    return true;
  });
  passed++;
  console.log('PASS ' + name);
}

async function resetLoungeFinancialState(targetLounge = lounge) {
  await admin(`
    ALTER TABLE private.booking_movement_payout_entries DISABLE TRIGGER USER;
    DELETE FROM private.booking_movement_payout_entries
    WHERE movement_id IN (SELECT id FROM private.booking_money_movements WHERE lounge_id = '${targetLounge}');
    ALTER TABLE private.booking_movement_payout_entries ENABLE TRIGGER USER;
    ALTER TABLE private.payout_settlement_entries DISABLE TRIGGER USER;
    DELETE FROM private.payout_settlement_entries WHERE lounge_id = '${targetLounge}';
    ALTER TABLE private.payout_settlement_entries ENABLE TRIGGER USER;
    DELETE FROM private.booking_refund_requests WHERE lounge_id = '${targetLounge}';
    ALTER TABLE private.booking_money_movements DISABLE TRIGGER USER;
    DELETE FROM private.booking_money_movements WHERE lounge_id = '${targetLounge}';
    ALTER TABLE private.booking_money_movements ENABLE TRIGGER USER;
    DELETE FROM public.shift_expenses WHERE lounge_id = '${targetLounge}';
    DELETE FROM public.shift_payments WHERE lounge_id = '${targetLounge}';
    DELETE FROM private.cash_collection_receipts
    WHERE booking_id IN (SELECT id FROM public.bookings WHERE lounge_id = '${targetLounge}');
    ALTER TABLE public.payments DISABLE TRIGGER USER;
    UPDATE public.payments SET payout_id = NULL WHERE lounge_id = '${targetLounge}';
    DELETE FROM public.payments WHERE lounge_id = '${targetLounge}';
    ALTER TABLE public.payments ENABLE TRIGGER USER;
    ALTER TABLE public.payouts DISABLE TRIGGER USER;
    DELETE FROM public.payouts WHERE lounge_id = '${targetLounge}';
    ALTER TABLE public.payouts ENABLE TRIGGER USER;
    DELETE FROM public.bookings WHERE lounge_id = '${targetLounge}';
  `);
}

async function createPlatformVerifiedDepositBooking({
  totalPrice = 200.0,
  depositAmount = 100.0,
  method = 'instapay',
  verifiedDay = '2026-10-10',
  completedBooking = true,
  targetLounge = lounge,
} = {}) {
  const bId = randomUUID();
  const opId = randomUUID();
  const ref = 'TX-PLAT-' + bId.slice(0, 8);
  const effectiveTotalPrice = completedBooking && totalPrice <= depositAmount ? depositAmount * 2 : totalPrice;
  await admin(
    `
      INSERT INTO public.bookings(
        id, user_id, lounge_id, room_id, status, confirmation_status,
        total_price, payment_status, payment_method,
        deposit_required, deposit_amount, deposit_paid, receipt_url
      )
      VALUES (
        $1, $2, $3, $4, 'upcoming', 'confirmed',
        $5, 'unpaid', $6,
        true, $7, false, 'booking_receipts/proof.jpg'
      )
    `,
    [bId, customer, targetLounge, room, effectiveTotalPrice, method, depositAmount]
  );

  await asActor(superAdmin);
  const res = (
    await db.query(
      `SELECT public.verify_booking_deposit_transfer($1, $2, $3, $4, 'platform') AS r`,
      [bId, shift, opId, ref]
    )
  ).rows[0].r;

  const paymentRow = (
    await admin(`SELECT payment_id FROM private.booking_money_movements WHERE id = $1`, [res.movement_id])
  ).rows[0];

  if (completedBooking) {
    await admin(
      `UPDATE public.bookings SET status = 'cancelled', cancellation_reason = 'Session finalized after deposit', updated_at = now() WHERE id = $1`,
      [bId]
    );
  }

  // Stamp verified_at and paid_at to the requested Cairo calendar date (at 12:00 UTC)
  await admin(`
    ALTER TABLE private.booking_money_movements DISABLE TRIGGER USER;
    UPDATE private.booking_money_movements
    SET verified_at = ('${verifiedDay}'::date + interval '12 hours')
    WHERE id = '${res.movement_id}';
    ALTER TABLE private.booking_money_movements ENABLE TRIGGER USER;

    ALTER TABLE public.payments DISABLE TRIGGER USER;
    UPDATE public.payments
    SET paid_at = ('${verifiedDay}'::date + interval '12 hours')
    WHERE id = '${paymentRow.payment_id}';
    ALTER TABLE public.payments ENABLE TRIGGER USER;
  `);

  return {
    bookingId: bId,
    paymentId: paymentRow.payment_id,
    movementId: res.movement_id,
    reference: ref,
  };
}

async function createLoungeCashCheckoutBooking({
  totalPrice = 100.0,
  verifiedDay = '2026-10-10',
  targetLounge = lounge,
} = {}) {
  const bId = randomUUID();
  const amountMinor = Math.round(totalPrice * 100);
  await admin(
    `
      INSERT INTO public.bookings(
        id, user_id, lounge_id, room_id, status, confirmation_status,
        total_price, payment_status, payment_method,
        deposit_required, deposit_amount, deposit_paid
      )
      VALUES (
        $1, $2, $3, $4, 'completed', 'confirmed',
        $5, 'unpaid', 'cash',
        false, 0, false
      )
    `,
    [bId, customer, targetLounge, room, totalPrice]
  );

  await asActor(cashier);
  await db.query(
    `SELECT public.checkout_booking_cash_atomic($1, $2, $3, $4) AS r`,
    [bId, shift, amountMinor, randomUUID()]
  );

  const mov = (
    await admin(
      `SELECT id, payment_id FROM private.booking_money_movements WHERE booking_id = $1 AND movement_type = 'collection'`,
      [bId]
    )
  ).rows[0];

  await admin(`
    ALTER TABLE private.booking_money_movements DISABLE TRIGGER USER;
    UPDATE private.booking_money_movements
    SET verified_at = ('${verifiedDay}'::date + interval '12 hours')
    WHERE id = '${mov.id}';
    ALTER TABLE private.booking_money_movements ENABLE TRIGGER USER;

    ALTER TABLE public.payments DISABLE TRIGGER USER;
    UPDATE public.payments
    SET paid_at = ('${verifiedDay}'::date + interval '12 hours')
    WHERE id = '${mov.payment_id}';
    ALTER TABLE public.payments ENABLE TRIGGER USER;
  `);

  return {
    bookingId: bId,
    paymentId: mov.payment_id,
    movementId: mov.id,
  };
}

async function executeVerifiedRefund({
  bookingId,
  movementId,
  amount,
  fundsHolder,
  refundMethod,
  shiftId = null,
  verifiedDay = '2026-10-15',
  reason = 'Verified customer refund',
}) {
  const actor = fundsHolder === 'platform' ? superAdmin : owner;
  const amountMinor = Math.round(amount * 100);
  await asActor(actor);
  const initRes = (
    await db.query(
      `SELECT public.initiate_booking_refund($1, $2, $3, $4, $5) AS r`,
      [bookingId, movementId, amountMinor, reason, randomUUID()]
    )
  ).rows[0].r;

  const execActor = fundsHolder === 'platform' ? superAdmin : cashier;
  await asActor(execActor);
  const execRes = (
    await db.query(
      `SELECT public.execute_booking_refund($1, $2, $3, $4, $5) AS r`,
      [
        initRes.refund_request_id,
        refundMethod,
        'REF-PROOF-' + initRes.refund_request_id.slice(0, 8),
        randomUUID(),
        shiftId,
      ]
    )
  ).rows[0].r;

  await admin(`
    ALTER TABLE private.booking_money_movements DISABLE TRIGGER USER;
    UPDATE private.booking_money_movements
    SET verified_at = ('${verifiedDay}'::date + interval '12 hours')
    WHERE id = '${execRes.refund_movement_id}';
    ALTER TABLE private.booking_money_movements ENABLE TRIGGER USER;
  `);

  return {
    refundRequestId: initRes.refund_request_id,
    reversalMovementId: execRes.refund_movement_id,
    execRes,
  };
}

try {
  await db.exec(`
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon; END IF;
      IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated; END IF;
      IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN CREATE ROLE service_role; END IF;
      IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_auth_admin') THEN CREATE ROLE supabase_auth_admin; END IF;
    END $$;

    CREATE SCHEMA IF NOT EXISTS auth;
    CREATE SCHEMA IF NOT EXISTS private;

    CREATE OR REPLACE FUNCTION auth.uid()
    RETURNS uuid
    LANGUAGE sql
    AS $$ SELECT NULLIF(current_setting('test.actor', true), '')::uuid $$;

    CREATE TABLE auth.users (
      id uuid PRIMARY KEY,
      banned_until timestamptz,
      deleted_at timestamptz
    );

    CREATE TYPE public.booking_status AS ENUM (
      'pending',
      'upcoming',
      'in_progress',
      'completed',
      'cancelled',
      'rejected',
      'expired'
    );

    CREATE TABLE public.profiles (
      id uuid PRIMARY KEY,
      role text,
      lounge_id uuid,
      is_active boolean DEFAULT true,
      is_banned boolean DEFAULT false
    );

    CREATE TABLE public.platform_super_admins (
      user_id uuid PRIMARY KEY
    );

    CREATE TABLE public.lounges (
      id uuid PRIMARY KEY,
      name text,
      name_ar text,
      name_en text,
      owner_id uuid,
      is_active boolean DEFAULT true,
      status text DEFAULT 'active',
      timezone text DEFAULT 'Africa/Cairo',
      allow_cash_payment boolean DEFAULT true,
      require_booking_deposit boolean DEFAULT false,
      booking_deposit_amount numeric(10,2),
      deposit_refund_allowed boolean DEFAULT true,
      cancellation_window_hours integer DEFAULT 4,
      updated_at timestamptz DEFAULT now()
    );

    CREATE TABLE public.rooms (
      id uuid PRIMARY KEY,
      lounge_id uuid REFERENCES public.lounges(id),
      status text DEFAULT 'available',
      is_available boolean DEFAULT true,
      updated_at timestamptz DEFAULT now()
    );

    CREATE TABLE public.fixture_permissions (
      actor uuid,
      lounge uuid,
      permission text
    );

    CREATE OR REPLACE FUNCTION public.is_super_admin()
    RETURNS boolean
    LANGUAGE sql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
      SELECT EXISTS (
        SELECT 1
        FROM public.platform_super_admins psa
        JOIN public.profiles p ON p.id = psa.user_id
        JOIN auth.users u ON u.id = p.id
        WHERE psa.user_id = auth.uid()
          AND p.role = 'super_admin'
          AND p.is_active IS TRUE
          AND p.is_banned IS FALSE
          AND u.deleted_at IS NULL
          AND (u.banned_until IS NULL OR u.banned_until <= now())
      );
    $$;

    CREATE OR REPLACE FUNCTION public.has_lounge_permission(p_lounge_id uuid, p_permission text)
    RETURNS boolean
    LANGUAGE sql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
      SELECT EXISTS (
        SELECT 1
        FROM public.fixture_permissions fp
        WHERE fp.actor = auth.uid()
          AND fp.lounge = p_lounge_id
          AND fp.permission = p_permission
      )
      OR EXISTS (
        SELECT 1
        FROM public.lounges l
        WHERE l.id = p_lounge_id
          AND l.owner_id = auth.uid()
      );
    $$;

    CREATE OR REPLACE FUNCTION private.can_manage_playspot_lounge(p_lounge_id uuid)
    RETURNS boolean
    LANGUAGE sql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
      SELECT public.is_super_admin()
      OR EXISTS (
        SELECT 1
        FROM public.lounges l
        JOIN public.profiles p ON p.id = auth.uid()
        WHERE l.id = p_lounge_id
          AND p.is_active IS TRUE
          AND p.is_banned IS FALSE
          AND (l.owner_id = auth.uid() OR (p.lounge_id = p_lounge_id AND p.role IN ('owner', 'manager')))
      );
    $$;

    CREATE OR REPLACE FUNCTION private.can_operate_playspot_lounge(p_lounge_id uuid)
    RETURNS boolean
    LANGUAGE sql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
      SELECT private.can_manage_playspot_lounge(p_lounge_id)
      OR public.has_lounge_permission(p_lounge_id, 'billing_checkout')
      OR public.has_lounge_permission(p_lounge_id, 'bookings_cancel');
    $$;

    CREATE OR REPLACE FUNCTION private.assert_lounge_operator(p_lounge_id uuid, p_require_active boolean DEFAULT true)
    RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
    BEGIN
      IF NOT private.can_operate_playspot_lounge(p_lounge_id) THEN
        RAISE EXCEPTION 'Unauthorized lounge operator' USING ERRCODE = '42501';
      END IF;
    END;
    $$;

    CREATE OR REPLACE FUNCTION private.require_active_booking_actor()
    RETURNS uuid
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
    DECLARE
      v_actor uuid := auth.uid();
    BEGIN
      IF v_actor IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
      END IF;
      PERFORM 1
      FROM public.profiles p
      JOIN auth.users u ON u.id = p.id
      WHERE p.id = v_actor
        AND COALESCE(p.is_active, true) IS TRUE
        AND COALESCE(p.is_banned, false) IS FALSE
        AND u.deleted_at IS NULL
        AND (u.banned_until IS NULL OR u.banned_until <= now());
      IF NOT FOUND THEN
        RAISE EXCEPTION 'Actor profile is inactive or banned' USING ERRCODE = '42501';
      END IF;
      RETURN v_actor;
    END;
    $$;

    CREATE OR REPLACE FUNCTION private.platform_commission_rate()
    RETURNS numeric
    LANGUAGE sql
    IMMUTABLE
    AS $$ SELECT 0.15::numeric $$;

    CREATE TABLE public.shifts (
      id uuid PRIMARY KEY,
      lounge_id uuid REFERENCES public.lounges(id),
      cashier_id uuid,
      staff_user_id uuid,
      status text DEFAULT 'open',
      starting_cash numeric(10,2) DEFAULT 0,
      closed_at timestamptz
    );

    CREATE TABLE public.bookings (
      id uuid PRIMARY KEY,
      user_id uuid,
      lounge_id uuid REFERENCES public.lounges(id),
      room_id uuid REFERENCES public.rooms(id),
      date date DEFAULT current_date,
      start_time time DEFAULT '20:00:00',
      end_time time DEFAULT '22:00:00',
      status public.booking_status DEFAULT 'upcoming',
      confirmation_status text DEFAULT 'confirmed',
      is_open_time boolean DEFAULT false,
      total_price numeric(10,2) NOT NULL,
      payment_status text DEFAULT 'unpaid',
      payment_method text DEFAULT 'cash',
      deposit_required boolean DEFAULT false,
      deposit_amount numeric(10,2) DEFAULT 0,
      deposit_paid boolean DEFAULT false,
      receipt_url text,
      discount_amount numeric(10,2) DEFAULT 0,
      discount_percentage numeric(5,2) DEFAULT 0,
      discount_reason text,
      discount_approved_by uuid,
      cancellation_reason text,
      cancelled_by uuid,
      cancelled_at timestamptz,
      actual_start_time timestamptz,
      open_time_started_at timestamptz,
      checked_in_at timestamptz,
      updated_at timestamptz DEFAULT now(),
      CONSTRAINT bookings_payment_method_check CHECK (
        payment_method IN ('cash', 'manual_transfer', 'card', 'vodafone_cash', 'fawry', 'instapay', 'app_wallet')
      )
    );

    CREATE TABLE public.payouts (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      lounge_id uuid NOT NULL REFERENCES public.lounges(id),
      period_start date,
      period_end date,
      total_amount numeric,
      status text NOT NULL DEFAULT 'pending',
      created_by uuid,
      approved_by uuid,
      approved_at timestamptz,
      processing_started_by uuid,
      processing_started_at timestamptz,
      paid_at timestamptz,
      paid_by uuid,
      transfer_method text,
      transfer_reference text,
      receipt_url text,
      notes text,
      cancelled_by uuid,
      cancelled_at timestamptz,
      cancelled_reason text,
      failure_reason text,
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE public.payments (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      booking_id uuid UNIQUE REFERENCES public.bookings(id),
      user_id uuid,
      lounge_id uuid REFERENCES public.lounges(id),
      amount numeric(10,2) CHECK (amount >= 0),
      discount_amount numeric(10,2) DEFAULT 0,
      discount_percentage numeric(5,2) DEFAULT 0,
      discount_reason text,
      discount_approved_by uuid,
      commission_rate numeric DEFAULT 0.15 CHECK (commission_rate BETWEEN 0 AND 1),
      commission numeric(10,2),
      net_to_lounge numeric(10,2),
      payment_method text,
      status text DEFAULT 'completed',
      payout_id uuid REFERENCES public.payouts(id),
      paid_at timestamptz DEFAULT now(),
      CONSTRAINT check_payment_amounts_valid CHECK (
        amount >= 0
        AND (discount_amount IS NULL OR (discount_amount >= 0 AND discount_amount <= amount))
      ),
      CONSTRAINT payments_payment_method_check CHECK (
        payment_method IN ('cash', 'manual_transfer', 'card', 'vodafone_cash', 'fawry', 'instapay', 'app_wallet')
      ),
      CONSTRAINT payments_status_check CHECK (
        status IN ('completed', 'refunded', 'pending', 'waiting_approval', 'cancelled')
      )
    );

    CREATE TABLE public.shift_payments (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      shift_id uuid NOT NULL REFERENCES public.shifts(id),
      lounge_id uuid NOT NULL REFERENCES public.lounges(id),
      booking_id uuid REFERENCES public.bookings(id),
      payment_method text NOT NULL,
      category text NOT NULL CHECK (category IN ('gaming_time', 'snacks', 'extra_controllers', 'other')),
      amount numeric(10,2) NOT NULL CHECK (amount >= 0),
      canteen_order_id uuid,
      paid_at timestamptz DEFAULT now()
    );

    CREATE TABLE public.shift_expenses (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      shift_id uuid NOT NULL REFERENCES public.shifts(id),
      lounge_id uuid NOT NULL REFERENCES public.lounges(id),
      amount numeric(10,2) NOT NULL CHECK (amount >= 0),
      reason text NOT NULL,
      expense_type text DEFAULT 'expense' CHECK (expense_type IN ('cash_drop', 'expense', 'other')),
      type text,
      created_by uuid,
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE public.notifications (
      user_id uuid,
      lounge_id uuid,
      title text,
      title_ar text,
      title_en text,
      body text,
      body_ar text,
      body_en text,
      type text,
      is_read boolean,
      metadata jsonb
    );

    CREATE TABLE public.audit_events (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      entity_type text NOT NULL,
      entity_id text NOT NULL,
      event_type text NOT NULL,
      booking_id uuid,
      actor_id uuid,
      severity text NOT NULL DEFAULT 'info',
      payload jsonb NOT NULL DEFAULT '{}'::jsonb,
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE OR REPLACE FUNCTION private.log_audit_event(
      p_entity_type text,
      p_entity_id text,
      p_event_type text,
      p_booking_id uuid DEFAULT NULL,
      p_actor_id uuid DEFAULT NULL,
      p_severity text DEFAULT 'info',
      p_payload jsonb DEFAULT '{}'::jsonb
    )
    RETURNS uuid
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
    DECLARE
      v_id uuid;
    BEGIN
      INSERT INTO public.audit_events(
        entity_type, entity_id, event_type, booking_id, actor_id, severity, payload
      )
      VALUES (
        p_entity_type, p_entity_id, p_event_type, p_booking_id, p_actor_id, COALESCE(p_severity, 'info'), COALESCE(p_payload, '{}'::jsonb)
      )
      RETURNING id INTO v_id;
      RETURN v_id;
    END;
    $$;

    CREATE OR REPLACE FUNCTION public.apply_booking_discount(
      p_booking_id uuid,
      p_discount_amount numeric,
      p_discount_percentage numeric,
      p_discount_reason text,
      p_approved_by uuid DEFAULT NULL
    )
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
    BEGIN
      UPDATE public.bookings
      SET total_price = round(total_price - COALESCE(p_discount_amount, 0), 2),
          discount_amount = COALESCE(p_discount_amount, 0),
          discount_percentage = COALESCE(p_discount_percentage, 0),
          discount_reason = p_discount_reason,
          discount_approved_by = COALESCE(p_approved_by, auth.uid())
      WHERE id = p_booking_id;
      RETURN jsonb_build_object('success', true);
    END;
    $$;

    CREATE OR REPLACE FUNCTION public.cancel_my_booking(
      p_booking_id uuid,
      p_reason text DEFAULT NULL
    )
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
    BEGIN
      UPDATE public.bookings
      SET status = 'cancelled'::public.booking_status,
          cancellation_reason = COALESCE(p_reason, 'Cancelled by customer'),
          cancelled_by = auth.uid(),
          cancelled_at = now(),
          updated_at = now()
      WHERE id = p_booking_id
        AND user_id = auth.uid();
      RETURN jsonb_build_object(
        'booking_id', p_booking_id,
        'status', 'cancelled',
        'policy_decision', private.booking_refund_policy_decision(p_booking_id)
      );
    END;
    $$;

    CREATE OR REPLACE FUNCTION public.enforce_payment_financials()
    RETURNS trigger
    LANGUAGE plpgsql
    SET search_path = ''
    AS $$
    BEGIN
      NEW.commission_rate := private.platform_commission_rate();
      NEW.commission := round(NEW.amount * NEW.commission_rate, 2);
      NEW.net_to_lounge := NEW.amount - NEW.commission;
      RETURN NEW;
    END;
    $$;

    CREATE TRIGGER finance
    BEFORE INSERT OR UPDATE ON public.payments
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_payment_financials();

    CREATE OR REPLACE FUNCTION public.prevent_closed_shift_transaction()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.shifts WHERE id = NEW.shift_id AND status = 'open') THEN
        RAISE EXCEPTION 'CLOSED_SHIFT' USING ERRCODE = '55000';
      END IF;
      RETURN NEW;
    END;
    $$;

    CREATE TRIGGER closed_shift_payment
    BEFORE INSERT ON public.shift_payments
    FOR EACH ROW
    EXECUTE FUNCTION public.prevent_closed_shift_transaction();

    CREATE TRIGGER closed_shift_expense
    BEFORE INSERT ON public.shift_expenses
    FOR EACH ROW
    EXECUTE FUNCTION public.prevent_closed_shift_transaction();

    GRANT USAGE ON SCHEMA public, auth, private TO authenticated, anon;
    GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated, anon;
  `);

  const sqlFile = async (rel) =>
    (await readFile(new URL(rel, import.meta.url), 'utf8')).replace(/\r\n/g, '\n');

  // Apply canonical prerequisites, payout custody, manual refund, and refund-aware payout reconciliation
  await db.exec(await sqlFile('../repairs/partial_cash_collection.sql'));
  await db.exec(await sqlFile('../migrations/20261011065428_payout_cash_commission_settlement.sql'));
  await installLatestFunctions(db, ['public.get_pending_payouts_overview', 'public.create_payout']);
  await db.exec(await sqlFile('../migrations/20261015192841_booking_legacy_cash_ledger_agreement.sql'));
  await db.exec(await sqlFile('../migrations/20261025101139_atomic_discount_cash_checkout.sql'));
  await db.exec(await sqlFile('../migrations/20261025225255_canonical_booking_collections.sql'));
  await db.exec(await sqlFile('../migrations/20261025225913_branch_booking_refund_policy.sql'));
  await db.exec(await sqlFile('../migrations/20261027150000_manual_refund_reversal_accounting.sql'));
  await db.exec(await sqlFile('../migrations/20261027180000_refund_aware_payout_reconciliation.sql'));

  // Seed actors, lounges, room, and shift
  await admin(`
    INSERT INTO auth.users(id) VALUES
      ('${superAdmin}'),
      ('${owner}'),
      ('${cashier}'),
      ('${customer}'),
      ('${outsider}');

    INSERT INTO public.profiles(id, role, lounge_id, is_active, is_banned) VALUES
      ('${superAdmin}', 'super_admin', NULL, true, false),
      ('${owner}', 'owner', '${lounge}', true, false),
      ('${cashier}', 'cashier', '${lounge}', true, false),
      ('${customer}', 'user', NULL, true, false),
      ('${outsider}', 'owner', '${foreignLounge}', true, false);

    INSERT INTO public.platform_super_admins(user_id) VALUES ('${superAdmin}');

    INSERT INTO public.lounges(
      id, name, name_ar, name_en, owner_id, allow_cash_payment,
      require_booking_deposit, booking_deposit_amount, deposit_refund_allowed, cancellation_window_hours
    ) VALUES
      ('${lounge}', 'PlaySpot Arena', 'بلاي سبوت أرينا', 'PlaySpot Arena', '${owner}', true, true, 50.00, true, 4),
      ('${foreignLounge}', 'Foreign Lounge', 'صالة أخرى', 'Foreign Lounge', '${outsider}', true, false, 0.00, false, 4);

    INSERT INTO public.rooms(id, lounge_id, status, is_available)
    VALUES ('${room}', '${lounge}', 'available', true);

    INSERT INTO public.shifts(id, lounge_id, cashier_id, staff_user_id, status, starting_cash)
    VALUES ('${shift}', '${lounge}', '${cashier}', '${cashier}', 'open', 500.00);

    INSERT INTO public.fixture_permissions(actor, lounge, permission) VALUES
      ('${cashier}', '${lounge}', 'billing_checkout'),
      ('${cashier}', '${lounge}', 'bookings_cancel');
  `);

  // =========================================================================
  // SCENARIO 1: Collection and refund before payout
  // - Platform collection (100.00 EGP -> +85.00 EGP) + partial refund before payout (-40.00 EGP -> -34.00 EGP)
  //   settles for exact net 51.00 EGP and links both movements in private.booking_movement_payout_entries.
  // - Pending unexecuted refund request (approved_pending_return) blocks create_payout (55000).
  // - Full refund before payout (-100.00 EGP) yields 0.00 net and NO_POSITIVE_SETTLEMENT_BALANCE.
  // =========================================================================
  await check('Scenario 1a: pending approved_pending_return refund request blocks create_payout until executed or cancelled', async () => {
    await resetLoungeFinancialState();
    const dep = await createPlatformVerifiedDepositBooking({
      totalPrice: 100.0,
      depositAmount: 100.0,
      verifiedDay: '2026-10-05',
    });

    await asActor(superAdmin);
    const req = (
      await db.query(
        `SELECT public.initiate_booking_refund($1, $2, $3, $4, $5) AS r`,
        [dep.bookingId, dep.movementId, 4000, 'Pending partial refund', randomUUID()]
      )
    ).rows[0].r;
    assert.equal(req.status, 'approved_pending_return');

    // Overview hides lounge when a pending refund request exists
    const overviewWhilePending = (await db.query(`SELECT * FROM public.get_pending_payouts_overview()`)).rows;
    assert.equal(overviewWhilePending.length, 0);

    // create_payout rejects while approved_pending_return exists
    await expectReject(
      'create_payout blocked by pending refund request',
      () => db.query(`SELECT public.create_payout($1, '2026-10-01', '2026-10-31')`, [lounge]),
      '55000',
      superAdmin
    );

    // Execute the 40.00 EGP partial refund -> net remaining is 60.00 EGP (commission 9.00, net_to_lounge 51.00)
    await asActor(superAdmin);
    const execRes = (
      await db.query(
        `SELECT public.execute_booking_refund($1, $2, $3, $4, $5) AS r`,
        [req.refund_request_id, 'instapay', 'REF-S1A-40', randomUUID(), null]
      )
    ).rows[0].r;

    await admin(`
      ALTER TABLE private.booking_money_movements DISABLE TRIGGER USER;
      UPDATE private.booking_money_movements
      SET verified_at = '2026-10-06 12:00:00+00'
      WHERE id = '${execRes.refund_movement_id}';
      ALTER TABLE private.booking_money_movements ENABLE TRIGGER USER;
    `);

    await asActor(superAdmin);
    const overviewAfterExec = (await db.query(`SELECT * FROM public.get_pending_payouts_overview()`)).rows;
    assert.equal(overviewAfterExec.length, 1);
    assert.equal(Number(overviewAfterExec[0].pending_amount), 51.0);
    assert.equal(Number(overviewAfterExec[0].total_transactions), 1);

    const payout = (
      await db.query(`SELECT public.create_payout($1, '2026-10-01', '2026-10-31') AS r`, [lounge])
    ).rows[0].r;
    assert.equal(payout.success, true);
    assert.equal(Number(payout.amount), 51.0);
    assert.equal(Number(payout.payment_count), 1);
    assert.equal(Number(payout.movement_count), 2);

    // Verify private.booking_movement_payout_entries allocated both the +8500 collection and -3400 refund
    const entries = (
      await admin(
        `
          SELECT bmpe.movement_id, bmpe.contribution_minor, m.movement_type, m.amount_minor
          FROM private.booking_movement_payout_entries bmpe
          JOIN private.booking_money_movements m ON m.id = bmpe.movement_id
          WHERE bmpe.payout_id = $1
          ORDER BY m.amount_minor DESC
        `,
        [payout.payout_id]
      )
    ).rows;
    assert.equal(entries.length, 2);
    assert.equal(entries[0].movement_type, 'collection');
    assert.equal(Number(entries[0].contribution_minor), 8500);
    assert.equal(entries[1].movement_type, 'refund');
    assert.equal(Number(entries[1].contribution_minor), -3400);

    // Verify get_payout_details reconciliation
    await asActor(superAdmin);
    const details = (await db.query(`SELECT public.get_payout_details($1) AS r`, [payout.payout_id])).rows[0].r;
    assert.equal(Number(details.reconciliation.calculated_net), 51.0);
    assert.equal(Number(details.reconciliation.difference), 0);
    assert.equal(Number(details.reconciliation.movement_count), 2);
    assert.equal(details.movement_entries.length, 2);
  });

  await check('Scenario 1b: full refund before payout yields zero net balance and NO_POSITIVE_SETTLEMENT_BALANCE', async () => {
    await resetLoungeFinancialState();
    const dep = await createPlatformVerifiedDepositBooking({
      totalPrice: 100.0,
      depositAmount: 100.0,
      verifiedDay: '2026-10-05',
    });

    await executeVerifiedRefund({
      bookingId: dep.bookingId,
      movementId: dep.movementId,
      amount: 100.0,
      fundsHolder: 'platform',
      refundMethod: 'instapay',
      verifiedDay: '2026-10-06',
    });

    await asActor(superAdmin);
    const overview = (await db.query(`SELECT * FROM public.get_pending_payouts_overview()`)).rows;
    assert.equal(overview.length, 0);

    const payout = (
      await db.query(`SELECT public.create_payout($1, '2026-10-01', '2026-10-31') AS r`, [lounge])
    ).rows[0].r;
    assert.equal(payout.success, false);
    assert.equal(payout.error, 'NO_POSITIVE_SETTLEMENT_BALANCE');
  });

  // =========================================================================
  // SCENARIO 2: Collection, completed payout ('paid'), then partial refund
  // - Period 1 (Oct): 100.00 EGP platform collection settled in Payout 1 (85.00 EGP).
  // - While Payout 1 is pending/approved/processing, refund initiation is blocked (55000).
  // - Once Payout 1 is completed ('paid'), a partial refund of 30.00 EGP (-25.50 EGP contribution) succeeds!
  // - Payout 1 remains 85.00 EGP ('paid') with immutable snapshot and details.
  // - Period 2 (Nov): New 100.00 EGP platform collection (+85.00 EGP) + post-payout refund (-25.50 EGP)
  //   settles in Payout 2 for 59.50 EGP without re-settling the original Oct collection!
  // =========================================================================
  await check('Scenario 2: completed paid payout allows post-payout partial refund, preserves historical paid payout, and carries -25.50 EGP into next period payout', async () => {
    await resetLoungeFinancialState();
    const octBooking = await createPlatformVerifiedDepositBooking({
      totalPrice: 100.0,
      depositAmount: 100.0,
      verifiedDay: '2026-10-10',
    });

    await asActor(superAdmin);
    const payout1 = (
      await db.query(`SELECT public.create_payout($1, '2026-10-01', '2026-10-31') AS r`, [lounge])
    ).rows[0].r;
    assert.equal(payout1.success, true);
    assert.equal(Number(payout1.amount), 85.0);

    // While Payout 1 is still pending (unpaid), initiating a refund on octBooking is blocked!
    await expectReject(
      'refund blocked while payout is pending',
      () =>
        db.query(
          `SELECT public.initiate_booking_refund($1, $2, $3, $4, $5)`,
          [octBooking.bookingId, octBooking.movementId, 3000, 'Attempt during pending payout', randomUUID()]
        ),
      '55000',
      superAdmin
    );

    // Approve -> processing -> complete Payout 1 ('paid')
    await asActor(superAdmin);
    await db.query(`SELECT public.approve_payout($1, 'Approved Oct payout')`, [payout1.payout_id]);
    await db.query(`SELECT public.start_payout_processing($1)`, [payout1.payout_id]);
    await db.query(
      `SELECT public.complete_payout($1, 'bank_transfer', 'BANK-OCT-001', 'https://receipts/oct1.pdf', 'Paid Oct')`,
      [payout1.payout_id]
    );

    // Now that Payout 1 is 'paid', initiate & execute a 30.00 EGP partial refund on octBooking in November!
    const postRefund = await executeVerifiedRefund({
      bookingId: octBooking.bookingId,
      movementId: octBooking.movementId,
      amount: 30.0,
      fundsHolder: 'platform',
      refundMethod: 'instapay',
      verifiedDay: '2026-11-05',
      reason: 'Post-payout partial refund',
    });

    // Historical Payout 1 must remain completely untouched (total_amount = 85.00, status = 'paid')
    await asActor(superAdmin);
    const details1 = (await db.query(`SELECT public.get_payout_details($1) AS r`, [payout1.payout_id])).rows[0].r;
    assert.equal(details1.payout.status, 'paid');
    assert.equal(Number(details1.payout.total_amount), 85.0);
    assert.equal(Number(details1.reconciliation.calculated_net), 85.0);
    assert.equal(Number(details1.reconciliation.difference), 0);
    assert.equal(Number(details1.reconciliation.movement_count), 1);

    // Add a November platform collection of 100.00 EGP (+85.00 EGP)
    const novBooking = await createPlatformVerifiedDepositBooking({
      totalPrice: 100.0,
      depositAmount: 100.0,
      verifiedDay: '2026-11-10',
    });

    // Pending payouts overview must show 85.00 - 25.50 = 59.50 EGP across 2 payments (oct refund + nov collection)
    await asActor(superAdmin);
    const overviewNov = (await db.query(`SELECT * FROM public.get_pending_payouts_overview()`)).rows;
    assert.equal(overviewNov.length, 1);
    assert.equal(Number(overviewNov[0].pending_amount), 59.5);
    assert.equal(Number(overviewNov[0].total_transactions), 2);

    // Create Payout 2 for November: settles novBooking (+85.00) and postRefund (-25.50) = 59.50 EGP!
    const payout2 = (
      await db.query(`SELECT public.create_payout($1, '2026-11-01', '2026-11-30') AS r`, [lounge])
    ).rows[0].r;
    assert.equal(payout2.success, true);
    assert.equal(Number(payout2.amount), 59.5);
    assert.equal(Number(payout2.payment_count), 2);
    assert.equal(Number(payout2.movement_count), 2);

    // Verify the original October collection movement was NOT settled a second time
    const octMovAllocations = (
      await admin(
        `SELECT count(*) AS c FROM private.booking_movement_payout_entries WHERE movement_id = $1`,
        [octBooking.movementId]
      )
    ).rows[0].c;
    assert.equal(Number(octMovAllocations), 1);

    // Verify Payout 2 contains only postRefund.reversalMovementId (-2550) and novBooking.movementId (+8500)
    const payout2Movs = (
      await admin(
        `
          SELECT movement_id, contribution_minor
          FROM private.booking_movement_payout_entries
          WHERE payout_id = $1
          ORDER BY contribution_minor ASC
        `,
        [payout2.payout_id]
      )
    ).rows;
    assert.equal(payout2Movs.length, 2);
    assert.equal(payout2Movs[0].movement_id, postRefund.reversalMovementId);
    assert.equal(Number(payout2Movs[0].contribution_minor), -2550);
    assert.equal(payout2Movs[1].movement_id, novBooking.movementId);
    assert.equal(Number(payout2Movs[1].contribution_minor), 8500);

    // Approve and complete Payout 2 as well, and verify Payout 1 is still intact
    await asActor(superAdmin);
    await db.query(`SELECT public.approve_payout($1, 'Approve Nov')`, [payout2.payout_id]);
    await db.query(`SELECT public.start_payout_processing($1)`, [payout2.payout_id]);
    await db.query(
      `SELECT public.complete_payout($1, 'bank_transfer', 'BANK-NOV-001', 'https://receipts/nov1.pdf', 'Paid Nov')`,
      [payout2.payout_id]
    );

    const details1After = (await db.query(`SELECT public.get_payout_details($1) AS r`, [payout1.payout_id])).rows[0].r;
    assert.equal(Number(details1After.reconciliation.calculated_net), 85.0);
    assert.equal(Number(details1After.reconciliation.difference), 0);

    const details2After = (await db.query(`SELECT public.get_payout_details($1) AS r`, [payout2.payout_id])).rows[0].r;
    assert.equal(Number(details2After.reconciliation.calculated_net), 59.5);
    assert.equal(Number(details2After.reconciliation.difference), 0);
  });

  // =========================================================================
  // SCENARIO 3: Multiple partial refunds followed by full refund + Commission reversal & rounding
  // - 100.00 EGP collection (10000 minor, commission 1500, net 8500) settled in Payout A (85.00 EGP, 'paid').
  // - Post-payout: three partial refunds of 33.33 EGP (3333 minor), 33.33 EGP (3333 minor),
  //   and 33.34 EGP (3334 minor) bring the booking to 0.00 EGP (payments.status = 'refunded', amount = 0).
  // - Commission reversed across the 3 movements: -500 + -500 + -500 = -1500 minor (zero rounding drift!).
  // - Net contribution across the 3 movements: -2833 + -2833 + -2834 = -8500 minor (-85.00 EGP).
  // - Even though payments.status = 'refunded' and payments.amount = 0, Payout B picks up all 3 refund
  //   movements (-85.00 EGP) alongside a 200.00 EGP (+170.00 EGP) collection and settles for 85.00 EGP!
  // =========================================================================
  await check('Scenario 3: multiple partial refunds to full refund after payout preserve exact commission rounding and settle -85.00 EGP even when payment status is refunded', async () => {
    await resetLoungeFinancialState();
    const b1 = await createPlatformVerifiedDepositBooking({
      totalPrice: 100.0,
      depositAmount: 100.0,
      verifiedDay: '2026-10-10',
    });

    await asActor(superAdmin);
    const payoutA = (
      await db.query(`SELECT public.create_payout($1, '2026-10-01', '2026-10-31') AS r`, [lounge])
    ).rows[0].r;
    assert.equal(Number(payoutA.amount), 85.0);
    await db.query(`SELECT public.approve_payout($1)`, [payoutA.payout_id]);
    await db.query(`SELECT public.start_payout_processing($1)`, [payoutA.payout_id]);
    await db.query(`SELECT public.complete_payout($1, 'bank_transfer', 'BANK-OCT-A')`, [payoutA.payout_id]);

    // Execute 3 partial refunds: 33.33, 33.33, 33.34 -> total 100.00 EGP
    const r1 = await executeVerifiedRefund({
      bookingId: b1.bookingId,
      movementId: b1.movementId,
      amount: 33.33,
      fundsHolder: 'platform',
      refundMethod: 'instapay',
      verifiedDay: '2026-11-02',
    });
    const r2 = await executeVerifiedRefund({
      bookingId: b1.bookingId,
      movementId: b1.movementId,
      amount: 33.33,
      fundsHolder: 'platform',
      refundMethod: 'instapay',
      verifiedDay: '2026-11-03',
    });
    const r3 = await executeVerifiedRefund({
      bookingId: b1.bookingId,
      movementId: b1.movementId,
      amount: 33.34,
      fundsHolder: 'platform',
      refundMethod: 'instapay',
      verifiedDay: '2026-11-04',
    });

    // Verify exact minor-unit commission & net reversal across all 3 refunds (zero rounding drift)
    const refundMovs = (
      await admin(
        `
          SELECT amount_minor, commission_minor, net_to_lounge_minor
          FROM private.booking_money_movements
          WHERE id IN ($1, $2, $3)
          ORDER BY verified_at ASC
        `,
        [r1.reversalMovementId, r2.reversalMovementId, r3.reversalMovementId]
      )
    ).rows;
    assert.deepEqual(
      refundMovs.map((m) => ({
        amount_minor: Number(m.amount_minor),
        commission_minor: Number(m.commission_minor),
        net_to_lounge_minor: Number(m.net_to_lounge_minor),
      })),
      [
        {amount_minor: -3333, commission_minor: -500, net_to_lounge_minor: -2833},
        {amount_minor: -3333, commission_minor: -500, net_to_lounge_minor: -2833},
        {amount_minor: -3334, commission_minor: -500, net_to_lounge_minor: -2834},
      ]
    );

    // Confirm payment row is now status='refunded' and amount=0.00
    const payRow = (await admin(`SELECT status, amount, commission, net_to_lounge FROM public.payments WHERE id = $1`, [b1.paymentId])).rows[0];
    assert.equal(payRow.status, 'refunded');
    assert.equal(Number(payRow.amount), 0);
    assert.equal(Number(payRow.commission), 0);
    assert.equal(Number(payRow.net_to_lounge), 0);

    // Add a 200.00 EGP platform collection in November (+170.00 EGP net_to_lounge)
    await createPlatformVerifiedDepositBooking({
      totalPrice: 200.0,
      depositAmount: 200.0,
      verifiedDay: '2026-11-12',
    });

    // Create Payout B in November: +170.00 - 85.00 = 85.00 EGP across 4 movements (3 refunds + 1 collection)
    await asActor(superAdmin);
    const payoutB = (
      await db.query(`SELECT public.create_payout($1, '2026-11-01', '2026-11-30') AS r`, [lounge])
    ).rows[0].r;
    assert.equal(payoutB.success, true);
    assert.equal(Number(payoutB.amount), 85.0);
    assert.equal(Number(payoutB.payment_count), 2);
    assert.equal(Number(payoutB.movement_count), 4);

    await db.query(`SELECT public.approve_payout($1)`, [payoutB.payout_id]);
    await db.query(`SELECT public.start_payout_processing($1)`, [payoutB.payout_id]);
    await db.query(`SELECT public.complete_payout($1, 'bank_transfer', 'BANK-NOV-B')`, [payoutB.payout_id]);
  });

  // =========================================================================
  // SCENARIO 4: Mixed lounge/platform custody on the same booking
  // - Booking total 100.00 EGP:
  //   * 20.00 EGP deposit verified to platform (+17.00 EGP net_to_lounge owed to lounge)
  //   * 80.00 EGP remaining cash collected at lounge checkout (-12.00 EGP commission owed to platform)
  //   * 30.00 EGP partial cash refund returned from lounge drawer (+4.50 EGP commission reversal credit)
  // - Net payout contribution for this single mixed-custody booking:
  //   +17.00 - 12.00 + 4.50 = +9.50 EGP (950 minor)
  // =========================================================================
  await check('Scenario 4: mixed lounge and platform custody on a single booking reconciles +17.00 platform deposit, -12.00 lounge cash commission, and +4.50 lounge refund commission credit = 9.50 EGP', async () => {
    await resetLoungeFinancialState();
    const dep = await createPlatformVerifiedDepositBooking({
      totalPrice: 100.0,
      depositAmount: 20.0,
      method: 'instapay',
      verifiedDay: '2026-10-10',
      completedBooking: false,
    });

    // Complete remaining 80.00 EGP in cash at the lounge
    await admin(`UPDATE public.bookings SET status = 'completed' WHERE id = $1`, [dep.bookingId]);
    await asActor(cashier);
    await db.query(
      `SELECT public.checkout_booking_cash_atomic($1, $2, $3, $4)`,
      [dep.bookingId, shift, 8000, randomUUID()]
    );

    const cashMov = (
      await admin(
        `
          SELECT id
          FROM private.booking_money_movements
          WHERE booking_id = $1 AND collection_purpose = 'settlement'
        `,
        [dep.bookingId]
      )
    ).rows[0];

    await admin(`
      ALTER TABLE private.booking_money_movements DISABLE TRIGGER USER;
      UPDATE private.booking_money_movements
      SET verified_at = '2026-10-11 12:00:00+00'
      WHERE id = '${cashMov.id}';
      ALTER TABLE private.booking_money_movements ENABLE TRIGGER USER;
    `);

    // Partial refund of 30.00 EGP from the lounge-held cash movement
    await executeVerifiedRefund({
      bookingId: dep.bookingId,
      movementId: cashMov.id,
      amount: 30.0,
      fundsHolder: 'lounge',
      refundMethod: 'cash',
      shiftId: shift,
      verifiedDay: '2026-10-12',
    });

    await asActor(superAdmin);
    const overview = (await db.query(`SELECT * FROM public.get_pending_payouts_overview()`)).rows;
    assert.equal(overview.length, 1);
    assert.equal(Number(overview[0].pending_amount), 9.5);
    assert.equal(Number(overview[0].total_transactions), 1);

    const payout = (
      await db.query(`SELECT public.create_payout($1, '2026-10-01', '2026-10-31') AS r`, [lounge])
    ).rows[0].r;
    assert.equal(payout.success, true);
    assert.equal(Number(payout.amount), 9.5);
    assert.equal(Number(payout.payment_count), 1);
    assert.equal(Number(payout.movement_count), 3);

    const details = (await db.query(`SELECT public.get_payout_details($1) AS r`, [payout.payout_id])).rows[0].r;
    assert.equal(Number(details.reconciliation.calculated_net), 9.5);
    assert.equal(Number(details.reconciliation.difference), 0);
    assert.equal(details.payments[0].payment_method, 'mixed');
    assert.equal(Number(details.payments[0].amount), 70.0);
    assert.equal(Number(details.payments[0].commission), 10.5);
    assert.equal(Number(details.payments[0].net_to_lounge), 59.5);
    assert.equal(Number(details.payments[0].contribution), 9.5);
  });

  // =========================================================================
  // SCENARIO 5: Lounge-held cash collection settled in Payout 1, then post-payout cash refund
  // credits reversed commission (+15.00 EGP) in Payout 2
  // =========================================================================
  await check('Scenario 5: post-payout refund of lounge-held cash collection credits reversed commission (+15.00 EGP) in the next payout period', async () => {
    await resetLoungeFinancialState();
    // Oct: 100.00 EGP lounge cash (-15.00 commission) + 100.00 EGP platform deposit (+85.00) = 70.00 EGP Payout 1
    const octCash = await createLoungeCashCheckoutBooking({
      totalPrice: 100.0,
      verifiedDay: '2026-10-08',
    });
    await createPlatformVerifiedDepositBooking({
      totalPrice: 100.0,
      depositAmount: 100.0,
      verifiedDay: '2026-10-09',
    });

    await asActor(superAdmin);
    const payout1 = (
      await db.query(`SELECT public.create_payout($1, '2026-10-01', '2026-10-31') AS r`, [lounge])
    ).rows[0].r;
    assert.equal(Number(payout1.amount), 70.0);
    await db.query(`SELECT public.approve_payout($1)`, [payout1.payout_id]);
    await db.query(`SELECT public.start_payout_processing($1)`, [payout1.payout_id]);
    await db.query(`SELECT public.complete_payout($1, 'bank_transfer', 'BANK-S5-1')`, [payout1.payout_id]);

    // Nov: Full 100.00 EGP cash refund of octCash from the lounge shift -> +15.00 EGP commission credit owed back to lounge!
    await executeVerifiedRefund({
      bookingId: octCash.bookingId,
      movementId: octCash.movementId,
      amount: 100.0,
      fundsHolder: 'lounge',
      refundMethod: 'cash',
      shiftId: shift,
      verifiedDay: '2026-11-05',
    });

    await asActor(superAdmin);
    const overviewNov = (await db.query(`SELECT * FROM public.get_pending_payouts_overview()`)).rows;
    assert.equal(overviewNov.length, 1);
    assert.equal(Number(overviewNov[0].pending_amount), 15.0);

    const payout2 = (
      await db.query(`SELECT public.create_payout($1, '2026-11-01', '2026-11-30') AS r`, [lounge])
    ).rows[0].r;
    assert.equal(payout2.success, true);
    assert.equal(Number(payout2.amount), 15.0);
    assert.equal(Number(payout2.movement_count), 1);
  });

  // =========================================================================
  // SCENARIO 6: Cancelling, failing, or review-cancelling an in-flight payout
  // restores prior 'paid' payout_id on post-payout refunded payments, releases
  // new payments to NULL, marks movements unsettled, preserves historical paid
  // payouts, and allows clean re-settlement
  // =========================================================================
  await check('Scenario 6a: cancel_payout restores prior paid payout_id on post-payout refunded payments, marks movements unsettled, and allows clean re-settlement', async () => {
    await resetLoungeFinancialState();
    const octDep = await createPlatformVerifiedDepositBooking({
      totalPrice: 100.0,
      depositAmount: 100.0,
      verifiedDay: '2026-10-10',
    });

    await asActor(superAdmin);
    const p1 = (
      await db.query(`SELECT public.create_payout($1, '2026-10-01', '2026-10-31') AS r`, [lounge])
    ).rows[0].r;
    await db.query(`SELECT public.approve_payout($1)`, [p1.payout_id]);
    await db.query(`SELECT public.start_payout_processing($1)`, [p1.payout_id]);
    await db.query(`SELECT public.complete_payout($1, 'bank_transfer', 'BANK-S6-1')`, [p1.payout_id]);

    // Post-payout partial refund of 20.00 EGP (-17.00 EGP) + new Nov booking of 100.00 EGP (+85.00 EGP) = 68.00 EGP
    const octRef = await executeVerifiedRefund({
      bookingId: octDep.bookingId,
      movementId: octDep.movementId,
      amount: 20.0,
      fundsHolder: 'platform',
      refundMethod: 'instapay',
      verifiedDay: '2026-11-05',
    });
    const novDep = await createPlatformVerifiedDepositBooking({
      totalPrice: 100.0,
      depositAmount: 100.0,
      verifiedDay: '2026-11-10',
    });

    await asActor(superAdmin);
    const p2 = (
      await db.query(`SELECT public.create_payout($1, '2026-11-01', '2026-11-30') AS r`, [lounge])
    ).rows[0].r;
    assert.equal(Number(p2.amount), 68.0);

    // Cancel p2 -> octDep.paymentId must revert to p1.payout_id, and novDep.paymentId must revert to NULL!
    const cancelRes = (await db.query(`SELECT public.cancel_payout($1, 'Cancel test') AS r`, [p2.payout_id])).rows[0].r;
    assert.equal(cancelRes.status, 'cancelled');

    const octPayAfterCancel = (await admin(`SELECT payout_id FROM public.payments WHERE id = $1`, [octDep.paymentId])).rows[0];
    const novPayAfterCancel = (await admin(`SELECT payout_id FROM public.payments WHERE id = $1`, [novDep.paymentId])).rows[0];
    assert.equal(octPayAfterCancel.payout_id, p1.payout_id);
    assert.equal(novPayAfterCancel.payout_id, null);

    // Verify movement settlement state reverted to is_settled = false for the cancelled payout's movements,
    // while octDep.movementId remains is_settled = true from p1
    const movStates = (
      await admin(
        `
          SELECT movement_id, is_settled
          FROM private.movement_settlement_values
          WHERE movement_id IN ($1, $2, $3)
        `,
        [octDep.movementId, octRef.reversalMovementId, novDep.movementId]
      )
    ).rows;
    const stateMap = new Map(movStates.map((r) => [r.movement_id, r.is_settled]));
    assert.equal(stateMap.get(octDep.movementId), true);
    assert.equal(stateMap.get(octRef.reversalMovementId), false);
    assert.equal(stateMap.get(novDep.movementId), false);

    // Re-create November payout -> succeeds with the exact same 68.00 EGP balance!
    await asActor(superAdmin);
    const p3 = (
      await db.query(`SELECT public.create_payout($1, '2026-11-01', '2026-11-30') AS r`, [lounge])
    ).rows[0].r;
    assert.equal(p3.success, true);
    assert.equal(Number(p3.amount), 68.0);
    assert.equal(Number(p3.movement_count), 2);
  });

  await check('Scenario 6b: fail_payout restores prior paid payout_id, releases new payments to NULL, marks movements unsettled, preserves historical paid payout, and allows replacement payout', async () => {
    await resetLoungeFinancialState();
    const octDep = await createPlatformVerifiedDepositBooking({
      totalPrice: 100.0,
      depositAmount: 100.0,
      verifiedDay: '2026-10-10',
    });

    await asActor(superAdmin);
    const p1 = (
      await db.query(`SELECT public.create_payout($1, '2026-10-01', '2026-10-31') AS r`, [lounge])
    ).rows[0].r;
    await db.query(`SELECT public.approve_payout($1)`, [p1.payout_id]);
    await db.query(`SELECT public.start_payout_processing($1)`, [p1.payout_id]);
    await db.query(`SELECT public.complete_payout($1, 'bank_transfer', 'BANK-S6B-1')`, [p1.payout_id]);

    const octRef = await executeVerifiedRefund({
      bookingId: octDep.bookingId,
      movementId: octDep.movementId,
      amount: 20.0,
      fundsHolder: 'platform',
      refundMethod: 'instapay',
      verifiedDay: '2026-11-05',
    });
    const novDep = await createPlatformVerifiedDepositBooking({
      totalPrice: 100.0,
      depositAmount: 100.0,
      verifiedDay: '2026-11-10',
    });

    await asActor(superAdmin);
    const p2 = (
      await db.query(`SELECT public.create_payout($1, '2026-11-01', '2026-11-30') AS r`, [lounge])
    ).rows[0].r;
    assert.equal(Number(p2.amount), 68.0);

    // fail_payout rejects while payout is still 'pending' (must be 'approved' or 'processing')
    await expectReject(
      'fail_payout rejected while payout status is pending',
      () => db.query(`SELECT public.fail_payout($1, 'Premature failure')`, [p2.payout_id]),
      'P0001',
      superAdmin
    );

    // Advance p2 to 'approved' -> 'processing', then fail it
    await asActor(superAdmin);
    await db.query(`SELECT public.approve_payout($1, 'Approved for bank transfer')`, [p2.payout_id]);
    await db.query(`SELECT public.start_payout_processing($1)`, [p2.payout_id]);

    const failRes = (
      await db.query(`SELECT public.fail_payout($1, 'Bank transfer rejected by beneficiary bank') AS r`, [p2.payout_id])
    ).rows[0].r;
    assert.equal(failRes.success, true);
    assert.equal(failRes.status, 'failed');

    const failedPayoutRow = (
      await admin(`SELECT status, failure_reason FROM public.payouts WHERE id = $1`, [p2.payout_id])
    ).rows[0];
    assert.equal(failedPayoutRow.status, 'failed');
    assert.equal(failedPayoutRow.failure_reason, 'Bank transfer rejected by beneficiary bank');

    // Verify payment links restored: octDep -> p1.payout_id ('paid'), novDep -> NULL
    const octPayAfterFail = (await admin(`SELECT payout_id FROM public.payments WHERE id = $1`, [octDep.paymentId])).rows[0];
    const novPayAfterFail = (await admin(`SELECT payout_id FROM public.payments WHERE id = $1`, [novDep.paymentId])).rows[0];
    assert.equal(octPayAfterFail.payout_id, p1.payout_id);
    assert.equal(novPayAfterFail.payout_id, null);

    // Verify movement settlement states after fail_payout
    const movStates = (
      await admin(
        `
          SELECT movement_id, is_settled
          FROM private.movement_settlement_values
          WHERE movement_id IN ($1, $2, $3)
        `,
        [octDep.movementId, octRef.reversalMovementId, novDep.movementId]
      )
    ).rows;
    const stateMap = new Map(movStates.map((r) => [r.movement_id, r.is_settled]));
    assert.equal(stateMap.get(octDep.movementId), true);
    assert.equal(stateMap.get(octRef.reversalMovementId), false);
    assert.equal(stateMap.get(novDep.movementId), false);

    // Historical paid payout p1 remains completely immutable
    await asActor(superAdmin);
    const details1 = (await db.query(`SELECT public.get_payout_details($1) AS r`, [p1.payout_id])).rows[0].r;
    assert.equal(details1.payout.status, 'paid');
    assert.equal(Number(details1.payout.total_amount), 85.0);
    assert.equal(Number(details1.reconciliation.calculated_net), 85.0);
    assert.equal(Number(details1.reconciliation.difference), 0);

    // Replacement November payout p3 succeeds and completes to 'paid'
    const p3 = (
      await db.query(`SELECT public.create_payout($1, '2026-11-01', '2026-11-30') AS r`, [lounge])
    ).rows[0].r;
    assert.equal(p3.success, true);
    assert.equal(Number(p3.amount), 68.0);
    assert.equal(Number(p3.payment_count), 2);
    assert.equal(Number(p3.movement_count), 2);

    await db.query(`SELECT public.approve_payout($1)`, [p3.payout_id]);
    await db.query(`SELECT public.start_payout_processing($1)`, [p3.payout_id]);
    await db.query(`SELECT public.complete_payout($1, 'bank_transfer', 'BANK-S6B-3')`, [p3.payout_id]);
  });

  await check('Scenario 6c: resolve_payout_review supports approve and cancel, restores prior paid payout_id on cancel, notifies owner, and allows clean re-settlement', async () => {
    await resetLoungeFinancialState();
    await admin(`DELETE FROM public.notifications WHERE lounge_id = $1`, [lounge]);

    const octDep = await createPlatformVerifiedDepositBooking({
      totalPrice: 100.0,
      depositAmount: 100.0,
      verifiedDay: '2026-10-10',
    });

    await asActor(superAdmin);
    const p1 = (
      await db.query(`SELECT public.create_payout($1, '2026-10-01', '2026-10-31') AS r`, [lounge])
    ).rows[0].r;
    await db.query(`SELECT public.approve_payout($1)`, [p1.payout_id]);
    await db.query(`SELECT public.start_payout_processing($1)`, [p1.payout_id]);
    await db.query(`SELECT public.complete_payout($1, 'bank_transfer', 'BANK-S6C-1')`, [p1.payout_id]);

    const octRef = await executeVerifiedRefund({
      bookingId: octDep.bookingId,
      movementId: octDep.movementId,
      amount: 20.0,
      fundsHolder: 'platform',
      refundMethod: 'instapay',
      verifiedDay: '2026-11-05',
    });
    const novDep = await createPlatformVerifiedDepositBooking({
      totalPrice: 100.0,
      depositAmount: 100.0,
      verifiedDay: '2026-11-10',
    });

    await asActor(superAdmin);
    const p2 = (
      await db.query(`SELECT public.create_payout($1, '2026-11-01', '2026-11-30') AS r`, [lounge])
    ).rows[0].r;
    assert.equal(Number(p2.amount), 68.0);

    // Calling resolve_payout_review when status is 'pending' (not 'needs_review') rejects
    await expectReject(
      'resolve_payout_review rejected when status is not needs_review',
      () => db.query(`SELECT public.resolve_payout_review($1, 'approve', 'Not in review')`, [p2.payout_id]),
      'P0001',
      superAdmin
    );

    await admin(`UPDATE public.payouts SET status = 'needs_review' WHERE id = $1`, [p2.payout_id]);

    // Invalid resolution or blank reason rejects
    await expectReject(
      'resolve_payout_review rejected on invalid resolution',
      () => db.query(`SELECT public.resolve_payout_review($1, 'hold', 'Invalid action')`, [p2.payout_id]),
      'P0001',
      superAdmin
    );
    await expectReject(
      'resolve_payout_review rejected on blank reason',
      () => db.query(`SELECT public.resolve_payout_review($1, 'approve', '   ')`, [p2.payout_id]),
      'P0001',
      superAdmin
    );

    // 1. resolve_payout_review('approve') returns status to 'pending' and keeps payments linked
    await asActor(superAdmin);
    const approveReviewRes = (
      await db.query(
        `SELECT public.resolve_payout_review($1, 'approve', 'Verified bank account details') AS r`,
        [p2.payout_id]
      )
    ).rows[0].r;
    assert.equal(approveReviewRes.success, true);
    assert.equal(approveReviewRes.status, 'pending');

    const p2AfterApproveReview = (
      await admin(`SELECT status, notes FROM public.payouts WHERE id = $1`, [p2.payout_id])
    ).rows[0];
    assert.equal(p2AfterApproveReview.status, 'pending');
    assert.ok(p2AfterApproveReview.notes.includes('Review resolved: Verified bank account details'));

    // 2. Put p2 back into 'needs_review' and resolve with 'cancel'
    await admin(`UPDATE public.payouts SET status = 'needs_review' WHERE id = $1`, [p2.payout_id]);

    await asActor(superAdmin);
    const cancelReviewRes = (
      await db.query(
        `SELECT public.resolve_payout_review($1, 'cancel', 'Beneficiary IBAN mismatch') AS r`,
        [p2.payout_id]
      )
    ).rows[0].r;
    assert.equal(cancelReviewRes.success, true);
    assert.equal(cancelReviewRes.status, 'cancelled');

    const p2AfterCancelReview = (
      await admin(`SELECT status, cancelled_reason, cancelled_by FROM public.payouts WHERE id = $1`, [p2.payout_id])
    ).rows[0];
    assert.equal(p2AfterCancelReview.status, 'cancelled');
    assert.equal(p2AfterCancelReview.cancelled_reason, 'Beneficiary IBAN mismatch');
    assert.equal(p2AfterCancelReview.cancelled_by, superAdmin);

    // Verify payment links restored: octDep -> p1.payout_id ('paid'), novDep -> NULL
    const octPayAfterReviewCancel = (await admin(`SELECT payout_id FROM public.payments WHERE id = $1`, [octDep.paymentId])).rows[0];
    const novPayAfterReviewCancel = (await admin(`SELECT payout_id FROM public.payments WHERE id = $1`, [novDep.paymentId])).rows[0];
    assert.equal(octPayAfterReviewCancel.payout_id, p1.payout_id);
    assert.equal(novPayAfterReviewCancel.payout_id, null);

    // Verify movement settlement states after review cancel
    const movStates = (
      await admin(
        `
          SELECT movement_id, is_settled
          FROM private.movement_settlement_values
          WHERE movement_id IN ($1, $2, $3)
        `,
        [octDep.movementId, octRef.reversalMovementId, novDep.movementId]
      )
    ).rows;
    const stateMap = new Map(movStates.map((r) => [r.movement_id, r.is_settled]));
    assert.equal(stateMap.get(octDep.movementId), true);
    assert.equal(stateMap.get(octRef.reversalMovementId), false);
    assert.equal(stateMap.get(novDep.movementId), false);

    // Verify owner notification was emitted with exact metadata
    const notifs = (
      await admin(
        `SELECT user_id, lounge_id, type, metadata FROM public.notifications WHERE lounge_id = $1 AND type = 'payout'`,
        [lounge]
      )
    ).rows;
    assert.equal(notifs.length, 1);
    assert.equal(notifs[0].user_id, owner);
    assert.equal(notifs[0].metadata.payout_id, p2.payout_id);
    assert.equal(notifs[0].metadata.reason, 'Beneficiary IBAN mismatch');
    assert.equal(Number(notifs[0].metadata.amount), 68.0);

    // Historical paid payout p1 remains untouched
    await asActor(superAdmin);
    const details1 = (await db.query(`SELECT public.get_payout_details($1) AS r`, [p1.payout_id])).rows[0].r;
    assert.equal(details1.payout.status, 'paid');
    assert.equal(Number(details1.payout.total_amount), 85.0);
    assert.equal(Number(details1.reconciliation.difference), 0);

    // Re-create November payout p3 -> succeeds with 68.00 EGP
    const p3 = (
      await db.query(`SELECT public.create_payout($1, '2026-11-01', '2026-11-30') AS r`, [lounge])
    ).rows[0].r;
    assert.equal(p3.success, true);
    assert.equal(Number(p3.amount), 68.0);
    assert.equal(Number(p3.movement_count), 2);
  });

  // =========================================================================
  // SCENARIO 7: Duplicate and concurrent payout attempts
  // =========================================================================
  await check('Scenario 7a: overlapping active payout period is rejected and never settles movements twice', async () => {
    await resetLoungeFinancialState();
    await createPlatformVerifiedDepositBooking({
      totalPrice: 100.0,
      depositAmount: 100.0,
      verifiedDay: '2026-10-15',
    });

    await asActor(superAdmin);
    const p1 = (
      await db.query(`SELECT public.create_payout($1, '2026-10-01', '2026-10-31') AS r`, [lounge])
    ).rows[0].r;
    assert.equal(p1.success, true);
    assert.equal(Number(p1.amount), 85.0);

    await expectReject(
      'overlapping payout period rejected with 55000',
      () => db.query(`SELECT public.create_payout($1, '2026-10-15', '2026-11-15')`, [lounge]),
      '55000',
      superAdmin
    );

    // Non-overlapping later period with no new movements returns NO_POSITIVE_SETTLEMENT_BALANCE
    const p2 = (
      await db.query(`SELECT public.create_payout($1, '2026-11-01', '2026-11-30') AS r`, [lounge])
    ).rows[0].r;
    assert.equal(p2.success, false);
    assert.equal(p2.error, 'NO_POSITIVE_SETTLEMENT_BALANCE');
  });

  // =========================================================================
  // SCENARIO 8: Reconciliation across 3 payout periods when Period 2 has net negative balance
  // - Period 1 (Sep): 100.00 EGP platform deposit (+85.00 EGP) -> Payout 1 ('paid', 85.00 EGP).
  // - Period 2 (Oct): 80.00 EGP post-payout refund (-68.00 EGP) + 40.00 EGP new collection (+34.00 EGP)
  //   -> net -34.00 EGP -> Oct create_payout returns NO_POSITIVE_SETTLEMENT_BALANCE and retains both movements.
  // - Period 3 (Nov): 100.00 EGP new platform deposit (+85.00 EGP)
  //   -> Nov create_payout ('2026-11-01'..'2026-11-30') carries forward BOTH Oct's unsettled -68.00 EGP refund
  //      and Oct's unsettled +34.00 EGP collection alongside Nov's +85.00 EGP collection = 51.00 EGP!
  // =========================================================================
  await check('Scenario 8: negative net balance in Period 2 (post-payout refund exceeds new collection) blocks Period 2 payout and carries both unsettled Period 2 movements into Period 3', async () => {
    await resetLoungeFinancialState();
    // Period 1 (Sep): 100.00 EGP platform deposit -> Payout 1 = 85.00 EGP ('paid')
    const sepDep = await createPlatformVerifiedDepositBooking({
      totalPrice: 200.0,
      depositAmount: 100.0,
      verifiedDay: '2026-09-10',
    });

    await asActor(superAdmin);
    const pSep = (
      await db.query(`SELECT public.create_payout($1, '2026-09-01', '2026-09-30') AS r`, [lounge])
    ).rows[0].r;
    assert.equal(Number(pSep.amount), 85.0);
    await db.query(`SELECT public.approve_payout($1)`, [pSep.payout_id]);
    await db.query(`SELECT public.start_payout_processing($1)`, [pSep.payout_id]);
    await db.query(`SELECT public.complete_payout($1, 'bank_transfer', 'BANK-SEP-1')`, [pSep.payout_id]);

    // Period 2 (Oct): 80.00 EGP refund on sepDep (-68.00 EGP) + 40.00 EGP new platform deposit (+34.00 EGP) = -34.00 EGP
    await executeVerifiedRefund({
      bookingId: sepDep.bookingId,
      movementId: sepDep.movementId,
      amount: 80.0,
      fundsHolder: 'platform',
      refundMethod: 'instapay',
      verifiedDay: '2026-10-10',
    });
    await createPlatformVerifiedDepositBooking({
      totalPrice: 100.0,
      depositAmount: 40.0,
      verifiedDay: '2026-10-15',
    });

    await asActor(superAdmin);
    const pOct = (
      await db.query(`SELECT public.create_payout($1, '2026-10-01', '2026-10-31') AS r`, [lounge])
    ).rows[0].r;
    assert.equal(pOct.success, false);
    assert.equal(pOct.error, 'NO_POSITIVE_SETTLEMENT_BALANCE');

    // Period 3 (Nov): 100.00 EGP new platform deposit (+85.00 EGP).
    // Calling create_payout for the strict November period ('2026-11-01'..'2026-11-30')
    // carries forward Oct's unsettled +34.00 EGP and -68.00 EGP plus Nov's +85.00 EGP = 51.00 EGP!
    await createPlatformVerifiedDepositBooking({
      totalPrice: 200.0,
      depositAmount: 100.0,
      verifiedDay: '2026-11-10',
    });

    await asActor(superAdmin);
    const pNov = (
      await db.query(`SELECT public.create_payout($1, '2026-11-01', '2026-11-30') AS r`, [lounge])
    ).rows[0].r;
    assert.equal(pNov.success, true);
    assert.equal(Number(pNov.amount), 51.0);
    assert.equal(Number(pNov.movement_count), 3);
  });

  // =========================================================================
  // SCENARIO 9: Authorization & assert_payout_settlement drift detection
  // =========================================================================
  await check('Scenario 9a: non-super-admin cannot verify platform deposit or call payout RPCs', async () => {
    await resetLoungeFinancialState();
    const bId = randomUUID();
    await admin(
      `
        INSERT INTO public.bookings(
          id, user_id, lounge_id, room_id, status, confirmation_status,
          total_price, payment_status, payment_method,
          deposit_required, deposit_amount, deposit_paid, receipt_url
        )
        VALUES (
          $1, $2, $3, $4, 'upcoming', 'confirmed',
          100.00, 'unpaid', 'instapay',
          true, 50.00, false, 'booking_receipts/proof.jpg'
        )
      `,
      [bId, customer, lounge, room]
    );

    // Owner/cashier cannot verify deposit as 'platform'
    await expectReject(
      'lounge owner rejected from verifying platform-held deposit',
      () =>
        db.query(
          `SELECT public.verify_booking_deposit_transfer($1, $2, $3, 'REF-PLAT', 'platform')`,
          [bId, shift, randomUUID()]
        ),
      '42501',
      owner
    );

    // Owner/cashier cannot call create_payout or get_pending_payouts_overview
    await expectReject(
      'lounge owner rejected from create_payout',
      () => db.query(`SELECT public.create_payout($1, '2026-10-01', '2026-10-31')`, [lounge]),
      '42501',
      owner
    );
    await expectReject(
      'cashier rejected from get_pending_payouts_overview',
      () => db.query(`SELECT * FROM public.get_pending_payouts_overview()`),
      '42501',
      cashier
    );
  });

  await check('Scenario 9b: assert_payout_settlement blocks approve_payout, resolve_payout_review(approve), start_payout_processing, and complete_payout when payment financials, payout_id link, pending refund requests, or unsettled movements drift', async () => {
    await resetLoungeFinancialState();
    const dep = await createPlatformVerifiedDepositBooking({
      totalPrice: 100.0,
      depositAmount: 100.0,
      verifiedDay: '2026-10-10',
    });

    await asActor(superAdmin);
    const pDrift = (
      await db.query(`SELECT public.create_payout($1, '2026-10-01', '2026-10-31') AS r`, [lounge])
    ).rows[0].r;
    assert.equal(pDrift.success, true);
    assert.equal(Number(pDrift.amount), 85.0);

    // 1. Payment financial drift: tamper with public.payments.amount/commission/net_to_lounge
    await admin(`
      ALTER TABLE public.payments DISABLE TRIGGER USER;
      UPDATE public.payments
      SET amount = 90.00, commission = 13.50, net_to_lounge = 76.50
      WHERE id = '${dep.paymentId}';
      ALTER TABLE public.payments ENABLE TRIGGER USER;
    `);
    await expectReject(
      'approve_payout blocked when payment amount drifts from movement entries',
      () => db.query(`SELECT public.approve_payout($1, 'Should fail on amount drift')`, [pDrift.payout_id]),
      '55000',
      superAdmin
    );
    await admin(`
      ALTER TABLE public.payments DISABLE TRIGGER USER;
      UPDATE public.payments
      SET amount = 100.00, commission = 15.00, net_to_lounge = 85.00
      WHERE id = '${dep.paymentId}';
      ALTER TABLE public.payments ENABLE TRIGGER USER;
    `);

    // 2. Payment payout_id link drift: unlink payment from in-flight payout
    await admin(`UPDATE public.payments SET payout_id = NULL WHERE id = '${dep.paymentId}'`);
    await expectReject(
      'approve_payout blocked when payment payout_id link drifts',
      () => db.query(`SELECT public.approve_payout($1, 'Should fail on payout_id drift')`, [pDrift.payout_id]),
      '55000',
      superAdmin
    );
    await admin(`UPDATE public.payments SET payout_id = '${pDrift.payout_id}' WHERE id = '${dep.paymentId}'`);

    // 3. Pending refund request drift during needs_review -> resolve_payout_review(approve)
    const fakeReqId = randomUUID();
    await admin(`
      UPDATE public.payouts SET status = 'needs_review' WHERE id = '${pDrift.payout_id}';
      INSERT INTO private.booking_refund_requests(
        id, operation_id, booking_id, payment_id, lounge_id, target_movement_id,
        funds_holder, requested_amount_minor, approved_commission_reversal_minor,
        refund_reason, policy_decision, status, initiated_by
      ) VALUES (
        '${fakeReqId}', '${randomUUID()}', '${dep.bookingId}', '${dep.paymentId}', '${lounge}', '${dep.movementId}',
        'platform', 2000, 300,
        'Drift test pending refund', '{"eligible":true}'::jsonb, 'approved_pending_return', '${superAdmin}'
      );
    `);
    await expectReject(
      'resolve_payout_review(approve) blocked when approved_pending_return refund request exists on payment',
      () => db.query(`SELECT public.resolve_payout_review($1, 'approve', 'Should fail')`, [pDrift.payout_id]),
      '55000',
      superAdmin
    );
    await admin(`DELETE FROM private.booking_refund_requests WHERE id = '${fakeReqId}'`);

    // Once pending refund request is removed, resolve_payout_review(approve) succeeds
    await asActor(superAdmin);
    const revOk = (
      await db.query(`SELECT public.resolve_payout_review($1, 'approve', 'Drift cleared') AS r`, [pDrift.payout_id])
    ).rows[0].r;
    assert.equal(revOk.status, 'pending');

    // Approve and move to processing
    await db.query(`SELECT public.approve_payout($1, 'Approved after drift cleared')`, [pDrift.payout_id]);
    await db.query(`SELECT public.start_payout_processing($1)`, [pDrift.payout_id]);

    // 4. Unsettled movement drift on the payment before complete_payout
    const driftedMovId = randomUUID();
    await admin(`
      ALTER TABLE private.booking_money_movements DISABLE TRIGGER USER;
      INSERT INTO private.booking_money_movements(
        id, operation_id, booking_id, payment_id, lounge_id, shift_id,
        movement_type, collection_purpose, payment_method,
        amount_minor, commission_minor, funds_holder, reversal_of,
        evidence_reference, verified_by, verified_at
      ) VALUES (
        '${driftedMovId}', '${randomUUID()}', '${dep.bookingId}', '${dep.paymentId}', '${lounge}', '${shift}',
        'refund', 'refund', 'instapay',
        -2000, -300, 'platform', '${dep.movementId}',
        'DRIFT-REF', '${superAdmin}', '2026-10-12 12:00:00+00'
      );
      ALTER TABLE private.booking_money_movements ENABLE TRIGGER USER;

      ALTER TABLE public.payments DISABLE TRIGGER USER;
      UPDATE public.payments
      SET amount = 80.00, commission = 12.00, net_to_lounge = 68.00
      WHERE id = '${dep.paymentId}';
      ALTER TABLE public.payments ENABLE TRIGGER USER;
    `);
    await expectReject(
      'complete_payout blocked when unsettled refund movement exists on in-flight payout payment',
      () => db.query(`SELECT public.complete_payout($1, 'bank_transfer', 'BANK-DRIFT')`, [pDrift.payout_id]),
      '55000',
      superAdmin
    );

    // Clean up the injected drift and verify complete_payout succeeds
    await admin(`
      ALTER TABLE private.booking_money_movements DISABLE TRIGGER USER;
      DELETE FROM private.booking_money_movements WHERE id = '${driftedMovId}';
      ALTER TABLE private.booking_money_movements ENABLE TRIGGER USER;

      ALTER TABLE public.payments DISABLE TRIGGER USER;
      UPDATE public.payments
      SET amount = 100.00, commission = 15.00, net_to_lounge = 85.00
      WHERE id = '${dep.paymentId}';
      ALTER TABLE public.payments ENABLE TRIGGER USER;
    `);
    await asActor(superAdmin);
    const completeOk = (
      await db.query(`SELECT public.complete_payout($1, 'bank_transfer', 'BANK-CLEAN-9B') AS r`, [pDrift.payout_id])
    ).rows[0].r;
    assert.equal(completeOk.status, 'paid');
  });

  // =========================================================================
  // SCENARIO 10: Settlement-date semantics & Cairo timezone boundaries
  // =========================================================================
  await check('Scenario 10a: movement settlement_date uses canonical m.verified_at in Africa/Cairo regardless of session timezone or payments.paid_at', async () => {
    await resetLoungeFinancialState();
    const dep = await createPlatformVerifiedDepositBooking({
      totalPrice: 100.0,
      depositAmount: 100.0,
      verifiedDay: '2026-10-01',
    });

    // Stamp movement verified_at to 2026-09-30 22:30:00+00 (which is 2026-10-01 in Africa/Cairo,
    // but still 2026-09-30 in UTC and America/Los_Angeles), while stamping payments.paid_at to 2026-09-15!
    await admin(`
      ALTER TABLE private.booking_money_movements DISABLE TRIGGER USER;
      UPDATE private.booking_money_movements
      SET verified_at = '2026-09-30 22:30:00+00'
      WHERE id = '${dep.movementId}';
      ALTER TABLE private.booking_money_movements ENABLE TRIGGER USER;

      ALTER TABLE public.payments DISABLE TRIGGER USER;
      UPDATE public.payments
      SET paid_at = '2026-09-15 12:00:00+00'
      WHERE id = '${dep.paymentId}';
      ALTER TABLE public.payments ENABLE TRIGGER USER;
    `);

    const msvRow = (
      await admin(`SELECT settlement_date::text AS sd FROM private.movement_settlement_values WHERE movement_id = $1`, [
        dep.movementId,
      ])
    ).rows[0];
    assert.equal(msvRow.sd, '2026-10-01');

    await asActor(superAdmin);
    await db.exec(`SET LOCAL timezone = 'America/Los_Angeles'`);

    // September payout must NOT pick up the 2026-10-01 Cairo movement (even though payments.paid_at is 2026-09-15!)
    const pSep = (
      await db.query(`SELECT public.create_payout($1, '2026-09-01', '2026-09-30') AS r`, [lounge])
    ).rows[0].r;
    assert.equal(pSep.success, false);
    assert.equal(pSep.error, 'NO_POSITIVE_SETTLEMENT_BALANCE');

    // October 1 payout picks it up cleanly
    const pOct = (
      await db.query(`SELECT public.create_payout($1, '2026-10-01', '2026-10-01') AS r`, [lounge])
    ).rows[0].r;
    assert.equal(pOct.success, true);
    assert.equal(Number(pOct.amount), 85.0);
  });

  await check('Scenario 10b: multi-movement booking across Cairo period boundary (Oct 31 deposit + Nov 1 cash checkout) preserves each movement settlement_date and settles cleanly across or within periods', async () => {
    await resetLoungeFinancialState();
    const dep = await createPlatformVerifiedDepositBooking({
      totalPrice: 100.0,
      depositAmount: 20.0,
      method: 'instapay',
      verifiedDay: '2026-10-31',
      completedBooking: false,
    });

    // Complete the session on Nov 1 with 80.00 EGP cash checkout (which overwrites payments.paid_at to Nov 1)
    await admin(`UPDATE public.bookings SET status = 'completed' WHERE id = $1`, [dep.bookingId]);
    await asActor(cashier);
    await db.query(
      `SELECT public.checkout_booking_cash_atomic($1, $2, $3, $4)`,
      [dep.bookingId, shift, 8000, randomUUID()]
    );

    const cashMov = (
      await admin(
        `SELECT id FROM private.booking_money_movements WHERE booking_id = $1 AND collection_purpose = 'settlement'`,
        [dep.bookingId]
      )
    ).rows[0];

    // Stamp deposit to 2026-10-31 18:00:00+00 (2026-10-31 in Cairo) and cash checkout to 2026-10-31 22:30:00+00 (2026-11-01 in Cairo)
    await admin(`
      ALTER TABLE private.booking_money_movements DISABLE TRIGGER USER;
      UPDATE private.booking_money_movements
      SET verified_at = '2026-10-31 18:00:00+00'
      WHERE id = '${dep.movementId}';
      UPDATE private.booking_money_movements
      SET verified_at = '2026-10-31 22:30:00+00'
      WHERE id = '${cashMov.id}';
      ALTER TABLE private.booking_money_movements ENABLE TRIGGER USER;

      ALTER TABLE public.payments DISABLE TRIGGER USER;
      UPDATE public.payments
      SET paid_at = '2026-10-31 22:30:00+00'
      WHERE id = '${dep.paymentId}';
      ALTER TABLE public.payments ENABLE TRIGGER USER;
    `);

    const dates = (
      await admin(
        `
          SELECT movement_id, settlement_date::text AS sd
          FROM private.movement_settlement_values
          WHERE movement_id IN ($1, $2)
        `,
        [dep.movementId, cashMov.id]
      )
    ).rows;
    const dateMap = new Map(dates.map((r) => [r.movement_id, r.sd]));
    assert.equal(dateMap.get(dep.movementId), '2026-10-31');
    assert.equal(dateMap.get(cashMov.id), '2026-11-01');

    // 1. Creating October payout ('2026-10-01'..'2026-10-31') settles ONLY the Oct 31 deposit (+17.00 EGP)
    await asActor(superAdmin);
    const pOct = (
      await db.query(`SELECT public.create_payout($1, '2026-10-01', '2026-10-31') AS r`, [lounge])
    ).rows[0].r;
    assert.equal(pOct.success, true);
    assert.equal(Number(pOct.amount), 17.0);
    assert.equal(Number(pOct.movement_count), 1);

    await db.query(`SELECT public.approve_payout($1)`, [pOct.payout_id]);
    await db.query(`SELECT public.start_payout_processing($1)`, [pOct.payout_id]);
    await db.query(`SELECT public.complete_payout($1, 'bank_transfer', 'BANK-S10B-OCT')`, [pOct.payout_id]);

    // 2. Creating November payout ('2026-11-01'..'2026-11-30') with a 100.00 EGP Nov deposit (+85.00 EGP)
    //    settles the Nov 1 cash checkout (-12.00 EGP) + Nov deposit (+85.00 EGP) = 73.00 EGP!
    await createPlatformVerifiedDepositBooking({
      totalPrice: 100.0,
      depositAmount: 100.0,
      verifiedDay: '2026-11-10',
    });

    await asActor(superAdmin);
    const pNov = (
      await db.query(`SELECT public.create_payout($1, '2026-11-01', '2026-11-30') AS r`, [lounge])
    ).rows[0].r;
    assert.equal(pNov.success, true);
    assert.equal(Number(pNov.amount), 73.0);
    assert.equal(Number(pNov.movement_count), 2);
  });

  // =========================================================================
  // SCENARIO 11: Direct tests for guard_canonical_booking_payment_write and scoped locking
  // =========================================================================
  await check('Scenario 11a: guard_canonical_booking_payment_write allows payout_id-only updates on movement-backed payments but rejects any non-canonical financial, status, or method mutation', async () => {
    await resetLoungeFinancialState();
    const dep = await createPlatformVerifiedDepositBooking({
      totalPrice: 100.0,
      depositAmount: 100.0,
      verifiedDay: '2026-10-10',
    });

    const dummyPayoutId = randomUUID();
    await admin(
      `INSERT INTO public.payouts(id, lounge_id, period_start, period_end, total_amount, status)
       VALUES ($1, $2, '2026-10-01', '2026-10-31', 85.00, 'pending')`,
      [dummyPayoutId, lounge]
    );

    // 1. Updating ONLY payout_id succeeds
    await admin(`UPDATE public.payments SET payout_id = $1 WHERE id = $2`, [dummyPayoutId, dep.paymentId]);
    await admin(`UPDATE public.payments SET payout_id = NULL WHERE id = $1`, [dep.paymentId]);

    // 2. Updating amount, status, or payment_method outside canonical writer context is rejected (even if payout_id is also updated!)
    await assert.rejects(
      admin(`UPDATE public.payments SET payout_id = $1, amount = 50.00 WHERE id = $2`, [dummyPayoutId, dep.paymentId]),
      (err) => err.code === '55000'
    );
    await assert.rejects(
      admin(`UPDATE public.payments SET status = 'refunded' WHERE id = $1`, [dep.paymentId]),
      (err) => err.code === '55000'
    );
    await assert.rejects(
      admin(`UPDATE public.payments SET payment_method = 'cash' WHERE id = $1`, [dep.paymentId]),
      (err) => err.code === '55000'
    );
    await assert.rejects(
      admin(`DELETE FROM public.payments WHERE id = $1`, [dep.paymentId]),
      (err) => err.code === '55000'
    );
  });

  if (db.connect) {
    await check('Scenario 7b (Native PG lockedRace): concurrent create_payout calls serialize on lounge lock and allocate each movement once', async () => {
      await resetLoungeFinancialState();
      const dep = await createPlatformVerifiedDepositBooking({
        totalPrice: 100.0,
        depositAmount: 100.0,
        verifiedDay: '2026-10-10',
      });
      await executeVerifiedRefund({
        bookingId: dep.bookingId,
        movementId: dep.movementId,
        amount: 20.0,
        fundsHolder: 'platform',
        refundMethod: 'instapay',
        verifiedDay: '2026-10-12',
      });

      const q = {
        sql: `SELECT public.create_payout($1, '2026-10-01', '2026-10-31') AS r`,
        args: [lounge],
      };

      const [first, second] = await lockedRace(db, q, q, superAdmin);
      assert.equal(first.error, undefined);
      assert.equal(first.rows[0].r.success, true);
      assert.equal(Number(first.rows[0].r.amount), 68.0);
      assert.equal(second.error?.code, '55000');

      const payoutCount = (await admin(`SELECT count(*) AS c FROM public.payouts WHERE lounge_id = $1`, [lounge])).rows[0].c;
      assert.equal(Number(payoutCount), 1);
    });

    await check('Scenario 11b (Native PG scoped locking): create_payout does not lock historical already-paid bookings, payments, or movements that have no unsettled movements or pending refund requests', async () => {
      await resetLoungeFinancialState();
      const octDep = await createPlatformVerifiedDepositBooking({
        totalPrice: 100.0,
        depositAmount: 100.0,
        verifiedDay: '2026-10-10',
      });

      await asActor(superAdmin);
      const pOct = (
        await db.query(`SELECT public.create_payout($1, '2026-10-01', '2026-10-31') AS r`, [lounge])
      ).rows[0].r;
      await db.query(`SELECT public.approve_payout($1)`, [pOct.payout_id]);
      await db.query(`SELECT public.start_payout_processing($1)`, [pOct.payout_id]);
      await db.query(`SELECT public.complete_payout($1, 'bank_transfer', 'BANK-S11B-OCT')`, [pOct.payout_id]);

      // Create an unsettled November booking
      await createPlatformVerifiedDepositBooking({
        totalPrice: 100.0,
        depositAmount: 100.0,
        verifiedDay: '2026-11-10',
      });

      // Hold FOR UPDATE locks on the historical settled October booking, payment, and movement in a separate session
      const lockClient = await db.connect();
      try {
        await lockClient.query('BEGIN');
        await lockClient.query(`SELECT 1 FROM public.bookings WHERE id = $1 FOR UPDATE`, [octDep.bookingId]);
        await lockClient.query(`SELECT 1 FROM public.payments WHERE id = $1 FOR UPDATE`, [octDep.paymentId]);
        await lockClient.query(`SELECT 1 FROM private.booking_money_movements WHERE id = $1 FOR UPDATE`, [octDep.movementId]);

        // Set a 2-second lock_timeout on the main session: if create_payout tried to lock historical
        // settled octDep rows, it would fail with 55P03 (lock_not_available)!
        await asActor(superAdmin);
        await db.exec(`SET LOCAL lock_timeout = '2s'`);
        const pNov = (
          await db.query(`SELECT public.create_payout($1, '2026-11-01', '2026-11-30') AS r`, [lounge])
        ).rows[0].r;
        assert.equal(pNov.success, true);
        assert.equal(Number(pNov.amount), 85.0);
        assert.equal(Number(pNov.movement_count), 1);
      } finally {
        await lockClient.query('ROLLBACK').catch(() => {});
        await lockClient.end().catch(() => {});
      }
    });
  }

  console.log(
    JSON.stringify({
      passed,
      environment: db.connect ? 'native PostgreSQL' : 'isolated PGlite',
    })
  );
} finally {
  await db.close();
}
