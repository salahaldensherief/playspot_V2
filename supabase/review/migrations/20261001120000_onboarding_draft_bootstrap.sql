BEGIN;
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
COMMIT;
