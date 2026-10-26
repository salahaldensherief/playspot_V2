-- Branch owners choose the cancellation cutoff and refundable percentage.
-- No cancellation RPC or money movement is changed here: eligibility is not
-- evidence that a manual refund was actually paid.
CREATE TABLE private.booking_refund_policy_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  version bigint GENERATED ALWAYS AS IDENTITY UNIQUE,
  operation_id uuid NOT NULL UNIQUE,
  lounge_id uuid NOT NULL REFERENCES public.lounges(id),
  cutoff_minutes_before_start integer NOT NULL
    CHECK (cutoff_minutes_before_start BETWEEN 0 AND 43200),
  refund_percentage numeric(5,2) NOT NULL
    CHECK (refund_percentage BETWEEN 0 AND 100),
  configured_by uuid NOT NULL REFERENCES auth.users(id),
  configured_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX booking_refund_policy_versions_latest
  ON private.booking_refund_policy_versions (lounge_id, version DESC);
ALTER TABLE private.booking_refund_policy_versions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.booking_refund_policy_versions
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;

CREATE FUNCTION private.reject_booking_refund_policy_mutation()
RETURNS trigger LANGUAGE plpgsql SET search_path TO '' AS $function$
BEGIN
  RAISE EXCEPTION 'REFUND_POLICY_VERSION_IS_IMMUTABLE' USING ERRCODE = '55000';
END;
$function$;
REVOKE ALL ON FUNCTION private.reject_booking_refund_policy_mutation()
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;
CREATE TRIGGER booking_refund_policy_versions_append_only
BEFORE UPDATE OR DELETE ON private.booking_refund_policy_versions
FOR EACH ROW EXECUTE FUNCTION private.reject_booking_refund_policy_mutation();

ALTER TABLE public.bookings ADD COLUMN refund_policy_version_id uuid
  REFERENCES private.booking_refund_policy_versions(id);

CREATE FUNCTION private.snapshot_booking_refund_policy()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
BEGIN
  SELECT p.id INTO NEW.refund_policy_version_id
  FROM private.booking_refund_policy_versions p
  WHERE p.lounge_id = NEW.lounge_id
  ORDER BY p.version DESC LIMIT 1;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION private.snapshot_booking_refund_policy()
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;
CREATE TRIGGER zz_snapshot_booking_refund_policy
BEFORE INSERT ON public.bookings
FOR EACH ROW EXECUTE FUNCTION private.snapshot_booking_refund_policy();

CREATE FUNCTION private.guard_booking_refund_policy_snapshot()
RETURNS trigger LANGUAGE plpgsql SET search_path TO '' AS $function$
BEGIN
  IF NEW.refund_policy_version_id IS DISTINCT FROM OLD.refund_policy_version_id THEN
    RAISE EXCEPTION 'BOOKING_REFUND_POLICY_SNAPSHOT_IMMUTABLE' USING ERRCODE = '55000';
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION private.guard_booking_refund_policy_snapshot()
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;
CREATE TRIGGER booking_refund_policy_snapshot_immutable
BEFORE UPDATE OF refund_policy_version_id ON public.bookings
FOR EACH ROW EXECUTE FUNCTION private.guard_booking_refund_policy_snapshot();

