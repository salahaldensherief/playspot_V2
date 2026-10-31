-- Disposable local project only, before application checkpoint.
DO $$ BEGIN
 ASSERT current_setting('server_version_num')::int / 10000 = 17;
 ASSERT to_regclass('auth.users') IS NOT NULL;
 ASSERT to_regclass('public.profiles') IS NULL, 'Already initialized: preserve and inspect';
 ASSERT (SELECT count(*) FROM auth.users)=0, 'Existing identities: preserve and inspect';
END $$;
CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_cron;
