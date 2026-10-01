# Device-bound offline cash reconciliation slice

This source depends on `active_super_admin_boundary.sql`,
`partial_cash_collection.sql`, `cashier_writer_permits.sql` and
`cashier_writer_availability.sql`. Load those
review sources before `offline_cash_reconciliation.sql` in the isolated fixture.
The item-order path additionally needs `offline_canteen_reconciliation.sql`;
its separate contract and verification are in `OFFLINE_CANTEEN_RECONCILIATION.md`.
It is not an automatically applied migration or deployed endpoint.

`apply_offline_cashier_operation(p_operation jsonb)` accepts the dashboard envelope:
operation UUID, actor/venue/device/permit/booking/shift UUIDs, positive integer
sequence, timezone-qualified occurrence timestamp, kind and payload. This slice
implements **collectCash, fixed-session addItems, and fixed reserve/start/close**.
The session path requires the additional reviewed sources and schema changes in
`OFFLINE_FIXED_SESSION_RECONCILIATION.md`. Other kinds fail with
`OFFLINE_OPERATION_KIND_NOT_IMPLEMENTED`; they never manufacture an acknowledgement.
The real cashier UI must remain disabled for this incomplete server feature.

The actor must match Auth. Current account, Auth identity, approved venue and
billing eligibility for cash, or session-control eligibility for orders, are rechecked. The writer row is locked and must match the
actor/device. Its immutable permit must belong to that same venue/actor/device and
have originally granted the command's required permission. The event must fall
inside that original permit window and cannot
be more than five minutes ahead of server time. Device UUID matching is a server
ownership check; it is not hardware attestation or a cryptographic event timestamp.
Heartbeat does not extend an existing permit. Renewal preserves original grant
records and venue-wide sequence/conflict boundaries. Historical events may use
their original permit after renewal, with current eligibility still rechecked.
Safe reassignment, old-writer reconciliation and shift lifecycle still need a
coordinated design before full offline release.

Only the next sequence can apply. A successful financial receipt, operation receipt
and sequence advance commit together. Exact retry returns `replayed`; changed JSON
under the same ID fails. Known business failures roll back financial effects before
persisting a conflict receipt. The writer sequence does not advance on conflict.
A replacement operation cannot bypass it, and later dependent operations remain
blocked. Conflict resolution requires a separate reviewed reconciliation workflow
that has not yet been built; no automatic skip/delete is implemented.

Cash events may synchronize after their recorded permit window ended, provided the
recorded event was inside that window and current account/venue/permissions/own open
shift remain valid. A closed shift produces a retained conflict for reconciliation;
the source does not write cash into a closed or another cashier's shift.

## Verification

25 native PostgreSQL 17.11 cash tests passed with this slice's five source dependencies
loaded together into one minimal fixture. They cover forged actor/device/permit,
invalid sequence/shift/time, unsupported operation kinds, sequence gaps, canonical
cash acknowledgements, response-loss retry, payload conflict, banned-account replay,
simultaneous requests actually waiting on the writer lock, financial rollback on a
business conflict, blocked dependents and inaccessible private receipts.

Run with `PLAYSPOT_NATIVE_PG_PORT=55439`:
`node supabase/tests/offline_cash_reconciliation.test.mjs`.
The partial-cash suite independently passes 47 tests. These counts are separate
fixture suites, not evidence of full hosted/UI end-to-end integration. Hosted audit
triggers, production RLS, Auth session revocation, room/pricing/inventory operations,
snapshots, device bootstrap, logout and conflict-review UI remain unverified here.
The separate item-order fixture passes 34 native cases and reproduces the actual
hosted booking-price trigger. The integrated fixed-session fixture passes 53 native
cases, including cash rollback on trigger-driven repricing. No hosted write,
migration or dev/main merge was performed.
