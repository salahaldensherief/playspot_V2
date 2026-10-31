BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- -----------------------------------------------------------------------------
-- 1. Lounges Timezone Column
-- -----------------------------------------------------------------------------
ALTER TABLE public.lounges
  ADD COLUMN IF NOT EXISTS timezone text NOT NULL DEFAULT 'Africa/Cairo';

-- -----------------------------------------------------------------------------
-- 2. Business Date Helper Function
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.business_date(
  p_lounge_id uuid,
  p_ts timestamptz DEFAULT now()
)
RETURNS date
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $f$
DECLARE
  v_tz text;
  v_opening_time time without time zone;
  v_closing_time time without time zone;
  v_local_ts timestamp without time zone;
  v_local_date date;
  v_local_time time without time zone;
BEGIN
  -- Fetch lounge timezone and operating hours
  SELECT
    COALESCE(NULLIF(btrim(l.timezone), ''), 'Africa/Cairo'),
    l.opening_time,
    l.closing_time
  INTO v_tz, v_opening_time, v_closing_time
  FROM public.lounges l
  WHERE l.id = p_lounge_id;

  IF v_tz IS NULL THEN
    v_tz := 'Africa/Cairo';
  END IF;

  -- Convert UTC timestamp to lounge local time
  v_local_ts := COALESCE(p_ts, now()) AT TIME ZONE v_tz;
  v_local_date := v_local_ts::date;
  v_local_time := v_local_ts::time;

  -- Handle operating hours crossing midnight
  -- E.g. opening_time = 10:00, closing_time = 03:00 AM next day
  IF v_opening_time IS NOT NULL AND v_closing_time IS NOT NULL THEN
    IF v_closing_time <= v_opening_time THEN
      IF v_local_time < v_closing_time THEN
        -- Early morning hours belong to previous operating day
        RETURN (v_local_date - INTERVAL '1 day')::date;
      END IF;
    END IF;
  END IF;

  RETURN v_local_date;
END;
$f$;

