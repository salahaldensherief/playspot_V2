> Review update, 21 October 2026: historical live-state claims below were made by the original proposal author and were NOT independently re-verified against hosted databases in this review. Current review uses repository source and isolated fixtures only. See IMPLEMENTATION_PLAN.md, MTTL_W01_FEASIBILITY.md and HARDWARE_LAB_GUIDE_AR.md for the current findings and mock-only boundary. No hosted schema/Edge Function change or hardware test was performed.

# PlaySpot Bridge — backend architecture contract (PROPOSAL, NOT DEPLOYED)

Date: 2026-10-21. Review target: dev. This is an implementation contract for Codex; it is **not a migration**, a shipped Connector, or proof of compatibility with any vendor.

## 0. Existing verified PlaySpot state
Read-only inspection of production project on 2026-10-21:
- Core business tables include public.lounges, rooms, bookings, booking_holds, pricing_rules, payments and shifts.
- Existing session commands include start_booking_session, extend_booking_session, complete_booking_session and cashier-specific RPCs.
- Database exclusion constraint on bookings enforces room_id + overlapping cashier_capacity_period for non-cancelled/non-rejected rows.
- Offline cashier coordination exists under private.cashier_writer_authorities and private.cashier_operation_receipts.
- rooms.control_type permits manual, wifi_relay and serial_relay; all 60 currently recorded rooms had control_type=manual.
- No dedicated integration provider/installation/room mapping/command queue/event inbox tables were found among public/private business tables.
- 7 Edge Functions were listed; no vendor Bridge connector found.

**Important:** Existing cashier offline writer authority is NOT vendor bridge authority. Do not reuse its permit as a general-purpose vendor credential. The exclusion constraint prevents overlap *inside PlaySpot*, not overlap in an external POS that has never received the booking.

## 1. Product contract
PlaySpot supports:
- Native OS: lounges not using another system.
- API provider adapter: official cloud or reachable vendor API.
- On-prem Connector/Agent: outbound authenticated HTTPS to PlaySpot and a vendor-supported local interface.
- Hybrid: API owns bookings while local Agent handles explicitly supported session operations.
- Assessment/manual confirmation: read-only or closed vendors, never promise instant booking.

Per lounge AND per operation, record an explicit authority owner:
- Availability owner.
- Reservation owner (must atomically hold or reserve future capacity).
- Session owner.
- Price owner.
- Payment/settlement owner.
Do not infer permission from questionnaire answers.

## 2. Proposed isolated data model
Put private operational objects under a non-exposed schema (e.g. private). Create a **reviewed, new migration using Supabase CLI** in this repository only after Codex confirms live state and compatibility. Example entities (names provisional):

1. integration_providers: vendor identifier, connector implementation/version, supported API/local versions, published capability metadata, approval state.
2. lounge_integrations: lounge FK, provider FK, mode [api,local,hybrid], state [draft,pending_review,paired,read_verified,booking_pilot,sessions_pilot,active,suspended,revoked], owner consent record, authority matrix, schema version, last_healthy_at; no plaintext secrets.
3. connector_installations: installation ID, lounge FK, paired_at, token/key fingerprint, last_seen_at, expires_at, revoked_at, min supported agent version; never Windows passwords.
4. external_resource_mappings: integration FK, room FK, external_resource_id string, external_station_type, verified_at, mapping_revision; unique (integration_id, external_resource_id) and (integration_id, room_id). Validate same lounge for every mapping.
5. integration_capabilities: integration FK, operation enum, read/write permission, source verification date, status [unknown,declared,tested,approved,disabled], vendor constraints.
6. integration_commands: operation_id UUID (immutable idempotency key), integration FK, resource and booking references, operation type, payload contract version, requested_by, expected version, status [queued,sent,acknowledged,confirmed,rejected,unknown,compensated], attempt_count, next_attempt_at, deadlines, sanitized error, created/updated timestamps.
7. integration_event_inbox: vendor event ID scoped to integration, monotonic sequence/cursor if supported, dedupe key unique, received_at, processed_at, sanitized payload, state.
8. integration_sync_cursors / reconciliation_runs: per integration resource state checkpoint, vendor time, observed time, drift, outcome and human review reason.
9. integration_audit_log: immutable actor/lounges/action/status/timestamps without secrets or customer PII.

