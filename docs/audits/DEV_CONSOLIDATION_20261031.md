# Dev consolidation — 31 October 2026

Current owner scope: isolated local dev only. No Production/hosted Staging access,
hosted changes, main promotion, deployment or store publication. Draft release
PRs Mobile #92 and Dashboard #88 remain unmerged. This is the current milestone
record; earlier rollout/readiness reports are dated evidence.

## Recovered and integrated source

Starting remote heads independently read with `git ls-remote`: Mobile dev
`c69bf8c0227aae2281d71cbf0ac517c58957b8a5`, Dashboard dev
`6113da82da43b8630f042b3be30e3cfeaf2560fd`. Main remains Mobile `34e0366e`,
Dashboard `7573b62b`. No hosted schema was inspected. Source migrations and the
local manifest do not establish what is applied to a hosted database.

Recovered uncommitted bootstrap/configuration work was preserved and completed.
The original dirty Mobile recovery checkout remains on its existing branch;
AGENTS and handoff hashes stayed unchanged. Existing keys, signing backup,
acceptance volumes and unsuccessful disposable attempts were retained.

Dashboard normal merge `e63e0c82` integrates existing combo calendar validity
controls from `origin/feat/canteen-combo-validity-ui-20261016`, without conflicts.
Both clients now explicitly accept the new loopback API and have named
**Consolidated dev** IDE profiles using ignored `.env.dev-local.json`.
Fail-closed hosted/key validation and financial behavior remain unchanged.

Mobile owns canonical migrations **and Edge Functions**. All Dashboard function
files were copied unchanged from `6113da82`; existing Dashboard copies remain
legacy references. Node contracts now also run in canonical Mobile CI. No Edge
deployment or Deno-runtime success is implied.

Other repairs: old stack verifier scopes its own containers when projects coexist;
shared probes explicitly allow only the two known local endpoints; local web
server selects the matching CSP/ports and still rejects hosted resources; alert
WAV header now matches existing unchanged PCM samples (2,485 samples + padding).
No new dependencies, decorative UI changes or golden updates.

## Fresh initialization and identity

One final clean initialization passed from versioned inputs in `tooling/dev-stack`:
project `playspot-dev-clean-20261031`, runtime `/opt/playspot-dev-clean-20261031`,
network `playspot-dev-clean-internal-20261031`, nine services on a dedicated
internal bridge. WSL `PlaySpotAcceptance20261030`, registry storage
`D:/PlaySpotIsolated20261030/wsl`; Docker ID
`a5425fa1-5622-4997-8e86-a80a06cec53d`, root `/var/lib/playspot-docker`.
Database image `public.ecr.aws/supabase/postgres:17.11.0.006`, actual server 17.11.
API/DB/Studio/mail bindings **127.0.0.1:56821–56824** verified in guest and host.
Original 56621–56624 stack remains running and independently verifies.

Versioned schema-only checkpoint SHA256
`f072564f9ad289e353ff86855c0c5f16981bf4d4151604e9787161b0664fd11d`
plus 13 dependency-ordered canonical deltas; see `manifest.json` for exact files,
hashes and provenance. No private schema-file path is needed to initialize it.
Managed schemas/roles come from CLI 2.122.0, not dump replacement. Effective
application inventory: 101 tables, 170 policies, real nine-argument audit logger,
zero active scheduler jobs. Reinitialization of an existing application was
explicitly rejected before writes. No reset, migration-ledger mark or blanket replay.

Missing reference rows were made explicit: local synthetic permission catalogue
has FALSE global defaults, an explicit scoped synthetic owner template and actual
audited cashier grants. It does not claim Production default-role equivalence.
Auth triggers run profile creation before settings and reject metadata-selected
super-admin elevation. Three real synthetic GoTrue accounts and 40 mixed stations
were seeded. Credentials/server keys remain private outside Git.

Startup/stop, prerequisites, client selection and probes:
[tooling/dev-stack/README.md](../../tooling/dev-stack/README.md).

## Executed acceptance matrix

