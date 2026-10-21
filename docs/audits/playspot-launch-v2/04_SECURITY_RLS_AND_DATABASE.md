# Security, RLS and database

Audit date: 21 October 2026 (Africa/Cairo). Scope: Mobile/backend dev `ca455197568f618285b4f52e1b25bfa52c892eb2`; Dashboard dev `a3b9c4bf50fa2b07c6318475a75dbfac2cd5b6c0`.

Evidence levels: source inspection, hosted **read-only catalog** inspection, isolated synthetic PostgreSQL execution, Flutter unit/widget execution. No live business workflow was executed. `VERIFIED` refers only to a named executed check, never whole-product readiness. Task 01 coverage remains **partial**: live Auth/Storage/Realtime workflows, full-schema combined peak-hour execution, operator usability and exhaustive semantic contract verification remain open. See [12](12_TEST_EVIDENCE.md) and [15](15_UNVERIFIED_ASSUMPTIONS_AND_DECISIONS.md).

## Observed boundaries

Production and demo were inspected only with SELECT/catalog/tool reads. No customer rows, tokens, vault values or private credentials were queried. public function bodies include code that references secret stores, but no secret retrieval function was executed. Hosted catalog snapshots are evidence of deployment state, not attack simulations.

201 public/storage policies were inspected structurally. The inventory has73 tables and6 views. All72 application tables report RLS enabled; extension-owned spatial_ref_sys does not. Four application views (active_lounge_requests, slot_waitlist, canteen_upsell_conversion_v and canteen_low_stock_alerts_v) have security_invoker=true. The other two are PostGIS metadata views using has_table_privilege. These catalog observations do not prove the full user-role read matrix; see evidence/public-views.json. Core bookings/payment/shift policies carry actor/lounge predicates. payments and shift_payments have read-scope predicates and no ordinary write policy in the captured policy set; grants and trigger-enforced paths are separately recorded. Profile insertion has both a permissive own-id policy and a restrictive policy: OR-combination alone would be insufficient, but zz_guard_profile_sensitive_columns exists BEFORE INSERT/UPDATE and restores/prohibits protected role/lounge/points fields. Do not report that as an exploited role-escalation vulnerability without reproducing all guards.

Sensitive RPCs inspected: start/extend/complete/status/cancel/hold/checkout/payment, lounge booking reads, shift closure and lounge permission helpers. SECURITY DEFINER functions use auth.uid/resource authorization and fixed search_path in these paths. The only definer functions with no configured path in the public inventory were three extension-owned st_estimatedextent overloads. This does not certify all definer bodies or all admin endpoints.

The anonymous executable application definers returned by the privilege query are discovery/support/availability functions. Intentional public execution still requires checking returned columns, venue visibility and enumeration/rate-limit behavior. authenticated EXECUTE is not a vulnerability by itself; body authorization must be evaluated. Conversely a locked-down Flutter screen is not authorization.

## Confirmed security blocker

PS-001: deployed send-system-announcement v1 grants owner role global messaging scope; dev contains canonical-super-admin authorization. The endpoint has verify_jwt=false, but that flag alone does not prove anonymous access: the handler performs its own checks. The defect is the accepted owner role and caller-controlled broadcast topic. No production request or FCM send was made.

## Storage

Read-only bucket metadata confirmed private kyc-documents, payment-proofs, receipts, tournament-receipts and tournament-result-proofs. Public catalogue/promotion buckets are separate. Private evidence buckets restrict supported MIME types and use 10 MiB limits; promotion-assets has a 5 MiB limit. Private-bucket existence is not proof that every signed-URL policy/ownership check is correct. Uploaded proof must bind actor + booking/object prefix; receipt tests are synthetic. Real wrong-actor URL generation/download and Storage upsert need authorized staging identities.

## Advisors and limits

Security advisor reported extension_in_public (postgis, btree_gist), RLS disabled on spatial_ref_sys, definer execute warnings, 18 RLS-without-policy tables and disabled leaked-password protection. Private internal tables with no policies may intentionally fail closed; these are not 18 proven data leaks. Confirm spatial_ref_sys grants and supported extension relocation before planning changes. Password hardening reference: [Supabase password security](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). Advisor remediation reference: [database linter](https://supabase.com/docs/guides/database/database-linter).

A bounded redacted scan of2376 current tracked text files (1054Mobile,1322Dashboard) found no service_role JWT, sb_secret or private-key-header candidate. This is not a complete secret scan: Git history, obfuscated/other secret formats, environment values and credential validity were not checked. No exposed service-role credential is asserted. See evidence/credential_scan.json. Test all enabled roles across two lounges and owner branches, banned/inactive actors, expired tokens, permission removal and long-running sessions. Remaining service deployment parity, real login/reset/token refresh/logout, export permissions, view role-execution behavior and full admin action matrix are launch-review work. Native fixtures validate selected controls only.

## Database integrity

Production has validated bookings_room_booking_period_excl using GiST (room_id, cashier_capacity_period), plus tournament station overlap and payout period overlap exclusions. The capacity predicate excludes cancelled/rejected rows and requires nonnull room/range. Capture of the constraint is not proof every writer populates its range correctly. Current writer/online-booking guards, hold advisory locks, row locks and native fixed-session tests provide additional evidence, with synthetic trigger limits documented. Never introduce a second independently authoritative writer for the same resource/window.

Use [evidence/prod_policies.json](evidence/prod_policies.json), constraints/triggers/column privileges and [FINDINGS](FINDINGS.md). Do not deploy SQL snapshots under evidence/.
