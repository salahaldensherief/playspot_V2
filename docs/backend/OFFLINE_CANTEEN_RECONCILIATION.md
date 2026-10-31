# Offline item orders on fixed sessions

Review source only; no hosted SQL has been applied. Load
`active_super_admin_boundary.sql`, `partial_cash_collection.sql`,
`cashier_writer_permits.sql`, `cashier_writer_availability.sql`, `offline_canteen_reconciliation.sql`, then
`offline_cash_reconciliation.sql`. The latter now dispatches `collectCash` and
`addItems`. The additional fixed reserve/start/close source dependencies are
documented in `OFFLINE_FIXED_SESSION_RECONCILIATION.md`. Real UI enablement still
requires the complete bootstrap, reconciliation and deployment workflow.

The order envelope contains the original requested `payload.items`, plus
`quoted_items` with cached integer minor-unit prices and `quoted_total_minor`
captured atomically with the local booking/outbox. A retry reuses that original
quote even if the cache subsequently changes. Existing experimental operations
without quotes are retained and require review; they are not rewritten on device.

The server rechecks active Auth/profile, approved venue and the exact
`sessions_control` permission (separate from billing permission), then locks the
writer, booking, exact own open shift, payment aggregate and requested products.
Products are locked in UUID order before any stock mutation. Quantities must be
JSON integers 1–100, with 1–50 lines; duplicate lines share an aggregate stock check.
Every product must be in the same venue, active and available, with a finite
nonnegative cent-precision canonical price matching the saved quote. Tracked stock
must cover all requested units; untracked stock is preserved. Missing stock policy
fails closed on both device and server.

The parent order is inserted before detail rows under immediate foreign keys.
Both order lines and booking request lines retain canonical names/prices. Adding
debt updates addons and payment status; it never inserts a payment or cash ledger
row. Existing collected cash must agree with its ledger. The acknowledgement
reports order total, canonical booking total, paid and due amounts.

Read-only hosted catalog inspection confirmed that every booking update executes
`fn_validate_and_clamp_booking_price`, which can reprice a fixed session using the
current room tariff. After updating the booking, the handler checks the actual
returned total against the local quote. Price drift, stock shortage or a late
detail failure rolls back header/lines/inventory/booking together, then retains a
conflict at the current sequence. No dependent event can skip that conflict.

Verification: 34 native PostgreSQL 17.11 cases passed, including demonstrable
two-connection lock waits for duplicate requests and a competing stock sale.
The fixture uses verified column names, immediate foreign keys, the actual hosted
booking-price trigger captured on 2026-10-01 and the booking status enum. Fixture
seeding temporarily disables only the offline availability trigger, restores it
before each tested operation, and never modifies a hosted database. It does not
reproduce all hosted audit, notifications, RLS, moderation or loyalty triggers.

Run: `PLAYSPOT_NATIVE_PG_PORT=55439 node supabase/tests/offline_canteen_reconciliation.test.mjs`
(set the environment variable using the platform's shell syntax).

Optional `PLAYSPOT_ORDER_CONTRACT_EXPORT` writes the first successfully tested
operation/response pair to an explicitly selected UTF-8 JSON file. The cash fixture
has equivalent `PLAYSPOT_CASH_CONTRACT_EXPORT`. These synthetic responses feed the
dashboard's offline receipt contract tests; no hosted credentials/data are exported.

This slice supports simple products on active fixed-duration sessions with
reconciled cash/no-payment state. It deliberately rejects unsettled open-time
sessions. Combo provenance, mixed tender/refunds, discount/room repricing,
standalone counter sales, canonical device bootstrap, secure shift lifecycle,
conflict review and real cashier UI wiring still need coordinated work. Legacy
canteen overloads are not called or automatically replaced by this source.
