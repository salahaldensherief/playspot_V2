# Client financial and table-management privilege review

Read-only hosted catalog inspection on 2026-10-01 confirmed `TRUNCATE`, `TRIGGER`
and `REFERENCES` grants to `anon`/`authenticated` across public tables, including
payments and permission tables. The payment ALL policy checked only the canonical
profile role and did not check active/banned eligibility. This is catalog evidence;
no anonymous HTTP exploit, destructive query or live privilege change was attempted.

PostgreSQL RLS does not govern whole-table `TRUNCATE` or foreign-key `REFERENCES`
checks. Table privileges need a separate boundary from UI permissions and RLS.
Reference: https://www.postgresql.org/docs/17/ddl-rowsecurity.html

## Review source

- `financial_client_privileges.sql` revokes all client table privileges on payments
  and shift payments, restores authenticated SELECT only, and replaces the three
  inspected legacy policies with verified account/financial-scope read policies.
  Restrictive read guards contain other leftover permissive policies. Customers
  can read their own payment; assigned billing staff and active canonical admins
  can read the permitted venue's records. Banned/inactive/deleted Auth accounts
  cannot read surviving financial rows. Authorized SECURITY DEFINER RPCs retain
  their validated mutation path; direct client cash/wallet fallback writes must
  be retired before rollout.
- `client_table_management_privileges.sql` targets PostgreSQL 17 and revokes
  TRUNCATE, REFERENCES, TRIGGER and MAINTAIN across existing public tables. It also
  removes those future defaults for the executing owner, at both global and public
  schema levels. Ordinary RLS-governed SELECT/INSERT/UPDATE/DELETE grants and trusted
  service-role maintenance privileges remain unchanged by this second source.

## Remaining deployment work

Hosted public tables/default ACLs have both `postgres` and `supabase_admin` owners.
The executing role must have grantor/owner authority over each affected existing
table; PostgreSQL can otherwise warn without revoking all grants. Defaults belonging
to another owner are not changed by `ALTER DEFAULT PRIVILEGES` for the executor.
The provider-owned defaults require a separately authorized owner/admin operation.
Do not report those defaults fixed merely because this source executes once.

After a reviewed deployment, re-query actual inherited table privileges and both
owners' default ACLs. Inspect all remaining read/write policies, RPC execution grants
and client mutation call sites. This review does not prove every backend feature or
permission boundary complete. Source profile-role containment and active-admin
repairs are rollout prerequisites; none has been applied by this work.

## Native verification

34 PostgreSQL 17.11 financial-boundary cases passed, including actual denied client
TRUNCATE/INSERT/UPDATE/DELETE, RLS reads with a leftover permissive policy, banned
super-admin denial and a successful authorized partial-cash RPC after revocation.
43 table-management cases passed for current/future tables and global/schema default
ACLs, denial of actual client TRUNCATE, retained scoped ordinary DML, intact existing
data and retained service-role maintenance privileges. Fixtures use one executor
owner; hosted multi-owner revocation is not established by these results.

Run with `PLAYSPOT_NATIVE_PG_PORT=55439`:
`node supabase/tests/financial_client_privileges.test.mjs` and
`node supabase/tests/client_table_management_privileges.test.mjs`.
All destructive-denial probes were confined to disposable local fixture databases.
No migration or dev/main merge was performed.
