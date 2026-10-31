# Dev testing checkpoint — 2026-10-02

This integration is for testing, not a production release. All current feature
heads were integrated into dev with merge ancestry preserved. No main update,
force push, original checkout cleanup, or hosted database migration was performed.

## Confirmed local verification

- Flutter 3.44.1 / Dart 3.12.1 on Windows.
- Mobile: 298 offline Flutter tests passed; analyze succeeded with 108 existing
  informational diagnostics and no warning/error.
- Dashboard: 627 offline Flutter tests passed; two live database tests skipped;
  analyze succeeded with 21 existing informational diagnostics and no warning/error.
- Backend: all 15 isolated PostgreSQL 17.11 suites passed (461 cases), including
  concurrent wallet, session, writer/offline availability, permissions and KYC.
  These use synthetic fixtures, not the complete hosted schema or production data.
- Changed Dart files are formatted. The required whole-tree format check was
  also run: it found existing formatting debt (321 Mobile / 477 Dashboard files).
  Unrelated legacy files were not rewritten.
- Public Supabase build credentials were verified against Auth settings (HTTP
  200). No service-role key is present in client builds. Actual account sign-in,
  OAuth, paid booking and native Maps end-to-end smoke remain unverified.

## SQL and hosted contract boundary

The canonical backend source is in playspot_V2. Its 16 newly introduced migration
candidates are under supabase/review/migrations; repairs remain review-only.
Nothing here applies them. Review the review README and docs/backend before any
coordinated staging rollout. Existing migration files on dev are unchanged.

Read-only hosted inspection found that offline cashier RPCs (including
apply_offline_cashier_operation and refresh_cashier_writer) and versioned KYC
review/draft RPC contracts are not deployed. The hosted submit_lounge_review
overloads are customer ratings, not the KYC document submission contract used by
the new Dashboard. Existing Supabase branch metadata reports MIGRATIONS_FAILED.
Passing fixtures cannot establish hosted compatibility.

## Remaining production blockers

- Stage and verify compatible SQL/RLS/grants, full hosted schema lock ordering,
  financial contracts, onboarding and super-admin KYC approval end to end.
- Complete cashier UI/action adapters to the durable encrypted Hive offline
  queue, canonical bootstrap/cache and reconnect reconciliation. The command and
  writer foundation does not make every existing screen work offline.
- Verify disconnect admission/fencing, replay conflicts, shift reconciliation,
  storage/logout lifecycle, and optional future LAN coordination for multiple
  cashier devices. Single-device offline operation is the current target.
- Test real devices, authenticated booking/payment, coordinate-only directions,
  and native frame performance. Widget screenshots and rebuild measurements
  are evidence for the rendered fixtures, not a native performance certification.
- Configure production release signing. The Android test artifact uses debug
  signing explicitly; the production signing guard is preserved.
- Dashboard standard JavaScript release builds; dependency warnings mean Wasm
  compatibility is not established.

Do not declare this checkpoint production-ready or assume all flows are complete.
GitHub CI must be checked separately from local results.

## Mobile test build

flutter test
flutter analyze --no-fatal-infos
flutter build apk --release --android-project-arg=allowDebugReleaseSigning=true --dart-define-from-file=<external-public-config.json>

The explicit debug signing switch is for a test APK only. Never enable it for a
store release. Configure SUPABASE_URL and SUPABASE_ANON_KEY through the external
JSON or Dart defines; never commit actual key configuration.

The lounge/directions work includes coordinate parsing, cache/GPS races,
distance units and responsive room information. See LOUNGE_LOCATION_AND_DETAILS.md.
