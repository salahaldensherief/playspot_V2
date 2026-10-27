import {createFixtureDatabase} from './runtime/database.mjs';
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

async function asActor(id = cashier) {
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

async function expectReject(name, fn, expectedCode, actorId = cashier) {
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
      );
    $$;

    CREATE OR REPLACE FUNCTION private.assert_payout_admin()
    RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
    BEGIN
      IF NOT public.is_super_admin() THEN
        RAISE EXCEPTION 'SUPER_ADMIN_REQUIRED' USING ERRCODE = '42501';
      END IF;
    END;
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
      status text NOT NULL DEFAULT 'pending',
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
      commission_rate numeric CHECK (commission_rate BETWEEN 0 AND 1),
      commission numeric(10,2),
      net_to_lounge numeric(10,2),
      payment_method text,
      status text,
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

    GRANT USAGE ON SCHEMA public, auth TO authenticated, anon;
  `);

  const sqlFile = async (rel) =>
    (await readFile(new URL(rel, import.meta.url), 'utf8')).replace(/\r\n/g, '\n');

  // Apply canonical prerequisites and the new manual refund migration
  await db.exec(await sqlFile('../repairs/partial_cash_collection.sql'));
  await db.exec(await sqlFile('../migrations/20261015192841_booking_legacy_cash_ledger_agreement.sql'));
  await db.exec(await sqlFile('../migrations/20261025101139_atomic_discount_cash_checkout.sql'));
  await db.exec(await sqlFile('../migrations/20261025225255_canonical_booking_collections.sql'));
  await db.exec(await sqlFile('../migrations/20261025225913_branch_booking_refund_policy.sql'));
  await db.exec(await sqlFile('../migrations/20261027150000_manual_refund_reversal_accounting.sql'));

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
      ('${outsider}', 'cashier', '${foreignLounge}', true, false);

    INSERT INTO public.platform_super_admins(user_id) VALUES ('${superAdmin}');

    INSERT INTO public.lounges(
      id, owner_id, is_active, status, allow_cash_payment,
      require_booking_deposit, booking_deposit_amount,
      deposit_refund_allowed, cancellation_window_hours
    ) VALUES
      ('${lounge}', '${owner}', true, 'active', true, true, 20.00, true, 4),
      ('${foreignLounge}', '${outsider}', true, 'active', true, true, 20.00, true, 4);

    INSERT INTO public.rooms(id, lounge_id, status, is_available) VALUES
      ('${room}', '${lounge}', 'available', true);

    INSERT INTO public.fixture_permissions(actor, lounge, permission) VALUES
      ('${cashier}', '${lounge}', 'billing_checkout'),
      ('${cashier}', '${lounge}', 'bookings_cancel'),
      ('${owner}', '${lounge}', 'billing_checkout'),
      ('${owner}', '${lounge}', 'bookings_cancel'),
      ('${outsider}', '${foreignLounge}', 'billing_checkout'),
      ('${outsider}', '${foreignLounge}', 'bookings_cancel');

    INSERT INTO public.shifts(id, lounge_id, cashier_id, staff_user_id, status, starting_cash)
    VALUES ('${shift}', '${lounge}', '${cashier}', '${cashier}', 'open', 50.00);
  `);

  await asActor(owner);
  await db.query(
    'SELECT public.configure_branch_booking_refund_policy($1, $2, $3, $4)',
    [lounge, 240, 100, randomUUID()]
  );

  // =========================================================================
  // SCENARIO 1: Deposit verification + Cancellation != Refund + Policy Check
  // =========================================================================
  const depositBooking = randomUUID();
  await admin(`
    INSERT INTO public.bookings(
      id, user_id, lounge_id, room_id, date, start_time, end_time,
      status, confirmation_status, total_price, payment_status,
      payment_method, deposit_required, deposit_amount, deposit_paid, receipt_url
    ) VALUES (
      '${depositBooking}', '${customer}', '${lounge}', '${room}',
      (now() + interval '2 days')::date, '18:00:00', '20:00:00',
      'upcoming', 'confirmed', 100.00, 'unpaid',
      'instapay', true, 20.00, false, 'https://receipts.example/dep-1.png'
    );
  `);

  let depositMovementId;
  await check('verify deposit transfer creates canonical collection movement', async () => {
    await asActor(cashier);
    const res = (
      await db.query(
        'SELECT public.verify_booking_deposit_transfer($1, $2, $3, $4, $5) AS r',
        [depositBooking, shift, randomUUID(), 'INSTAPAY-TX-1001', 'lounge']
      )
    ).rows[0].r;
    assert.equal(res.collected_minor, 2000);
    assert.equal(res.commission_minor, 300);
    assert.equal(res.replayed, false);
    depositMovementId = res.movement_id;
  });

  await admin(`UPDATE public.bookings SET payment_method='manual_transfer' WHERE id='${depositBooking}'`);
  await expectReject(
    'reject_manual_booking cannot wipe a booking with a verified partial deposit',
    () => db.query('SELECT public.reject_manual_booking($1, $2)', [depositBooking, 'bad receipt']),
    '55000',
    owner
  );
  await admin(`UPDATE public.bookings SET payment_method='instapay' WHERE id='${depositBooking}'`);

  await check('cancelling booking evaluates refund policy ONLY and never fabricates returned money', async () => {
    await asActor(customer);
    const cancelRes = (
      await db.query('SELECT public.cancel_my_booking($1, $2) AS r', [
        depositBooking,
        'Customer schedule change',
      ])
    ).rows[0].r;
    assert.equal(cancelRes.status, 'cancelled');

    const summary = (
      await db.query('SELECT public.get_booking_refund_summary($1) AS s', [depositBooking])
    ).rows[0].s;
    assert.equal(summary.gross_collected_minor, 2000);
    assert.equal(summary.total_refunded_minor, 0);
    assert.equal(summary.net_collected_minor, 2000);
    assert.equal(summary.booking_payment_status, 'partial');
    assert.equal(summary.payment_row_status, 'completed');
    assert.equal(summary.movements.length, 1);
  });

  // =========================================================================
  // SCENARIO 2: Authorization Boundaries on Refund Initiation
  // =========================================================================
  await expectReject(
    'anonymous caller cannot initiate refund',
    () =>
      db.query('SELECT public.initiate_booking_refund($1, $2, $3, $4, $5)', [
        depositBooking,
        depositMovementId,
        800,
        'anon attempt',
        randomUUID(),
      ]),
    '28000',
    ''
  );

  await expectReject(
    'customer cannot initiate refund',
    () =>
      db.query('SELECT public.initiate_booking_refund($1, $2, $3, $4, $5)', [
        depositBooking,
        depositMovementId,
        800,
        'customer attempt',
        randomUUID(),
      ]),
    '42501',
    customer
  );

  await expectReject(
    'cross-lounge staff cannot initiate refund',
    () =>
      db.query('SELECT public.initiate_booking_refund($1, $2, $3, $4, $5)', [
        depositBooking,
        depositMovementId,
        800,
        'outsider attempt',
        randomUUID(),
      ]),
    '42501',
    outsider
  );

  // =========================================================================
  // SCENARIO 3: Authorized Refund Initiation, Idempotency & Pending State
  // =========================================================================
  const initOp1 = randomUUID();
  let refundRequest1Id;

  await check('authorized refund initiation records pending request without moving money', async () => {
    await asActor(cashier);
    const res = (
      await db.query('SELECT public.initiate_booking_refund($1, $2, $3, $4, $5) AS r', [
        depositBooking,
        depositMovementId,
        800,
        'Partial deposit refund agreed',
        initOp1,
      ])
    ).rows[0].r;

    assert.equal(res.status, 'approved_pending_return');
    assert.equal(res.requested_amount_minor, 800);
    assert.equal(res.approved_commission_reversal_minor, 120);
    assert.equal(res.replayed, false);
    refundRequest1Id = res.refund_request_id;

    // Money has still NOT moved!
    const summary = (
      await db.query('SELECT public.get_booking_refund_summary($1) AS s', [depositBooking])
    ).rows[0].s;
    assert.equal(summary.gross_collected_minor, 2000);
    assert.equal(summary.total_refunded_minor, 0);
    assert.equal(summary.net_collected_minor, 2000);
    assert.equal(summary.pending_refund_minor, 800);
    assert.equal(summary.refundable_remaining_minor, 1200);
    assert.equal(summary.payment_row_amount_minor, 2000);
  });

  await check('idempotent replay of initiate_booking_refund returns same pending request', async () => {
    await asActor(cashier);
    const replay = (
      await db.query('SELECT public.initiate_booking_refund($1, $2, $3, $4, $5) AS r', [
        depositBooking,
        depositMovementId,
        800,
        'Partial deposit refund agreed',
        initOp1,
      ])
    ).rows[0].r;
    assert.equal(replay.replayed, true);
    assert.equal(replay.refund_request_id, refundRequest1Id);
  });

  await expectReject(
    'conflicting replay of initiate_booking_refund with different amount is rejected',
    () =>
      db.query('SELECT public.initiate_booking_refund($1, $2, $3, $4, $5)', [
        depositBooking,
        depositMovementId,
        900,
        'Partial deposit refund agreed',
        initOp1,
      ]),
    '22023',
    cashier
  );

  await expectReject(
    'initiating second pending request exceeding remaining unreserved collection is rejected',
    () =>
      db.query('SELECT public.initiate_booking_refund($1, $2, $3, $4, $5)', [
        depositBooking,
        depositMovementId,
        1201,
        'Over-request attempt',
        randomUUID(),
      ]),
    '22023',
    cashier
  );

  // =========================================================================
  // SCENARIO 4: Partial & Full Refund Execution + Exact Commission Reversal
  // =========================================================================
  const execOp1 = randomUUID();
  await check('executing partial transfer refund writes negative reversal movement and reconciles payment', async () => {
    await asActor(cashier);
    const res = (
      await db.query('SELECT public.execute_booking_refund($1, $2, $3, $4, $5) AS r', [
        refundRequest1Id,
        'instapay',
        'INSTAPAY-REFUND-9001',
        execOp1,
        shift,
      ])
    ).rows[0].r;

    assert.equal(res.replayed, false);
    assert.equal(res.refunded_amount_minor, 800);
    assert.equal(res.commission_reversed_minor, 120);
    assert.equal(res.net_to_lounge_reversed_minor, 680);
    assert.equal(res.gross_collected_minor, 2000);
    assert.equal(res.total_refunded_minor, 800);
    assert.equal(res.net_collected_minor, 1200);
    assert.equal(res.payment_status, 'partial');
    assert.equal(res.payment_row_status, 'completed');

    const cov = (
      await admin(
        'SELECT * FROM private.booking_money_coverage WHERE booking_id = $1',
        [depositBooking]
      )
    ).rows[0];
    assert.equal(cov.coverage_state, 'covered');
    assert.equal(Number(cov.movement_gross_minor), 2000);
    assert.equal(Number(cov.refunded_minor), -800);
    assert.equal(Number(cov.movement_net_minor), 1200);
    assert.equal(Number(cov.aggregate_gross_minor), 1200);
  });

  await check('idempotent replay of execute_booking_refund never duplicates movement', async () => {
    await asActor(cashier);
    const replay = (
      await db.query('SELECT public.execute_booking_refund($1, $2, $3, $4, $5) AS r', [
        refundRequest1Id,
        'instapay',
        'INSTAPAY-REFUND-9001',
        execOp1,
        shift,
      ])
    ).rows[0].r;
    assert.equal(replay.replayed, true);
    assert.equal(replay.net_collected_minor, 1200);
  });

  await expectReject(
    'executing already completed refund request with new operation_id is rejected',
    () =>
      db.query('SELECT public.execute_booking_refund($1, $2, $3, $4, $5)', [
        refundRequest1Id,
        'instapay',
        'INSTAPAY-REFUND-9001',
        randomUUID(),
        shift,
      ]),
    '55000',
    cashier
  );

  await check('second refund of remaining 1200 minor completes full refund and marks booking/payment refunded', async () => {
    await asActor(cashier);
    const req2 = (
      await db.query('SELECT public.initiate_booking_refund($1, $2, $3, $4, $5) AS r', [
        depositBooking,
        depositMovementId,
        1200,
        'Remaining deposit refund',
        randomUUID(),
      ])
    ).rows[0].r;
    assert.equal(req2.approved_commission_reversal_minor, 180);

    const exec2 = (
      await db.query('SELECT public.execute_booking_refund($1, $2, $3, $4, $5) AS r', [
        req2.refund_request_id,
        'instapay',
        'INSTAPAY-REFUND-9002',
        randomUUID(),
        shift,
      ])
    ).rows[0].r;

    assert.equal(exec2.gross_collected_minor, 2000);
    assert.equal(exec2.total_refunded_minor, 2000);
    assert.equal(exec2.net_collected_minor, 0);
    assert.equal(exec2.payment_status, 'refunded');
    assert.equal(exec2.payment_row_status, 'refunded');

    const summary = (
      await db.query('SELECT public.get_booking_refund_summary($1) AS s', [depositBooking])
    ).rows[0].s;
    assert.equal(summary.net_collected_minor, 0);
    assert.equal(summary.net_commission_minor, 0);
    assert.equal(summary.net_to_lounge_minor, 0);
    assert.equal(summary.deposit_paid, false);
    assert.equal(summary.booking_payment_status, 'refunded');
    assert.equal(summary.payment_row_status, 'refunded');
  });

  await expectReject(
    'initiating any further refund after full refund is rejected',
    () =>
      db.query('SELECT public.initiate_booking_refund($1, $2, $3, $4, $5)', [
        depositBooking,
        depositMovementId,
        1,
        'Extra 1 piastre attempt',
        randomUUID(),
      ]),
    '22023',
    cashier
  );

  // =========================================================================
  // SCENARIO 5: Branch Refund Policy Enforcement & Manager Override
  // =========================================================================
  const lateCancelBooking = randomUUID();
  await admin(`
    INSERT INTO public.bookings(
      id, user_id, lounge_id, room_id, date, start_time, end_time,
      status, confirmation_status, total_price, payment_status,
      payment_method, deposit_required, deposit_amount, deposit_paid, receipt_url
    ) VALUES (
      '${lateCancelBooking}', '${customer}', '${lounge}', '${room}',
      current_date, '20:00:00', '22:00:00',
      'upcoming', 'confirmed', 100.00, 'unpaid',
      'vodafone_cash', true, 20.00, false, 'https://receipts.example/dep-late.png'
    );
  `);

  await asActor(cashier);
  const lateDep = (
    await db.query(
      'SELECT public.verify_booking_deposit_transfer($1, $2, $3, $4, $5) AS r',
      [lateCancelBooking, shift, randomUUID(), 'VF-LATE-100', 'lounge']
    )
  ).rows[0].r;

  // Simulate late cancellation after the 240-minute cutoff (1 hour before start)
  await admin(`
    UPDATE public.bookings
    SET status = 'cancelled',
        cancelled_by = '${customer}',
        cancelled_at = ((current_date + time '20:00:00') AT TIME ZONE 'Africa/Cairo') - interval '30 minutes'
    WHERE id = '${lateCancelBooking}';
  `);

  await expectReject(
    'non-refundable policy blocks deposit refund initiation without override',
    () =>
      db.query('SELECT public.initiate_booking_refund($1, $2, $3, $4, $5, $6)', [
        lateCancelBooking,
        lateDep.movement_id,
        2000,
        'Customer requested exception',
        randomUUID(),
        false,
      ]),
    '55000',
    cashier
  );

  await expectReject(
    'cashier cannot use policy_override=true',
    () =>
      db.query('SELECT public.initiate_booking_refund($1, $2, $3, $4, $5, $6)', [
        lateCancelBooking,
        lateDep.movement_id,
        2000,
        'Cashier override attempt',
        randomUUID(),
        true,
      ]),
    '42501',
    cashier
  );

  await check('lounge owner can initiate with policy_override=true and then cancel pending request', async () => {
    await asActor(owner);
    const req = (
      await db.query('SELECT public.initiate_booking_refund($1, $2, $3, $4, $5, $6) AS r', [
        lateCancelBooking,
        lateDep.movement_id,
        2000,
        'Owner goodwill override',
        randomUUID(),
        true,
      ])
    ).rows[0].r;
    assert.equal(req.policy_override, true);
    assert.equal(req.status, 'approved_pending_return');

    const cancelled = (
      await db.query('SELECT public.cancel_booking_refund_request($1, $2) AS r', [
        req.refund_request_id,
        'Customer decided to keep booking',
      ])
    ).rows[0].r;
    assert.equal(cancelled.status, 'cancelled');
    assert.equal(cancelled.replayed, false);

    const replayCancel = (
      await db.query('SELECT public.cancel_booking_refund_request($1, $2) AS r', [
        req.refund_request_id,
        'Customer decided to keep booking',
      ])
    ).rows[0].r;
    assert.equal(replayCancel.replayed, true);
  });

  // =========================================================================
  // SCENARIO 6: Cash Checkout + Discount Clamping + Shift Drawer Cash Outflow
  // =========================================================================
  const cashBooking = randomUUID();
  await admin(`
    INSERT INTO public.bookings(
      id, user_id, lounge_id, room_id, status, total_price, payment_status, payment_method
    ) VALUES (
      '${cashBooking}', '${customer}', '${lounge}', '${room}',
      'completed', 100.00, 'unpaid', 'cash'
    );
  `);

  let cashMovementId;
  await check('atomic cash checkout with discount records canonical cash movement', async () => {
    await asActor(cashier);
    const checkout = (
      await db.query(
        'SELECT public.checkout_booking_cash_atomic($1, $2, $3, $4, $5, $6, $7) AS r',
        [cashBooking, shift, 8500, randomUUID(), 15.00, 15.00, 'Promo 15%']
      )
    ).rows[0].r;
    assert.equal(checkout.paid_minor, 8500);
    assert.equal(checkout.payment_status, 'paid');
    cashMovementId = checkout.movement_id;
  });

  // Drawer currently has: starting_cash (50.00) + cash_sales (85.00) = 135.00 EGP (13500 minor).
  // Reduce starting_cash to 0 and add an expense of 60.00 so drawer only has 25.00 EGP (2500 minor).
  await admin(`
    UPDATE public.shifts SET starting_cash = 0 WHERE id = '${shift}';
    INSERT INTO public.shift_expenses(shift_id, lounge_id, amount, reason, expense_type)
    VALUES ('${shift}', '${lounge}', 60.00, 'Supplier payout', 'cash_drop');
  `);

  let cashRefundReqId;
  await check('initiate full 85.00 EGP cash refund request', async () => {
    await asActor(cashier);
    const req = (
      await db.query('SELECT public.initiate_booking_refund($1, $2, $3, $4, $5) AS r', [
        cashBooking,
        cashMovementId,
        8500,
        'Full cash refund after power outage',
        randomUUID(),
      ])
    ).rows[0].r;
    cashRefundReqId = req.refund_request_id;
  });

  await expectReject(
    'cash refund without shift_id is rejected',
    () =>
      db.query('SELECT public.execute_booking_refund($1, $2, $3, $4, $5)', [
        cashRefundReqId,
        'cash',
        'CASH-VOUCHER-1',
        randomUUID(),
        null,
      ]),
    '55000',
    cashier
  );

  await expectReject(
    'cash refund exceeding available shift drawer cash is rejected',
    () =>
      db.query('SELECT public.execute_booking_refund($1, $2, $3, $4, $5)', [
        cashRefundReqId,
        'cash',
        'CASH-VOUCHER-1',
        randomUUID(),
        shift,
      ]),
    '22023',
    cashier
  );

  // Restore starting_cash to 100.00 so drawer has 100 + 85 - 60 = 125.00 EGP
  await admin(`UPDATE public.shifts SET starting_cash = 100.00 WHERE id = '${shift}'`);

  const cashExecOp = randomUUID();
  await check('cash refund with sufficient drawer cash creates shift_expense and clamps discount_amount', async () => {
    await asActor(cashier);
    const res = (
      await db.query('SELECT public.execute_booking_refund($1, $2, $3, $4, $5) AS r', [
        cashRefundReqId,
        'cash',
        'CASH-VOUCHER-1',
        cashExecOp,
        shift,
      ])
    ).rows[0].r;

    assert.equal(res.refunded_amount_minor, 8500);
    assert.equal(res.commission_reversed_minor, 1275);
    assert.equal(res.net_collected_minor, 0);
    assert.equal(res.payment_status, 'refunded');
    assert.equal(res.payment_row_status, 'refunded');
    assert.ok(res.shift_expense_id);

    const exp = (
      await admin('SELECT * FROM public.shift_expenses WHERE id = $1', [res.shift_expense_id])
    ).rows[0];
    assert.equal(Number(exp.amount), 85);
    assert.equal(exp.expense_type, 'other');
    assert.equal(exp.type, 'booking_refund');

    const pay = (
      await admin('SELECT * FROM public.payments WHERE booking_id = $1', [cashBooking])
    ).rows[0];
    assert.equal(Number(pay.amount), 0);
    assert.equal(Number(pay.discount_amount), 0);
    assert.equal(pay.status, 'refunded');
  });

  await check('replaying committed cash refund after shift closes succeeds without error', async () => {
    await admin(`UPDATE public.shifts SET status = 'closed', closed_at = now() WHERE id = '${shift}'`);
    await asActor(cashier);
    const replay = (
      await db.query('SELECT public.execute_booking_refund($1, $2, $3, $4, $5) AS r', [
        cashRefundReqId,
        'cash',
        'CASH-VOUCHER-1',
        cashExecOp,
        shift,
      ])
    ).rows[0].r;
    assert.equal(replay.replayed, true);
    await admin(`UPDATE public.shifts SET status = 'open', closed_at = NULL WHERE id = '${shift}'`);
  });

  // =========================================================================
  // SCENARIO 7: Platform Custody Refund & Payout Contribution / Lock Rules
  // =========================================================================
  const platformBooking = randomUUID();
  const platformPayment = randomUUID();
  const platformShiftPayment = randomUUID();
  const platformMovement = randomUUID();

  await admin(`
    INSERT INTO public.bookings(
      id, user_id, lounge_id, room_id, status, total_price, payment_status, payment_method
    ) VALUES (
      '${platformBooking}', '${customer}', '${lounge}', '${room}',
      'completed', 100.00, 'paid', 'card'
    );

    INSERT INTO private.cash_collection_context(transaction_id, booking_id)
    VALUES (txid_current(), '${platformBooking}');

    INSERT INTO public.payments(
      id, booking_id, user_id, lounge_id, amount, commission_rate, commission, net_to_lounge, payment_method, status
    ) VALUES (
      '${platformPayment}', '${platformBooking}', '${customer}', '${lounge}',
      100.00, 0.15, 15.00, 85.00, 'card', 'completed'
    );

    INSERT INTO public.shift_payments(
      id, shift_id, lounge_id, booking_id, payment_method, category, amount
    ) VALUES (
      '${platformShiftPayment}', '${shift}', '${lounge}', '${platformBooking}',
      'card', 'gaming_time', 100.00
    );

    INSERT INTO private.booking_money_movements(
      id, operation_id, booking_id, payment_id, lounge_id, shift_id, shift_payment_id,
      movement_type, collection_purpose, payment_method, amount_minor, commission_minor,
      funds_holder, evidence_reference, verified_by
    ) VALUES (
      '${platformMovement}', '${randomUUID()}', '${platformBooking}', '${platformPayment}',
      '${lounge}', '${shift}', '${platformShiftPayment}',
      'collection', 'settlement', 'card', 10000, 1500,
      'platform', 'PAYMOB-CARD-777', '${superAdmin}'
    );

    DELETE FROM private.cash_collection_context WHERE booking_id = '${platformBooking}';
  `);

  await expectReject(
    'lounge owner cannot initiate refund for platform-held funds',
    () =>
      db.query('SELECT public.initiate_booking_refund($1, $2, $3, $4, $5)', [
        platformBooking,
        platformMovement,
        4000,
        'Owner trying platform refund',
        randomUUID(),
      ]),
    '42501',
    owner
  );

  // Lock movement in a pending payout first and verify refund is blocked even for superAdmin
  const draftPayout = randomUUID();
  await admin(`
    INSERT INTO public.payouts(id, lounge_id, status) VALUES ('${draftPayout}', '${lounge}', 'pending');
    INSERT INTO private.booking_movement_payout_entries(payout_id, movement_id, contribution_minor)
    VALUES ('${draftPayout}', '${platformMovement}', 8500);
  `);

  await expectReject(
    'movement locked in active pending payout cannot be refunded until payout is cancelled or settled',
    () =>
      db.query('SELECT public.initiate_booking_refund($1, $2, $3, $4, $5)', [
        platformBooking,
        platformMovement,
        4000,
        'SuperAdmin refund during pending payout',
        randomUUID(),
      ]),
    '55000',
    superAdmin
  );

  // Mark that payout as 'paid' (settled in a prior payout period) so a post-settlement refund movement can be issued
  await admin(`UPDATE public.payouts SET status = 'paid' WHERE id = '${draftPayout}'`);

  let platformRefundReqId;
  await check('platform super admin can initiate refund for platform-held collection', async () => {
    await asActor(superAdmin);
    const req = (
      await db.query('SELECT public.initiate_booking_refund($1, $2, $3, $4, $5) AS r', [
        platformBooking,
        platformMovement,
        4000,
        'Platform gateway partial refund',
        randomUUID(),
      ])
    ).rows[0].r;
    assert.equal(req.funds_holder, 'platform');
    assert.equal(req.approved_commission_reversal_minor, 600);
    platformRefundReqId = req.refund_request_id;
  });

  await expectReject(
    'platform-held refund cannot be executed with cash return method',
    () =>
      db.query('SELECT public.execute_booking_refund($1, $2, $3, $4, $5)', [
        platformRefundReqId,
        'cash',
        'CASH-NOT-ALLOWED',
        randomUUID(),
        shift,
      ]),
    '22023',
    superAdmin
  );

  await check('platform super admin executes card refund and allocates negative payout liability entry', async () => {
    await asActor(superAdmin);
    const exec = (
      await db.query('SELECT public.execute_booking_refund($1, $2, $3, $4, $5) AS r', [
        platformRefundReqId,
        'card',
        'PAYMOB-REF-777-R1',
        randomUUID(),
        null,
      ])
    ).rows[0].r;

    assert.equal(exec.refunded_amount_minor, 4000);
    assert.equal(exec.commission_reversed_minor, 600);
    assert.equal(exec.net_to_lounge_reversed_minor, 3400);
    assert.equal(exec.net_collected_minor, 6000);
    assert.equal(exec.payment_status, 'partial');

    // Allocate the refund movement into the next pending payout:
    // For platform-held refund, contribution_minor must be net_to_lounge_minor = -3400!
    const nextPayout = randomUUID();
    await admin(`
      INSERT INTO public.payouts(id, lounge_id, status) VALUES ('${nextPayout}', '${lounge}', 'pending');
      INSERT INTO private.booking_movement_payout_entries(payout_id, movement_id, contribution_minor)
      VALUES ('${nextPayout}', '${exec.refund_movement_id}', -3400);
    `);

    const summary = (
      await db.query('SELECT public.get_booking_refund_summary($1) AS s', [platformBooking])
    ).rows[0].s;
    assert.equal(summary.platform_payout_contribution_minor, 5100); // 8500 - 3400
  });

  // =========================================================================
  // SCENARIO 8: Mixed-Method Booking Refund + Subsequent Re-collection
  // =========================================================================
  const mixedBooking = randomUUID();
  await admin(`
    INSERT INTO public.bookings(
      id, user_id, lounge_id, room_id, status, confirmation_status,
      total_price, payment_status, payment_method,
      deposit_required, deposit_amount, deposit_paid, receipt_url
    ) VALUES (
      '${mixedBooking}', '${customer}', '${lounge}', '${room}',
      'upcoming', 'confirmed',
      100.00, 'unpaid', 'instapay',
      true, 20.00, false, 'https://receipts.example/mixed-dep.png'
    );
  `);

  await check('mixed booking (20 EGP instapay deposit + 80 EGP cash) supports partial cash refund then re-collection', async () => {
    await asActor(cashier);
    await db.query(
      'SELECT public.verify_booking_deposit_transfer($1, $2, $3, $4, $5)',
      [mixedBooking, shift, randomUUID(), 'MIXED-DEP-1', 'lounge']
    );
    await admin(`UPDATE public.bookings SET status = 'completed' WHERE id = '${mixedBooking}'`);

    await asActor(cashier);
    const cashPart = (
      await db.query(
        'SELECT public.collect_booking_cash_partial($1, $2, $3, $4) AS r',
        [mixedBooking, shift, 8000, randomUUID()]
      )
    ).rows[0].r;
    assert.equal(cashPart.paid_minor, 10000);
    assert.equal(cashPart.payment_status, 'paid');

    // Refund 30.00 EGP (3000 minor) of the 80.00 EGP cash movement
    const req = (
      await db.query('SELECT public.initiate_booking_refund($1, $2, $3, $4, $5) AS r', [
        mixedBooking,
        cashPart.movement_id,
        3000,
        'Overcharged 1 controller hour',
        randomUUID(),
      ])
    ).rows[0].r;

    const exec = (
      await db.query('SELECT public.execute_booking_refund($1, $2, $3, $4, $5) AS r', [
        req.refund_request_id,
        'cash',
        'CASH-ADJ-30',
        randomUUID(),
        shift,
      ])
    ).rows[0].r;
    assert.equal(exec.net_collected_minor, 7000);
    assert.equal(exec.payment_status, 'partial');

    // Now re-collect the remaining 30.00 EGP (3000 minor) via collect_booking_cash_partial!
    const recollect = (
      await db.query(
        'SELECT public.collect_booking_cash_partial($1, $2, $3, $4) AS r',
        [mixedBooking, shift, 3000, randomUUID()]
      )
    ).rows[0].r;
    assert.equal(recollect.paid_minor, 10000);
    assert.equal(recollect.due_minor, 0);
    assert.equal(recollect.payment_status, 'paid');
  });

  // =========================================================================
  // SCENARIO 9: Multi-Connection Concurrency Races (Native PostgreSQL)
  // =========================================================================
  if (db.connect) {
    const raceBooking = randomUUID();
    await admin(`
      INSERT INTO public.bookings(
        id, user_id, lounge_id, room_id, status, total_price, payment_status, payment_method
      ) VALUES (
        '${raceBooking}', '${customer}', '${lounge}', '${room}',
        'completed', 100.00, 'unpaid', 'cash'
      );
    `);

    await asActor(cashier);
    const raceCollection = (
      await db.query(
        'SELECT public.collect_booking_cash_partial($1, $2, $3, $4) AS r',
        [raceBooking, shift, 10000, randomUUID()]
      )
    ).rows[0].r;

    await check('competing refund initiations cannot over-reserve the collected movement balance', async () => {
      const reqA = {
        sql: 'SELECT public.initiate_booking_refund($1, $2, $3, $4, $5) AS r',
        args: [raceBooking, raceCollection.movement_id, 6000, 'Race A', randomUUID()],
      };
      const reqB = {
        sql: 'SELECT public.initiate_booking_refund($1, $2, $3, $4, $5) AS r',
        args: [raceBooking, raceCollection.movement_id, 6000, 'Race B', randomUUID()],
      };
      const [first, second] = await lockedRace(db, reqA, reqB, cashier);
      assert.equal(first.rows[0].r.requested_amount_minor, 6000);
      assert.equal(second.error?.code, '22023');
    });

    await check('simultaneous same-operation execute_booking_refund executes once and replays once', async () => {
      const pendingId = (
        await admin(
          "SELECT id FROM private.booking_refund_requests WHERE booking_id = $1 AND status = 'approved_pending_return'",
          [raceBooking]
        )
      ).rows[0].id;

      const opId = randomUUID();
      const execReq = {
        sql: 'SELECT public.execute_booking_refund($1, $2, $3, $4, $5) AS r',
        args: [pendingId, 'cash', 'RACE-CASH-REF-1', opId, shift],
      };

      const [first, second] = await lockedRace(db, execReq, execReq, cashier);
      assert.equal(first.rows[0].r.replayed, false);
      assert.equal(second.error, undefined);
      assert.equal(second.value.rows[0].r.replayed, true);

      const summary = (
        await db.query('SELECT public.get_booking_refund_summary($1) AS s', [raceBooking])
      ).rows[0].s;
      assert.equal(summary.total_refunded_minor, 6000);
      assert.equal(summary.net_collected_minor, 4000);
    });
  }

  console.log(
    JSON.stringify({
      passed,
      engine: db.connect ? 'native-pg17' : 'pglite',
      status: 'ALL_MANUAL_REFUND_REVERSAL_INVARIANTS_PASSED',
    })
  );
} finally {
  await db.close();
}
