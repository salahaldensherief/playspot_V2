# Lifecycle repairs and Arabic copy — 16 October 2026

Source baseline: `65cebbf99b122cf0191f1fd8e5ff1069463a693f`.

## Application fixes

- Signup no longer depends on authenticated-session providers. Locale changes retain the current route and unsaved form while refreshing translated labels.
- Authentication creates only missing profiles and preserves customer-managed names and avatars. Profile write failures do not launch a second Google authentication flow. External Google/Facebook callback ordering remains unverified.
- Search suppresses unknown distances, formats known distances, and accepts valid long email domain suffixes. Booking availability interpolates its hour template correctly.
- Offline banners reserve layout space. The home header measures bundled fonts and text scaling; denied location shows the unavailable state. Profile navigation exposes tournaments/history consistently.
- Tournament reads retain bronze match types and authorized participant names through the new scoped RPC. The championship tree and real third-place playoff are separate. Read/realtime failures remain visible instead of leaving perpetual loading.
- Arabic interface copy uses Modern Standard Arabic. Existing translation keys, interpolation arguments and links are preserved. Brand names and customer-authored data are not translated.

## Backend candidates — not a hosted deployment

Seven new migrations are **reviewed source candidates**, tested in disposable native PostgreSQL fixtures; the tournament candidates were additionally exercised in a new isolated local Supabase stack. No production/cinematic Demo migrations, accounting changes or dataset rebuild were performed.

1. `20261015192841`: fail closed when legacy booking cash totals disagree with the shift ledger, including the synthetic EGP130 discrepancy without a modern receipt. Tested only in disposable fixtures; financial prerequisite/rollout review remains required.
2. `20261015193610`: resolved-feeder bracket progression, genuine dispute/confirmation validation, terminal-phase publication protection and consistent writer locking.
3. `20261015220755`: server clock phase transitions; **pg_cron with the cron schema is required**. Owner-only worker, bounded batches, skips terminal/drawn tournaments.
4. `20261015221433`: authorized display-name roster without private profile contact fields or broad profile RLS changes. Both client repositories need this contract before their tournament reads are deployed.
5. `20261015221806`: free/paid registration, capacity serialization, FIFO waitlist promotion, cancellation/refund state consistency and payment validation.
6. `20261015223039`: balanced byes, real semifinal-loser bronze playoff for new eligible draws, actual podium and completion gating. Existing drawn brackets/IDs are preserved.
7. `20261016103116`: due-time/room/phase match start, tournament transition to in_progress, started-match-only results and a deadline worker with compatible tournament-first locks and preserved server-only grants.

Do not blindly replay migration history against a hosted project. Verify prerequisite helpers, schema, deployed definitions, existing data and operational scheduling separately. Source commits do not prove hosted contracts were installed.

## Verification

- Latest complete Flutter suite after formal Arabic changes: **572 passed, 1 skipped**.
- Native PostgreSQL: **53 suites, zero failures**. Bronze suite covers 29 cases; start/security/concurrent-lock suite covers 15.
- Real isolated local Auth/PostgREST/RLS: **32 lifecycle scenarios passed**, including championship/bronze, awards once, capacity races, duplicates, deadline confirmation and simultaneous semifinal progression. Fixture timestamps advance intentionally; the clock worker drives phases.
- Analyzer: no errors/warnings; eight pre-existing deprecated API informational diagnostics. Formatting clean. Android debug build succeeds with the local public client configuration; no private/service-role key is bundled.
- Actual contained Android UI verified signup, existing local-account login/profile completion, home/venue/room/price, tournament navigation, championship/bronze names and scores, read-only match details and logout. Actual EN→AR→EN preserved the typed signup name and translated labels. That initial runtime language proof predates the final formal-copy assets; final copy runtime checks are recorded separately.

These checks are not whole-product or production certification. Booking/session/canteen/extension/staff/shift real-UI lifecycles, external integrations, precise paid/check-in eligibility UX, broader dispute races and manual physical-prize delivery remain to verify. Hosted financial RPC/migration prerequisites remain rollout blockers. Test credentials, logs and screenshots stay outside Git.
