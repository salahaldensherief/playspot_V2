# PlaySpot Staging Readiness Report

**Date:** 2026-10-26 21:50+03:00  
**Status:** **BLOCKED** for direct client-side hosted DDL deployment; **READY FOR OWNER AUTHORIZATION / STAGING PROVISIONING**  
**Target Architecture:** Supabase (PostgreSQL 17), Flutter Web Dashboard, Flutter Mobile Client  
**Canonical Baseline:**
- Mobile / Backend Repo: `salahaldensherief/playspot_V2` @ `f8d702b12f0342974757a42a43a17d8b3964dd58` (`dev`)
- Dashboard Repo: `salahaldensherief/Playspot_dashboard` @ `4991e4bb169e81c11fabcefda0c265a1a5370745` (`dev`)

---

## 1. Executive Summary & Readiness Classification

The PlaySpot backend staging environment is classified as **BLOCKED** for automated or local direct migration execution, and requires explicit owner authorization to establish or upgrade a recoverable hosted target.

### Exact Reasons for Blocked Classification:
1. **Zero DDL Execution Privilege Locally:** The local machine possesses only PostgREST data API credentials (`SUPABASE_ANON_KEY` and `service_role` JWT in `D:\PlaySpotDemoRuntime\private\`). PostgREST strictly rejects raw DDL (`CREATE FUNCTION`, `CREATE TABLE`, `CREATE TRIGGER`, `ALTER TABLE`) with HTTP 404/PGRST202. Neither the direct PostgreSQL database password (`postgresql://postgres:[PASSWORD]@db.<ref>.supabase.co:5432/postgres`) nor the Supabase Management API Personal Access Token (`sbp_...`) exists on disk or in the local environment.
2. **Data-Bearing Nature of `playspot-demo` (`tmqhncduzlavgqoyjcmn`):** The demo project is currently populated with live test data: 269 Auth users, 24 lounges, 144 rooms, 655 bookings, 500 cash payments, and 24 cash shifts. Wiping or resetting it (`supabase db reset`) is strictly prohibited. Modifying it in-place without a restorable full-cluster backup risks permanent corruption of test identities and workflows.
3. **Absence of a Restorable Full Backup:** The local repository holds only a schema-only export (`playspot_schema_20261025.sql`) from a previously stopped local Docker container. It lacks `auth.users` encrypted passwords, `auth.identities`, storage bucket assets, RLS definitions, and production/demo transaction rows. A schema-only dump is not a recoverable staging backup.
4. **Hosted Migration Gap:** `tmqhncduzlavgqoyjcmn` stopped at migration `20261017121640_demo_cash_session_start_before_collection` (21 migrations applied). It lacks 5 prerequisite intermediate migrations (`20261019212746` through `20261021120000`) before the 6 financial migrations from Mobile PR #89 can be applied.

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
