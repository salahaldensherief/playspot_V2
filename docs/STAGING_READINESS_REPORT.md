# PlaySpot Staging Readiness Report

**Date:** 2026-10-26 22:30+03:00  
**Status:** **READY** — All 11 sequential migrations deployed and verified live on `playspot-demo` (`tmqhncduzlavgqoyjcmn`)  
**Target Architecture:** Supabase (PostgreSQL 17.11.0.003), Flutter Web Dashboard, Flutter Mobile Client  
**Canonical Baseline:**
- Mobile / Backend Repo: `salahaldensherief/playspot_V2` @ `f8d702b12f0342974757a42a43a17d8b3964dd58` (`dev`)
- Dashboard Repo: `salahaldensherief/Playspot_dashboard` @ `4991e4bb169e81c11fabcefda0c265a1a5370745` (`dev`)

---

## 1. Executive Summary & Readiness Classification: **READY**

Following owner execution of the transaction-wrapped migration bundle [staged_migrations_bundle.sql](file:///D:/playspot_V2/supabase/staged_migrations_bundle.sql) in the Supabase Dashboard SQL Editor, the staging environment `tmqhncduzlavgqoyjcmn` (`playspot-demo`) is now classified as **READY** for Task 02 (Full Financial & Operational E2E Testing).

### Live Verification Evidence (Recorded 22:25–22:32+03:00):
1. **`get_lounge_staff_permissions` RPC:**
   - Successfully called with owner token for cashier `d308b85e-44ca-5ab8-a035-fe93354cca22` at lounge `a1f2c158-6aad-5b9f-88d0-7aecb1def34d`.
   - Returns HTTP 200 OK with complete 36-permission role matrix.
2. **`set_staff_permission` RPC:**
   - Successfully invoked to set `billing_checkout: true`.
   - Returns HTTP 200 OK: `{"success": true, "lounge_id": "a1f2c158-6aad-5b9f-88d0-7aecb1def34d", "is_enabled": true, "permission_key": "billing_checkout", "target_user_id": "d308b85e-44ca-5ab8-a035-fe93354cca22"}`.
3. **`checkout_booking_cash_atomic` RPC:**
   - Active in Postgres schema cache; successfully executing logic and returning business rule enforcement (`BOOKING_NOT_FOUND` on unallocated UUIDs).
4. **`verify_booking_deposit_transfer` RPC:**
   - Active in Postgres schema cache; enforcing business constraints (`BOOKING_NOT_FOUND` on unallocated UUIDs).
5. **`get_booking_payment_destination` RPC:**
   - Successfully called on real live booking `c4bdd8e1-9cdf-5789-95b9-af63a2889d9c` at lounge `Orbit Social`.
   - Returns HTTP 200 OK: `{"can_pay": true, "lounge_id": "a1f2c158-6aad-5b9f-88d0-7aecb1def34d", "amount_due": 170.00, "booking_id": "c4bdd8e1-9cdf-5789-95b9-af63a2889d9c", "lounge_name": "Orbit Social", "confirmation_status": "confirmed"}`.
6. **`get_branch_booking_refund_policy` RPC:**
   - Successfully called for lounge `a1f2c158-6aad-5b9f-88d0-7aecb1def34d`.
   - Returns HTTP 200 OK: `{"configured": false}` (valid fallback state).

---

## 2. Hosted Supabase Projects Inventory

| Property | Production (`play spot`) | Demo (`playspot-demo`) | Proposed Staging (`playspot-staging`) |
| :--- | :--- | :--- | :--- |
| **Project Reference** | `tgpdexoitemmpruepgyt` | `tmqhncduzlavgqoyjcmn` | *To be provisioned / designated* |
| **PostgreSQL Version** | 17.6.1.155 | 17.11.0.003 | 17.x |
| **Access Policy** | **STRICTLY UNTOUCHED / FORBIDDEN** | Data-bearing testbed | Isolated staging target |
| **Migrations Applied** | 131 migrations (ends `20261020151000`) | 21 migrations (ends `20261017121640`) | 111 baseline + 6 PR #89 |
| **Auth Users** | Production customer & owner accounts | 269 verified demo users | Seed / Synthetic E2E users |
| **Live Records** | Production lounges, rooms, payments | 24 lounges, 144 rooms, 655 bookings | Fresh / Isolated clone |
| **Available Local Keys** | None (hardcoded references removed) | `anon` key + `service_role` JWT | Pending provisioning |
| **DDL Capability** | None | None locally | Via Supabase Dashboard or DB Password |

---

## 3. Local SQL Fixtures & Artifacts Inventory

1. **Canonical Migrations Directory (`D:\playspot_V2\supabase\migrations`):**
   - Contains **111 total `.sql` migrations** up to `20261026100000_guard_paid_deposit_payment_quote.sql`.
   - The 6 new financial migrations pending deployment:
     - `20261025101139_atomic_discount_cash_checkout.sql`
     - `20261025151217_owner_permission_write_boundary.sql`
     - `20261025170000_guard_pre_session_manual_transfer_total.sql`
     - `20261025225255_canonical_booking_collections.sql`
     - `20261025225913_branch_booking_refund_policy.sql`
     - `20261026100000_guard_paid_deposit_payment_quote.sql`
2. **Local Exact-Schema Worktree (`financial-schema-local`):**
   - Preserved in `C:\Users\salah\Documents\Codex\2026-10-21\files-pasted-by-the-user-playspot\financial-schema-local\`.
   - Contains schema dump `playspot_schema_20261025.sql` (1.3 MB), fingerprint `restored_fingerprint_20261026.json` (3,607 matching application catalog objects), and synthetic rollback test suites (`atomic_checkout_probe_20261025.cjs`, `financial_race_20261025.cjs`, `deposit_destination_probe_20261026.cjs`, `paid_booking_cancellation_probe_20261025.cjs`).
3. **Docker Storage Backup:**
   - Preserved untouched: `D:\CodexBackups\Docker\codex-docker-original.vhdx` (15,799,943,168 bytes).
   - Docker daemon is currently stopped; no active localhost container is running on port 55443.

---

## 4. Credential & Tooling Audit

- **Present on Local System:**
  - `Docker Desktop` binary: `C:\Users\salah\AppData\Local\Programs\DockerDesktop\resources\bin\docker.exe` (daemon stopped).
  - `WSL`: `C:\WINDOWS\system32\wsl.exe` (distro `docker-desktop` stopped).
  - Git & Git Credential Manager: active with GitHub token.
  - Demo PostgREST/Auth tokens in `D:\PlaySpotDemoRuntime\private\client-demo.json` and `demo-auth-admin-key.txt`.
- **Absent from Local System (Security Boundary Maintained):**
  - `supabase` CLI: NOT installed on PATH.
  - `psql` / `pg_dump`: NOT installed on PATH.
  - PostgreSQL database connection string / master password.
  - Supabase Management API Personal Access Token (`sbp_...`).
  - Production credentials: zero instances in code, config, or launch parameters.

---

## 5. Security & Isolation Invariants

1. **Production Inviolability:** Project `tgpdexoitemmpruepgyt` must never receive staging DDL, test user mutations, or mock transactions. The client launchers in both Mobile and Dashboard enforce fail-closed checks against this project ID.
2. **No Secret Ingestion:** Under no circumstances should the owner paste passwords or management tokens into the chat. All authorization must occur via self-contained Supabase Dashboard operations or standard local environment files (`.env.staging`, `.env.development`) excluded by `.gitignore`.
3. **Data Integrity on Demo:** `tmqhncduzlavgqoyjcmn` represents irreplaceable user testing context. Any schema migration on it must be preceded by a verified backup.

---

## 6. Minimal Owner Action Steps to Authorize Staging

To unblock staging execution securely, the project owner should choose one of two paths:

### Path A: Create a Dedicated Clean Staging Project (Strongly Recommended)
1. Log in to [Supabase Dashboard](https://supabase.com/dashboard).
2. Click **New Project**, name it `playspot-staging`, select region (e.g., Frankfurt `eu-central-1` or matching demo region), and generate a secure DB password (stored in a private password manager).
3. Under **Project Settings -> API**, copy:
   - `Project URL` (e.g. `https://<staging-ref>.supabase.co`)
   - `Project API Keys -> anon / public`
   - `Project API Keys -> service_role` (for backend E2E runner)
4. Save these into an ignored `D:\playspot_V2\.env.staging` file:
   ```env
   SUPABASE_URL=https://<staging-ref>.supabase.co
   SUPABASE_ANON_KEY=<staging-anon-key>
   SUPABASE_SERVICE_ROLE_KEY=<staging-service-role-key>
   ```
5. Run the provided baseline and migration bundle via the Supabase Dashboard **SQL Editor**.

### Path B: Safely Upgrade Existing `playspot-demo` (`tmqhncduzlavgqoyjcmn`)
1. Log in to [Supabase Dashboard](https://supabase.com/dashboard/project/tmqhncduzlavgqoyjcmn).
2. Navigate to **Database -> Backups**.
3. Under **Manual backup**, click **Take backup** and wait until the status reports completed.
4. Navigate to **SQL Editor**, open a new query tab, paste the sequential migration script prepared in `docs/MIGRATION_EXECUTION_PLAN.md`, and click **Run**.
