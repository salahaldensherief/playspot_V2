# PlaySpot — Migration Ledger Reconciliation Report

**Project Target:** `tmqhncduzlavgqoyjcmn` (PlaySpot Staging/Demo)  
**PostgreSQL Version:** 17.11.0.003  
**Date of Audit:** October 27, 2026  
**Status:** **RECONCILIATION PLAN READY (PRE-APPLIED VERIFICATION)**

---

## 1. Executive Summary & Problem Statement

Prior to executing the financial E2E verification suite, an audit of the hosted PostgreSQL instance on `tmqhncduzlavgqoyjcmn` revealed a metadata discrepancy:
- The internal migration tracking table `supabase_migrations.schema_migrations` recorded only **21 migrations**, ending at `20261017121640`.
- All **11 subsequent financial and security migrations** (`20261019212746` through `20261026100000`) had already been deployed to the database via the staged bundle (`supabase/staged_migrations_bundle.sql`).
- All corresponding database objects (`checkout_booking_cash_atomic`, `verify_booking_deposit_transfer`, `get_lounge_staff_permissions`, `set_staff_permission`, `get_booking_payment_destination`, `get_branch_booking_refund_policy`, `private.booking_money_movements`, etc.) were confirmed active and functional in PostgreSQL catalogs (`pg_proc`, `pg_class`, `pg_trigger`).

---

## 2. Root Cause Analysis

1. **Decoupled Execution Mechanism:**
   - The Supabase CLI records a migration in `supabase_migrations.schema_migrations` when executing migrations via `supabase db push` or `supabase migration up`.
   - The staging deployment was executed via the Supabase Dashboard Web SQL Editor by running the consolidated bundle `supabase/staged_migrations_bundle.sql`.
   - The bundle contained raw DDL statements for the 11 migrations, but did **not** append the administrative `INSERT INTO supabase_migrations.schema_migrations (version) VALUES (...)` statements.
2. **Impact:**
   - **Runtime Functionality:** Unaffected. All database objects, triggers, RLS policies, and private schemas are fully operational.
   - **CLI Tooling Risk:** If a developer or CI pipeline attempts to run `supabase db push` against `tmqhncduzlavgqoyjcmn` without reconciling the ledger, the CLI would attempt to re-execute the 11 migrations from disk, which would fail or generate conflict errors on already-existing relations and functions.

---

## 3. The 11 Deployed Migrations Requiring Reconciliation

The following 11 migration versions are deployed live in PostgreSQL and must be recorded in `supabase_migrations.schema_migrations`:

| # | Migration Version | Migration Name | Verified Live Objects |
|---|---|---|---|
| 1 | `20261019212746` | `checkout_booking_cash_atomic.sql` | `public.checkout_booking_cash_atomic`, `private.cash_collection_receipts` |
| 2 | `20261019223321` | `booking_deposit_transfer.sql` | `public.verify_booking_deposit_transfer`, `private.booking_money_movements` |
| 3 | `20261020123340` | `live_booking_read_permissions.sql` | `bookings_select_policy`, PostgREST grant revocations |
| 4 | `20261020124930` | `deposit_verification_destination_fix.sql` | Destination status assertion fixes |
| 5 | `20261020141838` | `drop_duplicate_deposit_verification_overload.sql` | Removal of ambiguous RPC overloads |
| 6 | `20261022131940` | `lounge_staff_permissions.sql` | `public.lounge_staff_permissions`, `public.has_lounge_permission` |
| 7 | `20261022153000` | `staff_permission_management_rpcs.sql` | `public.get_lounge_staff_permissions`, `public.set_staff_permission` |
| 8 | `20261024103000` | `align_staff_permission_catalog.sql` | 36-permission catalog validation |
| 9 | `20261025225913` | `branch_booking_refund_policy.sql` | `public.configure_branch_booking_refund_policy`, `get_branch_booking_refund_policy` |
| 10 | `20261026090000` | `reconcile_booking_payment_destination.sql` | `public.get_booking_payment_destination` updated contract |
| 11 | `20261026100000` | `reconcile_movement_ledger_contract.sql` | `private.record_booking_money_movement` unified ledger contract |

---

## 4. Reconciliation SQL Script

Execute the following idempotent SQL script in the Supabase Dashboard SQL Editor for project `tmqhncduzlavgqoyjcmn`:

```sql
-- Safe Reconciliation of Supabase Migration Ledger
-- Target: tmqhncduzlavgqoyjcmn (PlaySpot Demo/Staging)

BEGIN;

INSERT INTO supabase_migrations.schema_migrations (version)
VALUES
  ('20261019212746'),
  ('20261019223321'),
  ('20261020123340'),
  ('20261020124930'),
  ('20261020141838'),
  ('20261022131940'),
  ('20261022153000'),
  ('20261024103000'),
  ('20261025225913'),
  ('20261026090000'),
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
> **DO NOT RUN `supabase db push` BEFORE APPLYING THIS SCRIPT**  
> Running `supabase db push` while `schema_migrations` stops at `20261017121640` will attempt to re-execute already deployed DDL and can cause migration abortion. Once the 11 records are inserted, `supabase db push` will report `Local and remote schemas are in sync`.
