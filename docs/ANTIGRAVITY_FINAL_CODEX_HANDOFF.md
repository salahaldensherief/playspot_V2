---
project: PlaySpot
checkpoint_date: 2026-10-26
checkpoint_timezone: Africa/Cairo
status: codex_rescue_complete; dashboard_launcher_merged; demo_e2e_probed; production_untouched
mobile_remote_dev: b631e54ff75846d6d5d8b014e131a17448bbb2f5
dashboard_remote_dev: 4991e4bb169e81c11fabcefda0c265a1a5370745
production_supabase_ref: tgpdexoitemmpruepgyt
separate_demo_supabase_ref: tmqhncduzlavgqoyjcmn
---

# Antigravity final Codex handoff

## FINAL RESCUE & DEV HANDOFF SUMMARY - 26 OCTOBER 2026, 21:25+03:00 (CANONICAL CURRENT STATE)

### 1. Final Git SHAs and Merged PRs

- **Mobile + Backend (`salahaldensherief/playspot_V2`):**
  - `dev` prior to this handoff commit: `b631e54ff75846d6d5d8b014e131a17448bbb2f5` (merged [PR #89](https://github.com/salahaldensherief/playspot_V2/pull/89) at `ac9b9da05673b2139d63847525fb8fefd1971d54` and documentation [PR #90](https://github.com/salahaldensherief/playspot_V2/pull/90) at `b631e54ff75846d6d5d8b014e131a17448bbb2f5`).
  - Post-merge CI on `b631e54ff75846d6d5d8b014e131a17448bbb2f5`: Dart formatting review (`#40350363653`) and Flutter CI (`#40350363654`) both passed (`success`).
- **Dashboard (`salahaldensherief/Playspot_dashboard`):**
  - Final `dev`: `4991e4bb169e81c11fabcefda0c265a1a5370745`.
  - Merged PRs on `dev`:
    - [PR #85](https://github.com/salahaldensherief/Playspot_dashboard/pull/85) (`79fccdfe3b1017680165b639027ef93fa4abf496`): Preview backend isolation and fail-closed Supabase configuration.
    - [PR #86](https://github.com/salahaldensherief/Playspot_dashboard/pull/86) (`91630de429be79a1485b6f7fc447241f6ecd7c20`): Combined atomic cash checkout (#83) and owner staff permission boundary (#84). Post-merge CI (`#40346067725` and `#40346067745`) passed (`success`).
    - [PR #87](https://github.com/salahaldensherief/Playspot_dashboard/pull/87) (`4991e4bb169e81c11fabcefda0c265a1a5370745`): Recovered Codex local development launcher (`scripts/launch_local.ps1`), documentation, and hosted financial contract gap report. Pre-merge CI (`#40371361584` and `#40371361529`) and post-merge `dev` CI (`#40372632548` and `#40372632594`) all passed (`success`).

### 2. Recovered Codex Local Files and Commits

- Located uncommitted Codex work in `C:\Users\salah\Documents\Codex\2026-10-21\files-pasted-by-the-user-playspot\dashboard-local-launch-20261026` on branch `fix/local-development-launch-20261026`:
  - `scripts/launch_local.ps1` (new, 105 lines): PowerShell launcher separating `-Environment Demo` from `-Environment Development`, validating `SUPABASE_URL` and `SUPABASE_ANON_KEY`, rejecting production (`tgpdexoitemmpruepgyt`), rejecting demo ref in `Development` mode, and rejecting privileged `sb_secret_`/`service_role` keys.
  - `docs/LOCAL_DEVELOPMENT_LAUNCH.md` (new, 11 lines): Windows launch instructions and env file contract.
  - `docs/qa/2026-10-26-hosted-financial-contract-gap.md` (new, 18 lines): Hosted vs `dev` SQL contract gap report.
  - `AGENTS.md` (+2 lines) and `README.md` (+2 lines).
  - Unstaged generated `macos/Flutter/GeneratedPluginRegistrant.swift` and git-ignored `.env.demo` were left untouched in the recovery worktree.
- Committed as `0a1e5e253dd16895e32be2fc32bdf5604e2f1cb8` (`chore: add validated local development launcher and hosted contract gap report`) and merged into Dashboard `dev` via [PR #87](https://github.com/salahaldensherief/Playspot_dashboard/pull/87) (`4991e4bb169e81c11fabcefda0c265a1a5370745`).

### 3. Applied vs. Unapplied Migrations

- **Production Supabase (`play spot`, ref `tgpdexoitemmpruepgyt`):**
  - **131 applied migrations** ending at `20261020133056_sync_lounge_review_summary`. Strictly untouched.
- **Separate Demo Supabase (`playspot-demo`, ref `tmqhncduzlavgqoyjcmn`):**
  - **21 applied migrations** ending at `20261017121640_demo_cash_session_start_before_collection`.
- **Unapplied Migrations on Both Hosted Environments (6 files from Mobile PR #89):**
  1. `supabase/migrations/20261025101139_atomic_discount_cash_checkout.sql`
  2. `supabase/migrations/20261025151217_owner_permission_write_boundary.sql`
  3. `supabase/migrations/20261025170000_guard_pre_session_manual_transfer_total.sql`
  4. `supabase/migrations/20261025225255_canonical_booking_collections.sql`
  5. `supabase/migrations/20261025225913_branch_booking_refund_policy.sql`
  6. `supabase/migrations/20261026100000_guard_paid_deposit_payment_quote.sql`
- **Why Hosted DDL Was Not Applied Automatically:** Local machine inspection confirmed that only PostgREST/Auth keys (`SUPABASE_ANON_KEY` and `service_role` JWT in `D:\PlaySpotDemoRuntime\private\`) exist on disk; no direct PostgreSQL connection password, `psql`/`supabase` CLI, or Supabase Management API personal access token (`sbp_...`) is stored locally, and PostgREST (`/rest/v1/`) does not execute raw DDL (`CREATE FUNCTION`/`CREATE TABLE`).

### 4. Actual End-to-End Test Evidence

- **Launcher Validation & Guardrails (`scripts/launch_local.ps1`):**
  - `./scripts/launch_local.ps1 -Environment Demo -ValidateOnly` -> `Validated Demo configuration for project tmqhncduzlavgqoyjcmn.` (exit 0).
  - Production ref (`tgpdexoitemmpruepgyt`) -> rejected (`The production Supabase project is forbidden for local development builds.`).
  - Demo ref (`tmqhncduzlavgqoyjcmn`) under `-Environment Development` -> rejected (`Development mode requires a separate, explicitly prepared development project...`).
  - Secret key (`sb_secret_...`) -> rejected (`A privileged Supabase key cannot be used in Flutter.`).
- **Authenticated Multi-Role E2E Probes Against Live `playspot-demo` (`tmqhncduzlavgqoyjcmn`):**
  - Verified password sign-in (`/auth/v1/token?grant_type=password`), RLS-scoped table reads, and `get_staff_permissions` RPC across all 4 roles for lounge `a1f2c158-6aad-5b9f-88d0-7aecb1def34d`:
    - **Customer** (`demo_c001@playspot-demo.com` / `4a076d31-7ec1-5503-98b9-7c4a77442bb7`): Auth OK; sees 1 lounge, 6 rooms, and only own **3 bookings** under RLS; `get_staff_permissions` returns `role: "user"`, `lounge_id: null`, all 36 staff permissions `false`.
    - **Owner** (`demo_v02_lounge_owner@playspot-demo.com` / `9bfb2467-377f-52d9-9798-392c502fdc76`): Auth OK; sees 1 lounge, 6 rooms, and all **31 lounge bookings**; `get_staff_permissions` returns `role: "owner"`, 34/36 permissions `true`.
    - **Manager** (`demo_v02_manager@playspot-demo.com` / `8d6b4e2d-5c60-5dfc-aba9-1e25d42116f2`): Auth OK; sees 1 lounge, 6 rooms, and all **31 lounge bookings**; `get_staff_permissions` returns `role: "manager"`, 33/36 permissions `true` (`payouts_manage: false`).
    - **Cashier** (`demo_v02_cashier@playspot-demo.com` / `d308b85e-44ca-5ab8-a035-fe93354cca22`): Auth OK; sees 1 lounge, 6 rooms, and all **31 lounge bookings**; `get_staff_permissions` returns `role: "cashier"`, operational cashier permissions `true` (`billing_checkout`, `bookings_create`, `pos_create_orders`, `rooms_view_status`, `sessions_control`, `shifts_open_own`, `shifts_blind_close`) and sensitive owner/manager permissions `false` (`billing_apply_discount`, `billing_void_item`, `bookings_cancel`, `staff_manage`, `shifts_review_and_approve`, `shifts_view_blind_cash`, `payouts_manage`).
  - Confirmed that the unapplied PR #89 RPCs (`checkout_booking_cash_atomic`, `verify_booking_deposit_transfer`, `get_lounge_staff_permissions`, `set_staff_permission`) return `HTTP 404 PGRST202` on `playspot-demo`, so clients fail closed on those new financial/permission write operations until the 6 migrations are applied.
- **Exact-Schema Financial Fixture Evidence (Preserved Locally):**
  - Preserved in `C:\Users\salah\Documents\Codex\2026-10-21\files-pasted-by-the-user-playspot\financial-schema-local\` (`exact_schema_checkout_proof.json`, `exact_schema_movements_proof.json`, `exact_schema_permission_proof.json`, `exact_schema_refund_policy_proof.json`, `exact_schema_transfer_guard_proof.json`).

### 5. Dashboard Launch Command & Canonical Local Setup

- Both canonical checkouts (`D:\flutter_projects\play_spot_dashboard` at `4991e4bb169e81c11fabcefda0c265a1a5370745` and `D:\playspot_V2`) now have git-ignored `.env.demo` and `.env` configured to point to `playspot-demo` (`https://tmqhncduzlavgqoyjcmn.supabase.co`).
- **Validate Configuration Only:**
  ```powershell
  Set-Location D:\flutter_projects\play_spot_dashboard
  ./scripts/launch_local.ps1 -Environment Demo -ValidateOnly
  ```
- **Launch Dashboard in Chrome (Demo Backend):**
  ```powershell
  Set-Location D:\flutter_projects\play_spot_dashboard
  ./scripts/launch_local.ps1 -Environment Demo
  ```
- **Launch Dashboard in Chrome (Dedicated Development Backend, once `.env.development` is prepared):**
  ```powershell
  Set-Location D:\flutter_projects\play_spot_dashboard
  ./scripts/launch_local.ps1 -Environment Development
  ```

### 6. APK and Browser-Preview Status

- **Canonical Dashboard Web Build (`D:\flutter_projects\play_spot_dashboard\build\web\main.dart.js`):**
  - Built cleanly with `flutter build web --release --no-pub --dart-define-from-file=.env.demo` (6,512,607 bytes).
  - Verified embedded project ref: `tmqhncduzlavgqoyjcmn` = `True`, `tgpdexoitemmpruepgyt` = `False`.
- **Live Local Browser Preview (`http://127.0.0.1:51611/`):**
  - Active local server (Node PID `3820`) returns HTTP 200 for `/` (2,774 bytes) and `/main.dart.js` (6,512,445 bytes, `tmqhncduzlavgqoyjcmn` = `True`, `tgpdexoitemmpruepgyt` = `False`).
- **Demo-Connected Android APK (`C:\Users\salah\Documents\Codex\2026-10-21\files-pasted-by-the-user-playspot\outputs\playspot-dev-demo-20261026.apk`):**
  - 200,083,207 bytes, SHA-256 `0251942AEDE65D6D99534F0CBB72CACA30E953C6508A8582E7BA67E6C367CE19`, valid v2 signature, pointing to `tmqhncduzlavgqoyjcmn` (same backend as the Dashboard demo configuration). Physical device installation remains pending a connected `adb` device and hosted migration deployment.

### 7. Remaining Blockers

1. **Hosted Development SQL Migration Deployment:** Applying the 6 PR #89 migrations (plus their prerequisite schema baseline if applied to `playspot-demo`) requires either the Supabase Dashboard SQL Editor or `supabase db push` / `psql` with the database password/PAT after taking a verified database backup.
2. **Manual Refund / Reversal Accounting:** Cancellation and refund-policy snapshots (`booking_refund_policies`) classify refund eligibility, but actual manual refund/reversal money movements (`private.booking_money_movements`) and shift/commission offsets are not yet implemented.
3. **Mixed-Custody Payout Settlement & Platform-Finance Verifier:** `settle_lounge_payout_atomic` still requires migration to movement-derived custody/commission math (`private.booking_money_movements`), and platform-held deposits require a dedicated platform-finance verification path.

### 8. Safe-to-Delete (Deleted) vs. Preserved Branches & PRs

- **Deleted Remote Branches (19 total - all verified 100% ancestor-merged into `origin/dev`, no open PR, and not checked out in any local worktree):**
  - **`playspot_V2` (9 deleted):**
    - `backend/playspot-core-v2` (`87201c8d088458d9b9d18dd090240639a3e6dc85`)
    - `ci/verify-mobile-android-release` (`7866b44bbc2c23dbc65746f74e68832c53bcebe3`)
    - `codex/backend-audit` (`b13fa450899f01d5d73e0669c1ed62e64f5a8583`)
    - `codex/catalogue-tombstones` (`b53a0b6716a93a8881d78dfe67aa48d14e45cc51`)
    - `codex/complete-playspot` (`b55f3ae72f9e95e588c01e68eea1aa23796a5093`)
    - `docs/atlas-open-time-draft-status` (`28d16911b717bc6c33527d56fe535657b12c7eae`)
    - `docs/playbook-system-atlas-20261022` (`24ff85642e5b019d1e3190ea1ee9cc2c0f027f38`)
    - `fix/compact-photo-button` (`4e0f03e155605585411d883157aadc73f6ded58b`)
    - `integration/mobile-financial-permissions-20261026` (`836cb05f366ed503b52b071e5983f1f08b7660e5`)
  - **`Playspot_dashboard` (10 deleted):**
    - `codex/backend-audit` (`a33526aa294287a480556d0f4708a2dd616181f7`)
    - `codex/complete-play` (`c945529fe67d458ea1713e34caaa5723698068f2`)
    - `codex/review-followups` (`cc2f866943eec49282531f91b9d6218a2700a383`)
    - `codex/session-start-cycle` (`69f2a3b37e463b2ca56fde0b657b0e622997791f`)
    - `docs/atlas-open-time-draft-status` (`cb5c7cec884df412f5afc46a28074e6e951460e1`)
    - `docs/playbook-system-atlas-20261022` (`77d8a0b3fbe55fd74a4895fff27853e43e9709e9`)
    - `fix/active-marketing-default` (`0fa929b968960f05501f4163a2402a0e53f98caf`)
    - `fix/scheduler-canonical-close-safety` (`4be53d823f519b8b291412f172bd41a789f66f3f`)
    - `offline_cashier_conflict_resolution` (`37a12c56ff4bf03b2e9b1d388301a081f67a57db`)
    - `supabase_access_check` (`9a1ff9a10290e094f76b7dcdf50d703eabbef121`)
- **Preserved Remote Branches & Open Draft PRs:**
  - All merged branches that are still checked out in local worktrees (`docs/antigravity-final-codex-handoff-20261026`, `docs/splash-final-evidence`, `fix/atomic-discount-cash-checkout`, `fix/branch-refund-policy`, `fix/canonical-financial-movements`, `fix/owner-permission-boundary`, `fix/pre-session-transfer-guard`, `fix/restore-splash-font` in Mobile; `docs/restore-approved-dashboard-ui`, `fix/atomic-dashboard-cash-checkout`, `fix/local-development-launch-20261026`, `fix/owner-staff-permission-ui`, `fix/preview-backend-isolation-20261026`, `integration/financial-dev-20261026` in Dashboard) are preserved so local worktree upstream refs remain intact.
  - All unmerged branches and all open PRs (13 in `playspot_V2`, 5 in `Playspot_dashboard`) are preserved in **Draft** state, including Mobile [PR #63](https://github.com/salahaldensherief/playspot_V2/pull/63) and Dashboard [PR #67](https://github.com/salahaldensherief/Playspot_dashboard/pull/67), which were converted to Draft so no older October 16 audit PR is accidentally merged without review.
  - All 58 local worktrees/clones across `C:` and `D:` and `D:\CodexBackups\Docker\codex-docker-original.vhdx` remain 100% untouched.

### 9. Next NEW Product Development Priorities

1. **Apply the Reviewed Backend Migrations to a Backed-Up Hosted Development Target:** Use Supabase SQL Editor or CLI with DB credentials to bring the development Supabase project up to the `dev` migration head (`20261026100000_guard_paid_deposit_payment_quote.sql`), then run full authenticated cross-client E2E checkout (`checkout_booking_cash_atomic`), deposit verification (`verify_booking_deposit_transfer`), and staff permission toggling (`get_lounge_staff_permissions` / `set_staff_permission`).
2. **Implement Verified Manual Refund & Reversal Ledger Movements:** Add an authorized RPC that writes negative/reversal rows to `private.booking_money_movements` and reconciles `bookings.payment_status`, `booking_payments`, and active shift cash totals when money is actually returned.
3. **Upgrade Payout Settlement (`settle_lounge_payout_atomic`) for Mixed-Custody Movements:** Compute platform-held vs lounge-held net balances and commissions directly from `private.booking_money_movements`, and add a dedicated platform-finance deposit verification workflow.
4. **Integrate Remaining Reviewed Open-Time & Financial Drafts:** Rebase and evaluate Mobile Draft PRs [#75](https://github.com/salahaldensherief/playspot_V2/pull/75) (`feature/open-time-customer-display`), [#82](https://github.com/salahaldensherief/playspot_V2/pull/82) (`test/financial-schema-fingerprint`), and [#83](https://github.com/salahaldensherief/playspot_V2/pull/83) (`fix/open-time-partial-status-contract`) against current `dev`.

---
## LIVE ADDENDUM — 26 OCTOBER 2026, 18:04+03:00 (READ BEFORE OLDER CHECKPOINT TEXT)

**The following is NEWER than the dated original checkpoint below and takes precedence wherever statuses conflict.**

- Owner clarified: PlaySpot remains in **active development/testing**. Consolidate **verified development source** onto `dev`; the owner wants to test the actual integrated apps, not accumulate finished Drafts. This is **not** authorization for uncontrolled loss of hosted data, blind SQL execution, or merging to `main`.
- **Dashboard `dev` is now `91630de429be79a1485b6f7fc447241f6ecd7c20`**. GitHub [PR #86](https://github.com/salahaldensherief/Playspot_dashboard/pull/86), combining cashier PR #83 and employee permissions PR #84, was **MERGED** following successful integrated CI (Flutter CI and Dart format) on `fb1c0763ee04e7b0aac4e8f713fcd58af4cc78c0`. GitHub also marked source PRs #83/#84 **MERGED**. Preview-isolation PR #85 was merged earlier. The post-merge `dev` formatting check passed; post-merge Flutter CI was **in progress** at the time of this addendum: https://github.com/salahaldensherief/Playspot_dashboard/actions/runs/40346067745. Recheck it.
- **Mobile/backend `dev` remains `ac9b9da05673b2139d63847525fb8fefd1971d54`**, integration PR #89 merged. Separate Mobile documentation-only handoff PR #90 is being updated. The remaining Mobile financial/Open Time draft PRs (#75, #82, #83) have **not** been merged and need overlap/compatibility analysis.
- **BOTH source `dev` branches are now integrated for the recent cashier/permissions changes. Hosted SQL has NOT been applied** as a consequence of these GitHub merges. Live Supabase `play spot` (ref `tgpdexoitemmpruepgyt`) has 131 recorded migrations ending at `20261020133056_sync_lounge_review_summary`; separate `playspot-demo` (ref `tmqhncduzlavgqoyjcmn`) has 21 recorded migrations ending at `20261017121640_demo_cash_session_start_before_collection`. New cash/deposit/permission/ledger RPCs are not proven on either hosted environment. The current dashboard `dev` preview fails closed without explicit build-time Supabase config.
- User wants to test using **real hosted development environments**, rather than test only mocks. Treat hosted data and Auth users as worth preserving even if the product is prelaunch: first classify which accounts, bookings and payments are genuine vs disposable, capture a restorable backup/recovery path and migration compatibility check, then run scoped authenticated development tests. **Never mistake a merged SQL file for a deployed migration.** Do not operate on `main` or deploy user-facing production without separate approval.
- **Branch hygiene:** GitHub currently lists **81 Mobile remote branches** and **75 Dashboard remote branches**, including `dev` and `main`; count is not proof of obsolescence. Preserve branches for open Draft PRs, unmerged unique changes, release recovery, and the many dirty local Codex worktrees. Deletion candidates must be individually proven fully contained in `dev` or otherwise intentionally superseded, and **must not** be checked out in a dirty local worktree. Prefer deleting only reviewed merged, no-longer-used feature refs; never mass-delete by date or prefix. Retain handoff records and any recovery refs until Antigravity successfully imports them.
- **Current next step:** verify post-merge Dashboard CI; establish backed-up hosted development DB contract; apply only reviewed migrations to the explicitly selected development backend with rollback plan; test authenticated customer/owner/cashier, fixed/Open Time, deposit + cash, staff permissions, cancellation/refund eligibility and ledger/payout integrity; then deliver a truly usable same-backend APK + Dashboard preview. Previous demo APK is NOT financial E2E acceptance.

### Updated first message for Antigravity

> Read both repository `AGENTS.md` and `docs/PLAYSPOT_SYSTEM_ATLAS.md`, then this LIVE ADDENDUM and all prior Codex handoff evidence. Mobile/backend `dev` is `ac9b9da05673b2139d63847525fb8fefd1971d54`; Dashboard `dev` is `91630de429be79a1485b6f7fc447241f6ecd7c20`, with cashier + permissions PR #86 and predecessor PRs #83/#84 merged as **source-only dev integration**. Recheck branches/CI; preserve every dirty worktree on C: and D:. Audit all 81/75 remote branches for safe cleanup but never delete any unmerged or dirty-worktree branch. The owner is in prelaunch dev and wants real hosted development testing; choose and verify a backed-up, recoverable hosted backend and distinguish development test records from important data before applying any SQL. Set explicit Supabase staging/development build-time URLs and keys; ensure no hidden production fallback. Verify Auth, RLS, finance, refunds and payouts under real users; deliver a same-backend installed APK and Dashboard preview. Never claim source merges deployed SQL, never blindly mutate live finance rows, never touch main, never force/reset/clean or remove Docker backups. Report verified test evidence and any blockers.

---

## Read this first

This is a dated checkpoint, not proof that any source migration is deployed. Read `AGENTS.md` and `docs/PLAYSPOT_SYSTEM_ATLAS.md` in both repositories, then fetch both `origin/dev` branches and inspect worktrees/dirty changes before editing. Never reset, clean, force-push, overwrite a dirty worktree, deploy to production, apply SQL to the production project, or touch the Docker VHDX backup at `D:\CodexBackups\Docker\codex-docker-original.vhdx`.

Canonical repositories: `salahaldensherief/playspot_V2` (Mobile + SQL), local checkout `D:\playspot_V2`; `salahaldensherief/Playspot_dashboard` (Flutter Web), available checkout `C:\Users\salah\Documents\Codex\2026-10-21\files-pasted-by-the-user-playspot\dashboard-atomic-checkout`. Both target **dev**, never main. The owner authorized verified dev integration, not production deployment.

## Verified Git state and work in this turn

| Repository | Remote `dev` | Merged | Still Draft/local |
| --- | --- | --- | --- |
| Mobile + backend | `ac9b9da05673b2139d63847525fb8fefd1971d54` | [PR #89](https://github.com/salahaldensherief/playspot_V2/pull/89), combining #84–#88 as source-only dev work | [#75](https://github.com/salahaldensherief/playspot_V2/pull/75), [#82](https://github.com/salahaldensherief/playspot_V2/pull/82), [#83](https://github.com/salahaldensherief/playspot_V2/pull/83) remain separate. Local integration branch `integration/financial-dev-20261026` at `d30b18cea32acebea2cf8cec43f74e4d3abaad6e` predates the externally completed #89 merge and is redundant; preserve it until reviewed. |
| Dashboard | `79fccdfe3b1017680165b639027ef93fa4abf496` | [PR #85](https://github.com/salahaldensherief/Playspot_dashboard/pull/85) merged a Preview isolation fix from `b7b54ce43afafaaa49a172d863776d1a4b555f81` | Cashier [#83](https://github.com/salahaldensherief/Playspot_dashboard/pull/83) and owner-permission [#84](https://github.com/salahaldensherief/Playspot_dashboard/pull/84) remain Draft. Combined [Draft PR #86](https://github.com/salahaldensherief/Playspot_dashboard/pull/86) at `fb1c0763ee04e7b0aac4e8f713fcd58af4cc78c0` contains both against current dev; both CI workflows passed. |

PR #85 was necessary because Vercel builds `dev` pushes as Preview and the Dashboard's old `lib/core/constants/app_constants.dart` had production Supabase URL and anon key fallbacks. PR #85 removes the fallbacks so builds without explicit Dart defines fail closed. The Vercel project has production-targeted Supabase variables; no preview-targeted variables were listed. `dev` deployments are Preview (`target: null`); last inspected production deployment came from `main` commit `fd46373158f41cef21b7e380045868c3b8afae59`. Old already-published previews may still have embedded production fallback and should not be shared as staging.

Only a **Preview isolation** change was merged in Dashboard this turn. The combined financial and permissions Dashboard code was exercised locally and preserved in Draft PR #86, but not merged because the separate hosted demo backend lacks its new RPCs and authenticated integration was not proven. PRs #83/#84/#86 should be advanced only after backend-first isolated staging validation and a safe preview build configuration. Source merge #89 did **not** apply SQL to any hosted project. This checkpoint is also preserved in Mobile [Draft PR #90](https://github.com/salahaldensherief/playspot_V2/pull/90), documentation only.

## Exact verification, with limits

- Mobile/backend PR #89 integration commit `836cb05f366ed503b52b071e5983f1f08b7660e5`: [Flutter CI #40309123430](https://github.com/salahaldensherief/playspot_V2/actions/runs/40309123430) and [formatting #40309123204](https://github.com/salahaldensherief/playspot_V2/actions/runs/40309123204) both reported success. PR #89 merged as `ac9b9da...`. These CI fixtures use PostgreSQL but are not full hosted Auth/browser tests.
- Dashboard combined local integration at `16c9e22...`: `flutter analyze --no-fatal-infos` found **0 issues**; full `flutter test --reporter compact` finished **1,337 passed, 2 skipped**; `dart format --output=none --set-exit-if-changed lib test` checked **1,121 files, 0 changed**; `flutter build web --release --no-pub` succeeded. Unconfigured `build/web` contained neither production nor demo Supabase project ref. The financial tests are mocked client contracts, not signed-in backend flows.
- Dashboard Preview safety PR #85 at `b7b54ce...`: [Flutter CI #40339176500](https://github.com/salahaldensherief/Playspot_dashboard/actions/runs/40339176500) and [formatting #40339176482](https://github.com/salahaldensherief/Playspot_dashboard/actions/runs/40339176482) succeeded before the dev merge. Recheck CI on merged dev `79fccdfe...` before claiming post-merge CI.
- Combined Dashboard Draft PR #86 at `fb1c076...`: [Flutter CI #40341604002](https://github.com/salahaldensherief/Playspot_dashboard/actions/runs/40341604002) and [formatting #40341604007](https://github.com/salahaldensherief/Playspot_dashboard/actions/runs/40341604007) both succeeded on the merged-against-current-dev head. These CI checks still do not exercise real hosted Auth or canonical SQL.
- Vercel built Draft PR #86 as a READY Preview at `https://playspot-dashboard-gj1t6ef5c-salaheldindev11-6746s-projects.vercel.app/` with `target: null`; its fetched `main.dart.js` contained neither production nor demo Supabase project reference. This Preview is deliberately unconfigured and cannot serve as the requested authenticated demo.
- Vercel built Dashboard `dev` `79fccdfe...` as a READY Preview at `https://playspot-dashboard-2a3ptvqf0-salaheldindev11-6746s-projects.vercel.app/`, not a production deployment. HTTP `/` returned 200; the fetched deployed `main.dart.js` contained neither production nor demo Supabase project reference. It is intentionally **not a usable signed-in staging preview** because no isolated backend is configured for that Preview. The latest inspected production deployment remains on `main`.
- A separate local Dashboard build from combined Draft PR #86 commit `fb1c076...` used explicit demo-project Dart defines. Its compiled `main.dart.js` contains the demo ref and no production ref. A local static server on `http://127.0.0.1:51611/` (Node PID 3820 at this checkpoint) returned HTTP 200 for `/` and `/main.dart.js`. The in-app browser actually rendered the English `/login` page with email/password fields and Sign In button. The tab was left open. This is **limited visual access**, not authenticated acceptance: no credentials were supplied, and the demo backend lacks canonical finance/permission RPCs. Server source: `...\outputs\serve_dashboard_preview.cjs`; build root: `...\integration-dashboard-20261026\build\web`. Restart the local server if the process ends.
- Earlier exact-schema financial evidence belongs to the previous Docker engine: the schema-only snapshot had 3,607/3,607 application catalog fingerprints, and isolated rollback fixtures covered deposits, mixed cash, checkout concurrency, permission denial and policy snapshots. This turn **could not re-run** those fixtures: after a Docker Desktop restart the active engine has no containers/images and localhost port 55443 is unavailable. The 1.3 MB schema-only dump and evidence files remain at `C:\Users\salah\Documents\Codex\2026-10-21\files-pasted-by-the-user-playspot\financial-schema-local`. Do not equate the fingerprint with a full managed Auth clone. Preserve the old Docker VHDX and inspect Docker contexts/storage before any reconstruction.
- Separate hosted project `tmqhncduzlavgqoyjcmn` is named `playspot-demo`. Read-only inspection found 73 public tables, 269 Auth users, 24 lounges, 144 rooms and 655 bookings. Its migration list stops at `20261017121640_demo_cash_session_start_before_collection`; `checkout_booking_cash_atomic` and `private.booking_money_movements` were absent. No SQL was applied there. Do not assume the accounts/data are disposable without reviewing ownership, backup and rollback.
- The local Dashboard login page was checked in a real browser, but **no signed-in current-Dashboard owner/cashier test** or Android device install was completed. After finding local demo test accounts on D:, direct password Auth and `/auth/v1/user` calls succeeded for both the demo owner and customer, and both returned the expected local user IDs. Credentials and tokens were never printed. This proves those two demo Auth accounts work, not that the current Dashboard or financial RPCs work. A successful compile and APK signature check do not prove authenticated flows or installability on a device.

## Demo-connected Android artifact

Built from Mobile/backend `dev` commit `ac9b9da...` with explicit build-time URL and public publishable key for the **separate demo project**, not production. Local artifact: [playspot-dev-demo-20261026.apk](C:/Users/salah/Documents/Codex/2026-10-21/files-pasted-by-the-user-playspot/outputs/playspot-dev-demo-20261026.apk). SHA-256: `0251942AEDE65D6D99534F0CBB72CACA30E953C6508A8582E7BA67E6C367CE19`, 200,083,207 bytes. `apksigner verify` reported a valid v2 signature and one signer; package `com.playspot.client`, min SDK 24, target SDK 36. The debug kernel contains the demo project reference and no production project reference. `adb devices -l` found no connected device, so physical installation and sign-in were untested. **Do not use this APK for financial acceptance:** the demo project lacks the new backend migration contract. No demo credentials are documented or shared here.

## Financial and operational invariants / release blockers

No payment gateway exists. Manual InstaPay/wallet proof is not receipt of money. Owners configure a small reservation deposit; no-deposit cash booking remains allowed where authorized. A verified deposit is only partial collection. Final bills can include time, extension and canteen. Movement-level method/custody/shift/commission/idempotency must reconcile with booking, payment and payout aggregates. An earlier synthetic example was EGP 20 verified lounge-held transfer + EGP 130 cash on EGP 150 gross. Platform-held transfer needs a separate authorized platform-finance verifier. Cancellation/refund-policy eligibility does not mean money was returned. Actual verified manual refund/reversal accounting and mixed-custody payout settlement are unfinished. Existing legacy clients and tabs can fail closed after partial collection. Older payouts and history need migration and reconciliation rules, not inferred collection methods.

Open Time/fixed-session final collection, canteen charges and state transitions still need signed-in end-to-end checks. Owner/employee permissions require RLS and revocation checks under real Auth. Offline cashier writer fencing, native operations and Windows Bridge/hardware are not production-verified. Preserve approved Dashboard UI; rejected Live Operations redesign is not a target.

Read-only D: discovery after this checkpoint: `D:\PlaySpotWork\mobile` and `D:\PlaySpotWork\dashboard` are older handoff checkouts with extensive dirty changes; `D:\PlaySpotDemoRuntime\private` contains local demo owner/customer test account material and a public demo client configuration; never copy credentials into Git or reports. That runtime has an older read-only demo client, not the current combined financial branch. `D:\PlaySpotQA\reports` contains older October 15 QA evidence. `D:\CodexBackups\Docker\codex-docker-original.vhdx` is a 15,799,943,168-byte backup and must remain untouched. The active Docker Desktop context had no containers and its WSL distro was stopped on inspection; this D: inventory does not restore or revalidate the previous exact-schema container.

## Current worktrees and preservation warnings

Important Mobile paths: `D:\playspot_V2` is local `dev` at `ac9b9da...` and clean; `...\mobile-staging-build-20261026` is `build/staging-apk-20261026` at `ac9b9da...` with seven Flutter-generated desktop files modified by `flutter build`; `...\integration-mobile-20261026` is at `d30b18c...` with seven generated files modified; `...\handoff-mobile-20261026` is the docs branch for Draft PR #90 (verify its latest remote head before editing). Important Dashboard paths: `...\dashboard-atomic-checkout` at `641725a...` clean; `...\dashboard-owner-permissions` at `b324e41...` has one pre-existing dirty `AGENTS.md`; `...\dashboard-preview-safety-20261026` at `b7b54ce...` clean; `...\integration-dashboard-20261026` at `fb1c0763ee04e7b0aac4e8f713fcd58af4cc78c0` is clean. The generated macOS change from this integration worktree is preserved in Git stash `793f6ce235a5231995fd91349111c67816b2c6ed`; an apply after merging dev reported already up to date, so do not drop it without inspection. Additional unrelated dirty worktrees observed: `C:\Users\salah\.codex\worktrees\playspot-full-audit\playspot_V2` (8 files), `...\work\dashboard-current` (1), `...\playspot-ops-dashboard` (5), `...\scheduler-safety-eval` (1), and `...\playspot-splash-font` (7 generated files). **Enumerate exact files before touching any of them.** No cleanup was performed.

## Next 10 safe tasks, dependency order

1. Fetch both current `dev` heads; re-read both `AGENTS.md` and Atlas files; confirm all above worktrees, PR heads, dirty files and merged CI without resetting anything.
2. Verify Dashboard merged `dev` CI and Vercel Preview `79fccdfe...` completion; confirm compiled Preview cannot contact production and old previews are not shared as staging.
3. Establish a staging backend with an actual restorable backup and full Auth/PostgREST/Storage. Either restore the exact schema into a **new** isolated Docker context without touching the old VHDX, or prepare the separate hosted demo after documenting backup/recovery and migration compatibility.
4. Apply the six Mobile #89 SQL migrations **only** to isolated staging in timestamp order; compare effective signatures, grants/RLS, triggers, constraints and baseline data first. Do not replay old migrations or touch production.
5. Run exact-schema rollback and real authenticated role tests for checkout, deposits, permissions, shift ownership, duplicate/lost ACK, refund eligibility, canteen and full/partial settlement. Reconcile movements, payments, shift_payments and ledgers, not merely RPC success.
6. The local combined Dashboard branch already includes current `dev` at `79fccdfe...`; fetch any newer `dev` before further edits. Compare #83/#84 RPC payloads and receipts to the staged backend and deployed legacy-client behavior while preserving its generated-file stash.
7. Build a Dashboard Preview with explicit **staging** Dart defines and inspect the actual compiled project reference. Verify owner/cashier login and Arabic/English flows in a real browser; then merge #83/#84 to `dev` only if the integrated flow is safe.
8. Implement authorized manual refund/reversal movements with verified actual return, partial/full/duplicate/concurrent tests, commission and custody adjustments; keep this as a focused Draft until exact-schema acceptance.
9. Fix mixed-method/mixed-custody payout settlement from method-specific movements, including negative offsets and reconciliation; add protected platform-finance deposit verification. Never mark a screenshot or cancellation as paid/refunded.
10. Build one shared staging-connected Dashboard/Android pair with synthetic owner/cashier/customer accounts; test device installation, real Auth, booking through final settlement, permissions, reports and failure recovery. Only then provide credentials and a Preview URL. Production approval remains a separate step.

## Specific successor entry points

- Mobile SQL: `supabase/migrations/20261025101139_atomic_discount_cash_checkout.sql`, `20261025151217_owner_permission_write_boundary.sql`, `20261025170000_guard_pre_session_manual_transfer_total.sql`, `20261025225255_canonical_booking_collections.sql`, `20261025225913_branch_booking_refund_policy.sql`, `20261026100000_guard_paid_deposit_payment_quote.sql`.
- Baseline payout: `supabase/migrations/20261011065428_payout_cash_commission_settlement.sql` and `20261011133001_latest_commit_contract_hardening.sql`; use the latest effective definition, not simply the earlier file. Financial fixture sources: `supabase/tests/financial_contract/*.cjs`.
- Dashboard: `lib/features/bookings/data/datasources/booking_remote_data_source_impl.dart` (`checkout_booking_cash_atomic`, `verify_booking_deposit_transfer`), `lib/features/permissions/data/data_sources/permissions_remote_data_source_impl.dart`, `lib/core/constants/app_constants.dart`, and `test/features/bookings/*contract_test.dart`, `test/features/permissions/staff_permission_contract_test.dart`.
- Evidence: `docs/audits/PLAYSPOT_CANONICAL_BOOKING_MOVEMENTS_20261026.md`, `PLAYSPOT_BRANCH_REFUND_POLICY_20261026.md` in Mobile; `docs/qa/2026-10-25-atomic-cash-checkout-integration.md`, `2026-10-25-owner-staff-permissions.md`, `2026-10-26-dev-preview-safety.md` in Dashboard.

## Minimal local recovery

1. Inspect the configured Docker context and `docker ps -a` **before** using any Docker storage. The active restarted engine currently has no containers/images; do not delete/reset its VHDX or the backed-up VHDX.
2. `git fetch origin dev` in each repository; compare `origin/dev` with the SHAs above. Use `git status --short --branch` on each named worktree. Preserve the ignored APK and `financial-schema-local` evidence.
3. For a safe client test, the source-only Dashboard combined branch is at `...\integration-dashboard-20261026`; backend SQL source is in Mobile `origin/dev`, but no matching hosted database exists yet. Do not point combined clients to the production Supabase project.
4. The APK above points only to the separate demo backend and is for limited non-financial exploration until staging is upgraded and sign-in/device testing passes.

## Ready-to-paste Google Antigravity continuation prompt

Continue PlaySpot from `ANTIGRAVITY_FINAL_CODEX_HANDOFF.md` dated 26 October 2026. Discover both repositories and every dirty worktree first; preserve all local branches, generated files, ignored artifacts, database dumps and Docker VHDX backups. Mobile/backend `dev` is `ac9b9da05673b2139d63847525fb8fefd1971d54` after merged PR #89. Dashboard `dev` is `79fccdfe3b1017680165b639027ef93fa4abf496` after merged Preview isolation PR #85; Dashboard financial PRs #83/#84 remain Draft. Production Supabase is `tgpdexoitemmpruepgyt` and must never be modified without separate explicit approval. The distinct `playspot-demo` project `tmqhncduzlavgqoyjcmn` has old migrations and lacks the canonical checkout/movement contract. First establish backup/recoverable full-Auth staging, apply only reviewed missing migrations there, run real signed-in owner/cashier/customer cross-client tests and movement/shift/ledger invariants, then integrate Dashboard Draft work into `dev` if safe. Continue refund, payout and platform-finance work as separate exact-schema-tested Draft changes. Do not deploy production, merge to main, reset/clean/force-push, or claim an unauthenticated preview or compiled APK proves end-to-end readiness. Report exact commits, CI, tests, preview/APK status and blockers in Egyptian Arabic.