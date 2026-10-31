# Branches, PRs and existing work
Audit date: 21 October 2026 (Africa/Cairo). Scope: Mobile/backend dev `ca455197568f618285b4f52e1b25bfa52c892eb2`; Dashboard dev `a3b9c4bf50fa2b07c6318475a75dbfac2cd5b6c0`.

Evidence levels: source inspection, hosted **read-only catalog** inspection, isolated synthetic PostgreSQL execution, Flutter unit/widget execution. No live business workflow was executed. `VERIFIED` refers only to a named executed check, never whole-product readiness. Task 01 coverage remains **partial**: live Auth/Storage/Realtime workflows, full-schema combined peak-hour execution, operator usability and exhaustive semantic contract verification remain open. See [12](12_TEST_EVIDENCE.md) and [15](15_UNVERIFIED_ASSUMPTIONS_AND_DECISIONS.md).

## Verified repository state

Both remote default branches are main. Audit branches were created from freshly fetched dev and old local checkouts were preserved. Mobile dev ca45519 (21Oct) adds cancellation reason UI; Dashboard dev a3b9c4b (21Oct) changes scheduled timestamps/end authority and layout. Main hashes: Mobile34e0366ee1e7e5158e41db1ace715efc7b30c1e9; Dashboard7573b62b8dce7a556059dba09ab2d964b81562d2. Main is materially behind dev in feature surface; neither main nor dev is automatically production-deployed truth.

| Repository / PR | Current status read from GitHub | Reuse / caution |
|---|---|---|
| Mobile68 | OPEN DRAFT, head f7ad0c7 | Original Bridge proposal/reference; included in69 |
| Mobile69 | OPEN DRAFT, head6297a37, base at a507948 | Composite tenant FK correction + mock hardware lab; no operational RPC activation |
| Dashboard68 | OPEN DRAFT, head6896088 | Original preview has review defects corrected in69 |
| Dashboard69 | OPEN DRAFT, headb097814, base at e2889e2 | Default-off survey, semantic steps, conditional answers; local draft only |
| Mobile67 /65 | CLOSED MERGED | Current canteen/booking and live-request work is in dev; do not reimplement |
| Mobile41 | CLOSED NOT MERGED (historical backend base) | Historical financial work later integrated/revised; inspect effective functions rather than blindly cherry-pick |
| Dashboard54 | CLOSED MERGED | Offline foundation already in dev; old PR release-blocker prose is historical, not current deployment fact |
| Dashboard66 | CLOSED MERGED | Malformed extension IDs/false acknowledgments fixed |
| Dashboard67 | OPEN, head ebea124 | git cherry origin/dev branch emits '-' => patch-equivalent fix already present as95354db; merging solely for this patch duplicates work |

PR69 CI exact heads were read independently: backend FlutterCI39623960920 and Bridge39623961142 successful; dashboard FlutterCI39623965997 successful. These heads precede current dev changes. The commit-workflow connector only returns PR-triggered runs; empty results for current dev are not proof no CI ran. Current local Dashboard full suite has1 failure, independent of old green CI.

## Branch comparison methodology and coverage

Every fetched remote ref is recorded below with ahead count and git-cherry plus/minus counts relative to dev. '+' means a patch-id absent from dev, not a recommended fix; '-' means patch-equivalent work exists. Ancestry-only --no-merged lists can mislead after cherry-picks. Important Bridge changes and recent request/session work were inspected directly; not every historical branch diff was semantically reviewed. No old branch is recommended for blind merge. Preserve current scheduling/localization/UI work when integrating reviewed Bridge changes.

## Remote reference inventory

