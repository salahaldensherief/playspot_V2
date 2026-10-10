BEGIN;
CREATE TABLE private.auth_disable_tasks (
  user_id uuid PRIMARY KEY REFERENCES public.profiles(id),
  status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','running','completed','failed','cancelled')),
  attempts integer NOT NULL DEFAULT 0 CHECK(attempts BETWEEN 0 AND 5),
  requested_at timestamptz NOT NULL DEFAULT now(),
  next_attempt_at timestamptz NOT NULL DEFAULT now(),
  lease_id uuid,
  leased_until timestamptz,
  completed_at timestamptz,
  last_error_code text
);
ALTER TABLE private.auth_disable_tasks ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.auth_disable_tasks FROM PUBLIC,anon,authenticated,service_role;
CREATE INDEX auth_disable_tasks_due ON private.auth_disable_tasks(next_attempt_at)
WHERE status IN ('pending','running');

-- Resume only explicitly requested, unfinished deletions from the older queue.
INSERT INTO private.auth_disable_tasks(user_id,requested_at)
SELECT d.user_id,d.requested_at FROM public.account_deletion_requests d
JOIN public.profiles p ON p.id=d.user_id
WHERE d.auth_disabled_at IS NULL AND (p.is_active IS NOT TRUE OR p.is_banned IS NOT FALSE);

CREATE FUNCTION private.queue_auth_disabling() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
BEGIN
  IF NEW.is_active IS NOT TRUE OR NEW.is_banned IS NOT FALSE THEN
    INSERT INTO private.auth_disable_tasks(user_id) VALUES(NEW.id)
    ON CONFLICT(user_id) DO UPDATE SET status='pending',attempts=0,requested_at=now(),
      next_attempt_at=now(),lease_id=NULL,leased_until=NULL,completed_at=NULL,last_error_code=NULL;
  ELSE
    UPDATE private.auth_disable_tasks SET status='cancelled',lease_id=NULL,leased_until=NULL
    WHERE user_id=NEW.id AND status IN ('pending','running','failed');
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION private.queue_auth_disabling() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER profile_auth_disable_recovery AFTER UPDATE OF is_active,is_banned ON public.profiles
FOR EACH ROW WHEN (OLD.is_active IS DISTINCT FROM NEW.is_active OR OLD.is_banned IS DISTINCT FROM NEW.is_banned)
EXECUTE FUNCTION private.queue_auth_disabling();

CREATE FUNCTION public.claim_auth_disable_tasks(p_limit integer DEFAULT 10)
RETURNS TABLE(user_id uuid,lease_id uuid,attempt integer)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
BEGIN
  IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 20 THEN
    RAISE EXCEPTION 'INVALID_RECOVERY_BATCH_SIZE' USING ERRCODE='22023';
  END IF;
  UPDATE private.auth_disable_tasks t SET status='failed',last_error_code='RETRY_LIMIT_REACHED',lease_id=NULL,leased_until=NULL
  WHERE t.status='running' AND t.leased_until<=now() AND t.attempts>=5;
  UPDATE private.auth_disable_tasks t SET status='cancelled',lease_id=NULL,leased_until=NULL
  WHERE t.status IN ('pending','running') AND EXISTS(
    SELECT 1 FROM public.profiles p WHERE p.id=t.user_id AND p.is_active IS TRUE AND p.is_banned IS FALSE);
  RETURN QUERY
  WITH due AS (
    SELECT t.user_id FROM private.auth_disable_tasks t
    WHERE (t.status='pending' AND t.next_attempt_at<=now()
      OR t.status='running' AND t.leased_until<=now()) AND t.attempts<5
    ORDER BY t.next_attempt_at,t.user_id FOR UPDATE SKIP LOCKED LIMIT p_limit
  ) UPDATE private.auth_disable_tasks t
    SET status='running',attempts=t.attempts+1,lease_id=gen_random_uuid(),leased_until=now()+interval '2 minutes'
    FROM due WHERE t.user_id=due.user_id RETURNING t.user_id,t.lease_id,t.attempts;
END;
$function$;

CREATE FUNCTION public.finish_auth_disable_task(p_user_id uuid,p_lease_id uuid,p_success boolean,p_error_code text DEFAULT NULL)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE v_task private.auth_disable_tasks%ROWTYPE;
BEGIN
  SELECT * INTO v_task FROM private.auth_disable_tasks t
  WHERE t.user_id=p_user_id AND t.lease_id=p_lease_id AND t.status='running' AND t.leased_until>now() FOR UPDATE;
  IF NOT FOUND OR p_success IS NULL THEN RAISE EXCEPTION 'STALE_AUTH_RECOVERY_LEASE' USING ERRCODE='55000'; END IF;
  IF p_error_code IS NOT NULL AND p_error_code NOT IN ('AUTH_UNAVAILABLE','AUTH_REJECTED') THEN
    RAISE EXCEPTION 'INVALID_AUTH_RECOVERY_ERROR' USING ERRCODE='22023';
  END IF;
  UPDATE private.auth_disable_tasks SET status=CASE WHEN p_success THEN 'completed' WHEN attempts>=5 THEN 'failed' ELSE 'pending' END,
    next_attempt_at=now()+make_interval(secs=>least(3600,30*power(2,attempts-1)::integer)),
    completed_at=CASE WHEN p_success THEN now() ELSE NULL END,
    last_error_code=CASE WHEN p_success THEN NULL ELSE coalesce(p_error_code,'AUTH_UNAVAILABLE') END,
    lease_id=NULL,leased_until=NULL WHERE user_id=p_user_id;
  IF p_success THEN UPDATE public.account_deletion_requests SET auth_disabled_at=coalesce(auth_disabled_at,now()) WHERE user_id=p_user_id; END IF;
  RETURN true;
END;
$function$;

CREATE FUNCTION public.get_auth_disable_recovery_status()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $function$
  SELECT jsonb_build_object('pending',count(*) FILTER(WHERE status='pending'),
    'running',count(*) FILTER(WHERE status='running'),'failed',count(*) FILTER(WHERE status='failed'),
    'completed',count(*) FILTER(WHERE status='completed'),
    'oldest_pending_at',min(requested_at) FILTER(WHERE status IN ('pending','running')))
  FROM private.auth_disable_tasks;
$function$;
REVOKE ALL ON FUNCTION public.claim_auth_disable_tasks(integer),
  public.finish_auth_disable_task(uuid,uuid,boolean,text),public.get_auth_disable_recovery_status()
FROM PUBLIC,anon,authenticated,supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.claim_auth_disable_tasks(integer),
  public.finish_auth_disable_task(uuid,uuid,boolean,text),public.get_auth_disable_recovery_status() TO service_role;
COMMIT;
