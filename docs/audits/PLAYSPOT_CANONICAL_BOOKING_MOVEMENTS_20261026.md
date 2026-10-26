# Canonical booking money movements — 26 October 2026

Status: **Draft foundation only. Do not merge or deploy independently.**

## Verified problem

The preserved schema-only export matched 3,607/3,607 catalog objects before Draft migrations. `payments_booking_id_unique` makes `payments` one aggregate row per booking. `shift_payments` records individual shift amounts but lacks idempotency, commission and custody per movement. The effective `create_payout` and `private.payment_settlement_values` attribute the *entire* aggregate row to its one `payment_method`. A verified EGP 20 transfer deposit followed by EGP 130 cash on an EGP 150 final bill cannot be represented faithfully by that one method. The current cash RPC rejects the second method with `PAYMENT_REQUIRES_RECONCILIATION`.

## Implemented in this Draft

`private.booking_money_movements` holds a verified collection or actual completed refund, in integer minor units. Each row records one operation ID, booking, aggregate payment, shift, method, amount, commission, custody holder, verifying actor, and evidence. Positive collections require exactly one matching `shift_payments` row. Refunds link an original collection and serialize on it; total refunded amount and commission cannot exceed the verified original. Cross-lounge, mismatched shift evidence, mutation after insert, duplicate operation or shift evidence, and direct authenticated access are rejected. `private.booking_movement_payout_entries` prevents concurrent active payouts from claiming one movement twice and validates its method-specific contribution; a failed/cancelled payout can be retried while keeping the old allocation evidence. No client or RPC can currently write these private tables.

A private `booking_money_coverage` view distinguishes untouched legacy aggregate rows from new rows whose movement gross agrees with the aggregate. It exposes no aggregate `payment_method`, so a payout/report migration can explicitly quarantine rows needing reconciliation rather than infer a method from one legacy field.

The aggregate `payments` row remains unique per booking. No historical payment is automatically classified into the new ledger. Existing payout functions still require a method-specific rewrite before mixed rows can be settled.

## Verified deposit and mixed cash extension (local, pending PR update)

`verify_booking_deposit_transfer` requires an authenticated cashier with a personally owned open shift and `billing_checkout`. It treats a receipt reference as evidence only; the cashier attests that funds arrived. It checks the server-stored required deposit against the final booking total, rejects prior collection and conflicting operation IDs, and atomically writes one aggregate payment, shift payment, method-specific movement and partial booking state. Exact replay returns the original movement even if the shift has since closed. It does not mark the entire booking paid.

For a movement-backed booking, `collect_booking_cash_partial` now verifies existing movement/aggregate/shift totals before another collection. The cash writer keeps electronic and cash methods separate, writes a new cash movement, and marks only the compatibility aggregate as `mixed`. The existing `checkout_booking_cash_atomic` RPC calls this writer, so its default amount uses the remaining balance after the verified deposit. Historical cash-only rows without movements stay on their prior path. The migration extends the two aggregate method constraints to `mixed`; every payout/report consumer must treat that value as a marker, never a method-specific collection.

The isolated rollback-only fixtures passed after this change: movement structure (EGP 20 + EGP 130, EGP 22.50 commission, custody contributions +17/−19.50); verified deposit (one payment, shift row and movement, partial status, unauthorized and duplicate rejection, replay after shift close); and the actual atomic checkout RPC (EGP 20 platform-held transfer plus EGP 130 lounge-held cash, zero due, two shift rows, two movements, EGP 22.50 commission, unauthorized/overpayment rejection and stable replay). This is a synthetic database integration proof. It does not establish that a customer transfer actually cleared, or complete payout/refund/client compatibility.

## Isolated test result

Applied this Draft migration only in `playspot_financial_restore_20261026_v2` after the preserved exact-schema restore and earlier Draft migrations. The synthetic rollback-only fixture passed 3/3. It inserted an EGP 20 electronic movement and an EGP 130 cash movement for one EGP 150 booking, and asserted 2,000 + 13,000 = 15,000 minor units, 2,250 commission, and separate custody contributions of +1,700 and −1,950 (net −250). It rejected duplicate submission, repeated shift evidence, mutation, excessive refund amount and commission, an incorrect payout contribution, and direct authenticated access. Zero synthetic movement or lounge rows remained after rollback. This proves the table constraints, **not** an end-to-end cashier or payout workflow.

## Release dependencies

1. Review the verified-deposit cashier attestation UI and the canonical atomic cash checkout integration in Draft backend PR #84 and Dashboard cashier PR #83. Submitted transfer proof must remain pending until staff verify actual receipt.
2. Migrate payout selection, custody, cancellation/failure, settlement assertion and reports to per-movement attribution. Historical aggregate payments need a read-through path with reconciliation quarantine; do not infer an electronic transfer from a mixed aggregate.
3. Implement branch-level refund deadline and percentage policy with snapshot, eligibility/obligation, manual return authorization, and verified refund movement. `cancel_my_booking` alone does not return money.
4. Update Mobile and Dashboard payment models, receipts, shift reports, analytics, offline retries and legacy-client behavior. Test restricted roles and authenticated browser flows.
5. Run exact-schema mixed-method concurrency, idempotency, refund, shift and payout invariants plus staging migration/recovery rehearsal before any production approval request.

This Draft now has public collection writers, but payout and refund behavior is not complete. Do not merge or deploy it alone. A green synthetic collection test must not be reported as financial integration completion.
