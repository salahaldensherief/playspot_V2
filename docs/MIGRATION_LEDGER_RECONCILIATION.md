# PlaySpot — Migration Ledger Reconciliation Report

**Project Target:** `tmqhncduzlavgqoyjcmn` (PlaySpot Staging/Demo)  
**PostgreSQL Version:** 17.11.0.003  
**Date of Audit:** October 27, 2026  
**Status:** **AUDITED & RECONCILIATION SPECIFICATION READY**

---

## 1. Executive Summary & Problem Statement

Prior to executing the financial E2E verification suite, an audit of the hosted PostgreSQL instance on `tmqhncduzlavgqoyjcmn` revealed a metadata discrepancy:
- The internal migration tracking table `supabase_migrations.schema_migrations` recorded only **21 migrations**, ending at `20261017121640_demo_cash_session_start_before_collection`.
- All **11 subsequent core and financial migrations** (`20261019212746` through `20261026100000`) had already been deployed to the database via the staged bundle (`supabase/staged_migrations_bundle.sql`).
- All corresponding database objects (`checkout_booking_cash_atomic`, `verify_booking_deposit_transfer`, `get_lounge_staff_permissions`, `set_staff_permission`, `get_booking_payment_destination`, `get_branch_booking_refund_policy`, `private.booking_money_movements`, etc.) were confirmed active and functional in PostgreSQL catalogs (`pg_proc`, `pg_class`, `pg_trigger`).

---

## 2. Root Cause Analysis

1. **Decoupled Execution Mechanism:**
   - The Supabase CLI records a migration in `supabase_migrations.schema_migrations` when executing migrations via `supabase db push` or `supabase migration up`.
   - The staging deployment was executed via the Supabase Dashboard Web SQL Editor by running the consolidated bundle `supabase/staged_migrations_bundle.sql`.
   - The bundle contained raw DDL statements for the 11 migrations, but did **not** append the administrative `INSERT INTO supabase_migrations.schema_migrations (version) VALUES (...)` statements.
2. **Impact & Risk Assessment:**
   - **Runtime Functionality:** Unaffected. All database objects, triggers, RLS policies, and private schemas are fully operational.
   - **CLI Tooling Risk:** If a developer or CI pipeline attempts to run `supabase db push` against `tmqhncduzlavgqoyjcmn` without reconciling the ledger, the CLI would attempt to re-execute the 11 migrations from disk, which would fail or generate conflict errors on already-existing relations and functions.

---

## 3. The 11 Verified Deployed Migrations

The following 11 migration files exist in `supabase/migrations/` and are verified as live in PostgreSQL catalogs on `tmqhncduzlavgqoyjcmn`:

| # | Migration Version | Exact File Name | Verified Live Objects & Constraints |
|---|---|---|---|
| 1 | `20261019212746` | `20261019212746_live_request_ownership_and_resolution.sql` | `public.resolve_live_request`, `service_calls` policy, `canteen_orders` revocation |
| 2 | `20261019212750` | `20261019212750_live_session_visit_number.sql` | `get_live_bookings_with_items` visit count calculation |
| 3 | `20261020123340` | `20261020123340_live_booking_read_permissions.sql` | `bookings_select_policy`, PostgREST grant revocations on `public.bookings` |
| 4 | `20261020151000` | `20261020151000_sync_lounge_review_summary.sql` | `update_lounge_average_rating`, `trg_update_lounge_rating` on `public.lounge_reviews` |
| 5 | `20261021120000` | `20261021120000_live_session_read_contract.sql` | `get_live_bookings_with_items`, `get_all_bookings_admin` contracts |
| 6 | `20261025101139` | `20261025101139_atomic_discount_cash_checkout.sql` | `checkout_booking_cash_atomic`, `collect_booking_cash_partial`, `private.cash_collection_receipts` |
| 7 | `20261025151217` | `20261025151217_owner_permission_write_boundary.sql` | `public.staff_permissions`, `get_lounge_staff_permissions`, `set_staff_permission` (36 catalog) |
| 8 | `20261025170000` | `20261025170000_guard_pre_session_manual_transfer_total.sql` | `private.guard_pre_session_manual_transfer_total` trigger on `public.payments` |
| 9 | `20261025225255` | `20261025225255_canonical_booking_collections.sql` | `verify_booking_deposit_transfer`, `private.booking_money_movements` |
| 10 | `20261025225913` | `20261025225913_branch_booking_refund_policy.sql` | `configure_branch_booking_refund_policy`, `get_branch_booking_refund_policy`, immutable snapshots |
| 11 | `20261026100000` | `20261026100000_guard_paid_deposit_payment_quote.sql` | `get_booking_payment_destination` with fail-closed paid deposit quote guard |

---

## 4. Reconciliation Procedures

### Recommended Method A: Official Supabase CLI Repair
Where the Supabase CLI is authenticated and linked to the project (`supabase link --project-ref tmqhncduzlavgqoyjcmn`), execute the official repair command for each verified version:

```bash
# Execute in repository root
supabase migration repair 20261019212746 --status applied
supabase migration repair 20261019212750 --status applied
supabase migration repair 20261020123340 --status applied
supabase migration repair 20261020151000 --status applied
supabase migration repair 20261021120000 --status applied
supabase migration repair 20261025101139 --status applied
supabase migration repair 20261025151217 --status applied
supabase migration repair 20261025170000 --status applied
supabase migration repair 20261025225255 --status applied
supabase migration repair 20261025225913 --status applied
supabase migration repair 20261026100000 --status applied
```

### Alternative Method B: Direct SQL Ledger Synchronization
If CLI linking is unavailable, execute the following idempotent SQL script in the Supabase Dashboard Web SQL Editor for project `tmqhncduzlavgqoyjcmn`:

```sql
-- Safe Reconciliation of Supabase Migration Ledger
-- Target: tmqhncduzlavgqoyjcmn (PlaySpot Demo/Staging)

BEGIN;

INSERT INTO supabase_migrations.schema_migrations (version)
VALUES
  ('20261019212746'),
  ('20261019212750'),
  ('20261020123340'),
  ('20261020151000'),
  ('20261021120000'),
  ('20261025101139'),
  ('20261025151217'),
  ('20261025170000'),
  ('20261025225255'),
  ('20261025225913'),
  ('20261026100000')
ON CONFLICT (version) DO NOTHING;

COMMIT;

-- Verification Query:
SELECT version, inserted_at
FROM supabase_migrations.schema_migrations
ORDER BY version DESC
LIMIT 15;
```

---

## 5. Protective Directives & Operational Rules

> [!WARNING]
> **DO NOT RUN `supabase db push` BEFORE APPLYING THIS RECONCILIATION**  
> Running `supabase db push` while `schema_migrations` stops at `20261017121640` will attempt to re-execute already deployed DDL and can cause migration conflicts. Once the 11 records are inserted, `supabase db push` will report `Local and remote schemas are in sync`.

> [!CAUTION]
> **PRODUCTION TARGET (`tgpdexoitemmpruepgyt`) PROHIBITION**  
> Under no circumstances should this repair or any migration script be run against production project `tgpdexoitemmpruepgyt` without formal staged release authorization.
