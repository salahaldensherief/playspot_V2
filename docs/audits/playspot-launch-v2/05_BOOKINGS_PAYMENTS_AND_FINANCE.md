# Booking, payment and finance integrity

Audit date: 21 October 2026 (Africa/Cairo). Scope: Mobile/backend dev `ca455197568f618285b4f52e1b25bfa52c892eb2`; Dashboard dev `a3b9c4bf50fa2b07c6318475a75dbfac2cd5b6c0`.

Evidence levels: source inspection, hosted **read-only catalog** inspection, isolated synthetic PostgreSQL execution, Flutter unit/widget execution. No live business workflow was executed. `VERIFIED` refers only to a named executed check, never whole-product readiness. Task 01 coverage remains **partial**: live Auth/Storage/Realtime workflows, full-schema combined peak-hour execution, operator usability and exhaustive semantic contract verification remain open. See [12](12_TEST_EVIDENCE.md) and [15](15_UNVERIFIED_ASSUMPTIONS_AND_DECISIONS.md).

## Traced lifecycle

Discovery/home/search -> LoungeDetails -> BookingScreen/BookingCubit -> BookingRepositoryImpl -> BookingRemoteDataSourceImpl -> availability/pricing/hold RPCs. CheckoutScreen/CheckoutCubit -> quote_my_booking_checkout/create_my_booking_checkout -> hold row lock, server quote, booking writes, voucher/extra handling -> response primary_booking_id and quote -> status stream -> request/confirmation UI. Customer history/cancellation uses separate scoped RPC paths. Cashier start/extension/completion and settlement are distinct RPCs.

Hold acquisition authorizes the actor, sorts/distincts resource IDs, serializes resource locks, checks venue/resources/bookings/other active holds and creates expiring scoped records. Checkout locks the active actor-owned hold and derives prices server-side. It accepts cash/manual_transfer; payment widgets named after payment brands do not prove a payment gateway or verified automated callback. Do not market these as implemented online card/refund rails without a working provider contract.

The transactional checkout path releases the hold after booking/extra/voucher writes. Repeated request-tap guards exist in the client. However no durable request receipt/lookup precedes the active-hold check: committed-but-lost-response recovery remains PS-005. A retry failure must not be represented as proof the first checkout never committed.

## Evidence by invariant

| Invariant | Observed evidence | Limit / next check |
|---|---|---|
| No overlapping Native capacity | Live validated GiST range exclusion; hold resource locks; native future-hold and fixed-session concurrent tests | Full deployed writer/trigger graph and physical occupancy mapping not replayed |
| Walk-in/online collisions | create_manual_booking_admin and online/offline authority guards; synthetic room/hold/writer suites | Combined online/native/offline 20:00 scenario still needed |
| Safe extension before next reservation | Both live extension functions reject conflicting periods; pricing test includes next slot/overnight | Approval still records money automatically PS-004; no real cashier acceptance |
| Price integrity | Server quote/clamp/snapshot/voucher checks; native pricing/checkout suites | Actual partner tariffs, midnight/DST and deployment version parity need test |
| Start does not imply paid | Source migration and cash-start tests support postpaid | Production fixed-session start still requires paid PS-002 |
| Settlement duplicate safety | complete_booking_payment locks booking and records delta; wallet race suite proves one debit/receipt in fixture | Full production functions differ from source, partial/mixed custody migration absent |
| Cash custody/payout | Source 17-check payout suite including concurrent allocation | Two production RPCs missing PS-003; old records need evidence-backed reconciliation |
| Cancellation | cancel_my_booking authorizes owner and terminal-state guard; status change syncs room | Cancellation is not proof a payment was refunded; providers/compensation unresolved |
| No-show | UI grace/no-show controls and cancellation event components exist | markNoShow only writes cancelled; cannot derive reliable no-show counts PS-007 |
| Shift close | Locks/permission checks, native close-vs-collection wallet case | Outstanding local outbox/handoff and exact totals need composed rehearsal |

## Financial blocker detail

Audit probe PS-004 used a synthetic paid EGP180 booking and exact deployed approve_booking_extension; approving +30 minutes produced total/payment EGP230 and a new EGP50 shift collection, with no explicit collection operation. This is code-behavior evidence from a reduced schema, not proof of a real erroneous transaction. The current tests expect the same behavior. Financial truth needs an operational decision: approving duration must not silently mean new cash/transfer was received. Preserve paid180/due50 until a receipt-backed collection.

Live complete_booking_payment and extension code use a fixed 0.15 commission; offline partial-cash logic reads a configured rate. This is a **commercial consistency risk**, not proof an agreed contract was breached: partner terms and commission model are not final. Reconcile rate provenance, commission rounding, payer/payee, cash kept by lounge and actual platform custody before enabling settlement. Trial pricing must not bypass financial controls.

Deposits are not a universal pilot prerequisite. First establish partial-payment/refund/remaining-balance semantics. Test cash-only and optional supported deposit variants with genuine attendance metrics; do not use unverified 30% no-show claims. A confirmed native reservation requires real capacity; external confirmation requires documented external allocation, not a status button.

## Required acceptance matrix

Concurrent same/different requests; holds expire during checkout; lost ACK after commit; cancel vs confirm/start; two walk-ins and three holds; extension across future booking; partial/full cash/transfer/wallet; repeated callbacks/settlement/refund; shift close during collection; wrong tenant/staff role; timezone midnight and Cairo DST; stock exhaustion; completion with outstanding debt. See [06](06_PEAK_HOUR_OPERATIONAL_STRESS_TEST.md) and [14](14_NEXT_CODEX_TASKS.md).
