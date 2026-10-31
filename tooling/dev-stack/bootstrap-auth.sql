-- The export excludes triggers on managed auth.users. Attach only the reviewed
-- role-fixed signup function; never attach metadata-role-based legacy helpers.
CREATE TRIGGER playspot_local_01_profile_created AFTER INSERT ON auth.users
 FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
CREATE TRIGGER playspot_local_02_notification_settings AFTER INSERT ON auth.users
 FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_notification_settings();
-- Restore the two source-observed extension-table guards omitted by pg_dump.
CREATE TRIGGER zz_block_api_truncate BEFORE TRUNCATE ON public.spatial_ref_sys
 FOR EACH STATEMENT EXECUTE FUNCTION private.block_api_writes();
CREATE TRIGGER zz_block_api_writes BEFORE INSERT OR DELETE OR UPDATE ON public.spatial_ref_sys
 FOR EACH ROW EXECUTE FUNCTION private.block_api_writes();
-- Local acceptance never starts scheduled jobs; no callbacks/mail/FCM delivery.
DO $$ BEGIN ASSERT NOT EXISTS(SELECT 1 FROM cron.job WHERE active), 'Unexpected active scheduler jobs'; END $$;
NOTIFY pgrst,'reload schema';
