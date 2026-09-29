-- Unified Pricing Engine Integrity & Security Test Suite
DO $test$
DECLARE
  v_lounge_id uuid := gen_random_uuid();
  v_room_id uuid := gen_random_uuid();
  v_rule_id uuid;
  v_quote jsonb;
  v_total numeric;
  v_has_peak boolean;
  v_conflict_thrown boolean := false;
BEGIN
  -- 1. Verify Table Existence
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'pricing_rules'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: pricing_rules table missing';
  END IF;

  -- 2. Verify bookings Columns
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'pricing_snapshot'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: bookings.pricing_snapshot column missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'pricing_rule_ids'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: bookings.pricing_rule_ids column missing';
  END IF;

  -- 3. Verify Function Privileges (anon revoked)
  IF pg_catalog.has_function_privilege('anon', 'public.quote_booking_price(uuid,date,time,time,text,int,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'TEST FAILED: quote_booking_price must NOT be executable by anon';
  END IF;

  IF pg_catalog.has_function_privilege('anon', 'public.upsert_pricing_rule(uuid,text,text,smallint[],time,time,text,numeric,uuid,uuid,uuid,text,date,date,text,int,boolean)', 'EXECUTE') THEN
    RAISE EXCEPTION 'TEST FAILED: upsert_pricing_rule must NOT be executable by anon';
  END IF;

  -- 4. Test Structure Verification: Check Constraints
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.pricing_rules'::regclass
      AND conname LIKE '%rule_type%'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: rule_type check constraint missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.pricing_rules'::regclass
      AND conname LIKE '%adjustment_type%'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: adjustment_type check constraint missing';
  END IF;

  RAISE NOTICE 'SUCCESS: All Pricing Engine schema, privilege, and integrity tests passed successfully!';
END;
$test$;
