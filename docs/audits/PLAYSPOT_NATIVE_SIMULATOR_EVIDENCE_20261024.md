# Native operations simulator — 24 October 2026

Status: implemented and locally tested in an isolated branch. This is protocol evidence, not a deployable Windows agent, backend integration, or a physical control pilot.

The inspected architecture alternatives were cloud-only Dashboard, per-PC cloud agent, branch coordinator with per-PC agents, and vendor bridge. The branch coordinator was chosen for deterministic LAN ordering during internet loss, but only as an isolated simulator. Existing offline cashier code stays intact and financial authority remains with the backend. The simulator contains no price, payment, booking-completion or Windows-control operation.

Implementation: Ed25519 permit/device/coordinator messages; one-use hashed enrollment token bound to station, permit and epoch; typed ordered start/end commands; durable operation result before ACK; duplicate/lost-ACK recovery; signed heartbeat, disconnected/unknown state, audit events; JSON persistence; loopback-only HTTP adapter. The agent reports *simulated* observed state. A pending command makes station connectivity unknown until ACK and a fresh heartbeat.

Local checks: Node 24.13.0, `npm run check` PASS, `npm test` PASS (5 tests: enrollment and restart/reconciliation, authorization/replay rejection, ordering/expiry/conflict/stale heartbeat, loopback transport, corrupt store failure). GitHub CI status must be recorded after PR creation. No real devices or production services were touched.

Security gate remains open: issuer is test-only; no backend role/shift verification or revocation; no writer lease or split-brain fencing across coordinators; no TLS/mTLS; no OS-protected key store or encrypted durable journal; no clock-drift bound; no physical observation; no exact-schema cloud reconciliation. Therefore this branch must not be deployed or treated as an approved device-control path.
