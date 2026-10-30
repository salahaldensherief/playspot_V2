# Isolated PlaySpot acceptance — 30 October 2026

This is a running disposable local environment, not hosted compatibility evidence. The initial offline plan is retained in baseline-review.json; applied-local-set.json supersedes its NOT EXECUTED fields for this environment. Never replay that candidate list automatically.

## Identity and safety

WSL PlaySpotAcceptance20261030, registry BasePath D:/PlaySpotIsolated20261030/wsl; Docker 29.1.3 ID a5425fa1-5622-4997-8e86-a80a06cec53d, root /var/lib/playspot-docker, managed containerd root beneath it, Unix socket /run/playspot-docker.sock. Ubuntu Base 24.04.5 rootfs SHA256 e77b6f10c2590cef872b33ee9f635a0e3fd1f57fb074c0e52b5c7f56147a0c86. Pinned CLI 2.122.0 archive SHA256 59ed066847b98d7461c60e9109d40cab6b9756177ce06ebb05b51338519f5136. The separately verified PostgreSQL 17.11 image was imported through Docker image load, with all OCI blobs and RootFS diff IDs checked. Existing Docker Desktop disks, backups, contexts and old fixture clusters were not altered.

Nine local Supabase services are up: DB, Auth, Kong/API, PostgREST, Realtime, Storage, pg_meta, Studio and local mail. All containers use only playspot-acceptance-internal (Internal=true). Docker 29 ignores published ports on that bridge: actual exposure is the fixed loopback_relay.py in the dedicated guest. Actual ss listeners are 127.0.0.1:56621 API, :56622 DB, :56623 Studio and :56624 mail. Windows has no non-loopback listeners in the acceptance port range. Never rely on requested Docker PortBindings as proof.

The internal network blocks container egress. The snapshot's known notification webhook function was replaced by a local no-op in the same restore transaction, before any users/data. External Auth providers, SMS, Edge Functions and analytics are disabled; mail is captured locally; active cron jobs=0. Client local mode validates exact http://127.0.0.1:56621 and public keys, avoids Firebase/push/font fetching and automatic sign-in/signup location updates. Web servers send a CSP disallowing external connections/assets. These controls are not evidence that every optional integration or Android feature has been exercised.

## Restart the existing environment (do not recreate it)

Check the distro BasePath first. The source scripts are copied to /opt/playspot-acceptance, config to /opt/playspot-acceptance/project/supabase/config.toml. Never copy the repository's migrations/seed into that CLI project; automatic replay is disabled.

Keep these foreground processes alive in separate terminals, starting only missing processes:

1. `wsl -d PlaySpotAcceptance20261030 --exec sh /opt/playspot-acceptance/daemon.sh`
2. `wsl -d PlaySpotAcceptance20261030 --exec python3 /opt/playspot-acceptance/loopback_relay.py`
3. From this Mobile worktree: `./tooling/local-supabase/stack.ps1 start`, then `./tooling/local-supabase/stack.ps1 verify`.

The relay must exist before CLI health checks because the internal bridge does not publish ports. A daemon restart automatically restarts the existing service containers; if already healthy, use verify instead of start. Never start Docker Desktop as fallback. Stop only this project with stack.ps1 stop (preserves backups/volumes), then gracefully interrupt the owned relay/daemon terminals. Do not use reset/prune/unregister/--all/--no-backup.

CLI status/start output contains local keys. Keep /opt/playspot-acceptance/private private and never print it. write-client-config.ps1 writes only public settings to ignored .env.isolated.json in both client roots and refuses to overwrite a nonempty existing file. Both ignored files have been populated with this stack's actual public key and PLAYSPOT_LOCAL_ACCEPTANCE=true.

## Run the real applications

Dashboard build: `flutter build web --release --no-pub --no-web-resources-cdn --dart-define-from-file=.env.isolated.json` in Dashboard root. Serve with `node tooling/local-supabase/local-web-server.mjs DASHBOARD_ROOT/build/web dashboard` from Mobile root. URL http://127.0.0.1:51651/login. This is lib/main.dart, not equipment preview. Named IDE profile: PlaySpot - Isolated loopback backend (Chrome).

Android: `flutter build apk --debug --no-pub --dart-define-from-file=.env.isolated.json --android-project-arg=localAcceptanceBuild=true`. This creates a separately installed com.playspot.client.local debug app. The native Firebase initializer is disabled before Dart; ordinary builds retain their initializer. The Gradle opt-in and Dart opt-in must agree. Only debug loopback cleartext is permitted; hosted/privileged configuration is rejected in local Dart mode. No release/store build or production signing is implied.

Connect an authorized USB device, then `adb -s DEVICE reverse tcp:56621 tcp:56621`, `adb -s DEVICE install PATH_TO_APK`. Open the local app. Do not change the API to a LAN/public/hosted address. No physical device was connected during this run. A new isolated AVD under D:/PlaySpotIsolated20261030/android-avd was used instead; emulator-5582, Android 36. An initial read-only old AVD was unauthorized and was not used for acceptance.

The delivered APK is D:/PlaySpotIsolated20261030/delivery/PlaySpot-local-acceptance-20261030.apk. Synthetic role credentials are in LOCAL-TEST-ACCOUNTS.txt beside it, outside Git; no server key is in that file or Flutter. Select PlaySpot Mobile - Isolated USB Android (select Android device) for native IDE use after adb reverse. Existing IDE profiles were preserved.

Mobile Web also serves http://127.0.0.1:51652 from its main build, with the same API. Its connected build predates the final key-format/automatic-location refinement; use the native APK as the current manually verified Mobile artifact or rebuild Web before claiming parity.

