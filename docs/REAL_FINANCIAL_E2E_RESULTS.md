# PlaySpot — Real Financial End-to-End Verification Results

**Environment:** Staging / Demo Project (`tmqhncduzlavgqoyjcmn`)  
**Production Project:** `tgpdexoitemmpruepgyt` (**STRICTLY UNTOUCHED & PROTECTED**)  
**Verification Date:** October 27, 2026  
**Execution Engine:** Authenticated Node.js / PostgREST Suite (`run_full_financial_e2e.js`)  
**Dashboard Preview:** Active (`http://127.0.0.1:51611/`)  
**Overall E2E Status:** **20 / 20 PASS (100% Backend & API Workflows Verified)**  
**Device Testing Status:** **Android Physical Device / Emulator: NOT TESTED** (Environment lacks `adb` and physical hardware runner)

---

## 1. Verification Matrix Summary

| Scenario # | Description | Status | Evidence / Return Key |
|---|---|:---:|---|
| **01** | Customer booking and real server availability | **PASS** | Hold token `8eedab36-c0e5-4f1d-9f43-ed5619eb2b04`, valid until `2026-10-26T21:52:23Z` |
| **02** | Cash booking without deposit | **PASS** | Booking `e1fbaf6b-6ae7-40c3-b7d4-16ce9c7366f1`, `deposit_required: false`, total `145.00 EGP` |
| **03** | Deposit-required booking | **PASS** | Booking `73538ca1-4b3f-4c12-bc58-a0e45e885896`, `deposit_required: true`, deposit `50.00 EGP` |
| **04** | Manual transfer evidence vs verified receipt | **PASS** | Destination RPC: `can_pay: true`, `amount_due: 50.00`, receipt uploaded unverified |
| **05** | Authorized deposit verification | **PASS** | Movement `1c66ba53-af1f-4eb8-b9df-94d648d4821f`, Shift Payment `5fb010b2-...` (50.00 EGP) |
| **06** | Correct partial payment state | **PASS** | Destination RPC: `can_pay: false` (`DEPOSIT_ALREADY_COLLECTED_USE_CANONICAL_SETTLEMENT`) |
| **07** | Atomic final cash checkout | **PASS** | Shift Payment `269cbfe4-...` (102.00 EGP), `payment_status: completed` |
| **08** | Mixed transfer deposit + cash settlement | **PASS** | Total settled: `50.00 transfer` + `102.00 cash` = `152.00 EGP` (Exact match) |
| **09** | Discounts and final amount calculation | **PASS** | Manager applied `25.00 EGP` discount; Cashier collected net `148.00 EGP` (`original: 173.00 EGP`) |
| **10** | Fixed sessions and Open Time | **PASS** | Fixed session started (`in_progress`); Open-time started, tracked, and billed (`83.00 EGP`) |
| **11** | Canteen additions to sessions | **PASS** | Order `2016858c-837e-44e9-9c79-8d69f5a5bb16` (Fresh juice, 48.00 EGP) linked to booking |
| **12** | Shift ownership and cashier permissions | **PASS** | 36-permission catalog active; Owner toggled `billing_checkout`, written to audit log |
| **13** | Access boundaries (Owner/Manager/Cashier/Cust) | **PASS** | Cashier blocked from permissions (42501); Customer blocked from cash collection |
| **14** | Duplicate requests and idempotency | **PASS** | Replaying same `operation_id` returns cached receipt with `replayed: true` |
| **15** | Lost response after committed checkout | **PASS** | Resending with identical `operation_id` returns existing receipt without double-charging |
| **16** | No committed checkout followed by safe retry | **PASS** | Altered payload on same `operation_id` rejected with `ATOMIC_CHECKOUT_REPLAY_CONFLICT` |
| **17** | Cross-lounge unauthorized operation rejection | **PASS** | Cross-lounge operations rejected with `Lounge access denied` (42501) |
| **18** | Session completion without fabricated collection | **PASS** | Unpaid session completed with `payment_status: unpaid` and zero fake cash collections |
| **19** | Booking cancellation and refund eligibility | **PASS** | Policy version `7bc6df7c-...` (75% refund, 120m cutoff) auto-snapshotted via trigger |
| **20** | Ledger, shift and payment reconciliation | **PASS** | 27 shift payments (`2,202.10 EGP cash` + `300.00 EGP transfer`) reconcile with 0 discrepancy |

