# Local PostgreSQL verification

The database factory uses PGlite by default. To exercise native PostgreSQL,
install the pinned packages in `runtime` and start a **synthetic** PostgreSQL
cluster on `127.0.0.1:55439` with the local role `playspot_fixture`.
Set `PLAYSPOT_NATIVE_PG_PORT=55439`, then run each `*.test.mjs` with Node.
The adapter accepts no URL or production connection string. Each test creates
its own randomly named database and drops only that database on successful
cleanup. Fixture roles are cluster-wide: use a disposable local cluster.

`wallet_concurrency.test.mjs` requires this native mode. It uses two independent
connections, leaves the first operation uncommitted, and confirms the second
connection is waiting on a PostgreSQL lock before committing the first.
It verifies payment replay, competing bookings sharing a wallet, cash topup
replay, refund replay, and a shift closing ahead of cash collection.

Verification on Windows with PostgreSQL 17.11: five concurrency scenarios passed.
The ordinary suites passed 60 wallet/session, 30 lounge review, 10 draft bootstrap,
17 profile security, and 13 onboarding resource cases. These fixtures contain
minimal synthetic schemas. PostGIS calls are stubbed; live triggers, Supabase
Auth integration, deployment sequencing and the full production schema are not
proven by these results. No production database was mutated.

The two onboarding corrections require coordinated client deployment: resource
payloads need stable IDs, and setup becomes complete only after the lounge review
submission is accepted. They do not approve or open the lounge. Do not deploy the
SQL blindly or expose the new client against a server lacking these RPCs.

Rejection now restores setup access for the selected owner branch, exposes an
owner-only saved draft and review reason, and preserves prior review revisions.
Omitted resources remain stored but inactive. Resources with future or active
bookings cannot be silently removed from the draft. The draft read returns
GeoJSON and excludes explicitly inactive resources; PostGIS remains stubbed in
the fixture, though the live function signature was checked read-only.
