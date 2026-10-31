BEGIN;
INSERT INTO profiles VALUES ('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000011','owner',true,false,true),('00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000012','owner',true,false,true),('00000000-0000-0000-0000-000000000003',NULL,'super_admin',true,true,true);
INSERT INTO rooms VALUES ('00000000-0000-0000-0000-000000000021','00000000-0000-0000-0000-000000000011','available',true,now());
INSERT INTO bookings VALUES ('00000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000021','upcoming'),('00000000-0000-0000-0000-000000000032','00000000-0000-0000-0000-000000000021','upcoming');
DO $$ DECLARE room uuid:='00000000-0000-0000-0000-000000000021'; checks integer:=0; denied boolean;target text; BEGIN
 PERFORM set_config('test.actor','00000000-0000-0000-0000-000000000001',true);
 PERFORM set_room_operational_status(room,'maintenance'); checks:=checks+1;
 denied:=false; BEGIN UPDATE bookings SET status='in_progress' WHERE id='00000000-0000-0000-0000-000000000031'; EXCEPTION WHEN object_not_in_prerequisite_state THEN denied:=true; END;
 IF NOT denied THEN RAISE EXCEPTION 'Started during maintenance'; END IF;checks:=checks+1;
 PERFORM set_room_operational_status(room,'available');
 UPDATE bookings SET status='in_progress' WHERE id='00000000-0000-0000-0000-000000000031';
 PERFORM set_room_operational_status(room,'occupied');checks:=checks+1;
 FOREACH target IN ARRAY ARRAY['available','maintenance'] LOOP
  denied:=false; BEGIN PERFORM set_room_operational_status(room,target); EXCEPTION WHEN object_not_in_prerequisite_state THEN denied:=true; END;
  IF NOT denied THEN RAISE EXCEPTION 'Overrode active room: %',target; END IF;checks:=checks+1;
 END LOOP;
 denied:=false; BEGIN UPDATE rooms SET is_available=true WHERE id=room; EXCEPTION WHEN object_not_in_prerequisite_state THEN denied:=true; END;
 IF NOT denied THEN RAISE EXCEPTION 'Bypassed through room table'; END IF;checks:=checks+1;
 denied:=false; BEGIN UPDATE bookings SET status='in_progress' WHERE id='00000000-0000-0000-0000-000000000032'; EXCEPTION WHEN object_not_in_prerequisite_state THEN denied:=true; END;
 IF NOT denied THEN RAISE EXCEPTION 'Two active sessions'; END IF;checks:=checks+1;
 UPDATE bookings SET status='completed' WHERE id='00000000-0000-0000-0000-000000000031'; PERFORM set_room_operational_status(room,'available');checks:=checks+1;
 FOREACH target IN ARRAY ARRAY['00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000003',''] LOOP
  PERFORM set_config('test.actor',target,true);denied:=false;
  BEGIN PERFORM set_room_operational_status(room,'occupied'); EXCEPTION WHEN insufficient_privilege OR invalid_authorization_specification THEN denied:=true; END;
  IF NOT denied THEN RAISE EXCEPTION 'Unauthorized room actor'; END IF;checks:=checks+1;
 END LOOP;
 IF has_function_privilege('anon','public.set_room_operational_status(uuid,text)','EXECUTE') THEN RAISE EXCEPTION 'Anonymous room grant'; END IF;checks:=checks+1;
 RAISE NOTICE '% checks passed',checks;
END $$;
ROLLBACK;
