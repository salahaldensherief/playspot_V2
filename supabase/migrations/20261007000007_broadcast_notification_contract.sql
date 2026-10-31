BEGIN;

CREATE OR REPLACE FUNCTION public.send_broadcast_notification(
  p_title_ar text,
  p_title_en text,
  p_body_ar text,
  p_body_en text,
  p_type text,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_inserted integer := 0;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000';
  END IF;

  IF NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501';
  END IF;

  IF NULLIF(btrim(COALESCE(p_title_ar,'')),'') IS NULL
     OR NULLIF(btrim(COALESCE(p_title_en,'')),'') IS NULL
     OR NULLIF(btrim(COALESCE(p_body_ar,'')),'') IS NULL
     OR NULLIF(btrim(COALESCE(p_body_en,'')),'') IS NULL THEN
    RAISE EXCEPTION 'BILINGUAL_NOTIFICATION_REQUIRED' USING ERRCODE='22023';
  END IF;

  INSERT INTO public.notifications (
    user_id,
    title_ar,
    title_en,
    body_ar,
    body_en,
    type,
    is_read,
    metadata
  )
  SELECT
    p.id,
    p_title_ar,
    p_title_en,
    p_body_ar,
    p_body_en,
    COALESCE(NULLIF(btrim(p_type),''),'system'),
    false,
    COALESCE(p_metadata,'{}'::jsonb)
  FROM public.profiles AS p
  WHERE COALESCE(p.is_active,true) IS TRUE
    AND COALESCE(p.is_banned,false) IS FALSE
    AND p.role = 'user';

  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  RETURN jsonb_build_object(
    'success', true,
    'recipient_count', v_inserted
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.send_broadcast_notification(
  text,text,text,text,text,jsonb
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.send_broadcast_notification(
  text,text,text,text,text,jsonb
) TO authenticated, service_role;

COMMIT;
