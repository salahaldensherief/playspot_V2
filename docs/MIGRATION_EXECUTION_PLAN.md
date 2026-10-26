# PlaySpot Staging Migration Execution Plan

**Date:** 2026-10-26 22:00+03:00  
**Status:** Plan Approved; Execution Pending Staging Authorization (TASK 01)  
**Target:** Explicitly designated Staging Project (or verified-backup Demo `tmqhncduzlavgqoyjcmn`)  
**Production Rule:** Under no circumstances apply to `tgpdexoitemmpruepgyt`  

---

## 1. Pre-Flight Checklist & Safety Invariants

Before executing any DDL in the target environment:

- [ ] **Target Verification:** Run validation check to confirm project reference is NOT `tgpdexoitemmpruepgyt`.
- [ ] **Full Cluster Backup:** Managed backup created in Supabase Dashboard (`Database -> Backups -> Take Backup`). Snapshot ID and timestamp recorded.
- [ ] **Traffic Isolation:** Verify that active cashier sessions on the target are closed or acknowledged as testing sessions.
- [ ] **Transaction Wrapping:** Every migration script must be executed within an explicit `BEGIN; ... COMMIT;` block to prevent partial DDL application on failure.

---

## 2. Migration Execution Sequence (11 Sequential Migrations)

The target environment (`tmqhncduzlavgqoyjcmn`) currently stops at `20261017121640`. Applying the 6 new PR #89 financial migrations requires first applying the 5 intermediate migrations in timestamp order:

### Phase 1: Intermediate Core Contracts (2026-10-19 to 2026-10-21)

| Step | Migration File | Key Objects / DDL |
| :---: | :--- | :--- |
| **01** | `20261019212746_live_request_ownership_and_resolution.sql` | `REVOKE UPDATE ON canteen_orders`; RLS on `service_calls`; `resolve_live_request` function |
| **02** | `20261019212750_live_session_visit_number.sql` | Updates `get_live_bookings_with_items` to calculate customer visit count across full history |
| **03** | `20261020123340_live_booking_read_permissions.sql` | `REVOKE INSERT, UPDATE, DELETE ON bookings`; RLS on `bookings` enforcing permission catalog |
| **04** | `20261020151000_sync_lounge_review_summary.sql` | `update_lounge_average_rating` function; `trg_update_lounge_rating` trigger on `lounge_reviews` |
| **05** | `20261021120000_live_session_read_contract.sql` | Updated `get_live_bookings_with_items` and `get_all_bookings_admin` contracts |

### Phase 2: Financial & Permission Architecture (2026-10-25 to 2026-10-26)

| Step | Migration File | Key Objects / DDL |
| :---: | :--- | :--- |
| **06** | `20261025101139_atomic_discount_cash_checkout.sql` | `collect_booking_cash_partial`; atomic checkout RPC `checkout_booking_cash_atomic` |
| **07** | `20261025151217_owner_permission_write_boundary.sql` | `lounge_staff_permissions` table & index; `get_lounge_staff_permissions`; `set_staff_permission` |
| **08** | `20261025170000_guard_pre_session_manual_transfer_total.sql` | `private.guard_pre_session_manual_transfer_total` trigger on `payments` |
| **09** | `20261025225255_canonical_booking_collections.sql` | `private.booking_money_movements` (append-only); `private.booking_movement_payout_entries`; `private.booking_money_coverage` view; `verify_booking_deposit_transfer` RPC |
| **10** | `20261025225913_branch_booking_refund_policy.sql` | `private.booking_refund_policy_versions` (append-only); immutable snapshots on `bookings`; `configure_branch_booking_refund_policy`; `get_branch_booking_refund_policy` |
| **11** | `20261026100000_guard_paid_deposit_payment_quote.sql` | `get_booking_payment_destination` RPC with fail-closed guard preventing over-quoting |

---

## 3. Validation Protocol & Executable Commands

Following migration execution, run the following verification commands to ensure schema integrity without violating security boundaries:

