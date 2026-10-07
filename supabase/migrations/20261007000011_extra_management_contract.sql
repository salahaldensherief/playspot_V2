BEGIN;

CREATE OR REPLACE FUNCTION public.save_lounge_extra(
  p_extra jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_id uuid;
  v_lounge_id uuid;
  v_existing public.extras%ROWTYPE;
  v_name_ar text;
  v_name_en text;
  v_name text;
  v_category text;
  v_price numeric;
  v_cost_price numeric;
  v_stock integer;
  v_min_stock integer;
  v_track_stock boolean;
  v_available boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000';
  END IF;

  IF p_extra IS NULL OR jsonb_typeof(p_extra) <> 'object' THEN
    RAISE EXCEPTION 'EXTRA_PAYLOAD_REQUIRED' USING ERRCODE='22023';
  END IF;

  BEGIN
    v_id := NULLIF(p_extra->>'id','')::uuid;
    v_lounge_id := NULLIF(p_extra->>'lounge_id','')::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    RAISE EXCEPTION 'INVALID_EXTRA_ID' USING ERRCODE='22023';
  END;

  IF v_lounge_id IS NULL THEN
    RAISE EXCEPTION 'LOUNGE_ID_REQUIRED' USING ERRCODE='22023';
  END IF;

  IF NOT (
    public.is_super_admin()
    OR public.has_lounge_permission(v_lounge_id, 'menu_manage_items')
  ) THEN
    RAISE EXCEPTION 'MENU_MANAGE_ITEMS_PERMISSION_REQUIRED' USING ERRCODE='42501';
  END IF;

  IF v_id IS NOT NULL THEN
    SELECT e.* INTO v_existing
    FROM public.extras AS e
    WHERE e.id=v_id
    FOR UPDATE;

    IF FOUND AND v_existing.lounge_id IS DISTINCT FROM v_lounge_id THEN
      RAISE EXCEPTION 'CROSS_LOUNGE_EXTRA' USING ERRCODE='42501';
    END IF;
  END IF;

  v_name_ar := NULLIF(btrim(COALESCE(p_extra->>'name_ar','')),'');
  v_name_en := NULLIF(btrim(COALESCE(p_extra->>'name_en','')),'');
  v_name := COALESCE(
    v_name_en,
    v_name_ar,
    NULLIF(btrim(COALESCE(p_extra->>'name','')),'')
  );
  IF v_name IS NULL THEN
    RAISE EXCEPTION 'EXTRA_NAME_REQUIRED' USING ERRCODE='22023';
  END IF;

  BEGIN
    v_price := COALESCE(NULLIF(p_extra->>'price','')::numeric,0);
    v_cost_price := NULLIF(p_extra->>'cost_price','')::numeric;
    v_stock := COALESCE(NULLIF(p_extra->>'stock_quantity','')::integer,0);
    v_min_stock := COALESCE(NULLIF(p_extra->>'min_stock_alert','')::integer,5);
  EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
    RAISE EXCEPTION 'INVALID_EXTRA_NUMERIC_VALUE' USING ERRCODE='22023';
  END;

  IF v_price < 0 OR (v_cost_price IS NOT NULL AND v_cost_price < 0)
     OR v_stock < 0 OR v_min_stock < 0 THEN
    RAISE EXCEPTION 'INVALID_EXTRA_NUMERIC_VALUE' USING ERRCODE='22023';
  END IF;

  v_category := lower(btrim(COALESCE(NULLIF(p_extra->>'category',''),'other')));
  v_track_stock := COALESCE((p_extra->>'track_stock')::boolean,false);
  v_available := COALESCE((p_extra->>'is_available')::boolean,true);

  IF v_id IS NULL THEN
    v_id := gen_random_uuid();
  END IF;

  INSERT INTO public.extras(
    id,lounge_id,name,name_ar,name_en,price,cost_price,category,
    icon_key,image_url,is_available,is_active,stock_quantity,
    track_stock,min_stock_alert
  )
  VALUES(
    v_id,v_lounge_id,v_name,v_name_ar,v_name_en,v_price,v_cost_price,v_category,
    NULLIF(btrim(COALESCE(p_extra->>'icon_key','')),''),
    NULLIF(btrim(COALESCE(p_extra->>'image_url','')),''),
    v_available,true,v_stock,v_track_stock,v_min_stock
  )
  ON CONFLICT(id) DO UPDATE SET
    name=EXCLUDED.name,
    name_ar=EXCLUDED.name_ar,
    name_en=EXCLUDED.name_en,
    price=EXCLUDED.price,
    cost_price=EXCLUDED.cost_price,
    category=EXCLUDED.category,
    icon_key=EXCLUDED.icon_key,
    image_url=EXCLUDED.image_url,
    is_available=EXCLUDED.is_available,
    stock_quantity=EXCLUDED.stock_quantity,
    track_stock=EXCLUDED.track_stock,
    min_stock_alert=EXCLUDED.min_stock_alert
  WHERE public.extras.lounge_id=EXCLUDED.lounge_id;

  RETURN (
    SELECT to_jsonb(e)
    FROM public.extras e
    WHERE e.id=v_id
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.set_lounge_extra_availability(
  p_extra_id uuid,
  p_is_available boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_extra public.extras%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000';
  END IF;

  SELECT e.* INTO v_extra
  FROM public.extras e
  WHERE e.id=p_extra_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'EXTRA_NOT_FOUND' USING ERRCODE='P0002';
  END IF;

  IF NOT (
    public.is_super_admin()
    OR public.has_lounge_permission(v_extra.lounge_id, 'menu_toggle_availability')
  ) THEN
    RAISE EXCEPTION 'MENU_TOGGLE_PERMISSION_REQUIRED' USING ERRCODE='42501';
  END IF;

  UPDATE public.extras
  SET is_available=p_is_available
  WHERE id=p_extra_id;

  RETURN jsonb_build_object(
    'success',true,
    'extra_id',p_extra_id,
    'is_available',p_is_available
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.archive_lounge_extra(
  p_extra_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_extra public.extras%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000';
  END IF;

  SELECT e.* INTO v_extra
  FROM public.extras e
  WHERE e.id=p_extra_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'EXTRA_NOT_FOUND' USING ERRCODE='P0002';
  END IF;

  IF NOT (
    public.is_super_admin()
    OR public.has_lounge_permission(v_extra.lounge_id, 'menu_manage_items')
  ) THEN
    RAISE EXCEPTION 'MENU_MANAGE_ITEMS_PERMISSION_REQUIRED' USING ERRCODE='42501';
  END IF;

  UPDATE public.extras
  SET is_active=false,
      is_available=false
  WHERE id=p_extra_id;

  RETURN jsonb_build_object(
    'success',true,
    'extra_id',p_extra_id,
    'archived',true
  );
END;
$function$;

REVOKE INSERT,UPDATE,DELETE ON public.extras FROM anon,authenticated;

REVOKE ALL ON FUNCTION public.save_lounge_extra(jsonb) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.set_lounge_extra_availability(uuid,boolean) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.archive_lounge_extra(uuid) FROM PUBLIC,anon;

GRANT EXECUTE ON FUNCTION public.save_lounge_extra(jsonb) TO authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.set_lounge_extra_availability(uuid,boolean) TO authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.archive_lounge_extra(uuid) TO authenticated,service_role;

COMMIT;
