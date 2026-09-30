-- Run only in the isolated database initialized by open_time_local_fixture.sql.
BEGIN;
INSERT INTO public.lounges(id,status,is_open,is_active,allow_cash_payment,
  require_prepaid_first_time,allow_open_time_sessions,open_time_minimum_minutes,
  open_time_rounding_minutes,open_time_max_minutes)
VALUES ('00000000-0000-0000-0000-000000000001','approved',true,true,true,true,true,60,15,720);
INSERT INTO public.rooms(id,lounge_id,name,status,is_available,is_active,hourly_rate_single,hourly_rate_multi)
VALUES ('00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','Test room','available',true,true,100,150);
INSERT INTO public.shifts(id,lounge_id,status,opened_at)
VALUES ('00000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','open',now());
DO $$
BEGIN
  BEGIN
    PERFORM public.start_open_time_session('00000000-0000-0000-0000-000000000002');
    RAISE EXCEPTION 'Unauthenticated start incorrectly accepted';
  EXCEPTION WHEN SQLSTATE '28000' THEN NULL;
  END;
END $$;
SET LOCAL test.actor = '00000000-0000-0000-0000-000000000004';
DO $$
BEGIN
  BEGIN
    PERFORM public.start_open_time_session('00000000-0000-0000-0000-000000000002');
    RAISE EXCEPTION 'Unauthorized start incorrectly accepted';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;
END $$;
SET LOCAL test.allowed = 'true';
DO $$
DECLARE v_result jsonb; v_id uuid; v_booking public.bookings%ROWTYPE;
BEGIN
  v_result := public.start_open_time_session('00000000-0000-0000-0000-000000000002');
  v_id := (v_result->>'booking_id')::uuid;
  SELECT * INTO v_booking FROM public.bookings WHERE id=v_id;
  ASSERT v_booking.status = 'in_progress', 'Session did not start';
  ASSERT v_booking.payment_status = 'unpaid', 'Starting session incorrectly collected cash';
  ASSERT v_booking.is_first_booking IS FALSE, 'Guest incorrectly treated as first app booking';
  ASSERT v_booking.duration_minutes = 60, 'Zero or maximum duration used for initial quote';
  ASSERT NOT EXISTS(SELECT 1 FROM public.payments), 'Starting session wrote payment';
  BEGIN
    PERFORM public.start_open_time_session('00000000-0000-0000-0000-000000000002');
    RAISE EXCEPTION 'Duplicate start incorrectly accepted';
  EXCEPTION WHEN SQLSTATE '55000' THEN NULL;
  END;
  UPDATE public.bookings SET open_time_started_at=now()-interval '90 minutes' WHERE id=v_id;
  v_result := public.complete_booking_session(v_id,auth.uid());
  ASSERT (v_result->>'final_total')::numeric=150, 'Completion total missing or incorrect';
  ASSERT (public.complete_booking_session(v_id,auth.uid())->>'final_total')::numeric=150,
    'Retry changed a completed bill';
  PERFORM public.complete_booking_payment(v_id,'cash',150);
  SELECT * INTO v_booking FROM public.bookings WHERE id=v_id;
  ASSERT v_booking.status='completed', 'Collection restarted a closed session';
  ASSERT v_booking.payment_status='paid', 'Collection did not mark payment';
  ASSERT (SELECT amount FROM public.payments WHERE booking_id=v_id)=150;
  ASSERT (SELECT amount FROM public.shift_payments WHERE booking_id=v_id)=150;
  BEGIN
    PERFORM public.complete_booking_payment(v_id,'cash',150);
    RAISE EXCEPTION 'Duplicate collection incorrectly accepted';
  EXCEPTION WHEN SQLSTATE '55000' THEN NULL;
  END;
  ASSERT (SELECT count(*) FROM public.shift_payments WHERE booking_id=v_id)=1;
  UPDATE public.bookings SET payment_status='unpaid' WHERE id=v_id;
  UPDATE public.shifts SET status='closed',closed_at=now();
  BEGIN
    PERFORM public.complete_booking_payment(v_id,'cash',150);
    RAISE EXCEPTION 'Collection without open shift incorrectly accepted';
  EXCEPTION WHEN SQLSTATE '55000' THEN NULL;
  END;
END $$;
ROLLBACK;
