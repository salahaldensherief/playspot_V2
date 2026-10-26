# PlaySpot — Remaining P0 / P1 Blockers & Readiness Audit

**Project:** PlaySpot Mobile & Dashboard Ecosystem  
**Staging Target:** `tmqhncduzlavgqoyjcmn`  
**Production Target:** `tgpdexoitemmpruepgyt` (**PROTECTED & UNTOUCHED**)  
**Audit Date:** October 27, 2026  
**Backend Readiness:** **READY FOR STAGING TESTING**  
**Production Readiness:** **NOT READY FOR PRODUCTION DEPLOYMENT UNTIL PHYSICAL E2E SIGN-OFF**

---

## 1. Blocker Classification Summary

| Priority | Count | Description | Impact |
|:---:|:---:|---|---|
| **P0** | **0** | Critical system crashes, data corruption, or payment security bypass | **None** |
| **P1** | **0** | Broken core user journeys (booking, deposit, checkout, permissions) | **None** |
| **P2** | **3** | Operational hygiene, CLI ledger sync, and hardware-dependent verification | **Documented Below** |

---

## 2. Detailed P2 Operational Items & Next Steps

### 1. [P2] Migration Ledger Synchronization
- **Issue:** The staging database runs all 11 new financial migrations in PostgreSQL catalogs, but `supabase_migrations.schema_migrations` only tracks up to `20261017121640`.
- **Mitigation:** Execute the provided script in [`MIGRATION_LEDGER_RECONCILIATION.md`](file:///D:/playspot_V2/docs/MIGRATION_LEDGER_RECONCILIATION.md) in the Supabase Dashboard SQL editor.
- **Rule:** Do NOT execute `supabase db push` until this reconciliation is completed.

### 2. [P2] Cashier Shift Invariant Enforcement (`OWN_OPEN_SHIFT_REQUIRED`)
- **Behavior:** The database enforces that any cash collection (`checkout_booking_cash_atomic`) or deposit verification (`verify_booking_deposit_transfer`) MUST occur within an open shift owned by the calling cashier (`v_shift.cashier_id = auth.uid()`).
- **Operational Requirement:** Mobile app and Web Dashboard UIs must prompt cashiers to open or claim a shift before presenting checkout actions. If a cashier attempts checkout without an open shift, error `55000: OWN_OPEN_SHIFT_REQUIRED` is returned by design.

### 3. [P2] Physical Android Device Verification
- **Status:** **NOT TESTED** in this automated run because the environment lacks `adb` and a connected physical Android device or emulator.
- **Requirement:** Before releasing the mobile APK to Google Play or external testers, perform an on-device walkthrough on real Android hardware covering:
  - Push notification receipt for deposit approval.
  - Camera/gallery upload of transfer payment receipts.
  - Offline sync reconnect behavior when returning to active network.

### 4. [P2] Direct SQL Cancellation Constraint on `booking_cancellation_events`
- **Behavior:** Directly executing a raw SQL `UPDATE bookings SET status = 'cancelled'` fails with `23502` if `booking_cancellation_events.id` lacks a default UUID generator in that specific schema variant.
- **Impact:** Does NOT affect mobile or dashboard users because all cancellation operations flow through authenticated RPCs (`cancel_booking_with_refund_policy`, `reject_booking`). It only affects raw administrative `UPDATE` scripts.

---

## 3. Production Deployment Policy

> [!CAUTION]
> **PRODUCTION DEPLOYMENT PROHIBITED AT THIS STAGE**  
> Under no circumstances should these migrations or client builds be deployed to production project `tgpdexoitemmpruepgyt` until:
> 1. The staging environment has undergone manual UI QA by the product owner.
> 2. Real Android device testing is conducted and documented.
> 3. Production database backup verification is performed with an explicit point-in-time recovery test.