For security, default all tables to no direct anon/authenticated table access. Use narrowly scoped RPC or Edge Function boundary with explicit caller, lounge, vendor and operation capability checks. RLS and grants should be deliberate; do not grant service_role to a PC or Flutter client. Prefer private schema + restricted service components. Validate uniqueness, foreign keys, resource/lounges tenant isolation, status transitions, credential revocation and idempotency at database level. Never create SECURITY DEFINER without explicit search_path and least-privilege EXECUTE.

## 3. Vendor adapter contract v1
An adapter is an implementation for one vendor and supported versions, NOT a universal protocol:
- discoverCapabilities() -> capability result with evidence/version/expiry.
- listResources() -> stable vendor resource IDs + availability support.
- readAvailability(resource, interval) -> AVAILABLE / OCCUPIED / UNKNOWN + vendor timestamp and freshness.
- reserveFutureSlot(operationId, resource, interval) -> CONFIRMED with externalReservationId, REJECTED, or UNKNOWN. Mandatory atomic capacity allocation for instant confirmation.
- readReservation(operationId or externalReservationId) -> status to resolve unknown outcomes.
- cancelReservation(operationId, externalReservationId) -> confirmed or unknown.
- startSession / extendSession / endSession -> opt-in per-capability, with externalSessionId and idempotency if vendor supports it.
- readSession(externalSessionId) -> status for reconciliation.
- readChanges(cursor) OR verifyWebhookSignature(event) -> event sync support.
If an operation cannot be supported, return UNSUPPORTED; never fake success or silently emulate with an unsafe write.

Use canonical server-owned room IDs mapped to per-vendor stable IDs. Vendor device number can differ between branches; scope by integration and lounge.

Canonical status enum in API: confirmed, rejected, pending, unknown, unsupported. Unknown is NOT rejected and must not be blindly retried.

## 4. Booking protocol (hardest invariant)
1. Validate actor, lounge, room mapping, vendor health, pricing policy and operation permission.
2. Create idempotent operation with unique operation_id and correlation_id. Keep booking PENDING; do not tell customer confirmed.
3. Ask vendor to atomically reserve capacity with matching time zone/UTC conversion. Guard against replay and ambiguous outcomes.
4. If vendor CONFIRMED, use the existing authoritative PlaySpot booking/hold/checkout logic, subject to its constraints. Do not insert arbitrary raw bookings or bypass SQL triggers.
5. If PlaySpot finalization fails after vendor reserved, run a documented compensation (cancel external reservation); if cancel ambiguous, mark NEEDS_RECONCILIATION and block that slot.
6. Mark confirmed to client only once BOTH sides are committed and linked. If vendor cannot atomically reserve future capacity, offer manually confirmed booking or allocated separate inventory, not "instant" checkout.
7. On timeout or dropped reply: query vendor by operation_id/externalReservationId before retry; NEVER send a second charge, reservation or session start without de-duplication or explicit human review.
8. Customer payments: avoid capturing irreversible funds before reservation integrity is established; coordinate payment authorization/capture/refund policy with existing pricing and payments RPCs.
9. Capture event origin and signed owner of the mutation; prevent event echoes A->B->A.
10. All intervals use well-defined UTC/tz conversion and half-open ranges. Support cross-midnight sessions and DST where relevant.

## 5. Agent threat model and lifecycle
- Agent installer must be signed and downloaded via authenticated approved distribution. Windows version/TLS compatibility verified; note Supabase has announced removal of older TLS 1.2 cipher suites starting Nov 10 2026.
- Outbound-only HTTPS (potential optional secure websocket), no inbound exposed lounge port, no RDP, no DB port forwarding.
- One-time expiring pairing challenge issued to an authorized lounge owner/manager and bound to specific lounge, device fingerprint and approved vendor connector. Server rotates short-lived scoped tokens. Permit revocation.
- Never embed Supabase service_role, platform keys, vendor API credentials, customer PII or sensitive logs in installer.
- Secrets are passed/stored through approved secret channel, not questionnaire drafts; encrypted in rest, least-privileged vendor scopes, rotation support.
- Connector executes only allowlisted commands with version/capability/actor/ownership and signed server instruction checks; rejects replay/out-of-order requests.
- Heartbeat + lease/expiry + circuit breaker; when offline/stale, capacity is UNKNOWN (not FREE). Queue does not automatically replay harmful commands after expiry.
- Versioned updates with rollback and operator-visible health/errors, multi-branch isolation and dedicated diagnostics.
- No unsupported hooks, password scraping, arbitrary SQL writes into vendor DB, UI automation that breaks vendor license, or disabling firewall/antivirus.

