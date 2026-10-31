# Real-system integration — 31 October 2026

**Latest owner boundary:** all Production connections are now stopped because no restorable backup is verified. See [the local recovery inventory](BACKUP_RECOVERY_INVENTORY_20261031.md). Prior read-only catalog/backup attempts below predate that clarification and do not authorize reconnecting.

The owner authorizes the actual Production destination, conditional on verified recovery, compatibility, ordered migrations and meaningful combined testing. Local Supabase is a verification environment, not a substitute final product. Google Play upload/publication remains excluded. This report supersedes historical prohibitions only within that explicit authorization; it does not establish that any Production change occurred.

## Source reconciliation

Starting remote dev: Mobile `ac3caa5614900c64567e0b6939936f9ee921bb66`; Dashboard `ec1f4a4edda88e692738315a7c8c6dda5629ce3c`. Both current main heads are ancestors of their dev sources: Mobile `34e0366ee1e7e5158e41db1ace715efc7b30c1e9`, Dashboard `7573b62b8dce7a556059dba09ab2d964b81562d2`. Existing receipt-binding security changes on main are preserved. Dashboard canonical checkout/staff integration was already merged by `91630de4`; do not duplicate it or merge the rejected Dashboard redesign.

Normal non-destructive merges in the Mobile combined verification worktree:

- `c9534852`: refund/payout source from `f27c78dc`, including refund booking-before-request lock order and payout concurrency regressions.
- `775b3d81`: Open Time partial classification `28184d1a`. Only conflict: AGENTS.md; retained both dated evidence sections and the current guide.
- `d0655a04`: native fixture recovery `a9dd3309` (loopback fallback and Cairo clock tests).
- `65c603eb`: forward-only audit repair; old refund migration remains unchanged.
- `885492ec`: Open Time customer presentation from `b9edcf97` (committed canteen charges, authoritative completed duration, restart/reconnect tests).
- `d74c8537`: extension approval is service debt, never collection, from `ab73b78e`.

Original Mobile recovery worktree/user AGENTS and handoff edits, all old refs, generated registrants, existing clusters/disks/backups remain preserved. Newly generated platform registrants are excluded from source commits. Temporary integration branches are verification tools; verified source must advance dev, not remain a separate permanent destination.

Unmerged Drafts are not blindly released: checkout recovery PR #72 introduces new RPCs and a persisted uncertain state; its definitive-rejection/recovery lifecycle still needs review and real-stack testing. Bridge protocols/onboarding and native hardware proposals do not prove a real adapter and are excluded from activation. Historical audit/report branches and patch-equivalent changes are inventory evidence, not new product behavior. Complete branch inventories are retained in task outputs/production-*-branch-inventory-20261031.json.

## Refund defect and repair

Production read-only inspection confirmed PostgreSQL 17.6 and absent public.audit_events, public.event_catalog and private.booking_refund_requests. A fresh public/private catalog fingerprint matched all **3,607/3,607** preserved reference objects, with zero extra/missing/changed hashes. No schema re-export or cluster rebuild was necessary. This does not inspect private customer records or establish rollout safety by itself.

The refund Draft called a seven-argument logger supplied only by its test fixture; canonical historical source defines nine arguments, with lounge_id first. New `20261031111003_refund_audit_contract.sql` extracts only reviewed audit storage, a real append-only logger, grants/RLS and the three corrected refund callers. It excludes historical general triggers, timeline replacements and event replay. It adds lounge scope and revokes direct logger/append privileges. Existing refund financial bodies and lock order are preserved. Both fixtures now run the actual migration, not the seven-argument substitute. Fixture-only scenario resets explicitly truncate their unique synthetic audit table before deleting bookings; Production immutability is unchanged.

Real local authenticated partial return: 100 EGP collected, 20 synthetic return, payment/movement net 80, commission 12, lounge net 68, drawer in 100/out 20, one reversal, one collection receipt, two scoped audit events. Independent read-only reconciliation passed. Continued full return totals 100: net/commission/payment zero, two reversals, four audit records; replay does not duplicate. Direct audit forgery denied. Cashier blind close initially denied 42501; owner granted shifts_blind_close through its RPC, then close succeeded and zero drawer reconciled. These attestations moved no external money and are not browser UI or hosted acceptance.

## Actual combined checks

