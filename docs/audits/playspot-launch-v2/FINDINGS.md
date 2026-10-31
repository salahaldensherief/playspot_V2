# Findings register

Audit date: 21 October 2026 (Africa/Cairo). Scope: Mobile/backend dev `ca455197568f618285b4f52e1b25bfa52c892eb2`; Dashboard dev `a3b9c4bf50fa2b07c6318475a75dbfac2cd5b6c0`.

Evidence levels: source inspection, hosted **read-only catalog** inspection, isolated synthetic PostgreSQL execution, Flutter unit/widget execution. No live business workflow was executed. `VERIFIED` refers only to a named executed check, never whole-product readiness. Task 01 coverage remains **partial**: live Auth/Storage/Realtime workflows, full-schema combined peak-hour execution, operator usability and exhaustive semantic contract verification remain open. See [12](12_TEST_EVIDENCE.md) and [15](15_UNVERIFIED_ASSUMPTIONS_AND_DECISIONS.md).


## PS-001 — P1: An owner can pass global announcement authorization

**Evidence status:** Confirmed deployed authorization defect.

**Evidence / reproduction:** Deployed `send-system-announcement` v1, `index.ts:19–43` accepts profile role owner/admin/super_admin; payload topic defaults all_users and is caller controlled at line 56. Read-only downloaded source is in evidence/live-announcement.ts. No broadcast was sent.

**Impact:** A lounge owner can invoke platform-wide messaging authority outside their tenant. This proves the permissive code path, not actual FCM delivery or an observed abuse.

**Recommended fix / containment:** Contain through an authorized restricted deployment of the existing isAnnouncementCallerAuthorized implementation. Restrict global broadcasts to canonical is_super_admin; keep service authentication separate. Do not deploy during this audit.

**Verification required:** Run role matrix (owner, staff, banned/inactive admin, canonical super admin, internal key, bad/missing token) with mocked FCM, then authorized staging delivery only.

**Existing work:** Fix already in Dashboard dev: supabase/functions/send-system-announcement/authorization.js and index.ts; 85 Edge tests pass locally. Production is older.

## PS-002 — P1: Dashboard offers postpaid cash start but production rejects it

**Evidence status:** Confirmed deployment contract mismatch; isolated reproduction.

**Evidence / reproduction:** Dashboard lib/features/bookings/domain/entities/booking.dart:295 and booking_card_actions.dart:154 permit cash before collection. Captured public.start_booking_session requires payment_status paid for every fixed session. Audit probe launch_v2_cash_start.probe.mjs reproduces SQLSTATE 55000 / PAYMENT_REQUIRED_BEFORE_SESSION_START.

**Impact:** A Native cashier cannot use the advertised start-now/pay-later path. Demo success cannot establish production parity.

**Recommended fix / containment:** Review and rehearse canonical 20261016211005_cash_session_start_before_collection.sql against exact production definitions; deploy only after separately authorized release and finance gates. Do not force payment confirmation just to start play.

**Verification required:** Unpaid/partial/paid cash, unpaid transfer, refunded/cancelled booking, missing shift, wrong tenant, repeated and concurrent start; no collection rows created by starting.

**Existing work:** Fix is already in Mobile dev migration and cash_session_start.test.mjs. No cherry-pick is needed; deployment is a separate action.

## PS-003 — P1: Payment custody review cannot reach its backend

**Evidence status:** Confirmed missing production RPCs.

**Evidence / reproduction:** Dashboard lib/features/payouts/data/datasources/payout_remote_data_source.dart:54,73 calls get_payment_funds_review and record_payment_funds_custody. Both absent from production pg_proc, present in demo and Mobile migration 20261011065428_payout_cash_commission_settlement.sql:81,116.

**Impact:** Platform cannot review/record ambiguous funds custody using the current client. Settlement approval must not assume money is in platform custody.

**Recommended fix / containment:** Prepare exact schema/function/grant dependency diff and financial migration rehearsal; resolve historical custody with evidence. Do not replay migration directories or infer custody from payment method.

**Verification required:** Mock missing-RPC failure visibly; run payout_funds_custody fixture (17 checks here); authorized staging unknown/platform/lounge cases, stale evidence, replay, tenant/role denial, concurrent payout allocation.

**Existing work:** Implementation already in Mobile dev; production rollout absent. Demo presence is not proof of financial correctness.

