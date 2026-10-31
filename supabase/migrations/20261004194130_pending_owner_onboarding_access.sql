BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';
-- Activate newly provisioned owner accounts for onboarding, never their venues.
-- Existing provisioning retries preserve account moderation state.
CREATE OR REPLACE FUNCTION public.finalize_owner_lounge_provisioning(
  p_actor_id uuid, p_owner_id uuid, p_owner_name text,
  p_lounge_name text, p_city text DEFAULT NULL,
  p_address text DEFAULT NULL, p_phone text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_previous_sub text := current_setting('request.jwt.claim.sub', true);
  v_email text;
  v_lounge_id uuid;
  v_existing_actor uuid;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'Service role required' USING ERRCODE = '42501';
  END IF;
  PERFORM set_config('request.jwt.claim.sub', p_actor_id::text, true);
  IF NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Active super administrator required' USING ERRCODE = '42501';
  END IF;
  PERFORM set_config('request.jwt.claim.sub', coalesce(v_previous_sub, ''), true);
  IF p_actor_id IS NULL OR p_owner_id IS NULL OR p_actor_id = p_owner_id
     OR nullif(btrim(p_owner_name), '') IS NULL
     OR nullif(btrim(p_lounge_name), '') IS NULL THEN
    RAISE EXCEPTION 'Invalid owner or lounge details' USING ERRCODE = '22023';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(p_owner_id::text, 918));
  SELECT lounge_id, actor_id INTO v_lounge_id, v_existing_actor
    FROM private.owner_lounge_provisioning WHERE owner_id = p_owner_id;
  IF FOUND THEN
    IF v_existing_actor <> p_actor_id THEN
      RAISE EXCEPTION 'Provisioning actor mismatch' USING ERRCODE = '42501';
    END IF;
    RETURN jsonb_build_object('success', true, 'owner_id', p_owner_id,
      'owner_user_id', p_owner_id, 'lounge_id', v_lounge_id, 'status', 'pending');
  END IF;
  SELECT email INTO v_email FROM auth.users WHERE id = p_owner_id;
  IF v_email IS NULL OR EXISTS (
    SELECT 1 FROM public.lounges WHERE owner_id = p_owner_id
  ) OR EXISTS (
    SELECT 1 FROM public.profiles WHERE id = p_owner_id
      AND (role NOT IN ('customer', 'user') OR lounge_id IS NOT NULL)
  ) THEN
    RAISE EXCEPTION 'Account cannot be reassigned' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.profiles(id, email, full_name, phone, role,
    is_active, is_banned, is_setup_completed)
  VALUES(p_owner_id, v_email, btrim(p_owner_name), p_phone, 'owner',
    true, false, false)
  ON CONFLICT (id) DO UPDATE SET full_name = excluded.full_name,
    phone = excluded.phone, role = 'owner', is_active = true,
    is_setup_completed = false, updated_at = now();
  INSERT INTO public.lounges(name, city, location, owner_id, status, is_open, is_active)
  VALUES(btrim(p_lounge_name), p_city, p_address, p_owner_id, 'pending', false, false)
  RETURNING id INTO v_lounge_id;
  UPDATE public.profiles SET lounge_id = v_lounge_id WHERE id = p_owner_id;
  INSERT INTO private.owner_lounge_provisioning(owner_id, actor_id, lounge_id)
  VALUES(p_owner_id, p_actor_id, v_lounge_id);
  RETURN jsonb_build_object('success', true, 'owner_id', p_owner_id,
    'owner_user_id', p_owner_id, 'lounge_id', v_lounge_id, 'status', 'pending');