REVOKE ALL ON FUNCTION public.business_date(uuid, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.business_date(uuid, timestamptz) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 3. Expanded CHECK Constraints
-- -----------------------------------------------------------------------------

-- Bookings payment_method
DO $$
BEGIN
  EXECUTE (
    SELECT 'ALTER TABLE public.bookings DROP CONSTRAINT ' || quote_ident(conname)
    FROM pg_constraint
    WHERE conrelid = 'public.bookings'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%payment_method%'
    LIMIT 1
  );
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

ALTER TABLE public.bookings
  ADD CONSTRAINT bookings_payment_method_check
  CHECK (payment_method IN (
    'cash', 'manual_transfer', 'online', 'card', 'wallet', 'app_wallet', 'instapay',
    'fawry', 'vodafone_cash', 'points', 'free', 'package', 'other',
    'visa', 'mastercard', 'pos', 'credit_card', 'bank_transfer'
  ))
  NOT VALID;

ALTER TABLE public.bookings VALIDATE CONSTRAINT bookings_payment_method_check;

-- Payments payment_method
DO $$
BEGIN
  EXECUTE (
    SELECT 'ALTER TABLE public.payments DROP CONSTRAINT ' || quote_ident(conname)
    FROM pg_constraint
    WHERE conrelid = 'public.payments'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%payment_method%'
    LIMIT 1
  );
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

ALTER TABLE public.payments
  ADD CONSTRAINT payments_payment_method_check
  CHECK (payment_method IN (
    'cash', 'manual_transfer', 'online', 'card', 'wallet', 'app_wallet', 'instapay',
    'fawry', 'vodafone_cash', 'points', 'free', 'package', 'other',
    'visa', 'mastercard', 'pos', 'credit_card', 'bank_transfer'
  ))
  NOT VALID;

ALTER TABLE public.payments VALIDATE CONSTRAINT payments_payment_method_check;

-- Shift Payments payment_method & category
DO $$
BEGIN
  EXECUTE (
    SELECT 'ALTER TABLE public.shift_payments DROP CONSTRAINT ' || quote_ident(conname)
    FROM pg_constraint
    WHERE conrelid = 'public.shift_payments'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%payment_method%'
    LIMIT 1
  );
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

ALTER TABLE public.shift_payments
  ADD CONSTRAINT shift_payments_payment_method_check
  CHECK (payment_method IN (
    'cash', 'manual_transfer', 'online', 'card', 'wallet', 'app_wallet', 'instapay',
    'fawry', 'vodafone_cash', 'points', 'free', 'package', 'other',
    'visa', 'mastercard', 'pos', 'credit_card', 'bank_transfer'
  ))
  NOT VALID;

ALTER TABLE public.shift_payments VALIDATE CONSTRAINT shift_payments_payment_method_check;

DO $$
BEGIN
  EXECUTE (
    SELECT 'ALTER TABLE public.shift_payments DROP CONSTRAINT ' || quote_ident(conname)
    FROM pg_constraint
    WHERE conrelid = 'public.shift_payments'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%category%'
    LIMIT 1
  );
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

ALTER TABLE public.shift_payments
  ADD CONSTRAINT shift_payments_category_check
  CHECK (category IN (
    'gaming_time', 'snacks', 'extra_controllers', 'package_sale', 'tournament_entry',
    'booking', 'canteen', 'session', 'other', 'expense', 'refund', 'deposit',
    'withdrawal', 'general'
  ))
  NOT VALID;

ALTER TABLE public.shift_payments VALIDATE CONSTRAINT shift_payments_category_check;

-- Notifications type
DO $$
BEGIN
  EXECUTE (
    SELECT 'ALTER TABLE public.notifications DROP CONSTRAINT ' || quote_ident(conname)
    FROM pg_constraint
    WHERE conrelid = 'public.notifications'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%type%'
    LIMIT 1
  );
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check
  CHECK (type IN (
    'booking', 'booking_status', 'booking_no_show', 'canteen', 'service_call',
    'client_request', 'booking_extension_approved', 'booking_extension_rejected',
    'offer', 'loyalty', 'loyalty_points', 'system', 'kyc', 'kyc_submitted',
    'kyc_approved', 'kyc_rejected', 'tournament', 'tournament_payment',
    'tournament_match', 'tournament_dispute', 'tournament_waitlist_promoted',
    'tournament_cancelled', 'tournament_prize', 'payout', 'staff_assigned',
    'shift_approved', 'booking_confirmed', 'booking_cancelled', 'booking_reminder',
    'booking_completed', 'points_earned', 'points_redeemed', 'tier_upgraded',
    'tier_downgraded', 'tournament_registered', 'tournament_starting',
    'tournament_won', 'waitlist_promoted', 'general',
    'package', 'package_expiring', 'winback', 'group_invite', 'group_update',
    'tournament_invite', 'growth_insight', 'price_change'
  ))
  NOT VALID;

ALTER TABLE public.notifications VALIDATE CONSTRAINT notifications_type_check;

-- -----------------------------------------------------------------------------
-- 4. Permissions Model Enhancements & Seeding
-- -----------------------------------------------------------------------------
ALTER TABLE public.app_permissions
  ADD COLUMN IF NOT EXISTS default_manager boolean NOT NULL DEFAULT false;

-- Sync default_manager with default_owner for existing permissions
UPDATE public.app_permissions
  SET default_manager = default_owner
  WHERE default_manager IS FALSE AND default_owner IS TRUE;

-- Update role_permission_value function to respect default_manager
CREATE OR REPLACE FUNCTION private.role_permission_value(p_role text, p_lounge_id uuid, p_key text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $f$
  SELECT COALESCE((SELECT CASE
    WHEN p_role NOT IN ('super_admin','owner','manager','cashier','staff') OR p_role IS NULL THEN false
    ELSE COALESCE(
      (SELECT lrp.is_enabled FROM public.lounge_role_permissions lrp
       WHERE lrp.lounge_id=p_lounge_id AND lrp.role=p_role AND lrp.permission_key=a.key),
      CASE p_role WHEN 'super_admin' THEN a.default_super_admin
        WHEN 'owner' THEN a.default_owner
        WHEN 'manager' THEN COALESCE(a.default_manager, a.default_owner)
        WHEN 'cashier' THEN a.default_cashier ELSE false END, false)
    END FROM public.app_permissions a WHERE a.key=p_key),false);
$f$;

-- Seed new foundation permission keys
INSERT INTO public.app_permissions (
  key, name_ar, name_en, category, description_ar, description_en,
  default_super_admin, default_owner, default_manager, default_cashier
) VALUES
  ('packages.manage', 'إدارة الباقات', 'Manage Packages', 'packages', 'إنشاء وتعديل باقات الساعات والخدمات', 'Create and manage packages', true, true, true, false),
  ('packages.sell', 'بيع الباقات', 'Sell Packages', 'packages', 'بيع الباقات للعملاء', 'Sell packages to customers', true, true, true, true),
  ('pricing.manage', 'إدارة التسعير والعروض', 'Manage Pricing', 'pricing', 'تعديل أسعار الغرف والأجهزة والعروض', 'Manage room pricing and offers', true, true, true, false),
  ('growth.view', 'عرض تحليلات النمو', 'View Growth Insights', 'analytics', 'عرض تقارير النمو ومؤشرات الأداء', 'View growth analytics and KPIs', true, true, true, false),
  ('crm.view', 'عرض قائمة العملاء', 'View CRM Data', 'crm', 'عرض بيانات وسجل العملاء', 'View customer list and history', true, true, true, false),
  ('crm.view_contact', 'عرض بيانات الاتصال', 'View Customer Contact Info', 'crm', 'عرض رقم هاتف وأيميل العميل', 'View customer phone and email', true, true, false, false),
  ('campaigns.manage', 'إدارة الحملات التسويقية', 'Manage Campaigns', 'campaigns', 'إنشاء وإدارة الحملات الإعلانية والإشعارات', 'Create and manage marketing campaigns', true, true, false, false),
  ('canteen.combos.manage', 'إدارة عروض الكانتين', 'Manage Canteen Combos', 'canteen', 'إنشاء وتعديل العروض المجمعة للكانتين', 'Manage canteen combo offers', true, true, true, false),
  ('audit.view', 'عرض سجل العمليات', 'View Audit Log', 'audit', 'عرض سجل الأحداث والعمليات الحساسة', 'View sensitive audit log events', true, true, true, false),
  ('groups.manage', 'إدارة المجموعات', 'Manage Groups', 'groups', 'إدارة مجموعات الأصدقاء والفرق', 'Manage user groups and teams', true, true, true, false)
ON CONFLICT (key) DO UPDATE SET
  name_ar = EXCLUDED.name_ar,
  name_en = EXCLUDED.name_en,
  category = EXCLUDED.category,
  description_ar = EXCLUDED.description_ar,
  description_en = EXCLUDED.description_en,
  default_super_admin = EXCLUDED.default_super_admin,
  default_owner = EXCLUDED.default_owner,
  default_manager = EXCLUDED.default_manager,
  default_cashier = EXCLUDED.default_cashier;

-- Helper Function: has_lounge_access
CREATE OR REPLACE FUNCTION public.has_lounge_access(
  p_lounge_id uuid,
  p_min_role text DEFAULT 'staff'
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $f$
DECLARE
  v_role text;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN false;
  END IF;

  v_role := private.permission_role(auth.uid(), p_lounge_id);
  IF v_role IS NULL THEN
    RETURN false;
  END IF;

  IF v_role = 'super_admin' THEN
    RETURN true;
  END IF;

  CASE lower(btrim(p_min_role))
    WHEN 'owner' THEN RETURN v_role = 'owner';
    WHEN 'manager' THEN RETURN v_role IN ('owner', 'manager');
    WHEN 'cashier' THEN RETURN v_role IN ('owner', 'manager', 'cashier');
    WHEN 'staff' THEN RETURN v_role IN ('owner', 'manager', 'cashier', 'staff');
    ELSE RETURN false;
  END CASE;
END;
$f$;

REVOKE ALL ON FUNCTION public.has_lounge_access(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_lounge_access(uuid, text) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 5. Feature Flags Table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.feature_flags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key text NOT NULL,
  lounge_id uuid REFERENCES public.lounges(id) ON DELETE CASCADE,
  enabled boolean NOT NULL DEFAULT false,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Partial Unique Indexes for Global vs Lounge Flags
CREATE UNIQUE INDEX IF NOT EXISTS idx_feature_flags_key_global
  ON public.feature_flags (key) WHERE lounge_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_feature_flags_key_lounge
  ON public.feature_flags (key, lounge_id) WHERE lounge_id IS NOT NULL;

-- Indexes for Fast Lookups
CREATE INDEX IF NOT EXISTS idx_feature_flags_key ON public.feature_flags(key);
CREATE INDEX IF NOT EXISTS idx_feature_flags_lounge_id ON public.feature_flags(lounge_id);

-- Enable RLS
ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "feature_flags_read_policy" ON public.feature_flags;
CREATE POLICY "feature_flags_read_policy"
  ON public.feature_flags FOR SELECT
  TO authenticated
  USING (
    lounge_id IS NULL OR public.has_lounge_access(lounge_id, 'staff')
  );

DROP POLICY IF EXISTS "feature_flags_super_admin_write" ON public.feature_flags;
CREATE POLICY "feature_flags_super_admin_write"
  ON public.feature_flags FOR ALL
  TO authenticated
  USING (
    private.permission_role(auth.uid(), NULL) = 'super_admin'
  )
  WITH CHECK (
    private.permission_role(auth.uid(), NULL) = 'super_admin'
  );

-- Helper function to evaluate feature flag status
CREATE OR REPLACE FUNCTION public.is_feature_enabled(
  p_key text,
  p_lounge_id uuid DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $f$
DECLARE
  v_enabled boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN false;
  END IF;

  -- 1. Check lounge specific flag first
  IF p_lounge_id IS NOT NULL THEN
    SELECT enabled INTO v_enabled
    FROM public.feature_flags
    WHERE key = p_key AND lounge_id = p_lounge_id;

    IF v_enabled IS NOT NULL THEN
      RETURN v_enabled;
    END IF;
  END IF;

  -- 2. Fall back to global flag (lounge_id IS NULL)
  SELECT enabled INTO v_enabled
  FROM public.feature_flags
  WHERE key = p_key AND lounge_id IS NULL;

  RETURN COALESCE(v_enabled, false);
END;
$f$;

REVOKE ALL ON FUNCTION public.is_feature_enabled(text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_feature_enabled(text, uuid) TO authenticated, service_role;

COMMIT;
