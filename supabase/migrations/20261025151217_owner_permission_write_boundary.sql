BEGIN;

-- Role templates and per-user overrides must be changed through audited RPCs.
-- Direct table writes bypass the delegation rules in update_role_permission.
REVOKE INSERT, UPDATE, DELETE ON public.staff_permissions
  FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.lounge_role_permissions
  FROM PUBLIC, anon, authenticated;
-- Guarded staff RPCs own membership changes. Direct writes allowed self-promotion.
REVOKE INSERT, UPDATE, DELETE ON public.lounge_staff
  FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS public.permission_audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lounge_id uuid NOT NULL REFERENCES public.lounges(id),
  actor_user_id uuid NOT NULL REFERENCES public.profiles(id),
  target_user_id uuid REFERENCES public.profiles(id),
  target_role text,
  permission_key text NOT NULL,
  old_value boolean,
  new_value boolean NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT permission_audit_target_check
    CHECK ((target_user_id IS NOT NULL) <> (target_role IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS permission_audit_logs_lounge_time_idx
  ON public.permission_audit_logs(lounge_id, created_at DESC);
ALTER TABLE public.permission_audit_logs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.permission_audit_logs FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.permission_audit_logs TO authenticated;
DROP POLICY IF EXISTS permission_audit_owner_read ON public.permission_audit_logs;
CREATE POLICY permission_audit_owner_read ON public.permission_audit_logs
  FOR SELECT TO authenticated
  USING (public.is_super_admin() OR EXISTS (
    SELECT 1 FROM public.lounges l
    JOIN public.profiles p ON p.id = l.owner_id
    WHERE l.id = permission_audit_logs.lounge_id
      AND l.owner_id = (SELECT auth.uid())
      AND p.is_active IS TRUE AND p.is_banned IS FALSE
  ) OR EXISTS (
    SELECT 1 FROM public.lounge_staff ls
    JOIN public.profiles p ON p.id = ls.user_id
    WHERE ls.lounge_id = permission_audit_logs.lounge_id
      AND ls.user_id = (SELECT auth.uid())
      AND ls.role = 'lounge_owner'
      AND p.is_active IS TRUE AND p.is_banned IS FALSE
  ));

-- The older get_staff_permissions reads the profile's primary lounge.
-- This explicit scope supports staff assigned to multiple branches.
CREATE OR REPLACE FUNCTION public.get_lounge_staff_permissions(
  p_lounge_id uuid, p_target_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_actor_role text;
  v_target_role text;
  v_permissions jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;
  IF p_lounge_id IS NULL OR p_target_user_id IS NULL THEN
    RAISE EXCEPTION 'Lounge and employee are required' USING ERRCODE = '22023';
  END IF;
  v_actor_role := private.permission_role(auth.uid(), p_lounge_id);
  v_target_role := private.permission_role(p_target_user_id, p_lounge_id);
  IF v_actor_role IS NULL OR v_actor_role NOT IN ('owner','super_admin')
     OR v_target_role IS NULL OR v_target_role NOT IN ('manager','cashier','staff') THEN
    RAISE EXCEPTION 'Not authorized for employee permissions in this lounge'
      USING ERRCODE = '42501';
  END IF;
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'permission_key',a.key,'name_ar',a.name_ar,'name_en',a.name_en,
    'category',a.category,'description_ar',a.description_ar,
    'description_en',a.description_en,
    'is_enabled',private.user_permission_value(p_target_user_id,p_lounge_id,a.key)
  ) ORDER BY a.key),'[]'::jsonb)
  INTO v_permissions
  FROM public.app_permissions a;
  RETURN jsonb_build_object('success',true,'lounge_id',p_lounge_id,
    'target_user_id',p_target_user_id,'role',v_target_role,
    'permissions',v_permissions);
