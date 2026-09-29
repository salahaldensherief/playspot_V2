-- Foundation Migration Integrity & Security Test Suite
DO $test$
DECLARE
  v_perm_count integer;
  v_test_lounge_id uuid := gen_random_uuid();
  v_bdate date;
BEGIN
  -- 1. Verify lounges.timezone column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'lounges' AND column_name = 'timezone'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: lounges.timezone column missing';
  END IF;

  -- 2. Verify business_date function security
  IF pg_catalog.has_function_privilege('anon', 'public.business_date(uuid,timestamptz)', 'EXECUTE') THEN
    RAISE EXCEPTION 'TEST FAILED: business_date must NOT be executable by anon';
  END IF;

  IF NOT pg_catalog.has_function_privilege('authenticated', 'public.business_date(uuid,timestamptz)', 'EXECUTE') THEN
    RAISE EXCEPTION 'TEST FAILED: business_date must be executable by authenticated';
  END IF;

  -- Test business_date fallback
  v_bdate := public.business_date(v_test_lounge_id, '2026-04-01 10:00:00+00'::timestamptz);
  IF v_bdate IS NULL THEN
    RAISE EXCEPTION 'TEST FAILED: business_date returned NULL';
  END IF;

  -- 3. Verify Constraints
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'bookings_payment_method_check' AND convalidated = true
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: bookings_payment_method_check constraint missing or not validated';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'shift_payments_category_check' AND convalidated = true
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: shift_payments_category_check constraint missing or not validated';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'notifications_type_check' AND convalidated = true
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: notifications_type_check constraint missing or not validated';
  END IF;

  -- 4. Verify Permission Keys
  SELECT COUNT(*) INTO v_perm_count
  FROM public.app_permissions
  WHERE key IN (
    'packages.manage', 'packages.sell', 'pricing.manage', 'growth.view',
    'crm.view', 'crm.view_contact', 'campaigns.manage', 'canteen.combos.manage',
    'audit.view', 'groups.manage'
  );

  IF v_perm_count <> 10 THEN
    RAISE EXCEPTION 'TEST FAILED: Expected 10 new permission keys, found %', v_perm_count;
  END IF;

  -- Verify manager default for campaigns.manage & crm.view_contact
  IF EXISTS (
    SELECT 1 FROM public.app_permissions
    WHERE key IN ('campaigns.manage', 'crm.view_contact') AND default_manager = true
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: Manager role should NOT have default access to campaigns.manage or crm.view_contact';
  END IF;

  -- 5. Verify feature_flags RLS & Helper Security
  IF NOT (SELECT relrowsecurity FROM pg_catalog.pg_class WHERE oid = 'public.feature_flags'::regclass) THEN
    RAISE EXCEPTION 'TEST FAILED: feature_flags RLS must be enabled';
  END IF;

  IF pg_catalog.has_function_privilege('anon', 'public.is_feature_enabled(text,uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'TEST FAILED: is_feature_enabled must NOT be executable by anon';
  END IF;

  RAISE NOTICE 'SUCCESS: All Foundation Migration integrity & security tests passed successfully!';
END;
$test$;
