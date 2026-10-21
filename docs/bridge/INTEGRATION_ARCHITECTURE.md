# PlaySpot Bridge — architecture contract (DESIGN DRAFT)

**Status:** planning and review only. This branch contains no deployed connector, external API credentials, local Windows binary, booking hooks, or enabled operational commands. `docs/bridge/proposed_schema.sql` is **NOT AN APPLIED MIGRATION**; it is a design candidate for Codex/security review. `dev` and production are untouched.

## Goal and supported paths

We support three *possible* paths, not an arbitrary software bypass:

1. **Cloud API:** authorized backend worker -> provider HTTPS API with documented booking/session scopes.
2. **Local Agent:** signed Windows service installed by lounge owner -> outbound TLS to PlaySpot; agent calls officially supported local API or SDK. No public port or direct exposure of Windows DB.
3. **Hybrid:** API owns one capability (e.g., future reservations), local agent owns another (e.g., session hardware control), with a single authoritative scheduler. Hybrid must not be two competing booking writers.

An unsupported/closed legacy system gets **read-only or manual confirmation** where legally and operationally feasible. Never assume access simply because a Windows program runs on the PC.

## Boundaries

```text
Onboarding questionnaire (advisory)
    -> assessment API [NOT IMPLEMENTED]
    -> technical approval + vendor certification [NOT IMPLEMENTED]
    -> integrations and resource mappings [SCHEMA PROPOSAL ONLY]

PlaySpot booking request
    -> canonical server-authoritative booking/hold/price path (EXISTING)
    -> Bridge reservation command [NOT IMPLEMENTED]
    -> provider/agent reserves capacity with its own concurrency protection
    -> provider receipt + canonical final confirmation [NOT IMPLEMENTED]

External legacy changes
    -> signed webhook or authenticated agent polling [NOT IMPLEMENTED]
    -> inbox dedupe by (integration_id, external_event_id)
    -> state reconciliation, not direct UI data writes [NOT IMPLEMENTED]
```

**Do not change existing public booking, shift, payment, or session RPCs until a new explicit contract has passed review and integration tests.** Reuse their authorization/business invariants. A remote API response is not proof of a DB-atomic booking unless it has successfully reserved the exact slot.

## Adapter contract (target; NOT implemented)

```typescript
interface LoungeSystemAdapter {
  discoverCapabilities(): Promise<CapabilityReport>;
  listResources(): Promise<ExternalResource[]>;
  getAvailability(roomKey: string, fromUtc: string, toUtc: string): Promise<AvailabilitySnapshot>;
  reserveSlot(command: {
    commandId: string; // unique durable, idempotent
    externalRoomKey: string;
    fromUtc: string;
    toUtc: string;
    holdExpiresAtUtc?: string;
  }): Promise<ReservationReceipt>; // ack, rejected, unknown
  cancelSlot(commandId: string, externalReservationId: string): Promise<Receipt>;
  getSession(externalSessionId: string): Promise<SessionSnapshot>;
  startSession?(commandId: string, reservationId: string): Promise<Receipt>;
  extendSession?(commandId: string, sessionId: string, minutes: number): Promise<Receipt>;
  endSession?(commandId: string, sessionId: string): Promise<Receipt>;
}
```

`discoverCapabilities` does **not** authorize commands. A staff/operator role must be authorized to act on the lounge and on the command. Capability flags are activated only after vendor tests, owner consent, onboarding approval and server-side gate.

## Command state machine

```text
queued -> leased -> acknowledged
               -> rejected
               -> ambiguous -> requires_review
               -> queued (retry ONLY when provider guarantees idempotency)
queued -> cancelled (before processing)
```

- `idempotency_key` is unique per integration. Retry with **same** key only, and only where the vendor guarantees deduplication.
- **Ambiguous execution** (timeout after remote command) is **not** success or safe automatic retry; query provider status or require manual review.
- Capture request/response timestamps, redacted payload, external receipt ID, attempt count, and actor; never log secrets, phone numbers, raw PII.
- A rebooted agent cannot replay `startSession` unless it proves previous command not applied.
- Handle a 429/5xx as retryable only if the provider contract supports it; backoff/jitter + bounded attempts.
- User-facing messages must say "pending/awaiting confirmation" until authoritative receipt.

## Canonical resource mapping

For every `integration_id`:
- `room_id` is a PlaySpot `public.rooms.id`.
- `external_resource_id` is the provider's station/room ID (opaque text, not necessarily numeric).
- Both must refer to the same lounge; enforce this in DB and server code.
- Map changes require lounge authorization and audit trail. A previously booked external ID cannot be silently reassigned.
- Time zones: provider wall clock -> lounge timezone -> UTC, explicitly handle DST and overnight ranges.

