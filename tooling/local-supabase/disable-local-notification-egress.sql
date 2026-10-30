-- REVIEW TEMPLATE ONLY. Apply solely to the newly verified disposable stack,
-- after managed schemas/extensions and the application-only restore are reviewed.
-- The local trigger behavior intentionally differs from the original fingerprint.
-- Do not apply this file to hosted databases or the preserved fixture cluster.
CREATE OR REPLACE FUNCTION public.handle_notification_webhook()
RETURNS trigger LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$ BEGIN RETURN NEW; END $$;
-- No external delivery; synthetic notifications remain database records.