## 6. Operations and observability
- Command lifecycle: queued -> sent -> confirmed/rejected/unknown. Unknown requires status lookup and/or manual recovery before retry.
- Event inbox with per-vendor signature validation, replay protection, dedupe, order tracking and dead-letter/manual review handling.
- Reconcile after reconnect, webhook gap, schedule, or mismatch: compare source versions + timestamps and apply safe transitions only. Persist immutable audit evidence.
- Keep per-connector metrics: healthy agents, freshness age, booking confirmation latency, pending/unknown commands, double-booking incidents, reconciliation drift, and error rate.
- Define a clearly communicated manual fallback to avoid a closed lounge suddenly disappearing.
- Rate limits, backoff, polling budgets and data retention are connector-specific.

## 7. Activation state machine
draft -> pending_review -> paired -> read_verified -> booking_pilot -> sessions_pilot (if needed) -> active.
Any active step can go to suspended/revoked. No auto-activation on questionnaire result. Only authorized central PlaySpot integration operator + lounge owner consent can enable booking/session operation flags after proven tests.
Manual confirmation remains available where only reads are possible.

## 8. Backward compatibility
Do not modify existing bookable room behavior, notification/loyalty/shift triggers or cashier writer authority without an explicit compatibility migration and test. Add a separate integration layer, feature-flag OFF by default, shadow/read-only pilot first. Dashboard and Mobile must continue working when there are zero lounge_integrations. Payment/pricing semantics remain authoritative in current RPCs.

## 9. Acceptance test matrix before deploy
- Two concurrent bookings for same external resource: at most one confirmed across BOTH systems.
- Duplicate command/event with same ID: one effect, stable receipt.
- Lost response after remote success: reconcile, do not repeat reservation/charge/session start.
- Agent offline / vendor 500 / 429 / timeout / callback out-of-order: fail closed and restore safely.
- Unauthorized cross-lounge user cannot read vendor credentials, map devices, pair an agent, or execute commands.
- Stale snapshot cannot be shown as guaranteed free.
- Revoked installation cannot reconnect, replay queued commands or trigger sessions.
- Incompatible vendor cannot be marked active from UI answers alone.
- Test UTC, cross-midnight bookings and lounge time zones.
- Price and payment cannot be rewritten by external payload or untrusted agent.
- Disable integration feature flag: Native PlaySpot booking works as before.

## 10. Rollout for Codex
A. Review this contract and questionnaire with actual vendor API docs and tech feasibility.
B. Add schema in **mobile repo only** using CLI-created migration, reviewed RLS/grants and migration tests in isolated staging, not direct production.
C. Build adapter plugin interface, vendor-specific pilot and optional local agent with signed distribution.
D. Wire dashboard questionnaire + localized guidance to server-side draft/review state; no secret collection in form.
E. Add command and health UI, operations approve/suspend/revoke and audit trails.
F. Pilot one lounge, one vendor. After parallel shadow sync and collision tests, enable feature flag.
G. Merge reviewed PRs to dev, run CI; deploy by change control, not automatically during code review.

### Security issue already verified, separate rollout item
Production Edge Function send-system-announcement (verify_jwt=false) currently authorizes profile labels owner/admin/super_admin to publish to all_users. On dashboard dev, the function uses is_super_admin RPC in authorization.js and has tests. **Review and stage deployment of tested dev function**; do not accidentally deploy legacy prod source. No security fix was deployed by this Bridge planning work.

### Existing demo-vs-prod financial parity to review separately
Demo has private.payment_funds_custody and private.payout_settlement_entries plus related RPCs that were absent in production when inspected. Do not blindly copy demo migrations; independently review funds ownership rules and production data shape.