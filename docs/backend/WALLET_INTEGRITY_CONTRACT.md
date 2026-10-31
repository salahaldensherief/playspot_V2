# Wallet integrity repair contract — 2026-10-01

Migration: 20261001090000_wallet_payment_integrity_and_unsafe_credit_containment.sql.
Status: written and locally engine-tested; NOT applied live; NOT UI-integrated.
Dependencies: phase 1 canonical payments and phase 7 wallet tables/functions. Deploy
only after reviewing the actual target definitions and all prior migration state.
Never run the whole directory automatically. Originals and frontend branches preserved.

## Public APIs

- get_or_create_user_wallet(p_user_id uuid default null): own wallet only; a verified
  server super admin can inspect another wallet. Returns user_id/balance/currency/frozen.
- pay_with_wallet(p_booking_id uuid,p_amount numeric,p_idempotency_key text default null):
  key is now mandatory (1–128 characters), stable across retries. Owner only; exact
  two-decimal positive amount equal to server total; open time must already be closed.
  Open lounge shift is locked while payment, shift receipt and wallet ledger commit.
  Returns canonical receipt plus transaction_id, amount_deducted, remaining_balance,
  final_total, amount_due=0, payment_status=paid. Repeat returns same operation receipt;
  altered caller/booking/amount/type fails. UI refreshes server booking after receipt.
- collect_wallet_cash_topup(p_customer_id uuid,p_lounge_id uuid,p_amount numeric,
  p_idempotency_key text): NEW staff-only billing_checkout RPC. Cash explicitly received
  before confirm; target wallet, open lounge shift and receipt recorded atomically.
  Returns success/customer_id/amount_collected/balance/shift_id/transaction_id.
  Same-ID replay verifies operator, customer, lounge, amount and collection type.
  Stored keys are namespaced by operator and operation type to prevent cross-user
  key squatting or collision with internally generated reversal keys.
- refund_to_wallet(p_booking_id uuid,p_amount numeric,p_reason text default cancellation):
  authorized billing operator + open same-lounge shift. Only FULL reversal of a verified
  wallet payment is implemented. No arbitrary cash-to-wallet conversion or partial
  refund. Stable per-booking reversal receipt; same operator/reason/amount replay does
  not credit twice. Preserves operational booking status, marks payment refunded and
  writes the wallet reversal ledger. Original gross shift receipt is retained for audit;
  financial reporting must net wallet reversals, not call that receipt net revenue.
- complete_booking_payment retains its three-argument contract for non-wallet billing.
  app_wallet is rejected: call pay_with_wallet with a stable operation ID instead.
- topup_user_wallet retains its old signature but client execution is revoked. A method
  string or uploaded manual receipt cannot mint balance. Provider-verified settlement
  and staff-reviewed transfer topup contracts remain future work, not automatic cash.

Private payment recording has no client execute grant. It reuses phase 1 payment and
shift recording and preserves its existing 15% commission arithmetic; this repair
neither approves that business rate nor invents a replacement. Currency remains the
existing EGP model; no Gulf currency rollout is claimed.

## Client transition

No current Flutter source calls wallet RPCs (checked in both isolated worktrees).
Do not enable a wallet payment method from the earlier handoff report. Publish this
migration after review, verify deployed grants/contracts, then expose read/pay/cash
collection/full reversal with explicit confirmation and caller permissions. Persist a
new UUID once per intent; retry the same ID after ambiguous timeout. No client financial
write fallback. UI has no service-role key. Approved partial/transfer refunds need a
separate reviewed contract and UI before release.

## Verification and limits

46 wallet/payment checks pass in a 60-check combined suite using PGlite 0.5.8 / PostgreSQL 18.3 WASM, synthetic fixture and exact
migration source. Live target is PostgreSQL 17. Tests cover caller ownership, invalid
amounts including NaN/Infinity/null, wrong lounge, frozen/insufficient wallet,
closed shift, completed-session preservation, failures after payment insert, stable
replay and mismatched payload, cash permissions and bounded/full reversal.

The fixture models minimal production table names/fields and positive receipt checks.
It does not mirror all production triggers, policies or historical data. Auth permission
helpers are fixture stand-ins. Single backend connection does not prove race safety.
Need isolated PG17 full-schema tests and multiple concurrent connections before release.

## Application and recovery

Do not deploy the insecure original wallet endpoints separately. Review the seven phase
migration dependencies plus this correction together. No destructive rollback: restore
reviewed prior function definitions only if they are safe; never drop wallet/ledger tables.
For a problem after rollout, disable client actions and preserve all receipts; use a
forward correction/reconciliation. Existing balances require an origin/ledger audit:
this patch cannot retroactively prove they were funded by a real payment.
