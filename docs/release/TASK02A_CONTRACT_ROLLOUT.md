# Task 02A contract rollout review (21 October 2026)

This is a release candidate plan, not authorization to apply a migration. Production project `tgpdexoitemmpruepgyt` was inspected read-only. The implementation branches target `dev`; no hosted writes, deployment, notification, or money movement were made.

## Pinned production differences

| Contract | Production observation | Candidate source |
|---|---|---|
| `start_booking_session(uuid)` | Definition MD5 `3d643a0528167b035f693a63fa8a7328`; denies unpaid fixed cash | `20261016211005_cash_session_start_before_collection.sql` (also updates `create_manual_booking_admin`) |
| `get_payment_funds_review(integer,integer)` and `record_payment_funds_custody(uuid,text,text)` | Both absent; custody tables/view/helpers absent | Coherent dependency set in `20261011065428_payout_cash_commission_settlement.sql` |
| `approve_booking_extension(uuid,numeric,text)` | Definition MD5 `f69eb1acd4d3a384a44a9bbf4203c117`; infers collection | `20261021120000_extension_approval_is_not_collection.sql` |
| `extend_booking_session(uuid,integer,numeric)` | Definition MD5 `4a640b9b4ded5f64e07af5ac9e8d1ac0`; infers collection | Same candidate migration |
| `create_my_booking_checkout(uuid,jsonb,jsonb,text,text,text,text)` | Definition MD5 `b60ae8cb33caced154fcb3c037c9040d`; no durable operation receipt | Additive `20261021121000_booking_checkout_operation_receipts.sql` |

Production migration ledger has none of the listed candidate versions. Demo has both custody RPCs with their expected signatures; demo state is not evidence that historical production money is classified. Production currently grants the existing RPCs to `authenticated`, `service_role`, and `supabase_auth_admin`. The candidate checkout v2 grants only `authenticated`; private receipts have no client table access.

## Preconditions and staging gate

1. Export schema only and a separately controlled backup from the exact production revision. Compare table columns, types, constraints, triggers, grants, RLS, and the full `pg_get_functiondef` of every replaced RPC with pinned hashes. Halt on drift. Never replay the migration directory wholesale.
2. Rehearse the smallest coherent dependency closure in a disposable full-schema staging database with synthetic users. Cash start migration contains two function replacements. Custody migration adds two private tables, a private view, helpers, guards, and multiple payout RPC replacements; applying only its two public RPCs is invalid. Inventory existing payouts, unidentified custody, active shifts, partial payments, and current client builds before choosing exact deployment SQL.
3. Run the role/tenant and concurrent fixture matrix, then a composed 20:00 scenario. A reduced native PostgreSQL fixture passed 19 cash-start, 17 custody, 8 extension, 48 cash collection, and 27 checkout/pricing cases. This is **not** the required full-schema rehearsal or two-cashier browser acceptance.
4. Require explicit release approval. Coordinate backend schema and Edge rollout first, then publish the new Mobile client. Old Mobile clients keep the seven-argument checkout RPC; they remain without unknown-outcome recovery until upgraded. Do not revoke that RPC during transition. Dashboard extension callers keep their existing signatures and receive debt semantics after rollout.

## Ordered rollout after separate approval

1. Restrict the announcement Edge Function using the Dashboard `send-system-announcement` artifact, after its mocked FCM role matrix and a staging smoke test. Production v1 still permits profile `owner`/`admin`. This security containment should be requested as an urgent separate approval.
2. Reconcile cash start and manual booking functions against exact production definitions. Apply only a reviewed equivalent of `20261016211005` after checking open shifts, role grants, room state, and trigger parity. Rehearse unpaid/partial/paid cash, transfer, wrong lounge, repeated start; attendance must create no payment rows.
3. Reconcile custody as a coherent financial release. Classify unknown historical transfer custody from independent evidence. Keep payouts blocked while funds holder is unknown. Do not assign holder from payment method. Review the fixed SQL 15% paths against configured offline commission rates and signed commercial terms before settlement.
4. Release extension semantics with a financial cutover checkpoint. Existing paid sessions may become `partial` after approval; existing payment and shift rows remain unchanged. Verify total=230, paid=180, due=50 for the 180+50 case. A separate cashier collection uses the already existing `collect_booking_cash_partial` receipt protocol; its operation ID, immutable amount/booking/shift and locking are mandatory.
5. Add checkout receipts and v2 RPC, then release a client that persists an actor-scoped operation ID before sending. Test commit/lost ACK, restart, same/different payload replay, cross-actor denial and multi-room/voucher/stock atomicity. Keep old RPC for deployed clients; monitor v2 use before eventual retirement.

## Rollback and containment

- Stop new client rollout first. Preserve private checkout and collection receipts, payment rows, shift ledger, payout evidence, and audit logs. Never delete or rewrite them to force the old behavior.
- A function rollback is conditional: old cash-start logic can strand legitimately started unpaid sessions; old extension logic can fabricate collections on the next approval. Keep corrected extension authorization and collection separation until all active sessions/debts are reconciled. If an error appears, disable affected UI actions or restrict execution while retaining read/recovery RPCs, then repair forward.
- After checkout v2 exposure, keep `recover_my_booking_checkout` available even if new submissions are paused. Existing committed receipts must remain queryable after a lost acknowledgment.
- A payout rollback must retain custody evidence and settlement links. Freeze payout transitions, reconcile with bank/venue records, and resume only after totals and holder are proven. No retrospective production financial edit is authorized here.

## Remaining release blockers

Exact full-schema migration rehearsal, deployed client version inventory, real Auth/Storage/Realtime, combined 20:00 operational test, AR/EN browser acceptance, PS-008 external allocation guarantee, and PS-009 device durability acceptance remain open. This plan does not certify launch readiness.
