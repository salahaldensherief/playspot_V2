BEGIN;
REVOKE ALL ON public.profiles FROM PUBLIC,anon,authenticated;
DO $$
DECLARE v_columns text;
BEGIN
 SELECT string_agg(quote_ident(attname),',') INTO v_columns FROM pg_attribute
 WHERE attrelid='public.profiles'::regclass AND attnum>0 AND NOT attisdropped;
 EXECUTE format('REVOKE INSERT (%s), UPDATE (%s) ON public.profiles FROM PUBLIC,anon,authenticated',v_columns,v_columns);
END;
$$;
GRANT SELECT ON public.profiles TO authenticated;
GRANT INSERT(id,full_name,email,phone,avatar_url,city_id,latitude,longitude,fcm_token,notification_preferences,updated_at)
 ON public.profiles TO authenticated;
GRANT UPDATE(id,full_name,email,phone,avatar_url,city_id,latitude,longitude,fcm_token,notification_preferences,updated_at)
 ON public.profiles TO authenticated;
ALTER TABLE public.profiles ALTER COLUMN role SET DEFAULT 'user';
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow insert profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own basic profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS profiles_update_policy ON public.profiles;
CREATE POLICY profile_insert_basic_self ON public.profiles FOR INSERT TO authenticated
 WITH CHECK(id=auth.uid() AND role='user' AND lounge_id IS NULL AND is_banned IS NOT TRUE);
CREATE POLICY profile_update_basic_self ON public.profiles FOR UPDATE TO authenticated
 USING(id=auth.uid()) WITH CHECK(id=auth.uid());

CREATE OR REPLACE FUNCTION public.ensure_my_referral_code() RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_code text;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='28000'; END IF;
 SELECT referral_code INTO v_code FROM public.profiles WHERE id=auth.uid() FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'PROFILE_REQUIRED' USING ERRCODE='P0002'; END IF;
 IF NULLIF(btrim(v_code),'') IS NOT NULL THEN RETURN v_code; END IF;
 v_code:='PS-'||replace(gen_random_uuid()::text,'-','');
 UPDATE public.profiles SET referral_code=v_code,updated_at=now() WHERE id=auth.uid();
 RETURN v_code;
END;
$$;
REVOKE ALL ON FUNCTION public.ensure_my_referral_code() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ensure_my_referral_code() TO authenticated;
COMMIT;
