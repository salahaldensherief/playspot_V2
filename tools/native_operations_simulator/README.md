# PlaySpot native operations protocol simulator

This is a disposable **local simulation**, not a deployable PC controller. It exercises a branch coordinator and a simulated station agent without Flutter, Supabase, Windows locking, or financial writes. The HTTP adapter binds to `127.0.0.1` on an ephemeral port for tests only; it has no production authentication or TLS layer. Never expose it to a network.

`Coordinator` verifies issuer-signed, short-lived venue/station/shift permits before enrollment and typed commands. Enrollment uses a 256-bit, one-use token and an agent-signed proof. The coordinator signs ordered commands; the agent verifies identity, epoch, sequence, expiry and expected state, then persists the result before returning a signed ACK. A lost ACK can be replayed by operation ID. Signed heartbeats report observed simulated state; missed heartbeats or pending commands render connectivity `unknown`. An ACK is a device-protocol result, **not** a financial receipt, canonical booking close, or proof of physical device control.

Run `npm ci`, `npm run check`, and `npm test` in this directory. Tests use temporary local files and loopback HTTP. No database credentials are needed.

Still required before any lab or production device use: real backend-issued authorization and revocation; single-writer lease/takeover and fencing across coordinators; mTLS/encrypted LAN transport; OS-protected private keys and encrypted journal; safe file locking/directory durability; bounded clock drift; actual observed Windows state; signed updates and rollback; cloud reconciliation against the exact booking/shift schema; conflict and multi-station/two-cashier fault injection. The simulator's permit issuer is generated inside tests and conveys no PlaySpot staff permission.
