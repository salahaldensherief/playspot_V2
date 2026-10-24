-- Manual regression against a disposable restore whose public/private fingerprint matched production.
-- Must run through a local Unix socket; all fixture rows are rolled back.
\set ON_ERROR_STOP on
DO $guard$
BEGIN
  IF inet_server_addr() IS NOT NULL THEN
    RAISE EXCEPTION 'ISOLATED_DATABASE_REQUIRED';
  END IF;
  IF md5(pg_get_functiondef('public.complete_booking_session(uuid,uuid)'::regprocedure))
     <> '0f389ab56f751d5e4453a7472402113d' THEN
    RAISE EXCEPTION 'PARTIAL_STATUS_MIGRATION_REQUIRED';
  END IF;
END;
$guard$;

BEGIN;
INSERT INTO auth.users(id) VALUES
  ('fffffff0-0000-0000-0000-000000000001'),
  ('fffffff0-0000-0000-0000-000000000002');
INSERT INTO public.profiles(id,role,is_active,is_banned) VALUES
  ('fffffff0-0000-0000-0000-000000000001','super_admin',true,false),
  ('fffffff0-0000-0000-0000-000000000002','user',true,false)
ON CONFLICT (id) DO UPDATE SET role=EXCLUDED.role,is_active=EXCLUDED.is_active,is_banned=EXCLUDED.is_banned;
INSERT INTO public.lounges(id,name,status,is_active,instapay_account,allow_cash_payment,require_prepaid_first_time)
VALUES ('fffffff0-0000-0000-0000-000000000010','Isolated regression','active',true,'TEST-ONLY',true,false);
INSERT INTO public.shifts(id,lounge_id,status,cashier_id,staff_user_id,opened_at)
VALUES ('fffffff0-0000-0000-0000-000000000030','fffffff0-0000-0000-0000-000000000010','open',
        'fffffff0-0000-0000-0000-000000000001','fffffff0-0000-0000-0000-000000000001',now());
INSERT INTO public.rooms(id,lounge_id,name,status,hourly_rate_single)
SELECT ('fffffff0-0000-0000-0000-00000000002'||n)::uuid,
       'fffffff0-0000-0000-0000-000000000010','Fixture '||n,'occupied',100
FROM generate_series(1,4) AS n;
INSERT INTO public.bookings(id,user_id,lounge_id,room_id,date,start_time,end_time,
  status,room_price,total_price,payment_status,payment_method,is_open_time,
  open_time_started_at,open_time_pricing_snapshot)
VALUES
  ('fffffff0-0000-0000-0000-000000000041','fffffff0-0000-0000-0000-000000000002',
   'fffffff0-0000-0000-0000-000000000010','fffffff0-0000-0000-0000-000000000021',
   current_date,'10:00','11:00','in_progress',100,100,'unpaid','cash',true,
   now()-interval '64 minutes',
   '{"effective_hourly_rate":100,"minimum_minutes":30,"rounding_minutes":15,"max_minutes":720}'),
  ('fffffff0-0000-0000-0000-000000000042','fffffff0-0000-0000-0000-000000000002',
   'fffffff0-0000-0000-0000-000000000010','fffffff0-0000-0000-0000-000000000022',
   current_date,'10:00','11:00','in_progress',100,100,'unpaid','cash',true,
   now()-interval '10 minutes',
   '{"effective_hourly_rate":100,"minimum_minutes":30,"rounding_minutes":15,"max_minutes":720}'),
  ('fffffff0-0000-0000-0000-000000000043','fffffff0-0000-0000-0000-000000000002',
   'fffffff0-0000-0000-0000-000000000010','fffffff0-0000-0000-0000-000000000023',
   current_date,'10:00','11:00','in_progress',100,100,'unpaid','cash',false,NULL,'{}'),
  ('fffffff0-0000-0000-0000-000000000044','fffffff0-0000-0000-0000-000000000002',
   'fffffff0-0000-0000-0000-000000000010','fffffff0-0000-0000-0000-000000000024',
   current_date,'10:00','11:00','in_progress',100,100,'unpaid','cash',true,
   now()-interval '200 minutes',
   '{"effective_hourly_rate":60,"minimum_minutes":30,"rounding_minutes":15,"max_minutes":120}');
INSERT INTO public.payments(booking_id,user_id,lounge_id,amount,commission_rate,commission,
  net_to_lounge,payment_method,status,paid_at)
