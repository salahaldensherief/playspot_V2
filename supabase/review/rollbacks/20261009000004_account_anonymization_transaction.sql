-- Emergency containment. Retain pending reconciliation records and disabled profiles.
-- Roll back/disable the Edge deletion endpoint first; never re-enable affected accounts.
BEGIN;
REVOKE EXECUTE ON FUNCTION public.anonymize_account_for_deletion(uuid) FROM service_role;
COMMIT;
