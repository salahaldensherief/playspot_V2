BEGIN;

-- Server time owns registration/check-in phases. This worker neither confirms
-- payments nor starts matches and never reopens a terminal/drawn tournament.
CREATE OR REPLACE FUNCTION private.advance_tournament_clock_phases()
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  t public.tournaments%ROWTYPE;
  target_status text;
  changed integer := 0;
BEGIN
  FOR t IN
    SELECT candidate.* FROM public.tournaments AS candidate
    WHERE (candidate.status = 'published' AND now() >= candidate.registration_opens_at)
       OR (candidate.status = 'registration_open' AND now() >= candidate.registration_closes_at)
       OR (candidate.status = 'registration_closed' AND now() >= candidate.check_in_opens_at)
       OR (candidate.status = 'check_in_open' AND now() >= candidate.check_in_closes_at)
    ORDER BY candidate.id
    LIMIT 500
    FOR UPDATE OF candidate SKIP LOCKED
  LOOP
    target_status := CASE
      WHEN now() >= t.check_in_closes_at THEN 'check_in_closed'
      WHEN now() >= t.check_in_opens_at THEN 'check_in_open'
      WHEN now() >= t.registration_closes_at THEN 'registration_closed'
      ELSE 'registration_open'
    END;
    UPDATE public.tournaments SET status = target_status, updated_at = now()
    WHERE id = t.id;
    PERFORM public.tournament_audit(t.id, 'tournament_status_changed', NULL, NULL,
      jsonb_build_object('status', t.status),
      jsonb_build_object('status', target_status, 'source', 'server_clock'));
    changed := changed + 1;
  END LOOP;
  RETURN changed;
END;
$$;
REVOKE ALL ON FUNCTION private.advance_tournament_clock_phases()
FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;

-- pg_cron is a required deployment prerequisite. Do not silently omit the
-- worker when installing the application contract in a different environment.
SELECT cron.schedule('playspot-tournament-clock-phases', '* * * * *',
  'SELECT private.advance_tournament_clock_phases()');

COMMIT;