VALUES
  ('fffffff0-0000-0000-0000-000000000041','fffffff0-0000-0000-0000-000000000002',
   'fffffff0-0000-0000-0000-000000000010',40,0.15,6,34,'cash','completed',now()),
  ('fffffff0-0000-0000-0000-000000000043','fffffff0-0000-0000-0000-000000000002',
   'fffffff0-0000-0000-0000-000000000010',100,0.15,15,85,'cash','completed',now());
INSERT INTO public.shift_payments(shift_id,lounge_id,booking_id,payment_method,category,amount,paid_at)
VALUES
  ('fffffff0-0000-0000-0000-000000000030','fffffff0-0000-0000-0000-000000000010',
   'fffffff0-0000-0000-0000-000000000041','cash','gaming_time',40,now()),
  ('fffffff0-0000-0000-0000-000000000030','fffffff0-0000-0000-0000-000000000010',
   'fffffff0-0000-0000-0000-000000000043','cash','gaming_time',100,now());
UPDATE public.bookings
SET status='in_progress',
    payment_status=CASE WHEN id='fffffff0-0000-0000-0000-000000000041' THEN 'partial'
                        WHEN id='fffffff0-0000-0000-0000-000000000043' THEN 'paid'
                        ELSE 'unpaid' END
WHERE id IN ('fffffff0-0000-0000-0000-000000000041',
             'fffffff0-0000-0000-0000-000000000042',
             'fffffff0-0000-0000-0000-000000000043',
             'fffffff0-0000-0000-0000-000000000044');

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub='fffffff0-0000-0000-0000-000000000002';
DO $denied$
BEGIN
  BEGIN
    PERFORM public.complete_booking_session('fffffff0-0000-0000-0000-000000000041');
    RAISE EXCEPTION 'unauthorized actor closed a session';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  IF has_function_privilege('anon','public.complete_booking_session(uuid,uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'anonymous function grant unexpectedly present';
  END IF;
END;
$denied$;
SET LOCAL request.jwt.claim.sub='fffffff0-0000-0000-0000-000000000001';
DO $test$
DECLARE r json; v_id uuid; v_status text; v_total numeric; v_paid numeric; v_due numeric; v_minutes integer;
BEGIN
  FOR v_id,v_status,v_total,v_paid,v_due,v_minutes IN
    SELECT * FROM (VALUES
      ('fffffff0-0000-0000-0000-000000000041'::uuid,'partial',125::numeric,40::numeric,85::numeric,75),
      ('fffffff0-0000-0000-0000-000000000042'::uuid,'unpaid',50::numeric,0::numeric,50::numeric,30),
      ('fffffff0-0000-0000-0000-000000000043'::uuid,'paid',100::numeric,100::numeric,0::numeric,NULL::integer),
      ('fffffff0-0000-0000-0000-000000000044'::uuid,'unpaid',120::numeric,0::numeric,120::numeric,120)
    ) AS expected(id,status,total,paid,due,minutes)
  LOOP
    SELECT public.complete_booking_session(v_id) INTO r;
    IF r->>'payment_status' IS DISTINCT FROM v_status
       OR (r->>'final_total')::numeric IS DISTINCT FROM v_total
       OR (r->>'amount_paid')::numeric IS DISTINCT FROM v_paid
       OR (r->>'amount_due')::numeric IS DISTINCT FROM v_due THEN
      RAISE EXCEPTION 'completion mismatch for %: %',v_id,r;
    END IF;
    IF (SELECT payment_status FROM public.bookings WHERE id=v_id) IS DISTINCT FROM v_status
       OR (SELECT open_time_billing_minutes FROM public.bookings WHERE id=v_id) IS DISTINCT FROM v_minutes THEN
      RAISE EXCEPTION 'stored classification/duration mismatch for %',v_id;
    END IF;
    SELECT public.complete_booking_session(v_id) INTO r;
    IF r->>'idempotent' IS DISTINCT FROM 'true' OR r->>'payment_status' IS DISTINCT FROM v_status THEN
      RAISE EXCEPTION 'duplicate close mismatch for %: %',v_id,r;
    END IF;
  END LOOP;
  IF (SELECT count(*) FROM public.payments WHERE booking_id IN
      ('fffffff0-0000-0000-0000-000000000041','fffffff0-0000-0000-0000-000000000043')) <> 2
     OR (SELECT sum(amount) FROM public.shift_payments WHERE booking_id IN
      ('fffffff0-0000-0000-0000-000000000041','fffffff0-0000-0000-0000-000000000043')) <> 140 THEN
    RAISE EXCEPTION 'completion fabricated or changed collected money';
  END IF;
END;
$test$;
ROLLBACK;
