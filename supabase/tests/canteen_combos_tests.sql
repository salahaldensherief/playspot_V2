-- Canteen Combos, Upsell Engine & Inventory Tests
DO $test$
DECLARE
  v_count integer;
BEGIN
  -- 1. Verify Combos Tables Exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'canteen_combos'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: canteen_combos table missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'canteen_combo_items'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: canteen_combo_items table missing';
  END IF;

  -- 2. Verify Upsell Tables Exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'upsell_rules'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: upsell_rules table missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'upsell_events'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: upsell_events table missing';
  END IF;

  -- 3. Verify canteen_order_items Columns
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'canteen_order_items' AND column_name = 'line_kind'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: canteen_order_items.line_kind column missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'canteen_order_items' AND column_name = 'combo_id'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: canteen_order_items.combo_id column missing';
  END IF;

  -- 4. Verify RPC Execution Privileges (anon revoked)
  IF pg_catalog.has_function_privilege('anon', 'public.place_canteen_order(uuid,jsonb,text,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'TEST FAILED: place_canteen_order must NOT be executable by anon';
  END IF;

  IF pg_catalog.has_function_privilege('anon', 'public.get_canteen_menu(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'TEST FAILED: get_canteen_menu must NOT be executable by anon';
  END IF;

  IF pg_catalog.has_function_privilege('anon', 'public.record_upsell_event(uuid,uuid,text,uuid,numeric)', 'EXECUTE') THEN
    RAISE EXCEPTION 'TEST FAILED: record_upsell_event must NOT be executable by anon';
  END IF;

  -- 5. Verify Analytical Views
  SELECT COUNT(*) INTO v_count
  FROM information_schema.views
  WHERE table_schema = 'public' AND table_name IN (
    'canteen_attach_rate_v', 'canteen_aov_v', 'canteen_top_combos_v',
    'canteen_upsell_conversion_v', 'canteen_low_stock_alerts_v'
  );

  IF v_count < 5 THEN
    RAISE EXCEPTION 'TEST FAILED: Missing one or more canteen growth views';
  END IF;

  RAISE NOTICE 'SUCCESS: All Canteen Combos, Upsell & Inventory tests passed successfully!';
END;
$test$;
