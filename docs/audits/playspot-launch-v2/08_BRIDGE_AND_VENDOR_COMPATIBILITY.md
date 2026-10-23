# Bridge and vendor compatibility

Audit date: 21 October 2026 (Africa/Cairo). Scope: Mobile/backend dev `ca455197568f618285b4f52e1b25bfa52c892eb2`; Dashboard dev `a3b9c4bf50fa2b07c6318475a75dbfac2cd5b6c0`.

Evidence levels: source inspection, hosted **read-only catalog** inspection, isolated synthetic PostgreSQL execution, Flutter unit/widget execution. No live business workflow was executed. `VERIFIED` refers only to a named executed check, never whole-product readiness. Task 01 coverage remains **partial**: live Auth/Storage/Realtime workflows, full-schema combined peak-hour execution, operator usability and exhaustive semantic contract verification remain open. See [12](12_TEST_EVIDENCE.md) and [15](15_UNVERIFIED_ASSUMPTIONS_AND_DECISIONS.md).

## Actual existing assets

Both PR68 and PR69 are open Drafts, unmerged. Backend PR69 `6297a37` includes PR68 and review fixes: private schema proposal, API/local/hybrid in-memory reference, fail-closed receipts and isolated hardware lab. Dashboard PR69 `b097814` includes the earlier onboarding proposal plus default-off flag, semantic step restoration, catalog-driven conditions/translations and always-false activation flags. Code and relevant diffs were inspected; 28 backend mock/reference tests and8 proposal SQL checks were rerun. Remote PR69 CI was independently read and green for those exact heads, not current dev.

Reusable: questionnaire routing/capability vocabulary, owner/branch/resource identity concepts, composite tenant FKs (protect parent tenant changes), command/inbound dedupe, ambiguous state, reconciliation proposal, mock collision/replay/lost-ACK cases and guide. Not implemented: production pairing/connector auth, credential vault, actual vendor transport, durable installed Windows runtime, per-operation vendor-certified guarantees, production activation or reconciliation worker. The reference uses Maps; restart loses its dedupe/reservations. It is deliberately not a production agent.

HardwareBridgeService in Dashboard dev issues unauthenticated plaintext GET requests to127.0.0.1:8443/local.playspot.me with roomId/action and2s timeouts. Search found DI registration and service definition; no live session consumer was established. Do not wire this into operations as a secure agent. Mock relay/device commands do not reserve capacity or record cash.

## Four independent controls

Commercial entitlement says a plan allows an integration. Technical capability says a verified version/channel supports a specific operation. Owner authorization/activation approves exact tenant/branch/resources and scope. Runtime health determines whether that approved operation can execute now. Effective capability is their intersection plus booking/finance invariants; a plan override cannot turn read-only into atomic reserve.

## Vendor operation assessment

No vendor endpoint/documentation/license or real venue installation was provided or tested in this audit. No external endpoint is invented. These are candidates, not integrations:

| Candidate | Official interface/version evidence | Read/write / reservation semantics | Health/consent/activation | Next evidence |
|---|---|---|---|---|
| Gizmo | UNVERIFIED | UNVERIFIED; no atomic reserve claim | Not assessed / not activated | Real partner version, official authorized API/SDK docs and sandbox |
| iCafeCloud | UNVERIFIED | UNVERIFIED | Not assessed / not activated | Same |
| PanCafe | UNVERIFIED | UNVERIFIED | Not assessed / not activated | Same |
| HandyCafe | UNVERIFIED | UNVERIFIED | Not assessed / not activated | Same |
| CCBoot / CCU / CCDisk | UNVERIFIED | Diskless infrastructure alone does not establish session/reservation API | Not assessed / not activated | Identify actual session/cashier layer first |
| Egyptian PS management systems | Specific product/version missing | Manual request-only until enforceable allocation verified | Venue responsibility required | Vendor/product inventory at onboarding |

Classify every operation separately: read-only, request-only, check-then-write, atomic-reserve. Check-then-write is not a guaranteed atomic reservation. Timeout after reserve is UNKNOWN; lookup/reconcile by stable operation id before retry. Require vendor-side dedupe or an equivalent atomic guarantee; local queue alone cannot supply one.

## First verified integration gate

Choose one commercially useful partner already using a supported interface; secure owner/vendor authorization and version docs. Specify resource mapping, operation-specific authority, reserve/cancel semantics, idempotency, lost-ACK lookup, cancellation/refund compensation, credential rotation/revocation and health failure behavior. Run two competing reservations plus restart/replay and wrong-tenant tests in authorized sandbox. Start request-only/read-only unless guarantee proven; enable write scope separately. No dozens of adapters, screen scraping or unattended hardware control now.

Lite Bridge is an early requirement and can reuse existing request UI without an integration server, but needs PS-008's allocation/operating protocol. Native, Local, Full Bridge and hardware remain distinct. Review69 rather than68 alone; reconcile current dev changes and retain default-off behavior before proposing any merge.
