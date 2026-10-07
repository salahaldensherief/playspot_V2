BEGIN;

CREATE OR REPLACE FUNCTION public.deactivate_lounge_admin(
  p_target_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_target public.profiles%ROWTYPE;
  v_unassigned_lounges integer := 0;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'SUPER_ADMIN_REQUIRED' USING ERRCODE = '42501';
  END IF;

  IF p_target_user_id IS NULL THEN
    RAISE EXCEPTION 'TARGET_USER_REQUIRED' USING ERRCODE = '22023';
  END IF;

  IF p_target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'CANNOT_DEACTIVATE_SELF' USING ERRCODE = '42501';
  END IF;

  SELECT p.*
  INTO v_target
  FROM public.profiles AS p
  WHERE p.id = p_target_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'TARGET_PROFILE_NOT_FOUND' USING ERRCODE = 'P0002';
  END IF;

  IF v_target.role IN ('super_admin', 'superadmin')
     OR EXISTS (
       SELECT 1
       FROM public.platform_super_admins AS sa
       WHERE sa.user_id = p_target_user_id
     ) THEN
    RAISE EXCEPTION 'CANNOT_DEACTIVATE_SUPER_ADMIN' USING ERRCODE = '42501';
  END IF;

  UPDATE public.lounges
  SET owner_id = NULL,
      updated_at = now()
  WHERE owner_id = p_target_user_id;
  GET DIAGNOSTICS v_unassigned_lounges = ROW_COUNT;

  DELETE FROM public.lounge_staff
  WHERE user_id = p_target_user_id;

  UPDATE public.profiles
  SET is_active = false,
      role = 'inactive',
      lounge_id = NULL,
      fcm_token = NULL,
      updated_at = now()
  WHERE id = p_target_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'target_user_id', p_target_user_id,
    'unassigned_lounges', v_unassigned_lounges
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.deactivate_lounge_admin(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.deactivate_lounge_admin(uuid)
TO authenticated, service_role;

COMMIT;
