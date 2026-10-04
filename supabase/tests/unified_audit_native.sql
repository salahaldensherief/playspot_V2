BEGIN;
INSERT INTO public.profiles(id,role,lounge_id,full_name,can_audit) VALUES
 ('00000000-0000-0000-0000-000000000001','owner','00000000-0000-0000-0000-000000000010','Owner A',true),
 ('00000000-0000-0000-0000-000000000002','owner','00000000-0000-0000-0000-000000000011','Owner B',true),
 ('00000000-0000-0000-0000-000000000003','cashier','00000000-0000-0000-0000-000000000010','Cashier',false),
 ('00000000-0000-0000-0000-000000000004','super_admin',NULL,'Platform',true);
INSERT INTO public.room_status_audit VALUES
 ('00000000-0000-0000-0000-000000000021','00000000-0000-0000-0000-000000000030','00000000-0000-0000-0000-000000000010','00000000-0000-0000-0000-000000000040','available','occupied',true,false,'00000000-0000-0000-0000-000000000001','update','booking','2026-10-04T12:00:00Z'),
 ('00000000-0000-0000-0000-000000000022','00000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000010',NULL,'occupied','available',false,true,'00000000-0000-0000-0000-000000000001','update','booking','2026-10-04T12:00:00Z'),
 ('00000000-0000-0000-0000-000000000023','00000000-0000-0000-0000-000000000032','00000000-0000-0000-0000-000000000011',NULL,'occupied','available',false,true,'00000000-0000-0000-0000-000000000002','update','booking','2026-10-04T12:00:00Z');
