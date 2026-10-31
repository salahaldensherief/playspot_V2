-- PRE-RESTORE READ-ONLY CHECKS. Only run through the dedicated verified daemon.
DO $$
BEGIN
  ASSERT current_database() = 'postgres', 'Unexpected database';
  ASSERT to_regclass('auth.users') IS NOT NULL, 'Managed Auth not initialized';
  ASSERT to_regclass('public.profiles') IS NULL, 'Application baseline already exists: inspect, do not replay';
  ASSERT (SELECT count(*) FROM auth.users) = 0, 'Unexpected identities: preserve and investigate';
  ASSERT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='anon'), 'Missing anon';
  ASSERT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='authenticated'), 'Missing authenticated';
  ASSERT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='service_role'), 'Missing server role';
  ASSERT EXISTS(SELECT 1 FROM pg_available_extensions WHERE name='postgis'), 'PostGIS unavailable';
  ASSERT EXISTS(SELECT 1 FROM pg_available_extensions WHERE name='btree_gist'), 'btree_gist unavailable';
END $$;
SELECT extname,extversion FROM pg_extension ORDER BY extname;
SELECT name,default_version FROM pg_available_extensions WHERE name IN ('postgis','btree_gist','pg_net','pg_cron','supabase_vault');