| Area | Actual evidence | Remaining gate |
|---|---|---|
| Auth/roles | Three real GoTrue logins and PostgREST profile reads; metadata escalation denied | Actual application login/UI acceptance |
| Cash booking/session | Customer hold/quote/create; cashier start/complete; canonical collection receipt | Full journey through both rendered clients |
| Retry/authorization | Customer denied; revoked cashier denied with existing JWT; four concurrent identical replays; changed payload/overpayment rejected | Other payment methods and independent cashier operations |
| Refund/accounting | Partial 20/100 then full return; replay; forged audit rejected; blind close with permission denial then owner grant | External money return intentionally not exercised |
| Ledger reconciliation | After partial: payment/movement 80, commission 12, lounge net 68; after full: net/payment/commission 0, drawer 100 in/100 out, two reversals/four audits, closed shift | Hosted compatibility unverified |
| RPC/table names | All 125 Mobile and 269 Dashboard literal call sites resolve against local functions/relations | Not exhaustive payload/response, dynamic-call or permission verification |
| Realtime/Storage | Authenticated WebSocket join and Storage API respond | Postgres-change delivery, receipt buckets/policies/upload absent/unverified |
| Notifications | Actual bundled WAV loads; PCM/header regression passes | Audible browser/hardware and external FCM delivery unverified |
| Edge Functions | 87 Node contracts pass against copied source | Runtime disabled; Deno/module cache and local Edge acceptance pending |
| Applications | Both `lib/main.dart` Web builds succeed using same local backend; served assets/local CanvasKit and CSP checked via HTTP | Browser tool fails at initialization: `failed to write kernel assets ... os error 3`; no fresh UI/emulator/device E2E claim |

Synthetic refund attestations moved no external money. Completion is not
collection, proof is not verified collection, and cancellation is not refund.
Notification transport is explicitly local-suppressed; rows are real, delivery is not.

## Combined checks actually run

- `flutter analyze --no-pub --no-fatal-infos`: no issues in both repositories.
- `flutter test --no-pub`: Mobile **647 pass / 1 skipped**, Dashboard **1357 pass / 2 skipped**.
- Changed Dart files format check: unchanged; `git diff --check`: passed.
- Both main Web builds: `flutter build web --no-pub --no-web-resources-cdn --dart-define-from-file=.env.dev-local.json`: passed. Mobile retains existing WASM compatibility/missing Cupertino font warnings; build success is not icon/render acceptance.
- Native PostgreSQL 17.11 focused suites: manual refund **39**, payout reconciliation **35**, custody **17**, partial cash **48**. Commands: `PLAYSPOT_NATIVE_PG_PORT=55499 node supabase/tests/NAME.test.mjs`; exact names and summaries in evidence.
- Canonical Edge Node tests **87 pass**; local server boundary tests **2 pass**.
- Historical payout counts reconciled against actual logs: 32/32 then 35/35; three serialization checks added in `aa8628f4`. No test changed to match a count.

Sanitized reports, exact log hashes and final summary lines are in
[evidence/dev-consolidation-20261031](evidence/dev-consolidation-20261031/validation-logs.json).
Full logs remain in workspace `outputs`; accounts/status with keys are excluded.

## Delivery and remaining material blockers

Both integration branches are temporary implementation tools. Final reviewed
commits are to be fast-forwarded normally into the already checked-out real local
dev worktrees; no reset/rebase/unrelated history rewrite. Record exact resulting
SHAs and remote CI in the delivery follow-up to this record.

Mobile workflow contains build/test jobs and no deployment. Dashboard's separate
Vercel Git integration triggers Preview on dev push; prior approval was specific
to `ec1f4a4e` and does not cover this change. Hold Dashboard remote push pending
owner approval of the final exact commit and Preview effect. Never bypass it.

Remaining: local Storage bucket/RLS definitions have no canonical replayable source;
do not fabricate open upload policies. Edge runtime/module isolation and actual
browser/installed-device financial journeys remain acceptance gates. Historical
Mobile checkout-recovery PR #72 remains outside dev pending resolution of its
unknown/non-committed recovery state; it was not blindly merged during bootstrap.
Native device-control proposals remain simulated/outside this focused milestone.
Production backup, effective-schema compatibility and migration-ledger reconciliation
remain unverified and out of current authorization; no hosted compatibility claim.