INSERT INTO public.shift_audit_logs VALUES ('00000000-0000-0000-0000-000000000024','00000000-0000-0000-0000-000000000010','00000000-0000-0000-0000-000000000050','shift','00000000-0000-0000-0000-000000000050','update','00000000-0000-0000-0000-000000000001','{}','{"expected_cash":130}','2026-10-04T12:00:00Z');
INSERT INTO private.booking_cancellation_events VALUES (1,'00000000-0000-0000-0000-000000000040','00000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000010','Customer request','customer',true,'00000000-0000-0000-0000-000000000001','2026-10-04T12:00:00Z');
INSERT INTO public.payouts VALUES ('00000000-0000-0000-0000-000000000060','00000000-0000-0000-0000-000000000010');
INSERT INTO public.payout_audit_logs VALUES ('00000000-0000-0000-0000-000000000025','00000000-0000-0000-0000-000000000060','update','00000000-0000-0000-0000-000000000001','{}','{}','Reviewed','2026-10-04T12:00:00Z');
INSERT INTO public.tournaments VALUES ('00000000-0000-0000-0000-000000000070','00000000-0000-0000-0000-000000000010');
INSERT INTO public.tournament_audit_logs VALUES ('00000000-0000-0000-0000-000000000026','00000000-0000-0000-0000-000000000070','update','00000000-0000-0000-0000-000000000001','{}','{}','Reviewed','2026-10-04T12:00:00Z');
DO $$
DECLARE venue uuid:='00000000-0000-0000-0000-000000000010'; mode text; denied boolean; ids text[]:='{}'; page jsonb; last_id text; stamp timestamptz; n int; checks int:=0;
BEGIN
 PERFORM set_config('test.actor','00000000-0000-0000-0000-000000000001',true);
 SELECT count(*) INTO n FROM public.get_audit_logs(venue); IF n<>6 THEN RAISE EXCEPTION 'Venue leakage/count %',n; END IF; checks:=checks+1;
 SELECT count(*) INTO n FROM public.get_audit_logs(venue,p_severity=>'warning'); IF n<>1 THEN RAISE EXCEPTION 'Severity filter'; END IF; checks:=checks+1;
 SELECT count(*) INTO n FROM public.get_audit_logs(venue,p_entity_type=>'payout'); IF n<>1 THEN RAISE EXCEPTION 'Entity filter'; END IF; checks:=checks+1;
 SELECT count(*) INTO n FROM public.get_audit_logs(venue,p_booking_id=>'00000000-0000-0000-0000-000000000040'); IF n<>2 THEN RAISE EXCEPTION 'Booking linkage'; END IF; checks:=checks+1;
 SELECT count(*) INTO n FROM public.get_audit_logs(venue,p_start_date=>'2026-10-05'); IF n<>0 THEN RAISE EXCEPTION 'Date filter'; END IF; checks:=checks+1;
 FOR n IN 1..3 LOOP
  FOR page IN SELECT * FROM public.get_audit_logs(venue,p_last_id=>last_id,p_last_created_at=>stamp,p_limit=>2) LOOP
   IF page->>'id'=ANY(ids) THEN RAISE EXCEPTION 'Duplicate cursor row'; END IF;
   ids:=array_append(ids,page->>'id');last_id:=page->>'id';stamp:=(page->>'created_at')::timestamptz;
  END LOOP;
 END LOOP;
 IF cardinality(ids)<>6 THEN RAISE EXCEPTION 'Same-timestamp cursor lost rows'; END IF; checks:=checks+1;
 UPDATE public.profiles SET can_finance=false WHERE role='owner';
 SELECT count(*) INTO n FROM public.get_audit_logs(venue); IF n<>4 THEN RAISE EXCEPTION 'Financial privilege leakage'; END IF; checks:=checks+1;
 UPDATE public.profiles SET can_finance=true WHERE role='owner';
 FOR mode IN SELECT unnest(ARRAY['cashier','cross_venue','global_owner','banned','inactive','revoked','anonymous']) LOOP
  UPDATE public.profiles SET is_active=true,is_banned=false,can_audit=(role<>'cashier');
  PERFORM set_config('test.actor',CASE mode WHEN 'cashier' THEN '00000000-0000-0000-0000-000000000003' WHEN 'anonymous' THEN '' ELSE '00000000-0000-0000-0000-000000000001' END,true);
  IF mode='banned' THEN UPDATE public.profiles SET is_banned=true WHERE role='owner'; END IF;
  IF mode='inactive' THEN UPDATE public.profiles SET is_active=false WHERE role='owner'; END IF;
  IF mode='revoked' THEN UPDATE public.profiles SET can_audit=false WHERE role='owner'; END IF;
  denied:=false;
  BEGIN
   PERFORM public.get_audit_logs(CASE mode WHEN 'cross_venue' THEN '00000000-0000-0000-0000-000000000011'::uuid WHEN 'global_owner' THEN NULL ELSE venue END);
  EXCEPTION WHEN insufficient_privilege OR invalid_authorization_specification THEN denied:=true; END;
  IF NOT denied THEN RAISE EXCEPTION 'Denied actor succeeded: %',mode; END IF; checks:=checks+1;
 END LOOP;
 PERFORM set_config('test.actor','00000000-0000-0000-0000-000000000004',true);
 SELECT count(*) INTO n FROM public.get_audit_logs(); IF n<>7 THEN RAISE EXCEPTION 'Platform global scope'; END IF;checks:=checks+1;
 denied:=false; BEGIN PERFORM public.get_audit_logs(p_limit=>5001); EXCEPTION WHEN invalid_parameter_value THEN denied:=true; END; IF NOT denied THEN RAISE EXCEPTION 'Unbounded limit'; END IF;checks:=checks+1;
 denied:=false; BEGIN PERFORM public.get_audit_logs(p_last_id=>'room:x'); EXCEPTION WHEN invalid_parameter_value THEN denied:=true; END; IF NOT denied THEN RAISE EXCEPTION 'Incomplete cursor'; END IF;checks:=checks+1;
 IF has_function_privilege('anon','public.get_audit_logs(uuid,text,text,uuid,text,uuid,timestamptz,timestamptz,text,timestamptz,integer)','EXECUTE') THEN RAISE EXCEPTION 'Anonymous ACL'; END IF;checks:=checks+1;
 RAISE NOTICE '% checks passed',checks;
END$$;
ROLLBACK;