CREATE FUNCTION public.configure_branch_booking_refund_policy(
  p_lounge_id uuid, p_cutoff_minutes_before_start integer,
  p_refund_percentage numeric, p_operation_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_existing private.booking_refund_policy_versions%ROWTYPE;
  v_new private.booking_refund_policy_versions%ROWTYPE;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE = '28000';
  END IF;
  IF p_lounge_id IS NULL OR p_operation_id IS NULL
    OR p_cutoff_minutes_before_start IS NULL
    OR p_cutoff_minutes_before_start NOT BETWEEN 0 AND 43200
    OR p_refund_percentage IS NULL
    OR p_refund_percentage::text IN ('NaN','Infinity','-Infinity')
    OR p_refund_percentage NOT BETWEEN 0 AND 100
    OR p_refund_percentage <> round(p_refund_percentage, 2) THEN
    RAISE EXCEPTION 'INVALID_REFUND_POLICY' USING ERRCODE = '22023';
  END IF;
  PERFORM 1 FROM public.profiles p JOIN auth.users u ON u.id = p.id
    WHERE p.id = v_actor AND p.role = 'owner'
      AND p.is_active IS TRUE AND p.is_banned IS FALSE
    FOR SHARE OF p, u;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'ACTIVE_OWNER_REQUIRED' USING ERRCODE = '42501';
  END IF;
  PERFORM 1 FROM public.lounges l
    WHERE l.id = p_lounge_id AND l.owner_id = v_actor FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'BRANCH_OWNER_REQUIRED' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_existing FROM private.booking_refund_policy_versions
    WHERE operation_id = p_operation_id;
  IF FOUND THEN
    IF v_existing.lounge_id IS DISTINCT FROM p_lounge_id
      OR v_existing.configured_by IS DISTINCT FROM v_actor
      OR v_existing.cutoff_minutes_before_start IS DISTINCT FROM p_cutoff_minutes_before_start
      OR v_existing.refund_percentage IS DISTINCT FROM p_refund_percentage THEN
      RAISE EXCEPTION 'REFUND_POLICY_REPLAY_CONFLICT' USING ERRCODE = '22023';
    END IF;
    RETURN jsonb_build_object('policy_version_id', v_existing.id,
      'cutoff_minutes_before_start', v_existing.cutoff_minutes_before_start,
      'refund_percentage', v_existing.refund_percentage, 'replayed', true);
  END IF;
  INSERT INTO private.booking_refund_policy_versions
    (operation_id,lounge_id,cutoff_minutes_before_start,refund_percentage,configured_by)
  VALUES (p_operation_id,p_lounge_id,p_cutoff_minutes_before_start,
    p_refund_percentage,v_actor) RETURNING * INTO v_new;
  RETURN jsonb_build_object('policy_version_id', v_new.id,
    'cutoff_minutes_before_start', v_new.cutoff_minutes_before_start,
    'refund_percentage', v_new.refund_percentage, 'replayed', false);
END;
$function$;
REVOKE ALL ON FUNCTION public.configure_branch_booking_refund_policy(uuid,integer,numeric,uuid)
  FROM PUBLIC, anon, service_role, supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.configure_branch_booking_refund_policy(uuid,integer,numeric,uuid)
  TO authenticated;

CREATE FUNCTION public.get_branch_booking_refund_policy(p_lounge_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO '' AS $function$
DECLARE v_policy private.booking_refund_policy_versions%ROWTYPE;
BEGIN
  PERFORM 1 FROM public.lounges l WHERE l.id = p_lounge_id
    AND ((l.is_active IS TRUE AND l.status = 'active')
      OR l.owner_id = auth.uid());
  IF NOT FOUND THEN
    RAISE EXCEPTION 'BRANCH_NOT_AVAILABLE' USING ERRCODE = 'P0002';
  END IF;
  SELECT * INTO v_policy FROM private.booking_refund_policy_versions
    WHERE lounge_id = p_lounge_id ORDER BY version DESC LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('configured', false);
  END IF;
  RETURN jsonb_build_object('configured', true,
    'policy_version_id', v_policy.id,
    'cutoff_minutes_before_start', v_policy.cutoff_minutes_before_start,
    'refund_percentage', v_policy.refund_percentage);
END;
$function$;
REVOKE ALL ON FUNCTION public.get_branch_booking_refund_policy(uuid)
  FROM PUBLIC, service_role, supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.get_branch_booking_refund_policy(uuid)
  TO anon, authenticated;

-- Internal policy decision only. The percentage is not a refund receipt or a
-- calculation of money owed; the verified collection ledger supplies that.
CREATE FUNCTION private.booking_refund_policy_decision(p_booking_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO '' AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_policy private.booking_refund_policy_versions%ROWTYPE;
  v_timezone text;
  v_start_at timestamptz;
  v_cutoff_at timestamptz;
BEGIN
  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'BOOKING_NOT_FOUND' USING ERRCODE = 'P0002';
  END IF;
  IF v_booking.status::text <> 'cancelled' OR v_booking.cancelled_at IS NULL THEN
    RETURN jsonb_build_object('decision', 'not_cancelled');
  END IF;
  IF v_booking.actual_start_time IS NOT NULL
    OR v_booking.open_time_started_at IS NOT NULL
    OR v_booking.checked_in_at IS NOT NULL THEN
    RETURN jsonb_build_object('decision', 'session_started',
      'eligible_percentage', 0);
  END IF;
  SELECT * INTO v_policy FROM private.booking_refund_policy_versions
    WHERE id = v_booking.refund_policy_version_id
      AND lounge_id = v_booking.lounge_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('decision', 'manual_review_no_policy_snapshot');
  END IF;
  SELECT timezone INTO v_timezone FROM public.lounges
    WHERE id = v_booking.lounge_id;
  IF v_booking.date IS NULL OR v_booking.start_time IS NULL
    OR v_timezone IS NULL THEN
    RETURN jsonb_build_object('decision', 'manual_review_missing_start');
  END IF;
  v_start_at := (v_booking.date + v_booking.start_time) AT TIME ZONE v_timezone;
  v_cutoff_at := v_start_at
    - make_interval(mins => v_policy.cutoff_minutes_before_start);
  RETURN jsonb_build_object(
    'decision', CASE WHEN v_booking.cancelled_at <= v_cutoff_at
      THEN 'eligible' ELSE 'cutoff_passed' END,
    'eligible_percentage', CASE WHEN v_booking.cancelled_at <= v_cutoff_at
      THEN v_policy.refund_percentage ELSE 0 END,
    'policy_version_id', v_policy.id,
    'cutoff_at', v_cutoff_at
  );
END;
$function$;
REVOKE ALL ON FUNCTION private.booking_refund_policy_decision(uuid)
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;
