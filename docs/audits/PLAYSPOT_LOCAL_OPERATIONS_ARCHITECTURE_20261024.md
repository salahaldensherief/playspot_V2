# PlaySpot local operations — architecture decision and threat model (proposal)

Status: **proposed, not implemented**. Source review: 24 October 2026, Mobile `dev` `e50e6865`, Dashboard `dev` `e111196f`. This document is a design gate for any physical PC control. It does not authorize hardware tests, vendor integration, or financial migration.

## Decision boundary

Keep the shared Supabase backend authoritative for customer booking capacity, prices, permissions, final financial ledgers and settlement. Keep the existing Dashboard offline cashier path as a separate, limited capability: it already has an encrypted journal, outbox, server-issued writer authority, heartbeat/release, command receipts and conflict review in `lib/features/offline_cashier/`. Its existence does **not** establish device control or prove multi-cashier recovery under a long partition.

For a future PlaySpot-native Windows deployment, **propose** one branch-local coordinator and a signed, paired agent on each managed PC. The coordinator would accept only typed, versioned operations such as `start_session`, `end_session`, `lock` and `show_notice`; an arbitrary command/shell channel is excluded. The agent reports observed local state and acknowledgments. Cloud booking/session identity and a scoped operating lease would authorize commands. A local acceptance is provisional until the canonical backend confirms it; a provisional event cannot create a server receipt or assert that cash was collected.

This is a conditional choice, not a commitment to a particular framework. A .NET Windows service is a reasonable candidate for Windows integration, but a prototype must compare supported Windows APIs, installer/update behavior, service isolation, cryptographic libraries and testability with alternatives. The architecture must work without a vendor bridge; third-party coexistence stays human-confirmed until a documented, authorized API passes a separate integration review.

| Option | Benefit | Limitation / decision |
| --- | --- | --- |
| Cloud-only Dashboard | Uses current deployment and server authorization | Cannot reliably observe or lock an offline PC; remains the booking/cashier-only mode |
| Agent on every PC talking to cloud | Fewer local components | Internet loss strands local control and invites inconsistent ordering; reject as the only control plane |
| Branch coordinator + per-PC agent | Local LAN continuity, centralized device identity and command ordering | New trusted component, updates and failure recovery; investigate behind a lab prototype before adoption |
| PanCafe/vendor adapter | Keeps an incumbent workflow where a supported API exists | No verified PanCafe API or PlaySpot authorization; do not infer device state from a PlaySpot booking |

## Authority and communication

1. Cloud issues a short-lived, lounge/branch/shift/writer-scoped permit after verifying staff role, permission and current canonical state. A revocation or expiry ends new local mutations. Reconnection must revalidate rather than silently extend a lease.
2. The local coordinator identifies each agent by a unique enrolled identity bound to one physical station. Pairing requires an authorized cashier/owner action and an out-of-band device confirmation. Store private keys in OS protected storage; never put a reusable server secret in the Flutter client.
3. Coordinator and agent mutually authenticate on the LAN and use encrypted transport. Each typed command has a server/permit identity, target station, command UUID, monotonically ordered sequence or equivalent epoch, expiry and expected prior state. Agents persist the last accepted epoch/sequence and command result before acknowledging.
4. An ACK means the agent accepted or rejected a command; a separately reported observation establishes the physical lock/session state. Neither is a financial receipt. The Dashboard must show `requested`, `accepted`, `observed`, `unknown` and `failed` distinctly when relevant.
5. Heartbeats carry agent version, station identity, clock/connection health and observed state. Missing heartbeats mean **unknown/stale**, never available. Cloud and local clocks are inputs for health checks, while authoritative session billing uses server start/end timestamps.
6. The coordinator journals permitted actions durably with actor, shift, device, permit, sequence, result and sync status. Cloud ingestion is idempotent by stable operation ID and rejects old epochs, wrong venue, revoked permits and impossible transitions. Conflicts are reviewed, not auto-converted into payments or completed sessions.
7. Only one active writer generation controls a lounge/branch during a network partition. The existing cashier writer lease may inform this design, but the two systems cannot share an authority merely by name: their grant, expiry, takeover and replay rules require explicit cross-stack tests.

## Threat model and required tests

| Failure or attack | Required control | Evidence gate before pilot |
| --- | --- | --- |
| Spoofed agent or cashier | Device certificate/identity, server-scoped staff permit, per-command authorization | Wrong device, venue, role and revoked user rejected |
| Replayed, reordered or duplicated command | Stable UUID, epoch/sequence, expiry, persistent result cache | Duplicate start/stop after crash and lost ACK returns same result without a second side effect |
| Split brain after LAN/Internet partition | Single writer generation, fencing token, bounded lease; freeze unsafe mutations if authority is uncertain | Two coordinators/cashiers race; old writer cannot commit after takeover |
| Clock tampering | Server timestamps for charges; bounded clock drift for command expiry; monotonic local elapsed only for display | Clock jumps forward/backward across restart do not create a false charge |
| Coordinator or agent crash | Durable write-before-ACK journal, state query on restart, explicit unknown state | Crash at each send/ACK/persist boundary recovers without phantom completion |
| Corrupt journal or stolen PC | Encrypted, authenticated storage; backup/recovery process; quarantine corrupted state | Corruption fails closed and can be reconciled without inventing receipts |
| Compromised update | Signed packages, staged rollout, version compatibility, rollback | Old/new agent combinations and rollback preserve command semantics |
| Offline cash and device session divergence | Separate local operation record from canonical charge/collection; conflict queue | Long outage, partial payment and shift close yield auditable due/collected balances |
| Unauthorized remote execution | No arbitrary command endpoint; allowlisted typed actions and limited service privilege | Protocol fuzzing cannot invoke shell or alter unrelated files |

## First implementation milestones and acceptance

1. **Architecture review:** map current offline cashier permit/RPC contracts, Windows station lifecycle and user-visible lock behavior. Agree the branch ownership/lease invariant and a recovery runbook. No device code yet.
2. **Disposable protocol simulator:** implement coordinator/agent state machines without actual locking or financial writes. Prove the table above with two stations, two cashiers, duplicate messages, restarts and partitions. Keep it outside production routes.
3. **Lab-only Windows prototype:** pair/revoke, typed commands, observability, update rollback and supported OS lock mechanism on test PCs. Explicit authorization is required before real hardware control.
4. **Isolated backend integration:** replay journals into a disposable exact-schema Supabase clone and reconcile bookings, session timestamps, shifts, canteen, due and collected ledgers. A green unit test alone does not satisfy this gate.
5. **Staged pilot and rollback:** begin with one branch and a small number of PCs, maintain a manual cashier fallback and an operator-visible unknown state. Define disable/revoke and data export before any rollout.

For the existing product, the immediate safe path is to validate cashier close and financial ledgers, then run the offline two-cashier pilot. Physical device control remains **unimplemented and blocked at this architecture/security gate**.