### A. PostgREST RPC Catalog Probe (PowerShell)
```powershell
$url = "https://<staging-ref>.supabase.co"
$anonKey = "<staging-anon-key>"
$ownerToken = "<owner-jwt>"

$headers = @{ apikey = $anonKey; Authorization = "Bearer $ownerToken"; "Content-Type" = "application/json" }

# 1. Verify checkout_booking_cash_atomic exists (expects 400 Bad Request on invalid params, NOT 404 Not Found)
Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/checkout_booking_cash_atomic" -Headers $headers -Body "{}"

# 2. Verify verify_booking_deposit_transfer exists
Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/verify_booking_deposit_transfer" -Headers $headers -Body "{}"

# 3. Verify get_lounge_staff_permissions exists
Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/get_lounge_staff_permissions" -Headers $headers -Body '{"p_lounge_id":"<lounge-id>"}'

# 4. Verify set_staff_permission exists
Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/set_staff_permission" -Headers $headers -Body "{}"
```

### B. Append-Only Trigger Integrity Verification (SQL)
```sql
-- Attempting to update an existing money movement must fail with an append-only exception:
DO $$
BEGIN
  BEGIN
    UPDATE private.booking_money_movements
    SET amount = 99999
    WHERE id = (SELECT id FROM private.booking_money_movements LIMIT 1);
    RAISE EXCEPTION 'TEST_FAILED: booking_money_movements update was not blocked';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM LIKE '%append-only%' OR SQLSTATE = '42501' OR SQLSTATE = 'P0001' THEN
        RAISE NOTICE 'TEST_PASSED: append-only trigger properly blocked update';
      ELSE
        RAISE;
      END IF;
  END;
END $$;
```

---

## 4. Rollback Strategy

If any migration in Phase 2 fails during execution or causes operational failure:

### Immediate Action (Transaction Level):
Since all migrations must be run in `BEGIN; ... COMMIT;` blocks, any script failure automatically rolls back the entire file.

### Manual Down-Script (If Phase 2 needs to be reversed after partial commit):
```sql
BEGIN;

-- 1. Drop quote guard
DROP FUNCTION IF EXISTS public.get_booking_payment_destination(uuid);

-- 2. Drop refund policies
DROP TRIGGER IF EXISTS booking_refund_policy_snapshot_immutable ON public.bookings;
DROP TRIGGER IF EXISTS zz_snapshot_booking_refund_policy ON public.bookings;
DROP TRIGGER IF EXISTS booking_refund_policy_versions_append_only ON private.booking_refund_policy_versions;
DROP FUNCTION IF EXISTS public.configure_branch_booking_refund_policy(uuid, integer, integer);
DROP FUNCTION IF EXISTS public.get_branch_booking_refund_policy(uuid);
DROP TABLE IF EXISTS private.booking_refund_policy_versions CASCADE;

-- 3. Drop canonical movements & deposit verifier
DROP TRIGGER IF EXISTS guard_canonical_booking_payment_write ON public.booking_payments;
DROP VIEW IF EXISTS private.booking_money_coverage CASCADE;
DROP TABLE IF EXISTS private.booking_movement_payout_entries CASCADE;
DROP TABLE IF EXISTS private.booking_money_movements CASCADE;
DROP FUNCTION IF EXISTS public.verify_booking_deposit_transfer(uuid, text, text, text);

-- 4. Drop pre-session transfer guard
DROP TRIGGER IF EXISTS guard_pre_session_manual_transfer_total ON public.payments;
DROP FUNCTION IF EXISTS private.guard_pre_session_manual_transfer_total();

-- 5. Drop staff permission boundaries
DROP FUNCTION IF EXISTS public.get_lounge_staff_permissions(uuid);
DROP FUNCTION IF EXISTS public.set_staff_permission(uuid, uuid, text, boolean);
DROP TABLE IF EXISTS public.lounge_staff_permissions CASCADE;

-- 6. Drop atomic cash checkout
DROP FUNCTION IF EXISTS public.checkout_booking_cash_atomic(uuid, uuid, integer, text, integer, text);

COMMIT;
```

### Full Disaster Recovery Rollback:
If database catalog inconsistency occurs, trigger **Restore from Backup** in Supabase Dashboard -> Database -> Backups using the snapshot taken during pre-flight.

---

## 5. Acceptance Criteria for Task 02 Handoff

Task 01 is complete when:
1. Staging target is designated and authenticated.
2. Verified backup is confirmed restorable.
3. Execution plan and rollback down-scripts are reviewed.
4. Next task (Task 02) can execute migrations and live E2E testing without any risk to production or demo data.
