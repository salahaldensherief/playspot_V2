# Test evidence

Audit date: 21 October 2026 (Africa/Cairo). Scope: Mobile/backend dev `ca455197568f618285b4f52e1b25bfa52c892eb2`; Dashboard dev `a3b9c4bf50fa2b07c6318475a75dbfac2cd5b6c0`.

Evidence levels: source inspection, hosted **read-only catalog** inspection, isolated synthetic PostgreSQL execution, Flutter unit/widget execution. No live business workflow was executed. `VERIFIED` refers only to a named executed check, never whole-product readiness. Task 01 coverage remains **partial**: live Auth/Storage/Realtime workflows, full-schema combined peak-hour execution, operator usability and exhaustive semantic contract verification remain open. See [12](12_TEST_EVIDENCE.md) and [15](15_UNVERIFIED_ASSUMPTIONS_AND_DECISIONS.md).

## Actual environment

Windows; Flutter3.44.1 / Dart3.12.1; Node24.13.0; native PostgreSQL17.11. Docker engine unavailable at discovery. A fresh loopback-only disposable PostgreSQL cluster was initialized under work/audit-pgdata on127.0.0.1:55439 with synthetic playspot_fixture role. No production/demo writes occurred. Existing binary was reused, not an existing customer database. The new cluster was stopped successfully after the native suites/probes; no remaining randomly named fixture databases were found before shutdown. No existing database service was stopped.

| Check / command | Actual result | Scope |
|---|---|---|
| flutter pub get, each client | Success | Pinned lockfile dependencies; no upgrades requested |
| flutter analyze --no-fatal-infos, each | No issues | Source analysis only |
| Mobile flutter test --reporter expanded |622 passed,1 skipped | Unit/widget/mocked integrations; no end-to-end production pass |
| Dashboard flutter test --reporter expanded |1307 passed,2 skipped,1 failed | live_sessions_operations_groups inconsistent fixture, PS-006 |
| Mobile dart format --output=none --set-exit-if-changed lib test |713 files,0 changes | Pass |
| Dashboard same format check |1113 files,1 would change | Fails formatting check; --output=none did not edit file |
| Dashboard python -m unittest discover -s scripts -p test_*.py |5 passed | Canonical migration policy tests |
| Dashboard node --test supabase/functions/*/*.test.mjs |85 passed | Mocked handlers/auth/partial failures; not deployed function verification |
| Native: each node supabase/tests/*.test.mjs, PLAYSPOT_NATIVE_PG_PORT=55439 |59/59 suites exit0 | Reduced synthetic schemas/stubbed Auth/PostGIS; independently logged |
| Initial PGlite same59 suites |21 exit0,37 exit1,1 abnormal Windows exit -1073740791 | Missing btree_gist/roles/native-only races/fixture assumptions; native retry supersedes environment blockers without erasing evidence |
| Bridge69 node --test tools/bridge-reference/*.test.mjs tools/hardware-lab/*.test.mjs |28 passed | No network/hardware; in-memory mocks |
| Bridge69 node supabase/tests/bridge_proposal.test.mjs |8 passed | Synthetic RLS/grants/FK/idempotency tests, not applied hosted schema |
| launch_v2_cash_start.probe.mjs |Defect reproduced, SQLSTATE55000 | Exact live definition in synthetic fixture |
| launch_v2_extension.probe.mjs |Defect behavior reproduced: paid180->230, shift+50,0 collection calls | Exact live approval definition, reduced schema; not full trigger integration |
| Dashboard flutter build web --release |SUCCESS,111.2seconds | JavaScript release; Wasm dry-run dependency warnings; no deployment |
| Mobile flutter build web --release |SUCCESS,112.2seconds | Existing consumer app compiles for web; browser Auth/booking/file/location acceptance not run |

Raw outputs and per-suite exit manifest are under evidence/. Both completed release-build logs are included. Native examples: wallet_concurrency5 checks, future_booking_hold9, payout_funds_custody17, offline_fixed_session_reconciliation54. Do not add these overlapping fixture counts into a fictitious end-to-end test total.

## Execution safety / earlier command failures

Old partial local clones failed fetch with unresolved deltas; fresh remote clones were used. Mobile default-main checkout hit Windows long paths; a clean dev worktree with core.longpaths enabled was used. Windows case-insensitive checkout collides on two PR-template names; only audit paths were staged. Initial connector calls with wrong argument schemas were rejected and corrected; no mutation occurred. One Bridge test command from the wrong directory returned0 tests and was **not** treated as a pass; rerun in the Bridge worktree ran28 tests. Two audit-probe invocations from the wrong directory did not execute and were rerun successfully in Mobile. These setup failures are not product defects.

## Not executed / not proven

Standalone historical .sql scripts, full migration-chain replay/restore, full production-schema peak-hour composite, real customer login/OTP/recovery/token refresh, real Storage downloads/uploads, FCM delivery, real payment gateway callbacks/refunds, user browser audio/autoplay, real cash reconciliation, venue staff rehearsal, vendor endpoints, Windows service crash/recovery, physical hardware, production deploy/signing/distribution and exhaustive every-request semantic role/type/nullability validation. Skipped Flutter live tests remain skipped. Release artifact compilation and old CI do not remove these gates.

## Remote CI

PR69 backend FlutterCI [39623960920](https://github.com/salahaldensherief/playspot_V2/actions/runs/39623960920), Bridge [39623961142](https://github.com/salahaldensherief/playspot_V2/actions/runs/39623961142), Dashboard [39623965997](https://github.com/salahaldensherief/Playspot_dashboard/actions/runs/39623965997) returned completed/success at their exact heads. Current-dev commit lookup through a PR-only connector returned an empty list; no current-dev CI success is claimed.