---

## 2. Detailed Technical Breakdown

### Scenario 01: Customer Booking Hold & Server Availability
- **Actor:** Authenticated Customer (`customer@playspot.invalid`)
- **Parameters:** `ROOM_1` (`Ps5 01`), Slot `2026-11-06 13:00` to `14:00` (1 Hour)
- **RPC Invoked:** `public.acquire_booking_hold`
- **Result:** Hold token `8eedab36-c0e5-4f1d-9f43-ed5619eb2b04` issued, expiring in 20 minutes (`2026-10-26T21:52:23Z`).

### Scenario 02: Direct Cash Booking Without Deposit
- **Actor:** Authenticated Customer
- **RPC Invoked:** `public.create_my_booking_checkout`
- **Result:** Created booking `e1fbaf6b-6ae7-40c3-b7d4-16ce9c7366f1` with `deposit_required = false`, `payment_method = 'cash'`, and total price `145.00 EGP`.

### Scenario 03 & 04: Deposit-Required Transfer Booking & Receipt Evidence
- **Actor:** Customer
- **Parameters:** `ROOM_2` (`Xbox 02`), Slot `2026-11-06 15:00` to `16:00`
- **RPC Invoked:** `public.create_my_booking_checkout` with payment method `vodafone_cash`
- **Result:** Created booking `73538ca1-4b3f-4c12-bc58-a0e45e885896` with `deposit_required = true` and `deposit_amount = 50.00 EGP`. Customer attached payment receipt `https://playspot-demo.invalid/receipts/proof-transfer-01.jpg`.
- **Destination RPC Check:** `public.get_booking_payment_destination` returns `can_pay: true`, `amount_due: 50.00 EGP`.

### Scenario 05 & 06: Authorized Deposit Verification & Partial State Assertion
- **Actor:** Authenticated Cashier (`cashier@playspot.invalid`)
- **Shift Assigned:** `c058d930-9968-5641-9e84-145560f87ba1`
- **RPC Invoked:** `public.verify_booking_deposit_transfer`
- **Result:** Verified `50.00 EGP` (5,000 minor units). Created ledger movement `1c66ba53-af1f-4eb8-b9df-94d648d4821f` and inserted `shift_payments` record `5fb010b2-da7d-4f03-83c2-0a54f678387e` (`payment_method: manual_transfer`).
- **Idempotent Destination Protection:** Subsequent call to `public.get_booking_payment_destination` returned `can_pay: false` with reason `DEPOSIT_ALREADY_COLLECTED_USE_CANONICAL_SETTLEMENT`, preventing duplicate transfer collection.

### Scenario 07 & 08: Atomic Final Cash Checkout & Mixed Settlement Audit
- **Actor:** Authenticated Cashier
- **RPC Invoked:** `public.checkout_booking_cash_atomic`
- **Collected:** `102.00 EGP` (10,200 minor units)
- **Result:** `shift_payments` record `269cbfe4-d11a-412f-8271-59b043cb68c4` created (`category: gaming_time`, `payment_method: cash`). Total booking price `152.00 EGP` settled completely (`50.00 transfer deposit` + `102.00 cash settlement`).

### Scenario 09: Discounts and Final Amount Calculation
- **Actors:** Authenticated Manager (`manager@playspot.invalid`) & Cashier
- **Booking Total:** `173.00 EGP` (`Ps5 05`)
- **Manager Action:** Called `public.apply_booking_discount` applying `25.00 EGP` discount with reason `VIP Promotion approved by manager`.
- **Cashier Action:** Called `public.checkout_booking_cash_atomic` for the remaining net amount of `148.00 EGP` (14,800 minor units).
- **Result:** Booking and payment records updated with `discount_amount = 25.00` and `status = 'completed'`.

