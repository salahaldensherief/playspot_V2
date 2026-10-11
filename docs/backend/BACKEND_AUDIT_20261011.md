# Backend audit and custody settlement — 11 October 2026

These changes are review candidates. No hosted migration or Edge deployment was performed. The separate staff provisioning PR is also required; this branch does not include it.

## Verified contract

Electronic payment methods do not identify who received money. The confirmed business policy permits both platform and lounge receipt for the same method. Cash belongs to the lounge. An eligible payment held by the platform contributes `net_to_lounge`; one held by the lounge contributes `-commission`. Earlier unsettled lounge commissions are carried forward once. A non-positive balance allocates no payments and remains outstanding.

`record_payment_funds_custody(payment_id, funds_holder, evidence_reference)` accepts explicit evidence from an active canonical platform administrator. It appends a private audit event for the exact financial revision. Identical requests replay; contradictory requests for the same revision fail. Changing financial fields invalidates old evidence and requires fresh review. No method-based historical backfill is supplied. Incorrect evidence for an unchanged revision needs an audited correction workflow before rollout; do not change financial amounts merely to bypass the review.

`get_payment_funds_review(limit, offset)` returns paginated unknown custody. The Dashboard presents both recipients without a default and requires an evidence reference. Invalid legacy financial values must be reconciled separately; the client deliberately rejects malformed records.

Payout creation locks eligible booking/payment rows in the collector's order and snapshots every contribution atomically with its payment link. Approval, processing and payment check the snapshot, current ledger and recorded transfer proof. Legacy unsnapshotted payouts cannot progress. Already paid history is preserved. Cancellation releases payment links. Direct table status updates cannot skip reconciliation.

Session completion calculates the bill, then reads actual collected amounts from the payment ledger. A prepaid 60 EGP session repriced to 120 EGP finishes with 60 EGP due; it does not invent a cash receipt. Explicit collection remains separate. Legacy paid flags without ledger evidence fail visibly.

Booking administration uses canonical `bookings.view` permission for each branch, including owner membership and explicit denials. Dashboard RPC failures no longer fall back to a broader table query.

Future online reservations are allowed only after all replayable permits for the current offline writer generation expire. Offline interval validation enforces both permit boundaries. The public status contract adds optional `future_booking_date_from`, the earliest whole local calendar day outside coverage and within lounge policy. Today's physical operating status remains unchanged.

## Audit claims checked against current source and hosted catalog

| Claim | Finding |
| --- | --- |
| All payment net amounts treated as lounge payouts | Confirmed; custody settlement replaces this behavior. |
| Session completion reports recalculated total as already paid | Confirmed; ledger-based completion added. The cited cash INSERT is absent in the latest hosted function. |
| Owner cannot read other branches | Confirmed; permission-scoped branch read added. |
| Future holds depend solely on current heartbeat | Confirmed; permit coverage boundary added. |
| FCM creates GoogleAuth per send | Confirmed; Dashboard Edge handler now reuses GoogleAuth and its own expiry/refresh mechanism. |
| 35 Mobile and 13 Dashboard RPCs absent | Current literal-name inventory: 62 Mobile names present; of 136 Dashboard names only `get_visible_shifts` absent, with an existing pending migration. This does not validate every signature or dynamic call. |
| `award_points` / `advance_loyalty_mission` absent | Both exist in the hosted catalog. |
| Old quote ignores midnight and loyalty vouchers | Current quote delegates to the newer price engine and voucher validator. Older excerpts are stale. |
| Direct manual booking extras are silently discarded | Current manual creation sends extras through its server RPC and propagates failure. |
| Reminder cron runs every five minutes | Hosted active reminder schedule runs every minute. Narrow windows still need delayed/concurrent execution review. |
| Canteen cancellation deletes closed-shift receipts | The cited RPC is absent and no current caller was identified. Current cancellation/refund paths still need complete tracing. |
| Announcement and account deletion Edge flaws | Source fixes already exist; deployed versions are older. Deployment and real Auth integration remain pending. |

## Validation and rollout gates

Native PostgreSQL 17.11: 43 isolated suites passed, including 17 custody/payout cases, 13 collected-balance/collection cases, 6 branch permission cases and 9 offline coverage cases. These use synthetic schemas and exercise actual migrations; they are not a full hosted-stack test. Mobile: 493 tests passed; analyze has 105 existing informational findings, no warnings/errors. Dashboard: 1138 tests passed with 2 existing skips; analyze has 49 informational findings, no warnings/errors. Edge handler tests: 76 passed, including 9 FCM cases. No real Google OAuth/FCM delivery was performed.

Before production: validate the complete migration chain against an isolated copy of the real schema/RLS/triggers; include pending 9/10 October prerequisites; reconcile legacy pending payouts, unknown recipients and invalid balances; verify all real roles through Auth/PostgREST/Realtime/Storage; define and test mixed-recipient installment receipts and evidence correction. Existing booking-level payment summaries cannot represent multiple recipients safely. The new `complete_booking_payment` routes cash through canonical remaining-balance collection and blocks electronic/mixed installments until an individual receipt ledger is available. It also rejects wallet-method recording through this RPC; wallet debit requires its verified flow. Do not treat this branch as release approval.
