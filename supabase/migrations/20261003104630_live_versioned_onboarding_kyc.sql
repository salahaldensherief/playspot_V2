-- Authorized live KYC/onboarding rollout. No existing venue is activated.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
-- 20261001110000_versioned_lounge_review.sql
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
-- 20261001120000_onboarding_draft_bootstrap.sql
ALTER TABLE public.lounges DROP CONSTRAINT lounges_at_least_one_payment_method;
ALTER TABLE public.lounges ADD CONSTRAINT lounges_at_least_one_payment_method CHECK(status IN ('pending','rejected') OR NULLIF(btrim(vodafone_cash_number),'') IS NOT NULL OR NULLIF(btrim(instapay_account),'') IS NOT NULL) NOT VALID;
CREATE OR REPLACE FUNCTION public.onboard_lounge(p_name text, p_city text, p_lat double precision, p_lng double precision, p_location text, p_opens_at text, p_closes_at text, p_image_url text DEFAULT NULL::text, p_description_ar text DEFAULT NULL::text, p_description_en text DEFAULT NULL::text, p_images text[] DEFAULT NULL::text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_existing_lounge_id uuid;
  v_new_lounge_id uuid;
  v_is_super_admin boolean;
  v_location_point public.geography;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NULLIF(btrim(p_name),'') IS NULL OR ((p_lat IS NULL) <> (p_lng IS NULL)) OR p_lat NOT BETWEEN -90 AND 90 OR p_lng NOT BETWEEN -180 AND 180 THEN
    RAISE EXCEPTION 'INVALID_LOUNGE_DRAFT' USING ERRCODE='22023';
  END IF;
  PERFORM 1 FROM public.profiles WHERE id=v_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'OWNER_PROFILE_REQUIRED' USING ERRCODE='42501'; END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.platform_super_admins psa
    WHERE psa.user_id = v_user_id
  ) OR EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = v_user_id AND p.role = 'super_admin'
  ) INTO v_is_super_admin;

  SELECT p.lounge_id INTO v_existing_lounge_id
  FROM public.profiles p
  WHERE p.id = v_user_id
    AND p.role IN ('owner', 'lounge_admin')
    AND COALESCE(p.is_setup_completed, false) = false;

  IF v_existing_lounge_id IS NULL
     AND NOT v_is_super_admin
     AND NOT EXISTS (
       SELECT 1 FROM public.profiles p
       WHERE p.id = v_user_id
         AND p.role IN ('owner', 'lounge_admin')
     ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF p_lat IS NOT NULL AND p_lng IS NOT NULL THEN
    v_location_point := public.ST_SetSRID(public.ST_MakePoint(p_lng, p_lat), 4326)::public.geography;
  END IF;

  IF v_existing_lounge_id IS NOT NULL THEN
    UPDATE public.lounges
    SET name = COALESCE(p_name, name),
        city = COALESCE(p_city, city),
        location = COALESCE(p_location, location),
        location_point = COALESCE(v_location_point, location_point),
        opening_time = COALESCE(NULLIF(p_opens_at, '')::time, opening_time),
        closing_time = COALESCE(NULLIF(p_closes_at, '')::time, closing_time),
        image_url = COALESCE(p_image_url, image_url),
        images = COALESCE(p_images, images),
        description_ar = COALESCE(p_description_ar, description_ar),
        description_en = COALESCE(p_description_en, description_en),
        status = 'pending',
        is_open = false,
        is_active = false
    WHERE id = v_existing_lounge_id AND owner_id=v_user_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'LOUNGE_OWNER_REQUIRED' USING ERRCODE='42501'; END IF;

    UPDATE public.profiles
    SET is_setup_completed = false,
        updated_at = now()
    WHERE id = v_user_id;

    RETURN jsonb_build_object(
      'success', true,
      'lounge_id', v_existing_lounge_id,
      'status', 'pending'
    );
  END IF;

  INSERT INTO public.lounges (
    owner_id, name, city, location, location_point, opening_time, closing_time,
    image_url, images, description_ar, description_en,
    is_open, is_active, status
  ) VALUES (
    v_user_id, p_name, p_city, p_location, v_location_point,
    NULLIF(p_opens_at, '')::time,
    NULLIF(p_closes_at, '')::time,
    p_image_url, p_images, p_description_ar, p_description_en,
    false, false, 'pending'
  )
  RETURNING id INTO v_new_lounge_id;

  UPDATE public.profiles
  SET lounge_id = v_new_lounge_id,
      is_setup_completed = false,
      updated_at = now()
  WHERE id = v_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'lounge_id', v_new_lounge_id,
    'status', 'pending'
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.onboard_lounge(text,text,double precision,double precision,text,text,text,text,text,text,text[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.onboard_lounge(text,text,double precision,double precision,text,text,text,text,text,text,text[]) TO authenticated;
-- 20261001170000_onboarding_omitted_resources.sql
CREATE OR REPLACE FUNCTION public.batch_complete_onboarding(p_lounge_id uuid, p_lounge_data jsonb, p_rooms jsonb, p_extras jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_owner_id uuid := auth.uid();
  v_updated_count integer;
BEGIN
  IF v_owner_id IS NULL THEN
    RAISE EXCEPTION 'Authentication is required'
      USING ERRCODE = '42501';
  END IF;


  PERFORM 1 FROM public.lounges WHERE id=p_lounge_id AND owner_id=v_owner_id AND status IN ('pending','rejected') FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'OWNED_DRAFT_REQUIRED' USING ERRCODE='42501'; END IF;
  IF EXISTS(SELECT 1 FROM public.bookings WHERE lounge_id=p_lounge_id AND status='in_progress') THEN
    RAISE EXCEPTION 'ONBOARDING_OPERATIONAL_CONFLICT' USING ERRCODE='55000';
  END IF;
  IF p_rooms IS NULL OR jsonb_typeof(p_rooms)<>'array' OR jsonb_array_length(p_rooms)<1 OR jsonb_array_length(p_rooms)>250
    OR p_extras IS NULL OR jsonb_typeof(p_extras)<>'array' OR jsonb_array_length(p_extras)>500 THEN
    RAISE EXCEPTION 'INVALID_ONBOARDING_RESOURCES' USING ERRCODE='22023';
  END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_rooms) r WHERE NULLIF(r->>'id','') IS NULL
    OR NULLIF(btrim(r->>'name'),'') IS NULL OR COALESCE((r->>'max_capacity')::integer,0)<1
    OR COALESCE((r->>'hourly_rate_single')::numeric,-1)<0 OR COALESCE((r->>'hourly_rate_multi')::numeric,-1)<0
    OR (r->>'hourly_rate_single') IN ('NaN','Infinity','-Infinity') OR (r->>'hourly_rate_multi') IN ('NaN','Infinity','-Infinity'))
    OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_extras) e WHERE NULLIF(e->>'id','') IS NULL
      OR NULLIF(btrim(e->>'name'),'') IS NULL OR COALESCE((e->>'price')::numeric,-1)<0 OR (e->>'price') IN ('NaN','Infinity','-Infinity')) THEN
    RAISE EXCEPTION 'INVALID_ONBOARDING_RESOURCE_FIELDS' USING ERRCODE='22023';
  END IF;
  IF (SELECT count(*) FROM jsonb_array_elements(p_rooms))<>(SELECT count(DISTINCT r->>'id') FROM jsonb_array_elements(p_rooms) r)
    OR (SELECT count(*) FROM jsonb_array_elements(p_extras))<>(SELECT count(DISTINCT e->>'id') FROM jsonb_array_elements(p_extras) e) THEN
    RAISE EXCEPTION 'DUPLICATE_ONBOARDING_RESOURCE' USING ERRCODE='22023';
  END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_rooms) r JOIN public.rooms existing ON existing.id=(r->>'id')::uuid WHERE existing.lounge_id<>p_lounge_id)
    OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_extras) e JOIN public.extras existing ON existing.id=(e->>'id')::uuid WHERE existing.lounge_id<>p_lounge_id) THEN
    RAISE EXCEPTION 'CROSS_LOUNGE_RESOURCE' USING ERRCODE='42501';
  END IF;

  IF p_lounge_data IS NOT NULL
     AND jsonb_typeof(p_lounge_data) <> 'object'
  THEN
    RAISE EXCEPTION 'p_lounge_data must be a JSON object';
  END IF;

  IF p_rooms IS NOT NULL
     AND jsonb_typeof(p_rooms) <> 'array'
  THEN
    RAISE EXCEPTION 'p_rooms must be a JSON array';
  END IF;

  IF p_extras IS NOT NULL
     AND jsonb_typeof(p_extras) <> 'array'
  THEN
    RAISE EXCEPTION 'p_extras must be a JSON array';
  END IF;

  IF p_lounge_data ? 'brand_id'
     AND NULLIF(p_lounge_data->>'brand_id', '') IS NOT NULL
     AND NOT EXISTS (
       SELECT 1
       FROM public.brands b
       WHERE b.id = (p_lounge_data->>'brand_id')::uuid
         AND b.owner_id = v_owner_id
     )
  THEN
    RAISE EXCEPTION 'Brand does not belong to the authenticated owner'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.lounges l
  SET
    vodafone_cash_number=CASE WHEN p_lounge_data ? 'vodafone_cash_number' THEN NULLIF(btrim(p_lounge_data->>'vodafone_cash_number'),'') ELSE l.vodafone_cash_number END,
    instapay_account=CASE WHEN p_lounge_data ? 'instapay_account' THEN NULLIF(btrim(p_lounge_data->>'instapay_account'),'') ELSE l.instapay_account END,
    name = COALESCE(p_lounge_data->>'name', l.name),
    name_ar = COALESCE(p_lounge_data->>'name_ar', l.name_ar),
    name_en = COALESCE(p_lounge_data->>'name_en', l.name_en),

    brand_id = CASE
      WHEN p_lounge_data ? 'brand_id'
        THEN NULLIF(p_lounge_data->>'brand_id', '')::uuid
      ELSE l.brand_id
    END,

    branch_name = CASE
      WHEN p_lounge_data ? 'branch_name'
        THEN NULLIF(p_lounge_data->>'branch_name', '')
      ELSE l.branch_name
    END,

    city = COALESCE(p_lounge_data->>'city', l.city),

    city_id = CASE
      WHEN p_lounge_data ? 'city_id'
        THEN NULLIF(p_lounge_data->>'city_id', '')::uuid
      ELSE l.city_id
    END,

    location = COALESCE(p_lounge_data->>'location', l.location),

    opening_time = CASE
      WHEN p_lounge_data ? 'opening_time'
        THEN NULLIF(p_lounge_data->>'opening_time', '')::time
      ELSE l.opening_time
    END,

    closing_time = CASE
      WHEN p_lounge_data ? 'closing_time'
        THEN NULLIF(p_lounge_data->>'closing_time', '')::time
      ELSE l.closing_time
    END,

    image_url = COALESCE(p_lounge_data->>'image_url', l.image_url),

    images = CASE
      WHEN jsonb_typeof(p_lounge_data->'images') = 'array' THEN
        ARRAY(
          SELECT jsonb_array_elements_text(p_lounge_data->'images')
        )
      WHEN p_lounge_data->'images' = 'null'::jsonb THEN NULL
      ELSE l.images
    END,

    description_ar = COALESCE(
      p_lounge_data->>'description_ar', l.description_ar
    ),

    description_en = COALESCE(
      p_lounge_data->>'description_en', l.description_en
    ),

    address = COALESCE(p_lounge_data->>'address', l.address),

    contact_phone = COALESCE(
      p_lounge_data->>'contact_phone', l.contact_phone
    ),

    location_point = CASE
      WHEN NULLIF(p_lounge_data->>'lat', '') IS NOT NULL
       AND NULLIF(p_lounge_data->>'lng', '') IS NOT NULL
      THEN public.ST_SetSRID(
        public.ST_MakePoint(
          (p_lounge_data->>'lng')::double precision,
          (p_lounge_data->>'lat')::double precision
        ),
        4326
      )::public.geography
      ELSE l.location_point
    END

  WHERE l.id = p_lounge_id
    AND l.owner_id = v_owner_id;

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;

  IF v_updated_count <> 1 THEN
    RAISE EXCEPTION 'Lounge not found or not owned by the authenticated user'
      USING ERRCODE = '42501';
  END IF;

  IF p_rooms IS NOT NULL AND jsonb_array_length(p_rooms) > 0 THEN
    INSERT INTO public.rooms (
      id,
      lounge_id,
      name,
      photo_url,
      images,
      features,
      is_available,
      controllers_count,
      screen_size,
      status,
      name_ar,
      name_en,
      features_ar,
      features_en,
      description_ar,
      description_en,
      extra_controller_price,
      device_type,
      room_type,
      hourly_rate_single,
      hourly_rate_multi,
      max_capacity,
      description,
      is_active,
      space_type_id
    )
    SELECT
      r.id,
      p_lounge_id,
      r.name,
      r.photo_url,
      r.images,
      r.features,
      COALESCE(r.is_available, true),
      COALESCE(r.controllers_count, 2),
      COALESCE(r.screen_size, '43"'),
      COALESCE(r.status, 'available'),
      r.name_ar,
      r.name_en,
      r.features_ar,
      r.features_en,
      r.description_ar,
      r.description_en,
      COALESCE(r.extra_controller_price, 0),
      r.device_type,
      COALESCE(r.room_type, 'standard'),
      COALESCE(r.hourly_rate_single, 0),
      COALESCE(r.hourly_rate_multi, 0),
      COALESCE(r.max_capacity, 4),
      r.description,
      COALESCE(r.is_active, true),
      r.space_type_id
    FROM jsonb_populate_recordset(
      NULL::public.rooms,
      p_rooms
    ) AS r ON CONFLICT(id) DO UPDATE SET
      name=EXCLUDED.name,
      photo_url=EXCLUDED.photo_url,
      images=EXCLUDED.images,
      features=EXCLUDED.features,
      controllers_count=EXCLUDED.controllers_count,
      screen_size=EXCLUDED.screen_size,
      name_ar=EXCLUDED.name_ar,
      name_en=EXCLUDED.name_en,
      features_ar=EXCLUDED.features_ar,
      features_en=EXCLUDED.features_en,
      description_ar=EXCLUDED.description_ar,
      description_en=EXCLUDED.description_en,
      extra_controller_price=EXCLUDED.extra_controller_price,
      device_type=EXCLUDED.device_type,
      room_type=EXCLUDED.room_type,
      hourly_rate_single=EXCLUDED.hourly_rate_single,
      hourly_rate_multi=EXCLUDED.hourly_rate_multi,
      max_capacity=EXCLUDED.max_capacity,
      description=EXCLUDED.description,
      is_active=EXCLUDED.is_active,
      space_type_id=EXCLUDED.space_type_id;
  END IF;

  IF p_extras IS NOT NULL AND jsonb_array_length(p_extras) > 0 THEN
    INSERT INTO public.extras (
      id,
      lounge_id,
      name,
      price,
      category,
      icon,
      is_available,
      name_ar,
      name_en,
      is_active,
      stock_quantity,
      track_stock,
      min_stock_alert,
      icon_key,
      image_url
    )
    SELECT
      e.id,
      p_lounge_id,
      e.name,
      e.price,
      e.category,
      e.icon,
      COALESCE(e.is_available, true),
      e.name_ar,
      e.name_en,
      COALESCE(e.is_active, true),
      COALESCE(e.stock_quantity, 0),
      COALESCE(e.track_stock, true),
      COALESCE(e.min_stock_alert, 5),
      COALESCE(e.icon_key, 'fastfood'),
      e.image_url
    FROM jsonb_populate_recordset(
      NULL::public.extras,
      p_extras
    ) AS e ON CONFLICT(id) DO UPDATE SET
      name=EXCLUDED.name,
      price=EXCLUDED.price,
      category=EXCLUDED.category,
      icon=EXCLUDED.icon,
      is_available=EXCLUDED.is_available,
      name_ar=EXCLUDED.name_ar,
      name_en=EXCLUDED.name_en,
      is_active=EXCLUDED.is_active,
      stock_quantity=EXCLUDED.stock_quantity,
      track_stock=EXCLUDED.track_stock,
      min_stock_alert=EXCLUDED.min_stock_alert,
      icon_key=EXCLUDED.icon_key,
      image_url=EXCLUDED.image_url;
  END IF;

  IF EXISTS(SELECT 1 FROM public.bookings b
    WHERE b.lounge_id=p_lounge_id AND b.status::text IN ('pending','upcoming','in_progress')
    AND NOT EXISTS(SELECT 1 FROM jsonb_to_recordset(p_rooms) AS chosen(id uuid) WHERE chosen.id=b.room_id)) THEN
    RAISE EXCEPTION 'RESOURCE_HAS_BOOKINGS' USING ERRCODE='55000';
  END IF;
  UPDATE public.rooms r SET is_active=false,is_available=false
   WHERE r.lounge_id=p_lounge_id AND NOT EXISTS(
    SELECT 1 FROM jsonb_to_recordset(p_rooms) AS chosen(id uuid) WHERE chosen.id=r.id);
  UPDATE public.extras e SET is_active=false,is_available=false
   WHERE e.lounge_id=p_lounge_id AND NOT EXISTS(
    SELECT 1 FROM jsonb_to_recordset(COALESCE(p_extras,'[]'::jsonb)) AS chosen(id uuid) WHERE chosen.id=e.id);

  UPDATE public.profiles
  SET is_setup_completed = false,
      updated_at = now()
  WHERE id = v_owner_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Owner profile not found';
  END IF;
END;
$function$;
REVOKE ALL ON FUNCTION public.batch_complete_onboarding(uuid,jsonb,jsonb,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.batch_complete_onboarding(uuid,jsonb,jsonb,jsonb) TO authenticated;
-- 20261001150000_finalize_review_submission.sql
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

-- 20261001160000_owner_review_status_and_rejection_reentry.sql
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
-- Retire legacy owner-wide approval and mutable unversioned submission.
REVOKE ALL ON FUNCTION public.review_kyc(uuid,boolean,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.submit_kyc_documents(text,text) FROM PUBLIC,anon,authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