## Pricing and financial authority

Use existing canonical price calculation for PlaySpot checkout unless a reviewed agreement designates the provider's rate as authoritative. Always snapshot the confirmed amount, currency and tax/fees. Disagreeing prices or unavailable rates must stop auto-confirmation; don't overwrite confirmed payment totals from an inbound webhook. Bridge does not implicitly add payout or payment settlement support.

## Local Agent proposal

- Download only signed artifacts from PlaySpot-controlled distribution.
- Pair with a short-lived, one-time token after owner authorization, device fingerprint/attestation, and rate limits.
- Agent uses outbound TLS; no Supabase `service_role`, no Postgres credentials, no RDP password. Use scoped credentials with rotation/revocation.
- HTTPS server channel verifies agent identity and enforces lounge/device binding, command scope, monotonic sequence, expiry, signature, and replay protection.
- Agent adapters are isolated per vendor and use only approved API/SDK facilities; no memory patching or unauthorized reverse engineering.
- Agent must expose clear diagnostics (connection status, vendor health, last successful sync, outdated version) while redacting secrets.
- Download, install, upgrade, uninstall, and recovery guides require *actual signed installer and screenshots* before public release.

## Failure modes

| Failure | Safe behavior |
|---|---|
| Windows PC offline | Mark availability unknown, pause unsafe auto-confirmation |
| Provider API 500 or timeout | Pending/unknown, no blind duplicate command |
| Same slot submitted twice | Provider atomic lock or manual-review gate; never two confirmed bookings |
| Event delivered twice | Inbox unique event ID: apply once |
| Event delivered out of order | Compare source version/time; reconcile before overwriting newer state |
| Booking cancelled in one system | Reconcile cancellation and notify both sides; respect payment/refund policy |
| Agent stolen/reinstalled | Revoke device identity, re-pair with new one-time code |
| API key revoked | Disable connector, hold future auto-confirmation, alert owner |
| Mismatched room mapping | Refuse operation, log incident, require review |

## Staged rollout gates

1. **Discovery:** interview vendors, collect API docs/SDK terms, owner consent.
2. **Assessment persistence:** versioned questionnaire with verified owner scope and privacy/retention controls.
3. **Integration schema:** review and test proposed private SQL on isolated test DB; do not apply direct to production.
4. **Credential provisioning:** vault/secure functions, no browser or Flutter credentials.
5. **Adapter implementation:** vendor-specific cloud/local connector with contract and failure tests.
6. **Manual booking pilot:** one controlled lounge, review each external reservation.
7. **Two-way booking:** only after concurrency, idempotency, disconnect/replay tests.
8. **Session controls:** enable separately per tested capability.
9. **Financial operations:** independent payout/payment approval and audit, not part of basic booking launch.

## Exact tests Codex should demand

- Unauthorized owner/employee/other lounge cannot create/activate integration.
- `anon`/`authenticated` cannot query proposed `private` tables directly.
- Wrong lounge/resource pairing raises an error.
- Concurrent same-slot booking requests => no more than one canonical confirmed.
- Two identical commands => single external side effect (or `ambiguous` + review).
- Timeout after external execution => no blind replay.
- Agent offline before/after ack => no phantom confirmed booking.
- Event duplicates/out-of-order => no regressions; reconcile exact state.
- Permissions cannot be forged by client JSON; vendor capabilities are server-verified.
- Local API inaccessible on PC or unsigned binary => no installation/activation.
- Price mismatch does not mutate completed payment.
- Approval/revocation/retention/rollback and incident handling.

## Design questions for Codex

1. Does the current `cashier_writer_authorities` model have a safe reusable authority/lease mechanism, or must remote providers have a separate one? **Do not reuse leases without validating semantics.**
2. Which current booking RPC can support an external *pending confirmation* lifecycle without prematurely committing charges/loyalty?
3. Which partner systems provide true future reservation/write APIs vs just station occupancy?
4. Should a Bridge be separately hosted from Supabase Edge Functions due to long-running Windows polling/retries?
5. Who owns pricing and cash settlement when external POS and PlaySpot disagree?

## Verified vs unverified

**Verified in live production during prior read-only review:** `public.bookings`, `booking_holds`, `rooms`, `private.cashier_writer_authorities`, booking overlap constraint and server RPCs for sessions exist.

**Not verified:** Any real vendor connector or protocol, live Windows agent, vendor-specific permissions/API, production readiness of this design.

**No changes have been made to Supabase production as part of this PR.**
