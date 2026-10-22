# Test results and evidence ledger

Environment: Windows, Flutter 3.44.1 / Dart 3.12.1, worktrees created from remote `dev` on 2026-10-22. Baselines: mobile `7caf41086a5f41dc8bd1a2c2e37a8bde722149e4`; dashboard `7c53b1edafb08e5e1fc51d5964ab82c87903e838`.

| Check | Evidence/result |
| --- | --- |
| Mobile focused Open Time/model checks | Final focused rerun: 48 passed, 0 failed. Covers authoritative completion, app restart, realtime reconnect, committed/cancelled canteen rows and paid/unpaid/queued presentation, MOCK TESTED |
| Mobile `flutter test` | Final commit `9608768f3fd6f27b3f5be1aed530e068bb9745b0`: 643 passed, 1 skipped, 0 failed, MOCK TESTED |
| Mobile `flutter analyze --no-fatal-infos` | Final source: 0 issues in 170.5s, SOURCE CHECKED |
| Dashboard focused station/scheduler checks | Station projection 2 passed; scheduler expiry/no-transition test passed, MOCK TESTED |
| Dashboard initial `flutter test` | 1307 passed, 2 skipped, 11 failed: 10 visual fixture expectations after adding a second room presentation; 1 missing optional `RoomCubit` in session-only fixture. Both implementation/test causes were patched. |
| Dashboard affected-test rerun | `flutter test --no-pub test/features/bookings/session_start_cycle_test.dart test/features/analytics/dashboard_spacing_visual_test.dart --reporter expanded`: 20 passed, 0 failed. |
| Dashboard full rerun | Final local commit `e79e9a536ee131414b2ee199782509aa722f734e`: 1320 passed, 2 skipped, 0 failed. `flutter analyze --no-fatal-infos`: 0 issues in 152.6s, MOCK TESTED. |
| Dashboard canonical-close/scheduler rerun | `session_start_cycle_test.dart` + `session_start_alert_clock_test.dart`: 13 passed, 0 failed. Long-running Open Time uses `completeOpenTimeSession`; scheduler alerts without generic completion, MOCK TESTED. |
| Final duplicate-active-station regression | Focused rerun after final patch: 3 passed, 0 failed; targeted `dart analyze` found no issues. |
| Backend Open Time/finance fixtures | Native PostgreSQL 17.11 disposable container: Open Time contract 9, close/balance 16, actor authorization 9, live-read RLS 1, client finance privileges 34, partial collection/concurrency 47; all passed. Candidate/latest function bodies ran with no production writes. This is a reconstructed minimal schema, not an exact production schema snapshot; exact-schema gate remains BLOCKED. |
| Browser station grid | Real in-app Chromium browser against localhost Web build: 6/20/40 mixed PC/PlayStation in AR/EN; stale realtime, manual-review conflict, partial-payment alert, Open Time pending bill, alert count and Permission OFF state rendered. 20/40 ready checks were 965–980 ms after an intentional 800 ms wait; stale/conflict case 1195 ms after a 1000 ms wait; console error/warn list empty. Physical device state, sound/autoplay and multi-cashier offline endurance remain NOT VERIFIED. |
| Android signed AAB / 16 KB / actual device | `flutter build appbundle --release --no-pub` failed closed because release signing is not configured. `android/gradlew.bat bundleRelease -PallowDebugReleaseSigning=true` reached `:app:packageReleaseBundle` then failed for insufficient disk space; generated build was cleaned. No AAB, real-device or 16 KB verification. |
| Dashboard production web build | `flutter build web --release --no-pub`: passed, generated `build/web` locally; compilation only, no staging/browser certification. |
| PR CI | [Mobile formatting](https://github.com/salahaldensherief/playspot_V2/actions/runs/39769359424) and [Dashboard formatting](https://github.com/salahaldensherief/Playspot_dashboard/actions/runs/39769286813) passed. [Mobile Flutter CI](https://github.com/salahaldensherief/playspot_V2/actions/runs/39769359449) and [Dashboard Flutter CI](https://github.com/salahaldensherief/Playspot_dashboard/actions/runs/39769286687) were still in progress at this snapshot. Later documentation commits may start new mobile runs. |

Update this ledger with rerun output and exact commit/CI links before merging. A passing mock test never implies real financial or device safety. See [release](13_RELEASE_READINESS.md).
