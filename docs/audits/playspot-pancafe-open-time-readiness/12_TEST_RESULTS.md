# Test results and evidence ledger

Environment: Windows, Flutter 3.44.1 / Dart 3.12.1, worktrees created from remote `dev` on 2026-10-22. Baselines: mobile `7caf41086a5f41dc8bd1a2c2e37a8bde722149e4`; dashboard `7c53b1edafb08e5e1fc51d5964ab82c87903e838`.

| Check | Evidence/result |
| --- | --- |
| Mobile focused Open Time/model checks | 14 passed, MOCK TESTED |
| Mobile `flutter test` | 627 passed, 1 skipped, 0 failed, MOCK TESTED |
| Mobile `flutter analyze --no-fatal-infos` | Passed before final documentation, SOURCE CHECKED |
| Dashboard focused station/scheduler checks | Station projection 2 passed; scheduler expiry/no-transition test passed, MOCK TESTED |
| Dashboard initial `flutter test` | 1307 passed, 2 skipped, 11 failed: 10 visual fixture expectations after adding a second room presentation; 1 missing optional `RoomCubit` in session-only fixture. Both implementation/test causes were patched. |
| Dashboard affected-test rerun | `flutter test --no-pub test/features/bookings/session_start_cycle_test.dart test/features/analytics/dashboard_spacing_visual_test.dart --reporter expanded`: 20 passed, 0 failed. |
| Dashboard full rerun | `flutter test --no-pub --reporter expanded`: 1318 passed, 2 skipped, 0 failed, MOCK TESTED. |
| Final duplicate-active-station regression | Focused rerun after final patch: 3 passed, 0 failed; targeted `dart analyze` found no issues. |
| Backend SQL, RLS and concurrency suite | NOT RUN against disposable exact schema; BLOCKED |
| Browser/20–40 stations, real audio, offline endurance | NOT VERIFIED |
| Android signed AAB / 16 KB / actual device | `flutter build appbundle --release --no-pub` failed closed because release signing is not configured. `android/gradlew.bat bundleRelease -PallowDebugReleaseSigning=true` reached `:app:packageReleaseBundle` then failed for insufficient disk space; generated build was cleaned. No AAB, real-device or 16 KB verification. |
| Dashboard production web build | `flutter build web --release --no-pub`: passed, generated `build/web` locally; compilation only, no staging/browser certification. |
| PR CI | Pending PRs |

Update this ledger with rerun output and exact commit/CI links before merging. A passing mock test never implies real financial or device safety. See [release](13_RELEASE_READINESS.md).
