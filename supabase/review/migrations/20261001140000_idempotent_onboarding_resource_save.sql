BEGIN;
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
COMMIT;