END;
$function$;
REVOKE ALL ON FUNCTION public.get_lounge_staff_permissions(uuid,uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_lounge_staff_permissions(uuid,uuid)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.set_staff_permission(
  p_lounge_id uuid,
  p_target_user_id uuid,
  p_permission_key text,
  p_is_enabled boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_actor_role text;
  v_target_role text;
  v_key text := btrim(p_permission_key);
  v_previous boolean;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;
  IF p_lounge_id IS NULL OR p_target_user_id IS NULL
     OR v_key IS NULL OR v_key = '' OR p_is_enabled IS NULL THEN
    RAISE EXCEPTION 'Permission request is incomplete' USING ERRCODE = '22023';
  END IF;

  v_actor_role := private.permission_role(v_actor, p_lounge_id);
  IF v_actor_role IS NULL OR v_actor_role NOT IN ('owner', 'super_admin') THEN
    RAISE EXCEPTION 'Only the lounge owner may set employee permissions'
      USING ERRCODE = '42501';
  END IF;

  v_target_role := private.permission_role(p_target_user_id, p_lounge_id);
  IF v_target_role IS NULL OR v_target_role NOT IN ('manager', 'cashier', 'staff')
     OR v_actor = p_target_user_id THEN
    RAISE EXCEPTION 'Target must be another active employee in this lounge'
      USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.app_permissions a WHERE a.key = v_key) THEN
    RAISE EXCEPTION 'Unknown permission key' USING ERRCODE = '22023';
  END IF;
  IF p_is_enabled AND NOT private.permission_key_allowed_for_role(v_target_role, v_key) THEN
    RAISE EXCEPTION 'Permission cannot be granted to this role'
      USING ERRCODE = '42501';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(
    'staff_permission:' || p_lounge_id::text || ':' || p_target_user_id::text || ':' || v_key, 0));

  SELECT sp.is_enabled INTO v_previous
  FROM public.staff_permissions sp
  WHERE sp.lounge_id = p_lounge_id
    AND sp.user_id = p_target_user_id
    AND sp.permission_key = v_key
  FOR UPDATE;

  INSERT INTO public.staff_permissions
    (lounge_id, user_id, permission_key, is_enabled, updated_at)
  VALUES (p_lounge_id, p_target_user_id, v_key, p_is_enabled, now())
  ON CONFLICT (user_id, lounge_id, permission_key)
  DO UPDATE SET is_enabled = EXCLUDED.is_enabled, updated_at = now();

  INSERT INTO public.permission_audit_logs
    (lounge_id, actor_user_id, target_user_id, permission_key, old_value, new_value)
  VALUES (p_lounge_id, v_actor, p_target_user_id, v_key, v_previous, p_is_enabled);

  RETURN jsonb_build_object(
    'success', true, 'lounge_id', p_lounge_id,
    'target_user_id', p_target_user_id,
    'permission_key', v_key, 'is_enabled', p_is_enabled
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.set_staff_permission(uuid,uuid,text,boolean)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_staff_permission(uuid,uuid,text,boolean)
  TO authenticated;

-- Role templates are lounge-wide. A manager's staff_manage permission must not
-- allow granting a privilege they do not hold, or changing their own template.
CREATE OR REPLACE FUNCTION public.update_role_permission(
  p_role text, p_permission_key text, p_is_enabled boolean,
  p_lounge_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_role text := lower(btrim(p_role));
  v_key text := btrim(p_permission_key);
  v_actor_role text;
  v_previous boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;
  IF v_role NOT IN ('owner','manager','cashier','staff','super_admin')
     OR p_is_enabled IS NULL THEN
    RAISE EXCEPTION 'Unsupported permission request' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.app_permissions a WHERE a.key = v_key) THEN
    RAISE EXCEPTION 'Unknown permission key' USING ERRCODE = '22023';
  END IF;
  IF p_is_enabled AND NOT private.permission_key_allowed_for_role(v_role,v_key) THEN
    RAISE EXCEPTION 'Permission cannot be delegated to this role'
      USING ERRCODE = '42501';
  END IF;

  IF p_lounge_id IS NULL THEN
    IF NOT public.is_super_admin() THEN
      RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
    END IF;
    UPDATE public.role_permissions
    SET is_enabled=p_is_enabled, updated_at=now()
    WHERE role=v_role AND permission_key=v_key;
    RETURN jsonb_build_object('success',true,'scope','global',
      'role',v_role,'permission_key',v_key,'is_enabled',p_is_enabled);
  END IF;

  v_actor_role := private.permission_role(auth.uid(),p_lounge_id);
  IF v_actor_role IS NULL OR v_actor_role NOT IN ('super_admin','owner','manager') THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
  END IF;
  IF v_actor_role <> 'super_admin'
     AND NOT public.has_lounge_permission(p_lounge_id,'staff_manage') THEN
    RAISE EXCEPTION 'Missing staff_manage permission' USING ERRCODE = '42501';
  END IF;
  IF v_role = 'super_admin' THEN
    RAISE EXCEPTION 'Super admin permissions are global-only' USING ERRCODE = '42501';
  END IF;
  IF v_role = 'owner' AND v_actor_role <> 'super_admin' THEN
    RAISE EXCEPTION 'Only a super admin can change owner permissions'
      USING ERRCODE = '42501';
  END IF;
  IF v_actor_role = 'manager' THEN
    IF v_role NOT IN ('cashier','staff') THEN
      RAISE EXCEPTION 'Managers can only edit cashier or staff permissions'
        USING ERRCODE = '42501';
    END IF;
    IF p_is_enabled AND NOT public.has_lounge_permission(p_lounge_id,v_key) THEN
      RAISE EXCEPTION 'Cannot delegate a permission the manager does not hold'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(
    'role_permission:' || p_lounge_id::text || ':' || v_role || ':' || v_key, 0));
  SELECT lrp.is_enabled INTO v_previous
  FROM public.lounge_role_permissions lrp
  WHERE lrp.lounge_id=p_lounge_id AND lrp.role=v_role AND lrp.permission_key=v_key;

  INSERT INTO public.lounge_role_permissions
    (lounge_id,role,permission_key,is_enabled,updated_at)
  VALUES (p_lounge_id,v_role,v_key,p_is_enabled,now())
  ON CONFLICT (lounge_id,role,permission_key)
  DO UPDATE SET is_enabled=EXCLUDED.is_enabled, updated_at=now();

  INSERT INTO public.permission_audit_logs
    (lounge_id,actor_user_id,target_role,permission_key,old_value,new_value)
  VALUES (p_lounge_id,auth.uid(),v_role,v_key,v_previous,p_is_enabled);
  RETURN jsonb_build_object('success',true,'scope','lounge',
    'lounge_id',p_lounge_id,'role',v_role,
    'permission_key',v_key,'is_enabled',p_is_enabled);
END;
$function$;

COMMIT;
