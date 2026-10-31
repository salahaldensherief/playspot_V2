-- Readable only to trusted server functions in this disposable local project.
-- Unlike a caller-controlled setting, clients cannot enable transport suppression.
CREATE TABLE private.local_development_environment (
  environment text PRIMARY KEY CHECK(environment='synthetic-only-v1')
);
ALTER TABLE private.local_development_environment ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.local_development_environment FROM PUBLIC,anon,authenticated,service_role;
INSERT INTO private.local_development_environment VALUES ('synthetic-only-v1');
REVOKE ALL ON FUNCTION public.handle_notification_webhook() FROM PUBLIC,anon,authenticated,service_role;
