BEGIN;

CREATE OR REPLACE FUNCTION public.save_redemption_option_admin(
  p_option_id uuid,
  p_title_ar text,
  p_title_en text,
  p_description_ar text,
  p_description_en text,
  p_points_cost integer,
  p_reward_type text,
  p_reward_value numeric,
  p_is_active boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_id uuid;
  v_type text := lower(btrim(COALESCE(p_reward_type,'')));
  v_title text;
  v_description text;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'SUPER_ADMIN_REQUIRED' USING ERRCODE='42501';
  END IF;

  IF p_points_cost IS NULL OR p_points_cost <= 0 THEN
    RAISE EXCEPTION 'INVALID_POINTS_COST' USING ERRCODE='22023';
  END IF;

  IF v_type NOT IN ('discount_fixed','free_hour') THEN
    RAISE EXCEPTION 'INVALID_REWARD_TYPE' USING ERRCODE='22023';
  END IF;

  IF v_type = 'discount_fixed'
     AND (p_reward_value IS NULL OR p_reward_value <= 0) THEN
    RAISE EXCEPTION 'INVALID_REWARD_VALUE' USING ERRCODE='22023';
  END IF;

  IF v_type = 'free_hour'
     AND p_reward_value IS NOT NULL
     AND p_reward_value <= 0 THEN
    RAISE EXCEPTION 'INVALID_REWARD_VALUE' USING ERRCODE='22023';
  END IF;

  IF NULLIF(btrim(COALESCE(p_title_ar,'')),'') IS NULL
     OR NULLIF(btrim(COALESCE(p_title_en,'')),'') IS NULL THEN
    RAISE EXCEPTION 'BILINGUAL_TITLE_REQUIRED' USING ERRCODE='22023';
  END IF;

  v_title := COALESCE(
    NULLIF(btrim(p_title_en),''),
    NULLIF(btrim(p_title_ar),''),
    'Redemption Option'
  );
  v_description := COALESCE(
    NULLIF(btrim(COALESCE(p_description_en,'')),''),
    NULLIF(btrim(COALESCE(p_description_ar,'')),'')
  );

  IF p_option_id IS NULL THEN
    INSERT INTO public.redemption_options (
      title,
      description,
      points_cost,
      reward_type,
      reward_value,
      is_active,
      title_ar,
      title_en,
      description_ar,
      description_en
    )
    VALUES (
      v_title,
      v_description,
      p_points_cost,
      v_type,
      CASE
        WHEN v_type='free_hour' THEN COALESCE(p_reward_value,1)
        ELSE p_reward_value
      END,
      COALESCE(p_is_active,true),
      btrim(p_title_ar),
      btrim(p_title_en),
      NULLIF(btrim(COALESCE(p_description_ar,'')),''),
      NULLIF(btrim(COALESCE(p_description_en,'')),'')
    )
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.redemption_options
    SET title = v_title,
        description = v_description,
        points_cost = p_points_cost,
        reward_type = v_type,
        reward_value = CASE
          WHEN v_type='free_hour' THEN COALESCE(p_reward_value,1)
          ELSE p_reward_value
        END,
        is_active = COALESCE(p_is_active,true),
        title_ar = btrim(p_title_ar),
        title_en = btrim(p_title_en),
        description_ar = NULLIF(btrim(COALESCE(p_description_ar,'')),''),
        description_en = NULLIF(btrim(COALESCE(p_description_en,'')),'')
    WHERE id = p_option_id
    RETURNING id INTO v_id;

    IF v_id IS NULL THEN
      RAISE EXCEPTION 'REDEMPTION_OPTION_NOT_FOUND' USING ERRCODE='P0002';
    END IF;
  END IF;

  RETURN (
    SELECT to_jsonb(r)
    FROM public.redemption_options AS r
    WHERE r.id = v_id
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.archive_redemption_option_admin(
  p_option_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_updated uuid;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'SUPER_ADMIN_REQUIRED' USING ERRCODE='42501';
  END IF;

  UPDATE public.redemption_options
  SET is_active = false
  WHERE id = p_option_id
  RETURNING id INTO v_updated;

  IF v_updated IS NULL THEN
    RAISE EXCEPTION 'REDEMPTION_OPTION_NOT_FOUND' USING ERRCODE='P0002';
  END IF;

  RETURN jsonb_build_object(
    'success',true,
    'option_id',v_updated,
    'archived',true
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.save_redemption_option_admin(
  uuid,text,text,text,text,integer,text,numeric,boolean
) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.archive_redemption_option_admin(uuid)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.save_redemption_option_admin(
  uuid,text,text,text,text,integer,text,numeric,boolean
) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.archive_redemption_option_admin(uuid)
TO authenticated, service_role;

COMMIT;
