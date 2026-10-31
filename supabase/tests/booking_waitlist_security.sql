-- Run after applying the waitlist migration to an isolated test database.
DO $test$
BEGIN
  IF NOT (SELECT relrowsecurity FROM pg_catalog.pg_class
          WHERE oid = 'public.booking_waitlist'::regclass) THEN
    RAISE EXCEPTION 'Waitlist RLS must be enabled';
  END IF;
  IF pg_catalog.has_table_privilege('anon', 'public.booking_waitlist', 'SELECT')
     OR pg_catalog.has_table_privilege('authenticated', 'public.booking_waitlist', 'INSERT')
     OR pg_catalog.has_table_privilege('authenticated', 'public.booking_waitlist', 'UPDATE')
     OR pg_catalog.has_table_privilege('authenticated', 'public.booking_waitlist', 'DELETE') THEN
    RAISE EXCEPTION 'Waitlist direct writes or anonymous reads are exposed';
  END IF;
  IF NOT pg_catalog.has_table_privilege(
    'authenticated', 'public.booking_waitlist', 'SELECT'
  ) THEN
    RAISE EXCEPTION 'Customers must be able to read their own requests';
  END IF;
  IF pg_catalog.has_function_privilege(
    'anon', 'public.join_booking_waitlist(uuid,timestamp,timestamp)', 'EXECUTE'
  ) OR pg_catalog.has_function_privilege(
    'authenticated', 'public.process_booking_waitlist()', 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'Waitlist function grants are too broad';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_policies
    WHERE schemaname = 'public' AND tablename = 'booking_waitlist'
      AND policyname = 'booking_waitlist_read_own'
  ) THEN
    RAISE EXCEPTION 'Own-row read policy is missing';
  END IF;
END;
$test$;