## PS-004 — P1: Extension approval infers new money collected

**Evidence status:** Confirmed isolated financial behavior; full-stack impact unverified.

**Evidence / reproduction:** Captured public.approve_booking_extension and extend_booking_session insert shift_payments and upsert payments when prior booking is paid. Dashboard request_card_actions.dart:140 calls approval without an explicit collection action. launch_v2_extension.probe.mjs overlays the exact deployed approval definition on the existing synthetic pricing fixture: paid 180 -> 230, shift collection +50, explicit collection calls 0.

**Impact:** If approval does not mean actual collection, revenue/cash and due amounts become wrong. Existing booking_extension_price_integrity.test.mjs deliberately expects this behavior, so green tests do not validate the operational meaning. No live financial corruption was tested or asserted.

**Recommended fix / containment:** Separate extension approval/price liability from receipt-backed collection. Preserve paid amount; increase due amount; require explicit permissioned idempotent collection for cash or verified transfer. Confirm intended operator semantics before release.

**Verification required:** 180 paid + 50 extension => total230, paid180, due50, unchanged ledger; explicit collection => paid230 once. Repeat approvals, lost ACK, partial deposits, wallet, transfer, shift closure and future reservation conflict.

**Existing work:** No verified fix found in reviewed branches. Existing source retains automatic collection. Do not merge an unrelated Bridge branch as remediation.

## PS-005 — P1: Checkout has no durable unknown-outcome recovery

**Evidence status:** Confirmed design gap; recovery outcome not exercised through app.

**Evidence / reproduction:** Mobile checkout_state.dart:8 only initial/loading/success/failure; CheckoutCubit.processPayment lines 457–500 maps repository failures to failure. Deployed create_my_booking_checkout consumes/releases the hold and has no request-id receipt lookup before the active-hold check. Receipt-upload recovery after a known primary_booking_id is implemented separately.

**Impact:** A committed checkout with a lost response can appear failed; same-hold retry sees an expired hold. Database capacity constraints reduce double allocation, but do not recover booking identity or justify a definitive failure message.

**Recommended fix / containment:** Add server request id + immutable payload fingerprint + transactionally stored checkout receipt; same request must return original IDs, changed payload must conflict. Persist only minimal actor-scoped recovery identity and show pending/unknown until lookup resolves.

**Verification required:** Commit then drop response, restart client, recover IDs without new booking; concurrent identical requests; changed-payload reuse; expired-but-previously-committed hold; another user cannot read receipt.

**Existing work:** No durable recovery implementation found in reviewed dev/Bridge diffs; client duplicate-tap guards and proof-upload retry do not solve it.

## PS-006 — P2: Current Dashboard dev does not pass its full Flutter suite

**Evidence status:** Confirmed test regression; product defect not established.

**Evidence / reproduction:** 1307 passed, 2 skipped, 1 failed: test/features/bookings/live_sessions_operations_groups_test.dart:38. Fixture start17:05/duration60 but explicit end19:00; expectation says ending at18:00. Latest a3b9c4b intentionally prefers explicit endTime over duration-derived end in Booking.endDateTime.

**Impact:** The regression suite is inconsistent with the new schedule authority. A failing assertion does not prove actual occupied-room overlap.

**Recommended fix / containment:** Choose and document scheduled-end authority, correct inconsistent fixture, add real server timestamp/overnight/DST cases. Preserve server-booked end rather than reverting behavior to satisfy a stale test.

**Verification required:** Focused group/schedule/clock tests and full Dashboard suite; AR/EN operator review of remaining time.

**Existing work:** No verified later fix found; Bridge PR69 uses an earlier base and its green CI does not cover this new dev commit.

## PS-007 — P2: No-show action is ordinary cancellation

**Evidence status:** Confirmed metric semantics gap.

**Evidence / reproduction:** Dashboard BookingCubit.markNoShow at lib/features/bookings/presentation/cubit/booking_cubit.dart:359 calls changeBookingStatus(cancelled); data source also normalizes no_show to cancelled. No explicit no-show reason is supplied by that action.

**Impact:** Attendance/no-show conversion cannot reliably distinguish customer cancellation from operator-marked nonattendance using status alone.

**Recommended fix / containment:** Keep capacity release transactional but record immutable outcome reason/actor/time, with a documented grace rule and reversal audit. Reuse cancellation event machinery where suitable.

