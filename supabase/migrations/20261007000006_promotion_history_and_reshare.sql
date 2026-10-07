BEGIN;

ALTER TABLE public.promotions
  ADD COLUMN IF NOT EXISTS archived_at timestamptz,
  ADD COLUMN IF NOT EXISTS archived_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS reshared_from_id uuid REFERENCES public.promotions(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS promotions_lounge_history_idx
  ON public.promotions (lounge_id, is_active, created_at DESC);

CREATE INDEX IF NOT EXISTS promotions_reshared_from_idx
  ON public.promotions (reshared_from_id)
  WHERE reshared_from_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.delete_promotion(p_promotion_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_lounge_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000';
  END IF;

  SELECT p.lounge_id
  INTO v_lounge_id
  FROM public.promotions AS p
  WHERE p.id = p_promotion_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Promotion not found' USING ERRCODE='P0002';
  END IF;

  IF NOT private.can_manage_promotion(v_lounge_id) THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501';
  END IF;

  UPDATE public.promotions
  SET is_active = false,
      archived_at = COALESCE(archived_at, now()),
      archived_by = COALESCE(archived_by, auth.uid())
  WHERE id = p_promotion_id;

  RETURN jsonb_build_object(
    'success', true,
    'promo_id', p_promotion_id,
    'archived', true
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.reshare_promotion(p_promotion_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_source public.promotions%ROWTYPE;
  v_new_id uuid;
  v_duration interval;
  v_new_expiry timestamptz;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000';
  END IF;

  SELECT p.*
  INTO v_source
  FROM public.promotions AS p
  WHERE p.id = p_promotion_id
  FOR SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Promotion not found' USING ERRCODE='P0002';
  END IF;

  IF NOT private.can_manage_promotion(v_source.lounge_id) THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501';
  END IF;

  IF v_source.expires_at IS NULL THEN
    v_new_expiry := NULL;
  ELSE
    v_duration := v_source.expires_at - v_source.created_at;
    IF v_duration <= interval '0 seconds' THEN
      v_duration := interval '7 days';
    END IF;
    v_new_expiry := now() + v_duration;
  END IF;

  INSERT INTO public.promotions (
    title,
    tag,
    colors,
    icon_key,
    image_url,
    deep_link,
    is_active,
    title_ar,
    title_en,
    tag_ar,
    tag_en,
    lounge_id,
    expires_at,
    is_room_specific,
    room_id,
    target_audience,
    discount_type,
    discount_value,
    reshared_from_id
  )
  VALUES (
    v_source.title,
    v_source.tag,
    v_source.colors,
    v_source.icon_key,
    v_source.image_url,
    v_source.deep_link,
    true,
    v_source.title_ar,
    v_source.title_en,
    v_source.tag_ar,
    v_source.tag_en,
    v_source.lounge_id,
    v_new_expiry,
    v_source.is_room_specific,
    v_source.room_id,
    v_source.target_audience,
    v_source.discount_type,
    v_source.discount_value,
    v_source.id
  )
  RETURNING id INTO v_new_id;

  RETURN jsonb_build_object(
    'success', true,
    'promo_id', v_new_id,
    'reshared_from_id', v_source.id,
    'expires_at', v_new_expiry
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.reshare_promotion(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reshare_promotion(uuid) TO authenticated, service_role;

COMMIT;
