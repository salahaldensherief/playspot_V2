BEGIN;
-- Both Flutter clients use authorized RPCs for shift lifecycle writes.
-- Lounge membership RLS cannot authorize arbitrary financial/approval columns.
REVOKE INSERT,UPDATE,DELETE ON public.shifts FROM anon,authenticated;
COMMIT;