**Verification required:** Cancellation vs no-show remain distinguishable, grace/arrival race does not double-release, unauthorized staff cannot override and reports count reversals correctly.

**Existing work:** No dedicated no-show event fix verified in reviewed work.

## PS-008 — P1 for external-mode launch: Lite Bridge confirmation is not an external reservation

**Evidence status:** Missing operational guarantee, not an observed double booking.

**Evidence / reproduction:** Dashboard approveBooking calls update_booking_status_admin(upcoming). No external allocation reference, inventory partition enforcement, reconciliation worker or vendor adapter is attached. PR69 backend changes add proposal/mock-only files and no production booking RPC changes.

**Impact:** PlaySpot capacity exclusion protects its own rows only. An operator can confirm while existing vendor software sells the same resource.

**Recommended fix / containment:** First pilot must use an enforceable dedicated allocation or explicit manual vendor-reservation protocol with reference, responsible operator, SLA, expiry and audit. Request-only until allocation is evidenced. Fail closed if no real guarantee.

**Verification required:** Two simultaneous operator confirmations/walk-ins/vendor booking; required allocation evidence; lost response; decline/expiry; customer language distinguishes request from confirmed reservation.

**Existing work:** No deployed full solution. Bridge questionnaire/planner is advisory; all activation remains false.

## PS-009 — P1 for offline launch: Offline financial durability and recovery need browser/device acceptance

**Evidence status:** Implemented foundation; environmental acceptance unverified.

**Evidence / reproduction:** Dashboard encrypted_cashier_journal.dart persists aggregate projection+outbox with HiveAesCipher and flush; local_cashier_commands.dart enforces scope/permit/sequence; offline route exists. 54 native fixed-session checks pass, with explicit synthetic-trigger limitations.

**Impact:** There is substantial reusable code, but browser storage eviction, secure-key loss, tab/browser restart, offline startup asset loading, multi-tab authority and real reconnect were not exercised in this audit.

**Recommended fix / containment:** Keep cloud-backed Native pilot online until a declared offline mode passes device tests. Build on existing journal/authority implementation, not a second POS. A future Windows service must use the same explicit ownership and reconciliation contract.

**Verification required:** Power loss after durable write/before ACK, reopen same actor, wrong actor/tenant, revoked/expired permit, clock rollback, multi-tab contention, outbox replay, storage quota/eviction and key recovery; no stale-capacity confirmation.

**Existing work:** Foundation already merged; Dashboard PR54 merged. Backend tests source exists. No production Windows service verified.

## PS-010 — P2: Referral codes do not provide the Founding 20 outcome funnel

**Evidence status:** Missing pilot measurement contract.

**Evidence / reproduction:** Mobile core/services/deep_link_service.dart handles code/ref/referral/p_referral_code into pending referral state. No dedicated venue-campaign attribution plus authoritative attended/completed/repeat event chain was found by repository/call inventory.

**Impact:** Registrations and referral claims cannot establish attended bookings, incremental demand or co-marketing value. Current no-show collapse worsens measurement.

**Recommended fix / containment:** Add minimal consent-aware venue/campaign attribution and server-owned attendance/completion events; use a simple partner tracker for contact/co-marketing/support evidence.

**Verification required:** Deduplicate completion by booking transition/version, deny client-forged completion, distinguish same-customer repeat, delete/pseudonymize personal data appropriately and separate observed origin from claimed incrementality.

**Existing work:** Existing referrals/analytics can be reused; no complete founding-partner funnel verified.

## PS-011 — P2: Scheduled start time gate is only a client rule

**Evidence status:** Confirmed client/server policy difference; business rule unresolved.

**Evidence / reproduction:** StartSessionButton uses schedule/time gates; captured public.start_booking_session checks auth, role, status, shift and payment but no lower bound against scheduled time. Room occupancy guards are separate.

**Impact:** An authorized sessions_control user can call the RPC outside the client start window. Whether this is forbidden or an approved early-arrival override needs an explicit product policy.

**Recommended fix / containment:** Define venue early-start/grace/override policy, enforce agreed rules in server transition with reason audit; do not implement arbitrary timing restrictions before this decision.

**Verification required:** Before/at/after start, Cairo DST, early-arrival authorized override, conflicting future booking, active occupancy and stale client clock.

**Existing work:** No verified server timing policy fix found. Existing postpaid source does not itself prove this gate.