## Baseline and dependencies

Immutable application-only snapshot SHA256 08d6c1d70278da715a5af80bc3a832358d098f9dd72eb1b6c2f56935ed5293ca (1,342,424 bytes), public/private only. Managed Auth/Storage/Realtime roles and schemas were retained. Required extensions installed locally: PostGIS public 3.3.7, btree_gist public 1.7, pg_net extensions 0.20.4, pg_cron 1.6.4; managed extensions retained. Two preserved spatial_ref_sys guards restored separately. No historical 3,607/3,607 match is claimed for this managed stack.

Eleven distinct reviewed migration files were executed, with hashes in applied-local-set.json. Most source comes from f27c78dca153e2ac1a466c02ffcae45f4bd1d587; separate Open Time correction from 28184d1aa8821ccc955092ed75970191c4abf9af. No financial branch was merged.

Missing private.payout_settlement_entries was defined by canonical 20261011065428_payout_cash_commission_settlement.sql, absent from the snapshot. The first payout application failed after some CREATE FUNCTION statements (the file is not transactional), before synthetic financial data existed. Applied that canonical prerequisite, restored the exact previously saved current guard_partial_cash_payment definition, then reapplied payout successfully. No substitute table or bypassed guard. The real cash start journey later exposed snapshot drift: start_booking_session required full payment before cash play. Canonical 20261016211005_cash_session_start_before_collection.sql was reviewed and applied locally, preserving unpaid cash attendance versus collection.

The final effective public/private catalogue has 1,399 functions (including extension functions), 98 tables, 97 non-internal triggers across selected schemas and 168 policies; full read-only definition hashes/config/ACL inventory is private/effective-catalog-final.json. This inventory is not proof of exhaustive authorization coverage or hosted compatibility. No hosted ledger repair or migration marks occurred.

## Actual acceptance evidence

- Real GoTrue password logins for three synthetic accounts, PostgREST profile reads confirming owner/cashier/user roles.
- Owner grants cashier permissions through actual RPC; cashier opens own shift; customer uses Mobile hold/quote/create contracts; cashier uses Dashboard start/complete contracts; close receipt confirms unpaid and 100 due; atomic cash checkout records 100 EGP.
- Independent reconciliation: booking total 100, payments 100, signed collection 10,000 minor units, shift collection 100; commission 15/net 85; exactly one movement and one receipt.
- Customer collection denied. Lost-response replay returns same movement. Four concurrent identical requests return same receipt. Changed payload rejected. Overpayment after settlement rejected. Revoked cashier cannot replay using an existing JWT; permission restored in finally.
- Native APK installed and launched, customer login submitted through real fields, profile completion and home rendered; Past bookings shows the same synthetic completed lounge booking. Final native build also installed/launched. This is native UI/Auth/read acceptance plus a separate real API financial journey, not a complete UI booking/checkout E2E claim.
- Storage API responds and authenticated Realtime channel join succeeds. Bucket count zero; receipt upload and Postgres change delivery NOT verified. No claim that mail delivery callbacks or optional integrations passed.
- Browser controls fail initialization (kernel-assets path error). A separate Android Chrome automation attempt was automatically rejected by policy; no bypass attempted. Desktop Dashboard authenticated UI acceptance remains pending. Local HTTP URL/main build are available for owner testing.

## Confirmed remaining financial blocker

Real authenticated refund initiation fails 42883: private.log_audit_event(text,text,text,uuid,uuid,text,jsonb) does not exist. Snapshot contains neither audit_events/event_catalog nor either logger signature. Historical canonical 20260929130000_audit_events_and_timeline.sql defines a DIFFERENT nine-argument logger with lounge_id first; the synthetic refund fixture defines a seven-argument stub. Do not copy that stub into the application baseline or blindly replay the historical audit migration. Audit foundation dependencies and refund call mapping need a focused reviewed fix and real-stack regression. Failure rolled back: zero refund requests and zero refund movements. No external refund was executed. Deposit, cancellation, shift close, discount journey and full refund reconciliation remain pending; no all-financial-contract acceptance claim.

Historical payout counts are reconciled by suite-count-evidence.json: older logs 32, later logs 35; commit aa8628f4262f198e79f158399fae20d1b9221c7b added three serialization cases. No tests edited to match a count.

Sources: https://supabase.com/docs/guides/local-development ; https://supabase.com/docs/guides/self-hosting/docker ; https://docs.docker.com/reference/cli/dockerd/ ; https://learn.microsoft.com/en-us/windows/wsl/use-custom-distro . CLI flags/config were checked against pinned installed help. Hosted compatibility, migration-ledger reconciliation, physical hardware/Bridge and device-specific acceptance are independent gates.
Final checks on delivered sources: Mobile flutter test --no-pub 630 passed / 1 skipped (201s); Dashboard 1,355 passed / 2 skipped (168s). Focused local configuration tests: Mobile 3, Dashboard 4; both passed. Touched-file Flutter analysis: Mobile no issues (73.1s), Dashboard no issues (29.0s). Final native debug APK build passed (52.5s); Dashboard connected main release Web build passed (146.0s). Existing Kotlin-plugin/optional Wasm warnings remain; no dependency upgrades or golden regeneration. The final APK was installed/launched again with adb reverse, SHA256 EAEE29CC13BE4438EA3851AE2CF5C1552F9D875656E060BE404806408D1E2038. Raw logs remain in task outputs/acceptance-*-delivery-full-tests.log, acceptance-*-final-analysis.log and acceptance-*-verified-build.log. This is local validation, not remote CI or complete UI E2E.
