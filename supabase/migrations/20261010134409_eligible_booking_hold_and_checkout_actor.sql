BEGIN;
SET LOCAL lock_timeout = '5s';

CREATE OR REPLACE FUNCTION private.require_active_booking_actor()
RETURNS uuid LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
  v_actor uuid := auth.uid();
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles p JOIN auth.users u ON u.id = p.id
    WHERE p.id = v_actor AND p.is_active IS TRUE AND p.is_banned IS FALSE
  ) THEN
    RAISE EXCEPTION 'Active account required' USING ERRCODE = '42501';
  END IF;
  RETURN v_actor;
END;
$function$;
REVOKE ALL ON FUNCTION private.require_active_booking_actor()
FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;

-- Gate before capacity locks, quote calculations, payments or inventory writes.
-- Keep the current financial/capacity bodies and their existing ACLs intact.
DO $migration$
DECLARE
  v_signature text;
  v_definition text;
  v_marker text := E'  IF v_user_id IS NULL THEN\n    RAISE EXCEPTION ''Authentication required'' USING ERRCODE = ''28000'';\n  END IF;';
  v_guard text := E'\n\n  PERFORM private.require_active_booking_actor();';
BEGIN
  FOREACH v_signature IN ARRAY ARRAY[
    'public.acquire_booking_hold(uuid[],timestamp without time zone,timestamp without time zone,integer)',
    'public.quote_my_booking_checkout(uuid,jsonb,jsonb,text)',
    'public.create_my_booking_checkout(uuid,jsonb,jsonb,text,text,text,text)'
  ] LOOP
    SELECT replace(pg_get_functiondef(v_signature::regprocedure), chr(13), '')
      INTO v_definition;
    IF position('PERFORM private.require_active_booking_actor();' IN v_definition) > 0 THEN
      CONTINUE;
    END IF;
    IF position(v_marker IN v_definition) = 0 THEN
      RAISE EXCEPTION 'Unsupported booking actor contract: %', v_signature;
    END IF;
    EXECUTE replace(v_definition, v_marker, v_marker || v_guard);
  END LOOP;
END;
$migration$;
COMMIT;
