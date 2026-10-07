BEGIN;

CREATE OR REPLACE FUNCTION private.permission_key_allowed_for_role(
  p_role text,
  p_key text
)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
SET search_path TO ''
AS $function$
  SELECT CASE lower(btrim(COALESCE(p_role, '')))
    WHEN 'super_admin' THEN true
    WHEN 'owner' THEN p_key NOT IN (
      'analytics_view_global',
      'lounges_manage_all'
    )
    WHEN 'manager' THEN p_key NOT IN (
      'analytics_view_global',
      'lounges_manage_all',
      'payouts_manage'
    )
    WHEN 'cashier' THEN p_key NOT IN (
      'analytics_view_global',
      'lounges_manage_all',
      'payouts_manage',
      'staff_manage',
      'staff.manage',
      'shifts_review_and_approve',
      'lounges_manage_settings'
    )
    WHEN 'staff' THEN p_key NOT IN (
      'analytics_view_global',
      'lounges_manage_all',
      'payouts_manage',
      'staff_manage',
      'staff.manage',
      'shifts_review_and_approve',
      'lounges_manage_settings'
    )
    ELSE false
  END;
$function$;

CREATE OR REPLACE FUNCTION private.role_permission_value(
  p_role text,
  p_lounge_id uuid,
  p_key text
)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT CASE
    WHEN NOT private.permission_key_allowed_for_role(p_role, p_key) THEN false
    ELSE COALESCE((
      SELECT COALESCE(
        (
          SELECT lrp.is_enabled
          FROM public.lounge_role_permissions AS lrp
          WHERE lrp.lounge_id = p_lounge_id
            AND lrp.role = p_role
            AND lrp.permission_key = a.key
        ),
        CASE p_role
          WHEN 'super_admin' THEN a.default_super_admin
          WHEN 'owner' THEN a.default_owner
          WHEN 'manager' THEN a.default_owner
          WHEN 'cashier' THEN a.default_cashier
          ELSE false
        END,
        false
      )
      FROM public.app_permissions AS a
      WHERE a.key = p_key
    ), false)
  END;
$function$;

CREATE OR REPLACE FUNCTION public.get_lounge_role_permission_catalog(
  p_lounge_id uuid,
  p_role text
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_actor_role text := private.permission_role(auth.uid(), p_lounge_id);
  v_role text := lower(btrim(COALESCE(p_role, '')));
BEGIN
  IF v_actor_role IS NULL
     OR v_actor_role NOT IN ('super_admin','owner','manager') THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501';
  END IF;

  IF v_role NOT IN ('owner','manager','cashier','staff','super_admin') THEN
    RAISE EXCEPTION 'Unsupported permission role' USING ERRCODE='22023';
  END IF;

  RETURN COALESCE((
    SELECT jsonb_agg(
      jsonb_build_object(
        'permission_key', a.key,
        'name_ar', a.name_ar,
        'name_en', a.name_en,
        'category', a.category,
        'description_ar', a.description_ar,
        'description_en', a.description_en,
        'is_enabled', private.role_permission_value(v_role, p_lounge_id, a.key)
      )
      ORDER BY a.key
    )
    FROM public.app_permissions AS a
    WHERE private.permission_key_allowed_for_role(v_role, a.key)
  ), '[]'::jsonb);
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_role_permission(
  p_role text,
  p_permission_key text,
  p_is_enabled boolean,
  p_lounge_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_role text := lower(btrim(p_role));
  v_permission_key text := btrim(p_permission_key);
  v_actor_role text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000';
  END IF;

  IF v_role NOT IN ('owner','manager','cashier','staff','super_admin') THEN
    RAISE EXCEPTION 'Unsupported permission role' USING ERRCODE='22023';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.app_permissions AS a WHERE a.key = v_permission_key
  ) THEN
    RAISE EXCEPTION 'Unknown permission key' USING ERRCODE='22023';
  END IF;

  IF p_is_enabled
     AND NOT private.permission_key_allowed_for_role(v_role, v_permission_key) THEN
    RAISE EXCEPTION 'Permission cannot be delegated to this role'
      USING ERRCODE='42501';
  END IF;

  IF p_lounge_id IS NULL THEN
    IF NOT public.is_super_admin() THEN
      RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501';
    END IF;

    UPDATE public.role_permissions
    SET is_enabled = p_is_enabled,
        updated_at = now()
    WHERE role = v_role
      AND permission_key = v_permission_key;

    RETURN jsonb_build_object(
      'success', true,
      'scope', 'global',
      'role', v_role,
      'permission_key', v_permission_key,
      'is_enabled', p_is_enabled
    );
  END IF;

  v_actor_role := private.permission_role(auth.uid(), p_lounge_id);

  IF v_actor_role IS NULL
     OR v_actor_role NOT IN ('super_admin','owner','manager') THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501';
  END IF;

  IF v_actor_role <> 'super_admin'
     AND NOT public.has_lounge_permission(p_lounge_id, 'staff_manage') THEN
    RAISE EXCEPTION 'Missing staff_manage permission' USING ERRCODE='42501';
  END IF;

  IF v_role = 'super_admin' THEN
    RAISE EXCEPTION 'Super admin permissions are global-only'
      USING ERRCODE='42501';
  END IF;

  IF v_role = 'owner' AND v_actor_role <> 'super_admin' THEN
    RAISE EXCEPTION 'Only a super admin can change owner permissions'
      USING ERRCODE='42501';
  END IF;

  IF v_actor_role = 'manager'
     AND v_role NOT IN ('cashier','staff') THEN
    RAISE EXCEPTION 'Managers can only edit cashier or staff permissions'
      USING ERRCODE='42501';
  END IF;

  INSERT INTO public.lounge_role_permissions (
    lounge_id, role, permission_key, is_enabled, updated_at
  )
  VALUES (
    p_lounge_id, v_role, v_permission_key, p_is_enabled, now()
  )
  ON CONFLICT (lounge_id, role, permission_key)
  DO UPDATE
  SET is_enabled = EXCLUDED.is_enabled,
      updated_at = now();

  RETURN jsonb_build_object(
    'success', true,
    'scope', 'lounge',
    'lounge_id', p_lounge_id,
    'role', v_role,
    'permission_key', v_permission_key,
    'is_enabled', p_is_enabled
  );
END;
$function$;

UPDATE public.lounge_role_permissions AS lrp
SET is_enabled = false,
    updated_at = now()
WHERE lrp.is_enabled IS TRUE
  AND NOT private.permission_key_allowed_for_role(lrp.role, lrp.permission_key);

UPDATE public.staff_permissions AS sp
SET is_enabled = false,
    updated_at = now()
FROM public.profiles AS p
WHERE p.id = sp.user_id
  AND sp.is_enabled IS TRUE
  AND NOT private.permission_key_allowed_for_role(
    private.permission_role(sp.user_id, sp.lounge_id),
    sp.permission_key
  );

REVOKE ALL ON FUNCTION private.permission_key_allowed_for_role(text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.role_permission_value(text,uuid,text) FROM PUBLIC;

COMMIT;
