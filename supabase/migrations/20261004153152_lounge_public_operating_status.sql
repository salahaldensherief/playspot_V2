-- Public availability reason: never exposes cashier, shift or device identities.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';
CREATE OR REPLACE FUNCTION public.get_lounge_operating_status(p_lounge_id uuid)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_lounge public.lounges%ROWTYPE; v_online boolean; v_fault boolean;
BEGIN
 SELECT * INTO v_lounge FROM public.lounges WHERE id=p_lounge_id AND status='active' AND is_active IS TRUE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','unavailable','can_book_online',false,'contact_phone',NULL); END IF;
 v_online:=public.get_lounge_online_availability(p_lounge_id);
 v_fault:=v_lounge.is_open IS TRUE AND NOT v_online
   AND EXISTS(SELECT 1 FROM public.shifts WHERE lounge_id=p_lounge_id AND status='open' AND closed_at IS NULL)
   AND EXISTS(SELECT 1 FROM private.cashier_writer_authorities w
     JOIN public.profiles p ON p.id=w.actor_id JOIN auth.users u ON u.id=p.id
     WHERE w.lounge_id=p_lounge_id AND p.is_active IS TRUE AND p.is_banned IS FALSE
       AND (w.online_requested IS FALSE OR w.heartbeat_expires_at<=clock_timestamp()));
 RETURN jsonb_build_object('status',CASE WHEN v_online THEN 'open' WHEN v_fault THEN 'technical_issue' ELSE 'closed' END,
   'can_book_online',v_online,'contact_phone',CASE WHEN v_fault THEN nullif(btrim(v_lounge.contact_phone),'') ELSE NULL END);
END; $$;
REVOKE ALL ON FUNCTION public.get_lounge_operating_status(uuid) FROM PUBLIC,service_role,supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.get_lounge_operating_status(uuid) TO anon,authenticated;
COMMIT;
