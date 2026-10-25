# Pre-session manual-transfer safety gate — 25 October 2026

Status: **Draft, independent of the cash-checkout PR; do not merge or deploy alone.** This migration adds a guard against the known false collection, not a deposit or mixed-method checkout implementation.

The preserved disposable PostgreSQL exact-schema restore matched 3,607/3,607 public/private catalog entries before Draft migrations. It contains synthetic guard token `PLAYSPOT_DISPOSABLE_EXACT_SCHEMA_20261025`. The effective `approve_manual_booking` requires a receipt URL, then calls `complete_booking_payment(..., 'manual_transfer', NULL)`. The latter records the entire booking total, marks it paid, and posts that amount to an open shift. The existing `get_booking_payment_destination` may instead quote the configured `deposit_amount`. Only `confirm_future_booking_request` and `get_booking_payment_destination` use the booking deposit fields in the effective function catalog; approval does not.

For a synthetic future booking with `total_price=100`, `deposit_amount=20`, and `deposit_paid=false`, the rollback-only exact-schema fixture observed:

| Case | Booking paid status | `payments` completed amount | `shift_payments` amount |
| --- | --- | ---: | ---: |
| Before guard: legacy approval | `paid` | 100 | 100 |
| After guard: legacy approval rejected | `unpaid` | 0 | 0 |
| After guard: completed-session manual settlement | `paid` | 100 | 100 |

The guard also rejects a direct legacy `complete_booking_payment` call before session completion. PostgreSQL rolls back the entire rejected transaction. It checks the verified function definitions before installation and only affects a `completed` manual-transfer payment row whose amount reaches the booking total while the booking is `pending`, `upcoming`, or `in_progress`. It does not treat receipt evidence as verified money and does not change existing rows. The fixture was run **3/3** times and rolled back its entire transaction each time; no production data or schema was touched.

An additional synthetic probe recorded a 20 manual-transfer collection on a completed booking and tried to collect the remaining 80 in cash. The canonical collector rejected it with `PAYMENT_REQUIRES_RECONCILIATION`, leaving the noncash shift total at 20. The current `payments` table has one row per booking and a single method; its payout custody path is method-based. Simply allowing the cash call or relabeling the aggregate payment would misstate custody and reconciliation. This is a critical release blocker, not solved by this guard.

Local checks on this branch: the rollback-only exact-schema fixture passed 3/3 consecutive runs; `node --check` and `git diff --check` passed; `flutter analyze --no-pub --no-fatal-infos` reported no issues; `flutter test --no-pub` passed 627 tests with one skipped. An initial analyzer run before `flutter pub get` lacked dependencies and is not counted as code validation. The generated plugin files touched by dependency setup had no content diff and were restored; the only intended changes are the migration, fixture and documentation.

## Dependencies before release

- Implement an explicit verified-deposit amount and evidence/reference authorization flow. A submitted transfer proof alone is not verification. Use a durable operation ID, actor, shift, booking, transfer reference, and server-calculated deposit policy.
- Introduce a collection ledger capable of multiple verified methods per bill. Reconcile each collection to payment, shift, commission and custody/payout records. A final bill must include session extensions and canteen charges without counting a deposit twice. Session completion must remain separate from payment completion.
- Implement authorized, idempotent, amount-limited reversal entries and owner-configurable cancellation/refund policy. Do not delete payment rows or flip status as a substitute.
- Update Dashboard and Mobile approval/checkout clients and test older tabs/builds. This guard makes existing pre-session manual approvals fail closed, so it **must not ship alone**. Stage backend and clients together after a restorable backup and rollback rehearsal; obtain specific production-change approval.
- Test authenticated restricted users in a real Dashboard browser, mixed-method concurrency, shift close, refunds, legacy clients, and the full accounting invariants. None are claimed by this PR.

Reproduce locally only with `PLAYSPOT_EXACT_SCHEMA_TEST=1`, `PLAYSPOT_ISOLATED_DB_URL` pointing to localhost, and the disposable guard token. Run `node supabase/tests/financial_contract/pre_session_manual_transfer_guard_exact_schema.cjs`; the script applies the migration inside a transaction and rolls back.