END;
$$;
REVOKE ALL ON FUNCTION public.finalize_owner_lounge_provisioning(uuid, uuid, text, text, text, text, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.finalize_owner_lounge_provisioning(uuid, uuid, text, text, text, text, text)
  TO service_role;
-- Retire the SQL path that inserted authentication records by hand.
REVOKE EXECUTE ON FUNCTION public.super_admin_create_lounge_with_owner(text, text, text, text, text)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.finalize_owner_lounge_provisioning_v2(
  p_actor_id uuid, p_owner_id uuid, p_owner_name text,
  p_lounge_name text, p_city text DEFAULT NULL,
  p_address text DEFAULT NULL, p_phone text DEFAULT NULL, p_owner_phone text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_previous_sub text := current_setting('request.jwt.claim.sub', true);
  v_email text;
  v_lounge_id uuid;
  v_existing_actor uuid;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'Service role required' USING ERRCODE = '42501';
  END IF;
  PERFORM set_config('request.jwt.claim.sub', p_actor_id::text, true);
  IF NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Active super administrator required' USING ERRCODE = '42501';
  END IF;
  PERFORM set_config('request.jwt.claim.sub', coalesce(v_previous_sub, ''), true);
  IF p_actor_id IS NULL OR p_owner_id IS NULL OR p_actor_id = p_owner_id
     OR nullif(btrim(p_owner_name), '') IS NULL
     OR nullif(btrim(p_lounge_name), '') IS NULL THEN
    RAISE EXCEPTION 'Invalid owner or lounge details' USING ERRCODE = '22023';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(p_owner_id::text, 918));
  SELECT lounge_id, actor_id INTO v_lounge_id, v_existing_actor
    FROM private.owner_lounge_provisioning WHERE owner_id = p_owner_id;
  IF FOUND THEN
    IF v_existing_actor <> p_actor_id THEN
      RAISE EXCEPTION 'Provisioning actor mismatch' USING ERRCODE = '42501';
    END IF;
    RETURN jsonb_build_object('success', true, 'owner_id', p_owner_id,
      'owner_user_id', p_owner_id, 'lounge_id', v_lounge_id, 'status', 'pending');
  END IF;
  SELECT email INTO v_email FROM auth.users WHERE id = p_owner_id;
  IF v_email IS NULL OR EXISTS (
    SELECT 1 FROM public.lounges WHERE owner_id = p_owner_id
  ) OR EXISTS (
    SELECT 1 FROM public.profiles WHERE id = p_owner_id
      AND (role NOT IN ('customer', 'user') OR lounge_id IS NOT NULL)
  ) THEN
    RAISE EXCEPTION 'Account cannot be reassigned' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.profiles(id, email, full_name, phone, role,
    is_active, is_banned, is_setup_completed)
  VALUES(p_owner_id, v_email, btrim(p_owner_name), NULLIF(btrim(p_owner_phone),''), 'owner',
    true, false, false)
  ON CONFLICT (id) DO UPDATE SET full_name = excluded.full_name,
    phone = excluded.phone, role = 'owner', is_active = true,
    is_setup_completed = false, updated_at = now();
  INSERT INTO public.lounges(name, city, location, address, contact_phone, owner_id, status, is_open, is_active)
  VALUES(btrim(p_lounge_name), p_city, p_address, p_address, NULLIF(btrim(p_phone),''), p_owner_id, 'pending', false, false)
  RETURNING id INTO v_lounge_id;
  UPDATE public.profiles SET lounge_id = v_lounge_id WHERE id = p_owner_id;
  INSERT INTO private.owner_lounge_provisioning(owner_id, actor_id, lounge_id)
  VALUES(p_owner_id, p_actor_id, v_lounge_id);
  RETURN jsonb_build_object('success', true, 'owner_id', p_owner_id,
    'owner_user_id', p_owner_id, 'lounge_id', v_lounge_id, 'status', 'pending');
END;
$$;
REVOKE ALL ON FUNCTION public.finalize_owner_lounge_provisioning_v2(uuid, uuid, text, text, text, text, text, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.finalize_owner_lounge_provisioning_v2(uuid, uuid, text, text, text, text, text, text)
  TO service_role;
REVOKE ALL ON FUNCTION public.finalize_owner_lounge_provisioning(uuid,uuid,text,text,text,text,text) FROM supabase_auth_admin;
REVOKE ALL ON FUNCTION public.finalize_owner_lounge_provisioning_v2(uuid,uuid,text,text,text,text,text,text) FROM supabase_auth_admin;
NOTIFY pgrst, 'reload schema';
COMMIT;

