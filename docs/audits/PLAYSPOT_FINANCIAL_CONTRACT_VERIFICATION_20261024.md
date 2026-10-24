# PlaySpot financial contract verification — 24 October 2026

**Verdict: FAIL for the inspected deployed completion contract; representative-schema runtime verification remains BLOCKED.** This is a read-only catalog/source comparison, not a production mutation or a claim that every financial path fails. Mobile [Draft PR #75](https://github.com/salahaldensherief/playspot_V2/pull/75) must stay Draft. No production customer rows, secrets or financial transactions were read or changed.

## Evidence boundary

- Source: Mobile `dev` `3898b24e`, Draft PR #75 head `b9edcf97`, 105 version-controlled `supabase/migrations/*.sql` files. Their version prefix `20260927000010` is duplicated by two different files.
- Read-only connected `play spot` Postgres 17.6 catalog: `list_migrations` returned 131 entries, including `open_time_sessions` applied under version `20260928224949` and `fix_residual_backend_issues` as `20261011120000`. The source `20261011133001_latest_commit_contract_hardening.sql` is absent from that applied history. The separate `playspot-demo` project has 21 demo-specific migrations, so it cannot stand in for the target contract.
- Disposable, network-disabled `postgres:17.11` container `playspot-schema-replay-task75b`: chronological replay of source migrations passed the first three files and failed at `20260331000004_validate_mobile_booking_price.sql` because `public.bookings` does not exist. Earlier functions were created because PL/pgSQL deferred table resolution. The repository therefore does not contain a self-sufficient baseline for exact replay. The container holds generated schema only, no customer data.
- Earlier PR #75 minimal fixtures and CI are useful unit/contract evidence, **not** a production-equivalent schema proof.

## Inspected effective contract

| Area | Read-only catalog observation | Implication |
| --- | --- | --- |
| `complete_booking_session(uuid,uuid)` | `SECURITY DEFINER`, `search_path=''`, authenticated execute; definition MD5 `b981afd7650dcc530867b69bdd80f0e9`. ACL also names `service_role` and `supabase_auth_admin`. | Effective definition/grants differ from latest version-controlled hardening migration. Review exact privilege boundary before any release. |
| Partial collection on close | Deployed function sums completed `payments.amount`, computes `amount_due`, then sets `payment_status` to **`unpaid` whenever `amount_due > 0`**. The latest source migration instead returns `partial` when a positive amount has been collected. | A partially paid completed session is mislabeled unpaid by the inspected deployed function. This is a concrete static contract defect; it does **not** prove a particular customer row is affected. |
| Collected amount helper | `private.booking_collected_amount` is absent from the inspected catalog, though latest source `complete_booking_session` calls it. `private.require_active_booking_actor` exists. | The source hardening function cannot be treated as already deployed or copied alone into production. Dependencies and migration order need a complete staging replay. |
| Open Time timestamps | Deployed `bookings` has `open_time_started_at`, `open_time_closed_at`, `open_time_billing_minutes`, `open_time_pricing_snapshot`; it lacks `open_time_ended_at`, which the earlier source migration defines. | PR #75's `open_time_closed_at` fallback is necessary for this observed contract; source-file presence does not prove column deployment. |
| Canteen charge | Deployed `place_canteen_order` adds its order total to `bookings.addons_price` and `addons_total`; deployed close uses `addons_total` in the Open Time total. | A committed order appears to enter the final total once along this path. Cancellation/stock/ledger and concurrent order behavior were **not** proven by a representative runtime test. |
| Open Time start | Deployed function locks the room row, rejects an active booking, requires an open shift, snapshots rate/minimum/rounding/max, and records the next reservation buffer. | Source logic supports these guards, but no exact-schema concurrent-start, midnight, max-duration or future-reservation test ran in this pass. |
| RLS and triggers | Relevant `bookings`, `rooms`, `payments`, `canteen_orders`, `canteen_order_items`, `shifts`, and `shift_payments` tables have RLS enabled. Catalog shows numerous booking/payment/shift triggers and distinct read policies. | Presence is not proof of actor-specific behavior. Role-grant and trigger-side-effect tests still require an isolated representative schema. |

The deployed function's `idempotent` branch returns existing final numbers for a repeated close; its correctness under concurrent payments, lost acknowledgments and ledger replay remains untested. There was no write to the connected project.

## Required closure before financial integration

1. Obtain a **schema-only** baseline or an authorized disposable branch whose effective tables, functions, triggers, policies and grants match the inspected project; never include customer data. Reconcile the 131 applied migration history with 105 source files and resolve the duplicate version prefix without rewriting production history.
2. Reproduce the partial-payment classification in isolation, then fix the owning backend contract with an ordered migration and a real payment/shift-ledger regression. Test `0 < collected < total`, `collected = total`, duplicate close, delayed payment and lost ACK.
3. Run Open Time snapshot, rounding, minimum/max, midnight, future reservation, canteen, concurrent start/close, role/RLS and ledger tests against that representative database, using realistic isolated actors and shifts.
4. Re-run Mobile/Dashboard Flutter tests and backend fixtures on final commits; inspect CI and keep PR #75 Draft until the exact-schema results and financial review pass. No production migration or deployment follows automatically from a green test.

The current verdict is **FAIL** because the inspected completion function misclassifies partial collection. End-to-end compatibility is additionally **BLOCKED** by the missing replayable baseline; neither verdict should be softened by the earlier minimal fixtures.
