BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE OR REPLACE FUNCTION private.permission_role(p_user_id uuid, p_lounge_id uuid)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $f$
  SELECT CASE
    WHEN p.role = 'super_admin' THEN 'super_admin'
    WHEN p_lounge_id IS NULL THEN NULL
    WHEN EXISTS (SELECT 1 FROM public.lounges l WHERE l.id=p_lounge_id AND l.owner_id=p.id) THEN 'owner'
    WHEN ls.role = 'lounge_owner' THEN 'owner'
    WHEN ls.role IN ('manager','cashier') THEN ls.role
    WHEN p.lounge_id=p_lounge_id AND p.role IN ('owner','manager','cashier','staff') THEN p.role
    WHEN p.lounge_id=p_lounge_id AND p.role IN ('lounge_admin','admin') THEN 'manager'
    ELSE NULL END
  FROM public.profiles p
  LEFT JOIN public.lounge_staff ls ON ls.user_id=p.id AND ls.lounge_id=p_lounge_id
  WHERE p.id=p_user_id AND COALESCE(p.is_active,true) AND NOT COALESCE(p.is_banned,false)
    AND p.role IN ('super_admin','owner','lounge_admin','admin','manager','cashier','staff');
$f$;

CREATE OR REPLACE FUNCTION private.role_permission_value(p_role text, p_lounge_id uuid, p_key text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $f$
  SELECT COALESCE((SELECT CASE
    WHEN p_role NOT IN ('super_admin','owner','manager','cashier','staff') OR p_role IS NULL THEN false
    ELSE COALESCE(
      (SELECT lrp.is_enabled FROM public.lounge_role_permissions lrp
       WHERE lrp.lounge_id=p_lounge_id AND lrp.role=p_role AND lrp.permission_key=a.key),
      CASE p_role WHEN 'super_admin' THEN a.default_super_admin
        WHEN 'owner' THEN a.default_owner WHEN 'manager' THEN a.default_owner
        WHEN 'cashier' THEN a.default_cashier ELSE false END, false)
    END FROM public.app_permissions a WHERE a.key=p_key),false);
$f$;

CREATE OR REPLACE FUNCTION private.user_permission_value(p_user_id uuid, p_lounge_id uuid, p_key text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $f$
  SELECT COALESCE((SELECT CASE
    WHEN private.permission_role(p_user_id,p_lounge_id) IS NULL THEN false
    ELSE COALESCE(
      (SELECT sp.is_enabled FROM public.staff_permissions sp
       WHERE sp.user_id=p_user_id AND sp.lounge_id IS NOT DISTINCT FROM p_lounge_id
         AND sp.permission_key=a.key),
      private.role_permission_value(private.permission_role(p_user_id,p_lounge_id),p_lounge_id,a.key),false)
    END FROM public.app_permissions a WHERE a.key=p_key),false);
$f$;

REVOKE ALL ON FUNCTION private.permission_role(uuid,uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.role_permission_value(text,uuid,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.user_permission_value(uuid,uuid,text) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.has_permission(p_user_id uuid,p_permission_key text)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $f$
DECLARE
  v_target uuid := COALESCE(p_user_id,auth.uid());
  v_lounge uuid;
BEGIN
  IF auth.uid() IS NULL THEN RETURN false; END IF;
  IF v_target <> auth.uid() AND private.permission_role(auth.uid(),NULL) IS DISTINCT FROM 'super_admin' THEN
    RETURN false;
  END IF;
  SELECT lounge_id INTO v_lounge FROM public.profiles WHERE id=v_target;
  RETURN private.user_permission_value(v_target,v_lounge,p_permission_key);
END;
$f$;

CREATE OR REPLACE FUNCTION public.has_lounge_permission(p_lounge_id uuid,p_permission_key text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $f$
  SELECT auth.uid() IS NOT NULL AND private.user_permission_value(auth.uid(),p_lounge_id,p_permission_key);
$f$;

CREATE OR REPLACE FUNCTION public.get_my_permissions(p_lounge_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $f$
DECLARE v_lounge uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  SELECT COALESCE(p_lounge_id,p.lounge_id) INTO v_lounge FROM public.profiles p WHERE p.id=auth.uid();
  RETURN COALESCE((SELECT jsonb_agg(jsonb_build_object(
    'permission_key',a.key,'name_ar',a.name_ar,'name_en',a.name_en,'category',a.category,
    'description_ar',a.description_ar,'description_en',a.description_en,
    'is_enabled',private.user_permission_value(auth.uid(),v_lounge,a.key)) ORDER BY a.key)
    FROM public.app_permissions a),'[]'::jsonb);
END;
$f$;

CREATE OR REPLACE FUNCTION public.get_lounge_role_permission_catalog(p_lounge_id uuid,p_role text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $f$
DECLARE v_actor_role text := private.permission_role(auth.uid(),p_lounge_id);
BEGIN
  IF v_actor_role IS NULL OR v_actor_role NOT IN ('super_admin','owner','manager') THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501';
  END IF;
  RETURN COALESCE((SELECT jsonb_agg(jsonb_build_object(
    'permission_key',a.key,'name_ar',a.name_ar,'name_en',a.name_en,'category',a.category,
    'description_ar',a.description_ar,'description_en',a.description_en,
    'is_enabled',private.role_permission_value(p_role,p_lounge_id,a.key)) ORDER BY a.key)
    FROM public.app_permissions a),'[]'::jsonb);
END;
$f$;

CREATE OR REPLACE FUNCTION public.get_staff_permissions(p_target_user_id uuid DEFAULT NULL)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $f$
DECLARE
  v_target uuid := COALESCE(p_target_user_id,auth.uid());
  v_lounge uuid; v_role text; v_actor_role text; v_permissions json;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  SELECT lounge_id,role INTO v_lounge,v_role FROM public.profiles WHERE id=v_target;
  IF NOT FOUND THEN RAISE EXCEPTION 'Target user not found'; END IF;
  v_actor_role := private.permission_role(auth.uid(),v_lounge);
  IF v_target <> auth.uid() AND (v_actor_role IS NULL OR v_actor_role NOT IN ('super_admin','owner','manager')) THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501';
  END IF;
  SELECT json_agg(json_build_object(
    'permission_key',a.key,'name_ar',a.name_ar,'name_en',a.name_en,'category',a.category,
    'description_ar',a.description_ar,'description_en',a.description_en,
    'is_enabled',private.user_permission_value(v_target,v_lounge,a.key)) ORDER BY a.key)
    INTO v_permissions FROM public.app_permissions a;
  RETURN json_build_object('success',true,'role',v_role,'lounge_id',v_lounge,
    'permissions',COALESCE(v_permissions,'[]'::json));
END;
$f$;

CREATE OR REPLACE FUNCTION public.get_role_permissions(p_role text)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $f$
  SELECT COALESCE(jsonb_agg(a.key ORDER BY a.key),'[]'::jsonb)
  FROM public.app_permissions a
  WHERE auth.uid() IS NOT NULL AND private.role_permission_value(p_role,
    (SELECT p.lounge_id FROM public.profiles p WHERE p.id=auth.uid()),a.key);
$f$;

REVOKE ALL ON FUNCTION public.get_my_permissions(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.get_lounge_role_permission_catalog(uuid,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.has_lounge_permission(uuid,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.get_role_permissions(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_my_permissions(uuid) TO authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.get_lounge_role_permission_catalog(uuid,text) TO authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.has_lounge_permission(uuid,text) TO authenticated,service_role;

COMMIT;
