BEGIN;
CREATE OR REPLACE FUNCTION public.review_lounge_request(
 p_request_id uuid,p_revision integer,p_approve boolean,p_notes text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_request private.lounge_review_requests%ROWTYPE; v_lounge_id uuid;
BEGIN
 IF auth.uid() IS NULL OR public.is_super_admin() IS NOT TRUE THEN
  RAISE EXCEPTION 'SUPER_ADMIN_REQUIRED' USING ERRCODE='42501';
 END IF;
 IF p_revision IS NULL OR p_revision<1 OR p_approve IS NULL
  OR (p_approve IS FALSE AND NULLIF(btrim(p_notes),'') IS NULL) THEN
  RAISE EXCEPTION 'INVALID_REVIEW_DECISION' USING ERRCODE='22023';
 END IF;
 SELECT lounge_id INTO v_lounge_id FROM private.lounge_review_requests WHERE id=p_request_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'REVIEW_NOT_FOUND' USING ERRCODE='P0002'; END IF;
 PERFORM 1 FROM public.lounges WHERE id=v_lounge_id FOR UPDATE;
 SELECT * INTO v_request FROM private.lounge_review_requests WHERE id=p_request_id FOR UPDATE;
 IF v_request.revision<>p_revision THEN RAISE EXCEPTION 'REVIEW_REVISION_CONFLICT' USING ERRCODE='55000'; END IF;
 IF v_request.status<>'pending' THEN
  IF v_request.reviewer_id=auth.uid() AND v_request.status=(CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END)
   AND v_request.notes IS NOT DISTINCT FROM NULLIF(btrim(p_notes),'') THEN
   RETURN jsonb_build_object('success',true,'request_id',v_request.id,'status',v_request.status,'idempotent',true);
  END IF;
  RAISE EXCEPTION 'REVIEW_ALREADY_DECIDED' USING ERRCODE='55000';
 END IF;
 IF (SELECT owner_id FROM public.lounges WHERE id=v_lounge_id) IS DISTINCT FROM v_request.owner_id THEN
  RAISE EXCEPTION 'LOUNGE_OWNER_CHANGED' USING ERRCODE='55000';
 END IF;
 IF v_request.snapshot IS DISTINCT FROM jsonb_build_object(
  'lounge',(SELECT to_jsonb(l)-ARRAY['status','is_active','is_open','updated_at'] FROM public.lounges l WHERE id=v_lounge_id),
  'rooms',(SELECT jsonb_agg(to_jsonb(r) ORDER BY r.id) FROM public.rooms r WHERE lounge_id=v_lounge_id),
  'extras',(SELECT COALESCE(jsonb_agg(to_jsonb(e) ORDER BY e.id),'[]'::jsonb) FROM public.extras e WHERE lounge_id=v_lounge_id)) THEN
  RAISE EXCEPTION 'REVIEW_DATA_CHANGED' USING ERRCODE='55000';
 END IF;
 UPDATE private.lounge_review_requests SET status=CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
  reviewer_id=auth.uid(),notes=NULLIF(btrim(p_notes),''),reviewed_at=now() WHERE id=p_request_id;
 UPDATE public.lounges SET status=CASE WHEN p_approve THEN 'active' ELSE 'rejected' END,
  is_active=p_approve,is_open=false WHERE id=v_lounge_id;
 UPDATE public.profiles SET is_active=CASE WHEN p_approve THEN true ELSE is_active END,
  is_setup_completed=p_approve,updated_at=now()
  WHERE id=v_request.owner_id AND lounge_id=v_lounge_id;
 INSERT INTO public.notifications(user_id,title,title_ar,title_en,body,body_ar,body_en,type,metadata)
 VALUES(v_request.owner_id,
  CASE WHEN p_approve THEN 'KYC Approved' ELSE 'KYC Rejected' END,
  CASE WHEN p_approve THEN 'تم قبول بيانات الصالة' ELSE 'تحتاج بيانات الصالة إلى تعديل' END,
  CASE WHEN p_approve THEN 'Lounge review approved' ELSE 'Lounge review rejected' END,
  COALESCE(NULLIF(btrim(p_notes),''),'Lounge review completed'),
  CASE WHEN p_approve THEN 'تم قبول البيانات. فتح الصالة للحجوزات يتطلب شيفتًا واتصالًا متاحًا.' ELSE btrim(p_notes) END,
  CASE WHEN p_approve THEN 'Data approved. Online booking requires an open shift and available connectivity.' ELSE btrim(p_notes) END,
  CASE WHEN p_approve THEN 'kyc_approved' ELSE 'kyc_rejected' END,
  jsonb_build_object('lounge_id',v_lounge_id,'request_id',p_request_id,'revision',p_revision,'approved',p_approve));
 RETURN jsonb_build_object('success',true,'request_id',p_request_id,'status',CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,'idempotent',false);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_lounge_review(p_lounge_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_review private.lounge_review_requests%ROWTYPE;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='28000'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.lounges WHERE id=p_lounge_id AND owner_id=auth.uid()) THEN
  RAISE EXCEPTION 'LOUNGE_OWNER_REQUIRED' USING ERRCODE='42501';
 END IF;
 SELECT * INTO v_review FROM private.lounge_review_requests
  WHERE lounge_id=p_lounge_id AND owner_id=auth.uid() ORDER BY revision DESC LIMIT 1;
 IF NOT FOUND THEN RETURN NULL; END IF;
 RETURN to_jsonb(v_review)||jsonb_build_object(
  'lounge_name',v_review.snapshot->'lounge'->>'name',
  'owner_name',(SELECT full_name FROM public.profiles WHERE id=auth.uid()),
  'owner_email',(SELECT email FROM public.profiles WHERE id=auth.uid()));
END;
$$;
REVOKE ALL ON FUNCTION public.get_my_lounge_review(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_my_lounge_review(uuid) TO authenticated;
CREATE OR REPLACE FUNCTION public.get_my_onboarding_draft(p_lounge_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_lounge public.lounges%ROWTYPE;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='28000'; END IF;
 SELECT * INTO v_lounge FROM public.lounges WHERE id=p_lounge_id AND owner_id=auth.uid();
 IF NOT FOUND THEN RAISE EXCEPTION 'LOUNGE_OWNER_REQUIRED' USING ERRCODE='42501'; END IF;
 IF v_lounge.status NOT IN ('pending','rejected') THEN
  RAISE EXCEPTION 'ONBOARDING_STATE_CONFLICT' USING ERRCODE='55000';
 END IF;
 RETURN jsonb_build_object('lounge',to_jsonb(v_lounge)||jsonb_build_object(
  'location_point',CASE WHEN v_lounge.location_point IS NULL THEN NULL ELSE public.st_asgeojson(v_lounge.location_point)::jsonb END),
  'review_notes',(SELECT notes FROM private.lounge_review_requests WHERE lounge_id=p_lounge_id
    AND owner_id=auth.uid() AND status='rejected' ORDER BY revision DESC LIMIT 1),
  'rooms',(SELECT COALESCE(jsonb_agg(to_jsonb(r) ORDER BY r.id),'[]'::jsonb) FROM public.rooms r WHERE lounge_id=p_lounge_id AND is_active IS DISTINCT FROM false),
  'extras',(SELECT COALESCE(jsonb_agg(to_jsonb(e) ORDER BY e.id),'[]'::jsonb) FROM public.extras e WHERE lounge_id=p_lounge_id AND is_active IS DISTINCT FROM false));
END;
$$;
REVOKE ALL ON FUNCTION public.get_my_onboarding_draft(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_my_onboarding_draft(uuid) TO authenticated;
COMMIT;
