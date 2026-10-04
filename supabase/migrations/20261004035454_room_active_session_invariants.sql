-- A room row is the mutex shared by operational changes and session starts.
CREATE OR REPLACE FUNCTION private.guard_running_booking_room()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE room_status text;
BEGIN
 IF NEW.status::text <> 'in_progress' OR NEW.room_id IS NULL THEN RETURN NEW; END IF;
 SELECT r.status INTO room_status FROM public.rooms r WHERE r.id=NEW.room_id FOR UPDATE;
 IF NOT FOUND OR room_status IN ('maintenance','deleted') THEN
  RAISE EXCEPTION 'ROOM_NOT_AVAILABLE_FOR_SESSION' USING ERRCODE='55000';
 END IF;
 IF EXISTS(SELECT FROM public.bookings b WHERE b.room_id=NEW.room_id AND b.status::text='in_progress' AND b.id<>NEW.id) THEN
  RAISE EXCEPTION 'ROOM_HAS_ACTIVE_SESSION' USING ERRCODE='55000';
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION private.guard_running_booking_room() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER trg_guard_running_booking_room BEFORE INSERT OR UPDATE OF room_id,status
ON public.bookings FOR EACH ROW EXECUTE FUNCTION private.guard_running_booking_room();

CREATE OR REPLACE FUNCTION private.guard_active_room_state()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF (NEW.status IS DISTINCT FROM OLD.status OR NEW.is_available IS DISTINCT FROM OLD.is_available)
  AND (NEW.status IS DISTINCT FROM 'occupied' OR NEW.is_available IS DISTINCT FROM false)
  AND EXISTS(SELECT FROM public.bookings b WHERE b.room_id=NEW.id AND b.status::text='in_progress') THEN
  RAISE EXCEPTION 'ROOM_HAS_ACTIVE_SESSION' USING ERRCODE='55000';
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION private.guard_active_room_state() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER trg_guard_active_room_state BEFORE UPDATE OF status,is_available
ON public.rooms FOR EACH ROW EXECUTE FUNCTION private.guard_active_room_state();

CREATE OR REPLACE FUNCTION public.set_room_operational_status(p_room_id uuid,p_status text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_status text:=lower(btrim(COALESCE(p_status,'')));v_lounge_id uuid;v_required_permission text;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='28000'; END IF;
 IF NOT EXISTS(SELECT FROM public.profiles p WHERE p.id=auth.uid() AND COALESCE(p.is_active,true) AND NOT COALESCE(p.is_banned,false)) THEN
  RAISE EXCEPTION 'NOT_AUTHORIZED' USING ERRCODE='42501';
 END IF;
 IF p_room_id IS NULL THEN RAISE EXCEPTION 'ROOM_ID_REQUIRED' USING ERRCODE='22023'; END IF;
 IF v_status NOT IN ('available','occupied','maintenance') THEN RAISE EXCEPTION 'INVALID_ROOM_STATUS' USING ERRCODE='22023'; END IF;
 SELECT r.lounge_id INTO v_lounge_id FROM public.rooms r WHERE r.id=p_room_id AND r.status<>'deleted' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'ROOM_NOT_FOUND' USING ERRCODE='P0002'; END IF;
 v_required_permission:=CASE WHEN v_status='maintenance' THEN 'rooms_manage' ELSE 'sessions_control' END;
 IF NOT public.is_super_admin() AND NOT public.has_lounge_permission(v_lounge_id,v_required_permission) THEN
  RAISE EXCEPTION 'NOT_AUTHORIZED' USING ERRCODE='42501';
 END IF;
 UPDATE public.rooms SET status=v_status,is_available=(v_status='available'),updated_at=now() WHERE id=p_room_id;
 RETURN jsonb_build_object('success',true,'room_id',p_room_id,'lounge_id',v_lounge_id,'status',v_status,'is_available',(v_status='available'));
END $$;
REVOKE ALL ON FUNCTION public.set_room_operational_status(uuid,text) FROM PUBLIC,anon,supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.set_room_operational_status(uuid,text) TO authenticated,service_role;
NOTIFY pgrst,'reload schema';
