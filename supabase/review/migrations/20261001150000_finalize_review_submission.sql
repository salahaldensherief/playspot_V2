BEGIN;
CREATE OR REPLACE FUNCTION public.submit_lounge_review(
 p_lounge_id uuid,p_id_document_path text,p_business_document_path text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
 v_lounge public.lounges%ROWTYPE;
 v_snapshot jsonb;
 v_request private.lounge_review_requests%ROWTYPE;
 v_revision integer;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='28000'; END IF;
 SELECT * INTO v_lounge FROM public.lounges WHERE id=p_lounge_id FOR UPDATE;
 IF NOT FOUND OR v_lounge.owner_id IS DISTINCT FROM auth.uid() THEN
  RAISE EXCEPTION 'LOUNGE_OWNER_REQUIRED' USING ERRCODE='42501';
 END IF;
 IF v_lounge.status NOT IN ('pending','rejected') THEN
  RAISE EXCEPTION 'LOUNGE_REVIEW_STATE_CONFLICT' USING ERRCODE='55000';
 END IF;
 IF NULLIF(btrim(v_lounge.name),'') IS NULL OR NULLIF(btrim(v_lounge.city),'') IS NULL
  OR NULLIF(btrim(v_lounge.address),'') IS NULL OR NULLIF(btrim(v_lounge.contact_phone),'') IS NULL
  OR v_lounge.opening_time IS NULL OR v_lounge.closing_time IS NULL
  OR v_lounge.location_point IS NULL
  OR (NULLIF(btrim(v_lounge.vodafone_cash_number),'') IS NULL
      AND NULLIF(btrim(v_lounge.instapay_account),'') IS NULL) THEN
  RAISE EXCEPTION 'LOUNGE_PROFILE_INCOMPLETE' USING ERRCODE='22023';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.rooms WHERE lounge_id=p_lounge_id AND is_active IS TRUE) THEN
  RAISE EXCEPTION 'LOUNGE_RESOURCES_REQUIRED' USING ERRCODE='22023';
 END IF;
 IF p_id_document_path IS NULL OR split_part(p_id_document_path,'/',1)<>auth.uid()::text
  OR p_id_document_path LIKE '%..%' OR p_id_document_path LIKE '%://%'
  OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='kyc-documents' AND name=p_id_document_path) THEN
  RAISE EXCEPTION 'INVALID_ID_DOCUMENT' USING ERRCODE='22023';
 END IF;
 IF p_business_document_path IS NOT NULL AND (
  split_part(p_business_document_path,'/',1)<>auth.uid()::text
  OR p_business_document_path LIKE '%..%' OR p_business_document_path LIKE '%://%'
  OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='kyc-documents' AND name=p_business_document_path)) THEN
  RAISE EXCEPTION 'INVALID_BUSINESS_DOCUMENT' USING ERRCODE='22023';
 END IF;
 v_snapshot:=jsonb_build_object('lounge',to_jsonb(v_lounge)-ARRAY['status','is_active','is_open','updated_at'],
  'rooms',(SELECT jsonb_agg(to_jsonb(r) ORDER BY r.id) FROM public.rooms r WHERE lounge_id=p_lounge_id),
  'extras',(SELECT COALESCE(jsonb_agg(to_jsonb(e) ORDER BY e.id),'[]'::jsonb) FROM public.extras e WHERE lounge_id=p_lounge_id));
 SELECT * INTO v_request FROM private.lounge_review_requests WHERE lounge_id=p_lounge_id AND status='pending';
 IF FOUND THEN
  IF v_request.snapshot=v_snapshot AND v_request.id_document_path=p_id_document_path
   AND v_request.business_document_path IS NOT DISTINCT FROM p_business_document_path THEN
   RETURN jsonb_build_object('success',true,'request_id',v_request.id,'revision',v_request.revision,'status','pending','idempotent',true);
  END IF;
  RAISE EXCEPTION 'PENDING_REVIEW_IMMUTABLE' USING ERRCODE='55000';
 END IF;
 SELECT COALESCE(max(revision),0)+1 INTO v_revision FROM private.lounge_review_requests WHERE lounge_id=p_lounge_id;
 UPDATE public.lounges SET status='pending',is_active=false,is_open=false WHERE id=p_lounge_id;
 INSERT INTO private.lounge_review_requests(lounge_id,owner_id,revision,snapshot,id_document_path,business_document_path)
 VALUES(p_lounge_id,auth.uid(),v_revision,v_snapshot,p_id_document_path,p_business_document_path) RETURNING * INTO v_request;
 UPDATE public.profiles SET is_setup_completed=true,updated_at=now()
  WHERE id=auth.uid() AND lounge_id=p_lounge_id;
 RETURN jsonb_build_object('success',true,'request_id',v_request.id,'revision',v_revision,'status','pending','idempotent',false);
END;
$$;

COMMIT;
