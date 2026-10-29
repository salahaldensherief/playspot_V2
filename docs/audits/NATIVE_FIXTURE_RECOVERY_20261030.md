# Local native PostgreSQL fixture recovery — 30 October 2026

This is test infrastructure only, based on payout checkpoint f27c78dca153e2ac1a466c02ffcae45f4bd1d587. No financial migration, deployed function or client behavior changed. This branch is not a proposal to merge the underlying financial stack.

## Reproduction and fix

The preserved PostgreSQL 17.11 cluster at ../pg-audit-20261029 could not bind its former loopback port 55439. Read-only Windows excluded-port inspection showed 55382–55481 reserved. The same existing cluster was started on 127.0.0.1:55499; no reset, export, restore, or deletion of existing databases. The runtime now allowlists only 55439/55499 and still hardcodes loopback, fixture identity and random synthetic database names.

Ordinary offline tests also failed with OFFLINE_DST_INTERVAL_REQUIRES_REVIEW: their Date.now()-2h session crossed Cairo's autumn repeated hour. The fixture clock now chooses a round-trippable two-hour Cairo window using the database's timezone rules, searching backwards only when necessary. Two hours covers adjacent reservations. Three deterministic cases cover an ordinary date, autumn repetition and spring gap. The production DST guard is unchanged; the explicit DST-crossing rejection test still executes and passes. A failed receipt assertion now prints its synthetic response for diagnosis; no assertions removed.

## Actual commands and results

Environment: PLAYSPOT_NATIVE_PG_PORT=55499; PLAYSPOT_TEST_RUNTIME points to the existing financial-movements/supabase/tests/runtime dependency installation. Commands run with Node 24.13.0 as `node supabase/tests/<suite>.test.mjs`. Every suite printed PostgreSQL 17.11 and exited 0.

- Financial stack regression suites: manual_refund_reversal 35; refund_aware_payout_reconciliation 35; payout_funds_custody 17; partial_cash_collection 47. Total 134. These are synthetic local fixtures, not renewed proof of the historical 3,607-item exact-schema match or hosted compatibility.
- cashier_writer_availability: 51 checks passed.
- fixture_session_clock: 3 passed.
- All 13 users of fixedSessionFixture rerun after the final clock change: booking_actor_authorization 9; cashier_conflict_review 15; cashier_writer_renewal 14; cashier_writer_release 25; cash_session_start 19; future_offline_coverage 9; future_booking_hold 9; latest_writer_contracts 6; lounge_operating_status 10; offline_booking_hold_guard 8; offline_cashier_bootstrap 22; offline_fixed_session_reconciliation 54; offline_permit_renewal 25. Total 225.
- Mobile checkout Flutter tests: 9 passed earlier in this checkpoint; no Dart source changed here.
- Raw evidence: task outputs/refinement-backend-*.log and refinement-final-*.test.log. git diff --check passes.

The suite runner creates and drops only its own random local synthetic databases. Existing data and other worktrees remain preserved; the cluster is left running on 55499. No hosted DB connection, schema mutation, migration history operation, push or deployment by this test branch.

## Related Dashboard delivery and remaining gates

Owner subsequently authorized Dashboard commit 200d995f7a3a87ce5163f5ae2119a61acc154d35 and its Vercel Preview. Normal dev push succeeded; read-only ls-remote independently returned that exact commit. GitHub quality, equipment-visuals and formatting all succeeded; Vercel status succeeded. CI: https://github.com/salahaldensherief/Playspot_dashboard/actions/runs/40963032428 . Preview status: https://vercel.com/salaheldindev11-6746s-projects/playspot-dashboard/8DLf3UTDFSyqCbGeLLcCmxZuTzMr . This supersedes the older report's Dashboard push hold for that specific delivery only. Production/hosted staging untouched.

Dashboard local full tests: 1,351 passed / 2 skipped; focused equipment tests 11 passed; analysis no issues; formatting zero changed; release main Web build succeeded. Widget captures are fixtures, not browser/Auth acceptance. Browser tooling could not retain a stable Chrome window; authenticated realtime, permissions and performance acceptance remain unverified.

Financial refund/payout branches stay separate and unmerged. Independent hosted schema/function/grant/RLS compatibility and migration-ledger reconciliation are still blocked by the current no-hosted-access boundary. The alleged eleven applied migrations remain unverified; no MIGRATION_LEDGER_RECONCILIATION.md was fabricated. Signing/device/privacy acceptance also remains open as described in RELEASE_BLOCKERS_20261029.md. This test-only patch can be reviewed independently against dev; it does not establish financial deployment readiness.
