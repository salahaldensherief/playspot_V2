# Prioritized implementation roadmap

Audit date: 21 October 2026 (Africa/Cairo). Scope: Mobile/backend dev `ca455197568f618285b4f52e1b25bfa52c892eb2`; Dashboard dev `a3b9c4bf50fa2b07c6318475a75dbfac2cd5b6c0`.

Evidence levels: source inspection, hosted **read-only catalog** inspection, isolated synthetic PostgreSQL execution, Flutter unit/widget execution. No live business workflow was executed. `VERIFIED` refers only to a named executed check, never whole-product readiness. Task 01 coverage remains **partial**: live Auth/Storage/Realtime workflows, full-schema combined peak-hour execution, operator usability and exhaustive semantic contract verification remain open. See [12](12_TEST_EVIDENCE.md) and [15](15_UNVERIFIED_ASSUMPTIONS_AND_DECISIONS.md).

## Work packages and dependency gates

| Package | Priority / dependency | Exact scope | Acceptance / release gate |
|---|---|---|---|
| A Deployment-contract reconciliation |P1, first | Pin deployed versions; diff live vs dev functions/grants/schema and Edge sources; prepare minimal reviewed rollout artifacts for PS-001/002/003 | Native fixtures plus exact-schema staging; no production action in Task01; source/CI/client version parity documented |
| B Financial/unknown-outcome correctness |P1, parallel investigation withA | PS-004 approval/collection separation; PS-005 durable checkout receipt/recovery; mixed/partial payment and shift close | Paid180 + extension50 remains paid180/due50 until collection; lost ACK recovers same IDs; no duplicate receipt/debit |
| C Booking and Native essentials |P1, afterA/B for enabled scope | Cash start/complete/debt settlement, wait/approve/decline/no-show evidence, stock/permission scopes, peak-hour request visibility | Composed20:00 full-schema+two-operator AR/EN rehearsal, real supported payment method and support runbook |
| D Lite Bridge safety |P1 for Booking-only, alongsideC | Venue mode/guarantee wording; manual external allocation reference or enforced dedicated partition; SLA/expiry/audit | No external confirmed status without accountable allocation; walk-in/vendor collision rehearsal; fallback contact |
| E Local foundation acceptance |P2 / P1 only if offline promised | Reuse journal/permits/bootstrap; browser restart/key storage/multi-tab/reconciliation; isolated Windows durable POC | Device crash/replay/authority/clock/quota tests; no offline offer until actual enabled scope passes |
| F Founding20 commercial+measurement |P2, parallelA–D | Minimal versioned terms, activation checklist, consent-aware QR origin, authoritative outcomes, support/co-marketing/willingness-to-pay tracker | Cohort scorecard with exact denominators, expiry drain/export tests, no client-forged completed event |
| G First Full Bridge |Only after named partner demand | One supported version/API, owner/vendor auth, reserve/cancel/unknown/reconcile/health protocol | Real sandbox collisions/replay/revocation; atomic guarantee or request-only |
| H Pilot expansion/hardening |AfterC/D/F gates | Learn from attended/repeat bookings, support economics and incident root causes | Wave2 then3 after criteria in10; paid commercial evidence before long extensions |
| I Advanced hardware |Deferred | Signed runtime/adapters/control only when operationally valuable | Certified authorization/recovery; no coupling to financial truth |

Task02 should begin withA/B, not a new universal integration layer. Local/Bridge architecture is examined now; small isolated recovery POC can proceed without delaying a safe online/Booking-only pilot. Complete outstanding Task01 semantic/full-stack coverage during staging preparation; do not silently mark this audit complete.

## Do not build yet

No four separate apps, full billing engine, large vendor-adapter library, universal hardware layer, mandatory deposits, group-booking/loyalty expansion, second customer app by default or replacement of all lounge software. Do not rewrite the working offline foundation, server quote/hold paths, request-race fixes or merged staff/onboarding work. Fix the owning server contract and extend existing tests.

## Experimental go/no-go gates

Wave1: allP1 issues relevant to enabled mode resolved and independently verified; no false confirmation, cross-tenant access or unexplained finance; complete readiness rehearsal and fallback. Wave2: stable clustered operations, attended-booking denominator and repeat-use evidence, operator SLA/support within capacity. Wave3: sustainable operational support and stated willingness to pay, not registrations alone. Free extensions: measured cooperation+service value. First vendor: named demand+supported guarantee. Local production: durable authority/recovery and device acceptance. Suggested numeric experiments in10 are hypotheses, not market benchmarks.

## Release and rollback

Commit audit-only reports/probes in isolated branches. Implementation changes need their own branches and meaningful regressions. Prepare migration preconditions/hashes/backup restoration and deploy order without applying here. For rollback, inspect active sessions/unpaid debt/received commands: reverting a function alone may strand records created under new semantics. Maintain receipt/financial truth and audit; never delete conflicting evidence to achieve green checks.
