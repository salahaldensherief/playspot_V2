BEGIN;
CREATE SCHEMA IF NOT EXISTS private;
CREATE TABLE private.lounge_review_requests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 lounge_id uuid NOT NULL REFERENCES public.lounges(id),
 owner_id uuid NOT NULL REFERENCES auth.users(id),
 revision integer NOT NULL CHECK(revision>0),
 snapshot jsonb NOT NULL CHECK(jsonb_typeof(snapshot)='object'),
 id_document_path text NOT NULL,
 business_document_path text,
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected')),
 reviewer_id uuid REFERENCES auth.users(id),
 notes text,
 created_at timestamptz NOT NULL DEFAULT now(),
 reviewed_at timestamptz,
 UNIQUE(lounge_id,revision)
);
CREATE UNIQUE INDEX lounge_review_one_pending ON private.lounge_review_requests(lounge_id) WHERE status='pending';
ALTER TABLE private.lounge_review_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.lounge_review_requests FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.freeze_pending_review_data() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_lounge_id uuid; v_old_lounge_id uuid;
BEGIN
 IF TG_TABLE_NAME='lounges' THEN
  v_lounge_id:=COALESCE(NEW.id,OLD.id);
 ELSE
  IF TG_OP<>'DELETE' THEN v_lounge_id:=NEW.lounge_id; END IF;
  IF TG_OP<>'INSERT' THEN v_old_lounge_id:=OLD.lounge_id; END IF;
 END IF;
 PERFORM 1 FROM public.lounges WHERE id IN (v_lounge_id,v_old_lounge_id) ORDER BY id FOR UPDATE;
 IF EXISTS(SELECT 1 FROM private.lounge_review_requests
  WHERE lounge_id IN (v_lounge_id,v_old_lounge_id) AND status='pending') THEN
  RAISE EXCEPTION 'PENDING_REVIEW_IMMUTABLE' USING ERRCODE='55000';
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF;
 RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.freeze_pending_review_data() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER freeze_pending_lounge_review BEFORE UPDATE OR DELETE ON public.lounges
 FOR EACH ROW EXECUTE FUNCTION private.freeze_pending_review_data();
CREATE TRIGGER freeze_pending_room_review BEFORE INSERT OR UPDATE OR DELETE ON public.rooms
 FOR EACH ROW EXECUTE FUNCTION private.freeze_pending_review_data();
CREATE TRIGGER freeze_pending_extra_review BEFORE INSERT OR UPDATE OR DELETE ON public.extras
 FOR EACH ROW EXECUTE FUNCTION private.freeze_pending_review_data();

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
  OR v_lounge.location_point IS NULL THEN
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
 RETURN jsonb_build_object('success',true,'request_id',v_request.id,'revision',v_revision,'status','pending','idempotent',false);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_lounge_review_requests() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL OR public.is_super_admin() IS NOT TRUE THEN
  RAISE EXCEPTION 'SUPER_ADMIN_REQUIRED' USING ERRCODE='42501';
 END IF;
 RETURN (SELECT COALESCE(jsonb_agg(to_jsonb(r)||jsonb_build_object(
  'owner_name',(SELECT full_name FROM public.profiles WHERE id=r.owner_id),
  'owner_email',(SELECT email FROM public.profiles WHERE id=r.owner_id),
  'lounge_name',r.snapshot->'lounge'->>'name') ORDER BY created_at,id),'[]'::jsonb)
  FROM private.lounge_review_requests r WHERE status='pending');
END;
$$;

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
 IF p_approve THEN
  UPDATE public.profiles SET is_active=true,is_setup_completed=true,updated_at=now()
   WHERE id=v_request.owner_id AND lounge_id=v_lounge_id;
 END IF;
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
REVOKE ALL ON FUNCTION public.submit_lounge_review(uuid,text,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.get_lounge_review_requests() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.review_lounge_request(uuid,integer,boolean,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.submit_lounge_review(uuid,text,text),public.get_lounge_review_requests(),public.review_lounge_request(uuid,integer,boolean,text) TO authenticated;
COMMIT;
