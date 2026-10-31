# Next exact Codex tasks

Audit date: 21 October 2026 (Africa/Cairo). Scope: Mobile/backend dev `ca455197568f618285b4f52e1b25bfa52c892eb2`; Dashboard dev `a3b9c4bf50fa2b07c6318475a75dbfac2cd5b6c0`.

Evidence levels: source inspection, hosted **read-only catalog** inspection, isolated synthetic PostgreSQL execution, Flutter unit/widget execution. No live business workflow was executed. `VERIFIED` refers only to a named executed check, never whole-product readiness. Task 01 coverage remains **partial**: live Auth/Storage/Realtime workflows, full-schema combined peak-hour execution, operator usability and exhaustive semantic contract verification remain open. See [12](12_TEST_EVIDENCE.md) and [15](15_UNVERIFIED_ASSUMPTIONS_AND_DECISIONS.md).

## Task02A — reconcile launch-critical deployed contracts and financial semantics

Start from freshly verified dev in both repos; read AGENTS.md and this audit. Preserve source/UI work and inspect deployment state again read-only. Implement only focused corrections and isolated tests. No live migrations/deployments, financial record edits or merge are authorized by this task specification.

1. Reproduce PS-001/002/003/004/005 with the audit evidence and exact source. Keep existing staged/production versions distinct. Review current canonical cash-start and custody migrations instead of rebuilding features.
2. Separate approved extension from collected money. Starting/approving/extending/completing service may create liability/attendance, never a fabricated collection. Keep existing prices/discount allocation and capacity conflict rules. Explicit receipt-backed collection must check billing permission and open shift, lock consistent resources and dedupe by immutable operation id/fingerprint.
3. Add durable transactional checkout operation receipt. Bind actor+payload+request id; return original booking IDs on replay/lookup after lost ACK even when the hold was consumed. Deny changed-payload reuse and cross-actor receipt reads. Preserve quote/version conflict behavior and multi-room atomicity. Persist minimal recovery identity in the existing scoped client store; represent unknown and allow safe recovery after restart.
4. Prepare exact production reconciliation release plan for canonical super-admin announcement authorization, cash-start parity and custody RPCs with grants/dependencies. No production operation until separate explicit authorization. Rehearse against a disposable full-schema database with synthetic users.
5. Correct PS-006 fixture/format debt with schedule-authority regression tests, without reverting intended server-end behavior. Record no-show outcome distinctly (PS-007) if needed for enabled pilot scope.

### Required acceptance tests

| Test | Must observe |
|---|---|
| Paid180 + approved50 extension | total230, paid180, due50; no new payment/shift collection until explicit action |
| Two concurrent collection retries | One receipt and one ledger increment; both recover same canonical result |
| Partial deposit+extension+completion | Agreed tariff unchanged except authorized extension; original paid amount retained; remaining balance exact |
| Cash vs manual transfer vs wallet | Start does not fabricate cash; transfer proof alone is not payment; provider outcome unknown remains pending |
| Lost checkout response after commit | Same IDs recover after reload/consumed hold; no second booking/voucher use/order |
| Changed payload/request id | Deterministic conflict; no new side effects |
| Owner/employee/other branch/canonical super admin | Exact allowed scope; owner cannot platform-broadcast; invalid actor cannot recover another receipt |
| Future reservation/active room | Extension/start cannot violate capacity or operational room state |
| Shift close vs collection + local outbox | Ordered denial/defer/handoff, no lost cash or silently closed authority |
| Contract expiry during service | Existing session/debt/refund/export/reconciliation remain safe |

Run full client analyze/tests/format, all59 native backend suites and focused new real-concurrency tests,85 Edge tests, exact-schema migration rehearsal, release builds and the composed20:00 scenario. Record actual outputs, not old CI prose. Finish with draft review artifacts and a precise deployment/rollback checklist; do not deploy/merge automatically.

## Task03 — mode-specific first-partner readiness

After02 gates: implement only missing Booking/Native essentials, Lite Bridge external-allocation protocol, clear pending/declined/expired/no-show states and visible recovery. Run operator walkthroughs with two cashiers inAR/EN, browser audio permissions, next-reservation visibility and backup contact. Acceptance: no false external confirmation or lost request and exact cash reconciliation for enabled scope.

## Task04 — Local acceptance and isolated durable runtime POC

Reuse existing Hive/journal/authority transport. Execute crash/restart, storage/key failures, wrong actor, clock reversal, renewal/revocation, two writers, replay/lost ACK and cloud collision. Specify supported commands; leave open-time/extensions/mixed refunds disabled until proven. Prototype Windows service only with mock transport and assigned resources, no venue installation/hardware.

## Task05 — Founding20 measurement and minimal terms

Implement the minimal model in09 only after current schema inspection. Server-owned lifecycle events and venue campaign origin; founder-facing support/co-marketing pipeline may remain a simple restricted tracker. Acceptance: cannot forge completed service with client events; no-show cancellation distinguished; trial expiry drains existing work; origin and incremental-demand uncertainty visible.

## Task06 — one vendor after evidence

Require real partner, product/version, official interface/license, consent and sandbox. Validate operation-specific reserve/cancel semantics, idempotency/unknown lookup, scope/health/revocation. Do not promote simulator success to vendor compatibility or wire the old plaintext power GET helper into cashier authority.
