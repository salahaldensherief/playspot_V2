# Exact-schema cash checkout evidence — 25 October 2026

Status: **Draft only. No production database change, merge, or deployment.**

## Baseline and defect

The authorized `public`/`private` schema-only snapshot from project `tgpdexoitemmpruepgyt` was restored to disposable PostgreSQL 17 container `playspot_financial_restore_20261025`. Before Draft migrations, the restored catalog matched the read-only target fingerprint in **3,607/3,607** entries after local ACL and extension-owned trigger reconciliation. The export, synthetic fixtures, and local credentials stay outside Git. This branch starts at Mobile `origin/dev` commit `3898b24ecd48307e608b4f94a59059cbf2704990`. Draft PR #83's Open Time status correction was already applied to the disposable database; it does not modify this cash collector.

The deployed collector inserted a private receipt before locking the booking. Two distinct operation IDs on one booking occasionally deadlocked while upgrading foreign-key key-share locks. The Dashboard's existing separate `apply_booking_discount` and `complete_booking_payment` calls reproduced a committed discount followed by a rejected collection after an earlier canonical partial receipt. A booking discounted from 100 to 90 and then fully collected showed `bookings.discount_amount=10`, `payments.discount_amount=0`, `payments.amount=90`, and shift cash movements summing to 90.

## Draft change

Migration `20261025101139_atomic_discount_cash_checkout.sql` checks the exact deployed collector definition before replacement. The collector takes a booking-scoped transaction advisory lock before receipt insertion. New `checkout_booking_cash_atomic` binds the full request to its operation ID, checks actor, booking and personally owned open shift, optionally approves a discount, invokes canonical partial collection, then aligns payment discount metadata. PostgreSQL rolls the entire call back if any step fails. `anon` has no execute grant; `authenticated` callers still need business authorization. An existing plain collection operation ID cannot be reused as a discounted checkout.

The new RPC follows the canonical collector's booking eligibility: completed sessions and future fixed reservations can take cash; an Open Time session still in progress cannot. It accepts positive integer minor-unit amounts and rejects a second discount request on an already discounted booking for manual reconciliation. A discount reducing the outstanding balance to zero without new cash needs a separate reviewed accounting path. Existing Dashboard callers still use the split flow, so this backend migration alone does **not** fix the deployed client behavior.

## Isolated test results

| Scenario | Observed result |
| --- | --- |
| Overpayment after discount | `CASH_EXCEEDS_OUTSTANDING_BALANCE`; discount, receipt, payment and shift movement all rolled back. |
| Lost ACK / same-operation replay | Same shift movement and totals, `replayed=true`, no second collection; changed discount with same operation ID rejected. |
| Simultaneous same-operation checkout | One initial result, one replay, one receipt and one shift movement. |
| Distinct concurrent canonical collections of 60 against 100 | **20/20** race runs: one collection, one balance rejection, no deadlock or duplicate movement after lock fix. The original exact-schema function intermittently returned `40P01`. |
| Previous partial 40, discount 10, collect 50 | Booking total 90; payment 90 with discount metadata 10; two categorized cash shift rows sum to 90; two receipts; paid status. Payment commission plus net-to-lounge equals 90. |
| Fixed and percentage discounts of 10 | Booking and payment discount amounts 10; cash/shift amount 90. |
| Unauthorized customer, wrong-shift cashier, revoked actor | Rejected. Direct authenticated receipt-table read denied; `anon` RPC execute denied. |
| Future fixed reservation | Discounted cash prepayment succeeded; payment and shift both recorded 90 and one receipt. |

The atomic regression script passed seven scenario groups in **5/5** consecutive runs, including commission/net, reason, approver, receipt, payment and categorized shift-row assertions. Both `.cjs` scripts in `supabase/tests/financial_contract` require an explicit opt-in and a local-only guard table; they were run only against the disposable container. The pre-migration 3,607/3,607 match establishes starting parity. The local database intentionally differs after Draft migrations and the local guard marker.

Repository checks at this branch: `flutter analyze --no-fatal-infos` found no issues; `flutter test` passed 627 tests with one skipped; all 59 top-level backend suites passed against a **separate** disposable PostgreSQL 17.11 fixture on localhost:55439; the three additional offline protocol fixture runs also passed. An earlier attempt without that native fixture fell back to PGlite and failed 38 of 59 suites, so it is not counted as PostgreSQL verification. GitHub CI is still pending for this branch.

## Remaining gates

- Wire every Dashboard cash action to an explicit shift, authoritative balance and durable operation ID. Many current callers omit `shiftId`; changing only the data source would strand those paths. Verify reconnect, retry and lost-ACK UI behavior.
- Review Mobile cash flows and old RPC compatibility. Do not call the split Dashboard flow fixed while it remains in use.
- Test refunds, shift close/handover, aggregate ledgers and the full role matrix against the combined Draft migration set.
- Before any production database change: verify a recent restorable backup, rehearse recovery, check deployed-client compatibility, explain impact, and obtain explicit owner approval for that specific change. Keep this PR Draft and target `dev`.

For isolated reruns, install dependencies in `supabase/tests/runtime`, create `private.playspot_isolated_test_guard` with token `PLAYSPOT_DISPOSABLE_EXACT_SCHEMA_20261025` **only in the disposable database**, and run each test with `PLAYSPOT_EXACT_SCHEMA_TEST=1` and `PLAYSPOT_ISOLATED_DB_URL` pointing to localhost. Never create the marker in production.
