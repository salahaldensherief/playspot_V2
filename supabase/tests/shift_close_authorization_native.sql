BEGIN;
INSERT INTO public.profiles(id,role,lounge_id) VALUES
 ('00000000-0000-0000-0000-000000000001','cashier','00000000-0000-0000-0000-000000000010'),
 ('00000000-0000-0000-0000-000000000002','cashier','00000000-0000-0000-0000-000000000010'),
 ('00000000-0000-0000-0000-000000000003','manager','00000000-0000-0000-0000-000000000010'),
 ('00000000-0000-0000-0000-000000000004','manager','00000000-0000-0000-0000-000000000011');
INSERT INTO public.shifts(id,lounge_id,cashier_id,staff_user_id) VALUES ('00000000-0000-0000-0000-000000000020','00000000-0000-0000-0000-000000000010','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001');
INSERT INTO public.shift_payments VALUES ('00000000-0000-0000-0000-000000000020','cash',50),('00000000-0000-0000-0000-000000000020','card',30);
INSERT INTO public.shift_expenses VALUES ('00000000-0000-0000-0000-000000000020','expense',20);
DO $$
DECLARE mode text; api text; actor text; outcome jsonb; denied boolean; passed int := 0;
BEGIN
 FOR api IN SELECT unnest(ARRAY['blind','legacy','lounge']) LOOP
  FOR mode IN SELECT unnest(ARRAY['other_cashier','other_venue_manager','banned','inactive','revoked','own','manager']) LOOP
   UPDATE public.profiles SET is_active=true,is_banned=false,can_close=true;
   UPDATE public.shifts SET status='open',closed_at=null;
   actor := CASE mode WHEN 'other_cashier' THEN '00000000-0000-0000-0000-000000000002' WHEN 'other_venue_manager' THEN '00000000-0000-0000-0000-000000000004' WHEN 'manager' THEN '00000000-0000-0000-0000-000000000003' ELSE '00000000-0000-0000-0000-000000000001' END;
   PERFORM set_config('test.actor',actor,true);
   IF mode='banned' THEN UPDATE public.profiles SET is_banned=true WHERE id=actor::uuid; END IF;
   IF mode='inactive' THEN UPDATE public.profiles SET is_active=false WHERE id=actor::uuid; END IF;
   IF mode='revoked' THEN UPDATE public.profiles SET can_close=false WHERE id=actor::uuid; END IF;
   denied := false;
   BEGIN
    IF api='blind' THEN outcome:=public.blind_close_shift('00000000-0000-0000-0000-000000000020','00000000-0000-0000-0000-000000000001',140,NULL);
    ELSIF api='lounge' THEN outcome:=to_jsonb(public.close_lounge_shift('00000000-0000-0000-0000-000000000010',140,NULL));
    ELSE outcome:=public.close_shift('00000000-0000-0000-0000-000000000020',140,NULL)::jsonb; END IF;
   EXCEPTION WHEN insufficient_privilege THEN denied:=true;
   END;
   IF mode IN ('own','manager') THEN
    IF denied OR (api<>'lounge' AND outcome->>'success' IS DISTINCT FROM 'true') OR outcome->>'status' IS DISTINCT FROM 'closed' THEN RAISE EXCEPTION '% % failed valid closure',api,mode; END IF;
    IF NOT EXISTS(SELECT FROM public.shifts WHERE status='closed' AND expected_cash=130 AND actual_cash_counted=140 AND difference=10) THEN RAISE EXCEPTION 'Financial regression: % %',api,mode; END IF;
    IF api='blind' AND mode='own' AND outcome->>'expected_cash' IS NOT NULL THEN RAISE EXCEPTION 'Blind cash disclosed'; END IF;
   ELSE
    IF NOT denied THEN RAISE EXCEPTION 'Unauthorized closure: % %',api,mode; END IF;
    IF EXISTS(SELECT FROM public.shifts WHERE status<>'open') THEN RAISE EXCEPTION 'Denied mutation persisted'; END IF;
   END IF;
   passed:=passed+1; RAISE NOTICE 'PASS % %',api,mode;
  END LOOP;
 END LOOP;
 IF has_function_privilege('anon','public.blind_close_shift(uuid,uuid,numeric,text)','EXECUTE') OR has_function_privilege('anon','public.close_shift(uuid,numeric,text)','EXECUTE') OR has_function_privilege('anon','public.close_lounge_shift(uuid,numeric,text)','EXECUTE') THEN RAISE EXCEPTION 'Anonymous execute grant'; END IF;
 IF NOT has_function_privilege('authenticated','public.blind_close_shift(uuid,uuid,numeric,text)','EXECUTE') THEN RAISE EXCEPTION 'Authenticated execution missing'; END IF;
 IF (SELECT count(*) FROM public.shift_audit_logs)<>2 THEN RAISE EXCEPTION 'Blind closure audit missing'; END IF;
 passed:=passed+3; RAISE NOTICE 'PASS anonymous ACL, authenticated ACL and audit';
 RAISE NOTICE '% checks passed',passed;
END$$;
ROLLBACK;
