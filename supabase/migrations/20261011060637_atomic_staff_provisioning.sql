BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
CREATE TABLE IF NOT EXISTS private.staff_provisioning_receipts (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id),
  actor_id uuid NOT NULL,
  lounge_id uuid NOT NULL,
  role text NOT NULL,
  full_name text NOT NULL,
  phone text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE private.staff_provisioning_receipts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.staff_provisioning_receipts FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;
CREATE OR REPLACE FUNCTION public.finalize_lounge_staff_provisioning(
  p_actor_id uuid, p_user_id uuid, p_lounge_id uuid,
  p_role text, p_full_name text, p_phone text DEFAULT ''
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_previous_sub text := current_setting('request.jwt.claim.sub', true);
  v_actor public.profiles%ROWTYPE;
  v_account auth.users%ROWTYPE;
  v_receipt private.staff_provisioning_receipts%ROWTYPE;
  v_super boolean;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'SERVICE_ROLE_REQUIRED' USING ERRCODE = '42501';
  END IF;
  IF p_actor_id IS NULL OR p_user_id IS NULL OR p_lounge_id IS NULL
    OR p_actor_id = p_user_id OR p_role NOT IN ('manager','cashier','staff')
    OR p_role IS NULL OR nullif(btrim(p_full_name),'') IS NULL THEN
    RAISE EXCEPTION 'INVALID_STAFF_DETAILS' USING ERRCODE = '22023';
  END IF;
  SELECT p.* INTO v_actor FROM public.profiles p JOIN auth.users u ON u.id=p.id
    WHERE p.id=p_actor_id FOR SHARE OF p,u;
  IF NOT FOUND OR v_actor.is_active IS NOT TRUE OR v_actor.is_banned IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'ACCOUNT_NOT_ELIGIBLE' USING ERRCODE = '42501';
  END IF;
  PERFORM set_config('request.jwt.claim.sub',p_actor_id::text,true);
  v_super := public.is_super_admin();
  IF v_super IS NOT TRUE AND (v_actor.role NOT IN ('owner','lounge_owner','manager','lounge_admin')
    OR public.has_lounge_permission(p_lounge_id,'staff_manage') IS NOT TRUE) THEN
    RAISE EXCEPTION 'STAFF_MANAGEMENT_DENIED' USING ERRCODE = '42501';
  END IF;
  IF v_super IS NOT TRUE AND v_actor.role IN ('manager','lounge_admin') AND p_role='manager' THEN
    RAISE EXCEPTION 'PEER_MANAGER_CREATION_DENIED' USING ERRCODE = '42501';
  END IF;
  PERFORM set_config('request.jwt.claim.sub',coalesce(v_previous_sub,''),true);
  PERFORM 1 FROM public.lounges WHERE id=p_lounge_id FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'LOUNGE_NOT_FOUND' USING ERRCODE='P0002'; END IF;
  SELECT * INTO v_account FROM auth.users WHERE id=p_user_id FOR UPDATE;
  IF NOT FOUND OR (v_account.raw_app_meta_data->'staff_provisioning') IS DISTINCT FROM
    jsonb_build_object('actor_id',p_actor_id,'lounge_id',p_lounge_id,'role',p_role) THEN
    RAISE EXCEPTION 'STAFF_PROVISIONING_IDENTITY_MISMATCH' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_receipt FROM private.staff_provisioning_receipts WHERE user_id=p_user_id;
  IF FOUND THEN
    IF (v_receipt.actor_id,v_receipt.lounge_id,v_receipt.role,v_receipt.full_name,v_receipt.phone)
      IS DISTINCT FROM (p_actor_id,p_lounge_id,p_role,btrim(p_full_name),coalesce(p_phone,'')) THEN
      RAISE EXCEPTION 'STAFF_PROVISIONING_REPLAY_MISMATCH' USING ERRCODE='22023';
    END IF;
    RETURN jsonb_build_object('success',true,'user_id',p_user_id,'role',p_role);
  END IF;
  PERFORM 1 FROM public.profiles WHERE id=p_user_id FOR UPDATE;
  IF EXISTS(SELECT 1 FROM public.lounge_staff WHERE user_id=p_user_id)
    OR EXISTS(SELECT 1 FROM public.profiles WHERE id=p_user_id AND
      (lounge_id IS NOT NULL OR role NOT IN ('user','customer','cashier','staff') OR is_banned IS DISTINCT FROM false)) THEN
    RAISE EXCEPTION 'STAFF_ACCOUNT_CANNOT_BE_REASSIGNED' USING ERRCODE='22023';
  END IF;
  INSERT INTO public.profiles(id,email,full_name,phone,role,lounge_id,is_active,is_banned,updated_at)
    VALUES(p_user_id,v_account.email,btrim(p_full_name),coalesce(p_phone,''),p_role,p_lounge_id,true,false,now())
    ON CONFLICT(id) DO UPDATE SET email=excluded.email,full_name=excluded.full_name,
      phone=excluded.phone,role=excluded.role,lounge_id=excluded.lounge_id,is_active=true,updated_at=now();
  INSERT INTO public.lounge_staff(lounge_id,user_id,role) VALUES(p_lounge_id,p_user_id,p_role);
  INSERT INTO private.staff_provisioning_receipts(user_id,actor_id,lounge_id,role,full_name,phone)
    VALUES(p_user_id,p_actor_id,p_lounge_id,p_role,btrim(p_full_name),coalesce(p_phone,''));
  RETURN jsonb_build_object('success',true,'user_id',p_user_id,'role',p_role);
END;
$$;
REVOKE ALL ON FUNCTION public.finalize_lounge_staff_provisioning(uuid,uuid,uuid,text,text,text)
  FROM PUBLIC, anon, authenticated, supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.finalize_lounge_staff_provisioning(uuid,uuid,uuid,text,text,text) TO service_role;
-- Recover only accounts created by this workflow's trusted server metadata.
-- Finalization still repeats current actor authorization before granting access.
CREATE OR REPLACE FUNCTION public.recover_lounge_staff_provisioning(
  p_actor_id uuid, p_email text, p_lounge_id uuid, p_role text
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_user_id uuid;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;
  SELECT id INTO v_user_id FROM auth.users
    WHERE lower(email)=lower(btrim(p_email))
      AND raw_app_meta_data->'staff_provisioning' =
        jsonb_build_object('actor_id',p_actor_id,'lounge_id',p_lounge_id,'role',p_role);
  RETURN v_user_id;
END;
$$;
REVOKE ALL ON FUNCTION public.recover_lounge_staff_provisioning(uuid,text,uuid,text)
  FROM PUBLIC, anon, authenticated, supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.recover_lounge_staff_provisioning(uuid,text,uuid,text) TO service_role;
NOTIFY pgrst, 'reload schema';
COMMIT;