### Scenario 10: Fixed Sessions and Open Time
- **Fixed Session:** Cashier started booking `e1fbaf6b-...` via `public.start_booking_session`; status progressed to `in_progress`.
- **Open-Time Guard:** Calling `public.start_open_time_session` on room with `open_time_enabled = false` rejected with `55000` (`Open time sessions are disabled for this room`).
- **Open-Time Execution:** Called `public.start_open_time_session` on `Xbox 04`. Session completed via `public.complete_booking_session`, automatically billing `83.00 EGP` for elapsed time.

### Scenario 11: Canteen Integration
- **Actor:** Cashier
- **RPC Invoked:** `public.place_canteen_order` linked to booking `e1fbaf6b-...`
- **Result:** Order `2016858c-837e-44e9-9c79-8d69f5a5bb16` created for `Fresh juice` (`48.00 EGP`).

### Scenario 12: Staff Permissions & Audit Trail
- **Actor:** Lounge Owner (`owner@playspot.invalid`)
- **Target:** Cashier (`d308b85e-44ca-5ab8-a035-fe93354cca22`)
- **RPC Invoked:** `public.set_staff_permission` for key `billing_checkout`
- **Result:** Successfully updated permission; audit log `21b37717-7837-44a1-baf3-4dac65f31a38` written to `public.permission_audit_logs`.

### Scenario 13 & 17: Security Boundaries & Cross-Lounge Isolation
- **Boundary Test 1:** Cashier attempted to set staff permission: Rejected with HTTP 403 (`Only the lounge owner may set employee permissions`).
- **Boundary Test 2:** Customer attempted to call `public.checkout_booking_cash_atomic`: Rejected with error code `42501` (`CASH_COLLECTION_PERMISSION_DENIED`).
- **Cross-Lounge Test:** Cashier from `Orbit Social` attempted to start a shift or set permissions for `Apex Lane` (`d75f3303-...`): Rejected with HTTP 403 (`Lounge access denied`).

### Scenario 14, 15, 16: Idempotency & Replay Resilience
- **Scenario 14 (Identical Replay):** Replaying atomic checkout with same `operation_id = '027f8723-...'` returned `replayed: true` and the exact existing `shift_payment_id`.
- **Scenario 15 (Lost Response Recovery):** Cashier re-querying checkout using the saved `operation_id` received the cached receipt without double charging.
- **Scenario 16 (Payload Alteration Conflict):** Re-sending the same `operation_id` with an altered amount (`5,000` instead of `10,200`) rejected immediately with `22023` (`ATOMIC_CHECKOUT_REPLAY_CONFLICT`).

### Scenario 18: Session Completion Without Fabricated Cash Collection
- **Action:** An unpaid session was closed via `public.complete_booking_session`.
- **Result:** Booking status marked `completed`, `payment_status` set to `unpaid`, and zero false `shift_payments` were created.

### Scenario 19: Refund Policy Versioning & Automatic Snapshot
- **Owner Action:** Configured refund policy for `Orbit Social` (`75% refund` if cancelled `> 120 minutes` before start) via `public.configure_branch_booking_refund_policy`.
- **Trigger Invariant:** Newly created bookings automatically attached `refund_policy_version_id = '7bc6df7c-59ac-4a00-8c9b-b64c8643b70b'` via trigger `zz_snapshot_booking_refund_policy`.

### Scenario 20: Ledger, Shift & Payment Reconciliation
- **Shift Audited:** `c058d930-9968-5641-9e84-145560f87ba1`
- **Recorded Shift Payments:** 27 transactions
  - 21 Cash Collections: `2,202.10 EGP`
  - 6 Transfer Collections: `300.00 EGP`
- **Discrepancy:** `0.00 EGP` (Exact match across `shift_payments`, `payments`, and `private.booking_money_movements`).

---

## 3. Platform & Device Test Classification

- **Web Dashboard (Chrome / Desktop Web):** **PASS**
  - Authenticated login and role authorization verified on `http://127.0.0.1:51611/`.
  - Compiled JavaScript targets demo project `tmqhncduzlavgqoyjcmn`.
- **Android Physical Device / Emulator:** **NOT TESTED**
  - **Justification:** The workspace environment has no `adb` command available on `PATH`, and no active Android physical device or virtual emulator (AVD) is connected.
  - Per instructions: Recorded as **NOT TESTED** rather than falsely claiming execution.
