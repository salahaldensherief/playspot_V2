INSERT INTO public.app_permissions(key,name_ar,name_en,category,description_ar,description_en,default_super_admin,default_owner,default_cashier)
VALUES ('audit.view','عرض سجل التدقيق','View audit log','reports','عرض الأحداث المسجلة في نطاق الصالة','Read recorded events in the lounge scope',true,true,false)
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.get_audit_logs(
 p_lounge_id uuid DEFAULT NULL, p_entity_type text DEFAULT NULL, p_entity_id text DEFAULT NULL,
 p_user_id uuid DEFAULT NULL, p_severity text DEFAULT NULL, p_booking_id uuid DEFAULT NULL,
 p_start_date timestamptz DEFAULT NULL, p_end_date timestamptz DEFAULT NULL,
 p_last_id text DEFAULT NULL, p_last_created_at timestamptz DEFAULT NULL, p_limit integer DEFAULT 20
) RETURNS SETOF jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_actor uuid:=auth.uid(); v_global boolean;
BEGIN
 IF v_actor IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
 IF NOT EXISTS(SELECT FROM public.profiles p WHERE p.id=v_actor AND COALESCE(p.is_active,true) AND NOT COALESCE(p.is_banned,false)) THEN RAISE EXCEPTION 'Active account required' USING ERRCODE='42501'; END IF;
 v_global:=public.is_super_admin();
 IF p_lounge_id IS NULL AND NOT v_global THEN RAISE EXCEPTION 'Lounge scope required' USING ERRCODE='42501'; END IF;
 IF p_lounge_id IS NOT NULL AND NOT public.has_lounge_permission(p_lounge_id,'audit.view') THEN RAISE EXCEPTION 'Audit access denied' USING ERRCODE='42501'; END IF;
 IF p_limit IS NULL OR p_limit<1 OR p_limit>5000 OR (p_start_date IS NOT NULL AND p_end_date IS NOT NULL AND p_end_date<p_start_date) THEN RAISE EXCEPTION 'Invalid audit range' USING ERRCODE='22023'; END IF;
 IF p_last_id IS NOT NULL AND p_last_created_at IS NULL THEN RAISE EXCEPTION 'Incomplete cursor' USING ERRCODE='22023'; END IF;
 RETURN QUERY
 WITH events AS (
  SELECT 'room:'||r.id::text AS id,r.lounge_id,'room'::text AS entity_type,r.room_id::text AS entity_id,
   COALESCE(r.operation,'room_status_changed') AS action,r.changed_by AS actor_user_id,'info'::text AS severity,
   jsonb_build_object('status',r.old_status,'is_available',r.old_is_available) AS old_data,
   jsonb_build_object('status',r.new_status,'is_available',r.new_is_available) AS new_data,
   NULL::text AS reason,r.changed_at AS created_at,r.booking_id
  FROM public.room_status_audit r WHERE p_lounge_id IS NULL OR r.lounge_id=p_lounge_id
  UNION ALL
  SELECT 'shift:'||s.id::text,s.lounge_id,s.entity_type,s.entity_id::text,s.action,s.actor_user_id,'info',s.old_data,s.new_data,NULL,s.created_at,
   CASE WHEN s.entity_type='booking' THEN s.entity_id ELSE NULL END
  FROM public.shift_audit_logs s WHERE (p_lounge_id IS NULL OR s.lounge_id=p_lounge_id)
   AND public.has_lounge_permission(s.lounge_id,'shifts_view_blind_cash')
  UNION ALL
  SELECT 'cancellation:'||c.id::text,c.lounge_id,'booking',c.booking_id::text,'booking_cancelled',c.cancelled_by,'warning',
   jsonb_build_object('was_approved',c.was_approved),jsonb_build_object('status','cancelled','source',c.cancellation_source),c.cancellation_reason,c.cancelled_at,c.booking_id
  FROM private.booking_cancellation_events c WHERE p_lounge_id IS NULL OR c.lounge_id=p_lounge_id
  UNION ALL
  SELECT 'payout:'||a.id::text,p.lounge_id,'payout',a.payout_id::text,a.action,a.actor_user_id,'info',a.old_data,a.new_data,a.reason,a.created_at,NULL::uuid
  FROM public.payout_audit_logs a JOIN public.payouts p ON p.id=a.payout_id
  WHERE (p_lounge_id IS NULL OR p.lounge_id=p_lounge_id) AND public.has_lounge_permission(p.lounge_id,'payouts_manage')
  UNION ALL
  SELECT 'tournament:'||a.id::text,t.lounge_id,'tournament',a.tournament_id::text,a.action,a.actor_user_id,'info',a.old_data,a.new_data,a.reason,a.created_at,NULL::uuid
  FROM public.tournament_audit_logs a JOIN public.tournaments t ON t.id=a.tournament_id
  WHERE p_lounge_id IS NULL OR t.lounge_id=p_lounge_id
 )
 SELECT jsonb_build_object('id',e.id,'lounge_id',e.lounge_id,'entity_type',e.entity_type,'entity_id',e.entity_id,'action',e.action,
  'actor_user_id',e.actor_user_id,'actor_name',p.full_name,'actor_role',p.role,'severity',e.severity,'old_data',e.old_data,'new_data',e.new_data,'reason',e.reason,'created_at',e.created_at)
 FROM events e LEFT JOIN public.profiles p ON p.id=e.actor_user_id
 WHERE (p_entity_type IS NULL OR p_entity_type='all' OR e.entity_type=p_entity_type)
  AND (p_entity_id IS NULL OR e.entity_id=p_entity_id)
  AND (p_user_id IS NULL OR e.actor_user_id=p_user_id)
  AND (p_severity IS NULL OR p_severity='all' OR e.severity=p_severity)
  AND (p_booking_id IS NULL OR e.booking_id=p_booking_id)
  AND (p_start_date IS NULL OR e.created_at>=p_start_date)
  AND (p_end_date IS NULL OR e.created_at<=p_end_date)
  AND (p_last_created_at IS NULL OR e.created_at<p_last_created_at OR (e.created_at=p_last_created_at AND p_last_id IS NOT NULL AND e.id<p_last_id))
 ORDER BY e.created_at DESC,e.id DESC LIMIT p_limit;
END$$;
REVOKE ALL ON FUNCTION public.get_audit_logs(uuid,text,text,uuid,text,uuid,timestamptz,timestamptz,text,timestamptz,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_audit_logs(uuid,text,text,uuid,text,uuid,timestamptz,timestamptz,text,timestamptz,integer) TO authenticated;
NOTIFY pgrst,'reload schema';