- All **62** top-level native PostgreSQL 17.11 backend suites exited 0, loopback 55499. Focused final counts: refund 39; payout reconciliation 35; custody 17; partial collection 48; extension price integrity 8.
- Mobile `flutter test --no-pub`: **647 passed / 1 skipped**, 185 seconds. `flutter analyze --no-pub --no-fatal-infos`: no issues, 186.1 seconds. Sixteen changed Dart files format-checked with zero changes. No golden refresh or dependency upgrade.
- Dashboard code unchanged from verified ec1f4a4e; prior 1,355 passed / 2 skipped, successful remote CI and Preview remain dated evidence, not new Production acceptance.
- Approved Computer Use initialization reattempt failed before input: `failed to write kernel assets ... os error 3`. No alternate rejected automation bypass. Authenticated operational browser acceptance remains open.
- Sanitized raw outputs: production-suite-*.log, production-combined-mobile-*.log, production-integration-real-refund-20261031.json, production-integration-refund-reconciliation-20261031.json, production-integration-full-refund-shift-20261031.json and production-fingerprint-comparison-20261031.json.

## Production release gates

Production backups API/CLI returned backups=null, physical_backup_data={}, pitr_enabled=false, walg_enabled=true. A recent restorable backup has **not** been verified. No Production migration/data mutation, hosted migration-ledger repair, main push or Production deployment has occurred. Do not treat WALG enabled as a recoverable backup. Obtain a verified owner backup or securely configured supported backup/export and restore rehearsal before mutation.

The Production migration ledger was read without modification and ends at 20261020133056. Compare the actual effective definitions to the reviewed rollout manifest; never replay every file or mark historical migrations applied merely because a function exists. Eleven alleged manually applied Staging migrations remain unverified; no Staging access or fabricated ledger report.

Review backend-first sequence from the schema-matched snapshot and the explicit local manifest, including the canonical custody and cash-session prerequisites, extension correction, partial classification, atomic checkout, permission boundary, deposit guard/movement/policy, refund, payout and audit repair. The exact final ordered set and rollback preimages still require a complete rehearsal against the selected release candidate; local application order is historical evidence, not an executable Production replay plan. Existing clients and cached cashier tabs need a compatible transition. Deposit/cancellation/discount and browser flows remain gates.

The documented release process is dev integration then reviewed main promotion; inspect current Vercel project Production branch/settings and required checks before promotion. GitHub branch metadata returned protected=false and no rulesets; this does not authorize bypassing the review process. Existing Vercel Production deployment metadata is historical and is not proof that current main or dev is deployed.

## Actual Mobile identity and signing

Owner confirms no prior Google Play upload and authorizes a dedicated upload key. No suitable release key/key.properties was found in inspected repositories, transfer and backup locations. A new RSA-2048 upload key was created outside Git at `D:/PlaySpotReleaseSecrets/android-upload-20261031/playspot-upload.jks`; protected backup at `D:/CodexBackups/PlaySpotUploadKey-20261031`. Passwords are random 256-bit values, DPAPI encrypted for this Windows account/machine; directories and ignored key.properties allow only owner and SYSTEM. Backup checksums and reopening/decryption were verified. Preserve both copies and prepare owner-managed off-device/vault recovery before store submission.

Public certificate SHA-256: `F3:09:2C:E6:7A:6E:31:02:EA:BE:68:C9:BA:92:71:78:9F:88:C5:EF:92:B9:2B:4A:45:EA:14:2D:7C:D8:5B:83`.

Actual application ID remains **com.playspot.client**, version **1.0.0+1**. Both ignored Production configuration files explicitly select `https://tgpdexoitemmpruepgyt.supabase.co` with an independently checked anon-role public key; no secret/service-role key or local opt-in. Signed AAB built from source `0d5becf9dd985a563b151dad6ad820dc69e8ba45` in 460.7s, exit 0. Kotlin cross-drive incremental-cache failures fell back to compilation; no dependencies/caches were upgraded or discarded. jarsigner verifies the archive and its certificate matches the upload certificate above; official bundletool 1.18.3 (verified SHA-256 a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29) validates it. Built manifest: applicationId com.playspot.client, versionName 1.0.0/code 1, minSdk 24, targetSdk 36, no debuggable=true. AOT library contains the intended Production URL and checked public key. Artifact is 80,985,102 bytes, SHA-256 `3F5CB7A488D4B203C11FB640C9B9C9650DAB6687505C58D4C8CE5511EFE10151`, copied to D:/PlaySpotReleaseDelivery/20261031/PlaySpot-1.0.0+1-production-HOLD.aab. This is a held build, not runtime/backend acceptance or approval to install/use financial paths. Google Play App Signing enrollment is separate at the first store submission; no upload/publication is authorized.

Source 0d5becf9 was fast-forwarded into local dev and normally pushed; independent ls-remote matched. [Remote CI 41197071021](https://github.com/salahaldensherief/playspot_V2/actions/runs/41197071021) completed success, including backend fixtures and Android compile-only verification; formatting review also succeeded. These source/CI results do not alter the unresolved Production release gates.

Official references: [Supabase backups](https://supabase.com/docs/guides/platform/backups), [Android signing](https://developer.android.com/studio/publish/app-signing), [Flutter Android release](https://docs.flutter.dev/deployment/android).