| Repository | Remote ref | Commit | Ahead of dev | Patch absent (+) / equivalent (-) |
|---|---|---|---|---|
| mobile-dev | origin/backend/playspot-core-v2 | 87201c8d088458d9b9d18dd090240639a3e6dc85 | 0 | 0 / 0 |
| mobile-dev | origin/chore/github-hygiene | 7dc5b83a5ef4aecc69f352541e42381ebe1d04da | 31 | 30 / 1 |
| mobile-dev | origin/chore/harden-android-release-signing | 52c596aff95948c99440eae278c8c918aeff5e52 | 5 | 4 / 1 |
| mobile-dev | origin/chore/harden-android-release-signing-v2 | aef74bed310ff00694df74c14ea44dffb22c3dcf | 5 | 5 / 0 |
| mobile-dev | origin/chore/platform-hardening-phase-1 | 696963e93f08b5e8f2965261a8cbf824d08aba3e | 83 | 81 / 2 |
| mobile-dev | origin/chore/release-build-verification | bd2cc252ede7d29305d136b924578b3cf62a9a13 | 1 | 1 / 0 |
| mobile-dev | origin/ci/verify-mobile-android-release | 7866b44bbc2c23dbc65746f74e68832c53bcebe3 | 0 | 0 / 0 |
| mobile-dev | origin/codex/backend-audit | b13fa450899f01d5d73e0669c1ed62e64f5a8583 | 0 | 0 / 0 |
| mobile-dev | origin/codex/booking-canteen-prompt-20261019 | 33c74d183cb6a86c82d41ca11c8c41a936f0382f | 1 | 0 / 1 |
| mobile-dev | origin/codex/catalogue-tombstones | b53a0b6716a93a8881d78dfe67aa48d14e45cc51 | 0 | 0 / 0 |
| mobile-dev | origin/codex/complete-playspot | b55f3ae72f9e95e588c01e68eea1aa23796a5093 | 0 | 0 / 0 |
| mobile-dev | origin/codex/live-session-security-20261019 | 6ad4733c149988d455dc9d23bda35513e8cac04c | 4 | 4 / 0 |
| mobile-dev | origin/codex/mobile-audit-20261016 | 2bd423a5954ce88825abc8f5eeeb1f48faed0ae3 | 1 | 0 / 1 |
| mobile-dev | origin/codex/native-fixture-role-20261019 | 82afaf4c45b2d555b97839acdb3da24beaa5c92c | 1 | 0 / 1 |
| mobile-dev | origin/codex/review-canteen-dev-20261019 | 034524edb471a97b3a29a145c3528551f0aff7c7 | 3 | 3 / 0 |
| mobile-dev | origin/dev | ca455197568f618285b4f52e1b25bfa52c892eb2 | 0 | 0 / 0 |
| mobile-dev | origin/feat/lounge-canteen-combo-preview-20261016 | c15b0f1e78e4fba3b708d33abd7355fd147ee598 | 11 | 11 / 0 |
| mobile-dev | origin/feature/bridge-backend-contract-20261021 | f7ad0c756df354728704dcf4ffd320d7ca0908f9 | 8 | 8 / 0 |
| mobile-dev | origin/feature/bridge-hardware-lab-review-20261021 | 6297a377d4561c6d2af454d09bfb9fad5cc03084 | 9 | 9 / 0 |
| mobile-dev | origin/fix/active-session-contracts | 6afb459104e0753c01dff3de3c963082e1cd34ca | 25 | 24 / 1 |
| mobile-dev | origin/fix/active-session-rpc-payload | 0ddf9f844b2bf2ce5c4b8817cc32e7fdc08f1c76 | 2 | 2 / 0 |
| mobile-dev | origin/fix/app-runtime-coordination | 2eb815f3f56ac8d3ae0cbd68b2d408a9901a4ba0 | 28 | 27 / 1 |
| mobile-dev | origin/fix/app-status-canonical-contract | 76112fd6b41ab89d0cf981e53e8a767dfe707698 | 6 | 1 / 5 |
| mobile-dev | origin/fix/app-status-schema-contract | 085f3f8ede18399e4bb30fae5f664cfb9723d358 | 3 | 3 / 0 |
| mobile-dev | origin/fix/auth-referral-contract | 2fad7ebca002b1bcd1fad7aec1cadaffe0cefe1a | 23 | 22 / 1 |
| mobile-dev | origin/fix/booking-availability-contract | aa97c18cd803a7f8875399334f44a5e809f8fa59 | 25 | 24 / 1 |
| mobile-dev | origin/fix/booking-slot-holds | aad0b93b1a69491a0a1efdee9df9e6c3809136d6 | 39 | 38 / 1 |
| mobile-dev | origin/fix/canteen-menu-availability-20261016 | 25f038d97c89da17db0218832376ed75c4c2f38c | 5 | 5 / 0 |
| mobile-dev | origin/fix/compact-photo-button | 4e0f03e155605585411d883157aadc73f6ded58b | 0 | 0 / 0 |
| mobile-dev | origin/fix/discovery-postgis-qualification | 001e125b420c731b17e78b344cd0d8eb4a98cc73 | 1 | 0 / 1 |
| mobile-dev | origin/fix/discovery-search-contract | c4709317ba95f48b8cd969642e897856bd97688a | 31 | 29 / 2 |
| mobile-dev | origin/fix/expired-booking-extension-state-20261016 | 639ef97d6d21da4f73a8b0ea191b8230bde37a39 | 2 | 2 / 0 |
| mobile-dev | origin/fix/extension-pending-banner-20261016 | e4cb20324f1f23349956f5006592ae703047d54f | 3 | 3 / 0 |
| mobile-dev | origin/fix/loyalty-notification-contract | 2863a404f3e57261f94e0617b96c100119415f1d | 24 | 23 / 1 |
| mobile-dev | origin/fix/notification-preference-delivery | 89d819307b43dae67bcdb846f8c1b0ce7dae4087 | 24 | 23 / 1 |
| mobile-dev | origin/fix/p0-canteen-order-rpc | 3e8e634aba8bce4506f8fc0f6779125bc437f8ff | 21 | 20 / 1 |
| mobile-dev | origin/fix/p0-customer-booking-rpcs | dcb7b674084307a67d525f09f5c82a6fbaa4308c | 23 | 22 / 1 |
| mobile-dev | origin/fix/private-payment-proof-flow | f2389db9ca43a30e6646ea87b1726ea38c1252a9 | 13 | 13 / 0 |
| mobile-dev | origin/fix/promotion-schema-contract | de6222aea2e839bb786f0b5fa8cbc88c32441137 | 20 | 19 / 1 |
| mobile-dev | origin/fix/public-combo-preview-20261016 | b870ddc2634b40eb0b3a49d312f8627a5b1a2806 | 13 | 13 / 0 |
| mobile-dev | origin/fix/public-combo-preview-guest-20261016 | ef23d553fa367815b49b48428ad22405f2bc3c27 | 10 | 10 / 0 |
| mobile-dev | origin/fix/quick-rebook-canonical-flow | 88a25c28fb37fe9ce96dec2f687f3ee97d3164a1 | 62 | 61 / 1 |
| mobile-dev | origin/fix/quick-rebook-canonical-v2 | 4a3f820209b71e4b9e70006fa37f0a4cbf37759f | 72 | 71 / 1 |
| mobile-dev | origin/fix/review-cache-persistence-await-20261016 | bb39758a3a7ea87e03eff6097dfc5105d0d0b0ce | 5 | 5 / 0 |
| mobile-dev | origin/fix/review-storage-flush-ci-20261016 | f7dc4d482dbdf0c0b0fc32453258a848d3cb8a5b | 2 | 2 / 0 |
| mobile-dev | origin/fix/runtime-app-status-coordination | 5e73366ea0ed9785fddd805237c25a20a1582e34 | 24 | 23 / 1 |
| mobile-dev | origin/fix/server-authoritative-booking-core | d98bf98ea1eeaf8ccc7d2516c92d07320c364d04 | 49 | 48 / 1 |
| mobile-dev | origin/fix/server-booking-checkout-contract | 4bc9b56a2a60f693fbe75fb153bde705e099732b | 49 | 48 / 1 |
| mobile-dev | origin/fix/session-request-integrity | 67c35c1d235df1cfb1d71774de57e3a7e84fb0c0 | 20 | 19 / 1 |
| mobile-dev | origin/fix/storage-tournament-contracts | e6cd7ecfe2cf42ed2b7cfedd95b63e60985a215a | 2 | 2 / 0 |
| mobile-dev | origin/fix/support-rpc-contract | cbf70e0b597702fcde06965376e18d8117fe0cf1 | 2 | 2 / 0 |
| mobile-dev | origin/fix/terminal-booking-extension-state-20261016 | 93d2227db4a8bc9e5a80272c2d2757848dd32f3e | 1 | 1 / 0 |
| mobile-dev | origin/fix/terminal-extension-lifecycle-20261016 | 458fbc5bd0e534533596d6708903f7130289ee2c | 3 | 3 / 0 |
| mobile-dev | origin/fix/terminal-extension-state-20261016 | 2d6662467bef2318c3a08d4607424332f7ff57b3 | 3 | 3 / 0 |
| mobile-dev | origin/fix/test-getstorage-backup-channel-lifecycle-20261016 | 68d49099eba40bd1384a68cbb8de09e84aefe9b3 | 2 | 2 / 0 |
| mobile-dev | origin/fix/tournament-active-participation-query | f7cbe06a463ef56db61f5e7ca903c2bf1922d54d | 1 | 0 / 1 |
| mobile-dev | origin/fix/tournament-lifecycle-contracts | 082ffb3d8e57962d90658752343ad7b09b713669 | 21 | 20 / 1 |
| mobile-dev | origin/handoff/ui-transfer-20260930 | da77f7985f8fe8236b5a160a5e3c535a63bf4142 | 1 | 1 / 0 |
| mobile-dev | origin/main | 34e0366ee1e7e5158e41db1ace715efc7b30c1e9 | 0 | 0 / 0 |
| dashboard-current | origin/backend_comprehensive_audit_review | 122fb7ec413b8163c8a985e6e3893ab208462644 | 3 | 2 / 0 |
| dashboard-current | origin/chore/github-hygiene | b5c8948cf8d71e00048687b6bca562c5c695a8d6 | 27 | 26 / 1 |
| dashboard-current | origin/chore/platform-hardening-phase-1 | aaac7b30e42ca5ca970fdb6b636554ff037b4b98 | 62 | 62 / 0 |
| dashboard-current | origin/chore/post-hardening-advisor-cleanup | f6698fde53e1e08619f6c6c76e03a9b1db12b1c0 | 2 | 2 / 0 |
| dashboard-current | origin/chore/reconcile-final-live-contracts | 5404e185c59f87085a93255ea7ec351046b252d6 | 22 | 22 / 0 |
| dashboard-current | origin/chore/release-build-verification | be5efa5da3fea6d67d4abcbd52837b5779816e47 | 1 | 0 / 1 |
| dashboard-current | origin/ci/release-pr-format-scope | fd98681cd31dde2045e73314644fceb005f311e6 | 1 | 0 / 1 |
| dashboard-current | origin/codex/backend-audit | a33526aa294287a480556d0f4708a2dd616181f7 | 0 | 0 / 0 |
| dashboard-current | origin/codex/complete-play | c945529fe67d458ea1713e34caaa5723698068f2 | 0 | 0 / 0 |
| dashboard-current | origin/codex/review-followups | cc2f866943eec49282531f91b9d6218a2700a383 | 0 | 0 / 0 |
| dashboard-current | origin/codex/session-audit-20261016 | ebea1248acd8a85b09f26d2ae68c4ad2b1862c03 | 1 | 0 / 1 |
| dashboard-current | origin/codex/session-start-cycle | 69f2a3b37e463b2ca56fde0b657b0e622997791f | 0 | 0 / 0 |
| dashboard-current | origin/dev | a3b9c4bf50fa2b07c6318475a75dbfac2cd5b6c0 | 0 | 0 / 0 |
| dashboard-current | origin/feat/canteen-combo-validity-ui-20261016 | f4a52ad254636fdc006e34136a377dba4c15a4a2 | 12 | 12 / 0 |
| dashboard-current | origin/feature/bridge-onboarding-plan-20261021 | 6896088ccaf3a9d1ee7544a650235ad3c655c35d | 29 | 29 / 0 |
| dashboard-current | origin/feature/bridge-security-review-20261021 | b097814ffe57ccba7c811f5370f6aad106b5861c | 30 | 30 / 0 |
| dashboard-current | origin/fix/active-marketing-default | 0fa929b968960f05501f4163a2402a0e53f98caf | 0 | 0 / 0 |
| dashboard-current | origin/fix/analytics-revenue-contract | 6dd0e59d6f0ac6da11d2f62128fd99f5bb45dd28 | 14 | 14 / 0 |
| dashboard-current | origin/fix/app-status-canonical-contract | cc6b11b4597ad86f14fefd6472c07bd2d6b0ce3f | 4 | 3 / 1 |
| dashboard-current | origin/fix/canteen-menu-permissions-20261016 | ff4d4f6b968e46123253008d05b3c956aba4c1f3 | 11 | 11 / 0 |
| dashboard-current | origin/fix/ci-secure-promo-rpc-test | 95f214b65b4c71494e82f410ef8be41f7717f9f7 | 2 | 2 / 0 |
| dashboard-current | origin/fix/extension-review-no-false-success-20261016 | aa281e3f9af41fc60e60ea7f8821f76a6c68e829 | 8 | 8 / 0 |
| dashboard-current | origin/fix/final-runtime-contracts-v4 | 604d9168e0eb5929604207e188bee2cb4d968b96 | 24 | 24 / 0 |
| dashboard-current | origin/fix/final-security-closure-v3 | 948253ef1441a4f327be62eac947d13bda2f2f91 | 23 | 23 / 0 |
| dashboard-current | origin/fix/financial-commission-contract | 6001d16f203239be7a0cb555387e73890fcf568d | 16 | 16 / 0 |
| dashboard-current | origin/fix/financial-commission-truth | 2a1daa6a188d74f0ed6740b6838507d53728acb1 | 17 | 17 / 0 |
| dashboard-current | origin/fix/kyc-server-authoritative-review | 15f3661c36e97c462710dad8ab473931c3c7f23b | 2 | 2 / 0 |
| dashboard-current | origin/fix/loyalty-real-data-only | b82648b7df21c5fdf4acdd44b898982dd52c3c23 | 15 | 15 / 0 |
| dashboard-current | origin/fix/marketing-promotion-contract | 6a5f549e786f71e3156e594816b292b16c958da7 | 23 | 23 / 0 |
| dashboard-current | origin/fix/notification-preference-delivery | 705c2dae3674ffedcf6c90273b742fd0d42f0833 | 18 | 18 / 0 |
| dashboard-current | origin/fix/p0-booking-payment-contract | 483c13a3e6a732b7a5aa7b5b2c7ccbc665f57e8e | 23 | 23 / 0 |
| dashboard-current | origin/fix/p0-canteen-order-contract | f442fed60a3d49158d14b40f0304955ba07f0e32 | 15 | 15 / 0 |
| dashboard-current | origin/fix/p0-customer-booking-mutations | 3ac05ff8493bab07f0907f0344cdc1d8ffffe004 | 2 | 2 / 0 |
| dashboard-current | origin/fix/p0-live-requests-contract | fdb2d7856074c1f48326aa6c3e229901a250f587 | 18 | 18 / 0 |
| dashboard-current | origin/fix/p0-notification-contract | 911936b991108989575bbfbe094628a57ec9e9f1 | 15 | 15 / 0 |
| dashboard-current | origin/fix/p0-permissions-contract | 7b632ebfcc1a17449c3bbc853d391bab8cdd0f89 | 30 | 30 / 0 |
| dashboard-current | origin/fix/p0-request-resolution-contract | 11bdaf2b89c4b17b330a80fbcf7a8ce2a45b0544 | 18 | 18 / 0 |
| dashboard-current | origin/fix/p0-session-extension-contract | 6001d16f203239be7a0cb555387e73890fcf568d | 16 | 16 / 0 |
| dashboard-current | origin/fix/p0-session-shift-contracts | 5675736e0530d02255cc35a2327f21c1dca15ce2 | 16 | 16 / 0 |
| dashboard-current | origin/fix/p0-supabase-security-contracts | 8bf093f613e15d3187ef66c328abfa8c11cec6b2 | 7 | 7 / 0 |
| dashboard-current | origin/fix/payout-financial-visibility | 3f4534e06c21f40993c1b3708b703375be7b1eae | 14 | 14 / 0 |
| dashboard-current | origin/fix/room-operational-state-contract | fa448358d4739f2a28a6fb6fdcca174812c3e5f4 | 20 | 20 / 0 |
| dashboard-current | origin/fix/shift-expense-server-authoritative | 896ac5ff5663e77ce998e59f51defe5e06986aa9 | 3 | 3 / 0 |
| dashboard-current | origin/fix/storage-security-closure | defe1370302ec4cd3a7226300943a4777ac3e6fd | 36 | 36 / 0 |
| dashboard-current | origin/fix/storage-security-closure-v2 | 3cace74d19b6e63fc850c01db44622ed9c98277a | 4 | 4 / 0 |
| dashboard-current | origin/fix/support-server-authoritative | 1ad150d34d36bd30a6a30019287ced667a898ae2 | 4 | 4 / 0 |
| dashboard-current | origin/fix/support-server-contracts | 95a275262865b2cd129baead605b32e5ef21e457 | 3 | 3 / 0 |
| dashboard-current | origin/fix/tournament-admin-contracts | 711fa8154ce9b8922feb1192bbee8bc314586ff0 | 21 | 21 / 0 |
| dashboard-current | origin/fix_dashboard_bookings_auth | 4c3fa647d610d7291fe819a7e30b15ee719bdfe5 | 1 | 1 / 0 |
| dashboard-current | origin/main | 7573b62b8dce7a556059dba09ab2d964b81562d2 | 0 | 0 / 0 |
| dashboard-current | origin/offline_cashier_conflict_resolution | 37a12c56ff4bf03b2e9b1d388301a081f67a57db | 0 | 0 / 0 |
| dashboard-current | origin/release/reconcile-main-history | 84a5b50b6f1effe6d98e931cbaf07fbd45eac9e1 | 1 | 0 / 0 |
| dashboard-current | origin/release/track-booking-receipt-binding | cb653c7c10ff8b810ec6d5fadf626b370b3fe51b | 1 | 0 / 1 |
| dashboard-current | origin/responsive_dashboard_ui_redesign | 018bc0b1388c092fac592e0a213f9786bf3f0efa | 1 | 1 / 0 |
| dashboard-current | origin/security/bind-booking-receipt-reference | b2beb908dfb758ecc55b2e560ebafbc4b43a12d6 | 1 | 0 / 1 |
| dashboard-current | origin/security/close-legacy-review-rpc | 22dd1c2f32bd0b4798a033298bbd0156d9259856 | 1 | 0 / 1 |
| dashboard-current | origin/security/tournament-participant-read-scope | 3a101ac5e9f7952e26164c457606558d5f00c815 | 1 | 0 / 1 |
| dashboard-current | origin/supabase_access_check | 9a1ff9a10290e094f76b7dcdf50d703eabbef121 | 0 | 0 / 0 |
