BEGIN;
CREATE OR REPLACE FUNCTION public.set_booking_first_booking()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_completed_count integer;
BEGIN
  IF NEW.user_id IS NULL THEN
    IF auth.uid() IS NULL OR NOT EXISTS(SELECT 1 FROM public.profiles p JOIN auth.users u ON u.id=p.id
      WHERE p.id=auth.uid() AND p.is_active IS TRUE AND p.is_banned IS FALSE)
      OR NOT EXISTS(SELECT 1 FROM public.lounges WHERE id=NEW.lounge_id AND is_active IS TRUE AND status='active')
      OR (public.is_super_admin() IS NOT TRUE AND public.has_lounge_permission(NEW.lounge_id,'bookings.manage') IS NOT TRUE) THEN
      RAISE EXCEPTION 'WALK_IN_BOOKING_PERMISSION_DENIED' USING ERRCODE='42501';
    END IF;
    NEW.is_first_booking:=false;RETURN NEW;
  END IF;
  SELECT coalesce(completed_bookings_count,0) INTO v_completed_count FROM public.profiles WHERE id=NEW.user_id FOR UPDATE;
  NEW.is_first_booking:=(coalesce(v_completed_count,0)=0);
  RETURN NEW;
END; $$;
REVOKE ALL ON FUNCTION public.set_booking_first_booking() FROM PUBLIC,anon,authenticated;
COMMIT;
