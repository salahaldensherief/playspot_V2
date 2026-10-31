# Founding20 and commercial readiness

Audit date: 21 October 2026 (Africa/Cairo). Scope: Mobile/backend dev `ca455197568f618285b4f52e1b25bfa52c892eb2`; Dashboard dev `a3b9c4bf50fa2b07c6318475a75dbfac2cd5b6c0`.

Evidence levels: source inspection, hosted **read-only catalog** inspection, isolated synthetic PostgreSQL execution, Flutter unit/widget execution. No live business workflow was executed. `VERIFIED` refers only to a named executed check, never whole-product readiness. Task 01 coverage remains **partial**: live Auth/Storage/Realtime workflows, full-schema combined peak-hour execution, operator usability and exhaustive semantic contract verification remain open. See [12](12_TEST_EVIDENCE.md) and [15](15_UNVERIFIED_ASSUMPTIONS_AND_DECISIONS.md).

## Product decision

Preserve two entry plans: Booking (venue keeps existing software) and Native (PlaySpot operates essential workflows). Local/Bridge are capabilities and hardware is optional. Up to20 partners remains the campaign target; activate approximately3–5, then8–10 total, then up to20 only after explicit gates. Combine a geographic cluster for demand learning with a small number of technically different venues. Twenty scattered venues do not establish marketplace liquidity.

Current onboarding/KYC handles venue/resource setup, draft recovery and review; it does not establish configurable commercial plans, versioned entitlements, trial/renewal obligations or willingness to pay. No complete plan/trial contract was found in source/catalog inventory. Referral/marketing modules can be reused but do not measure partner cooperation fully.

## Smallest proposed model — design only, no migration

Use existing lounge/owner identity. Prefer three small private commercial tables plus the existing audit mechanism; do not introduce billing/Stripe/subscription machinery during this audit.

| Proposed object | Minimal fields / rules | Authority |
|---|---|---|
| plan_versions | uuid PK, plan_key text, version integer, features jsonb validated to known boolean/limit keys, created_at timestamptz; unique(plan_key,version); immutable once assigned | Restricted platform commercial administrator |
| partner_terms | uuid PK, lounge_id FK, plan_version_id FK, starts_at/trial_ends_at/ends_at timestamptz with valid ordering, state, commercial terms snapshot/reference, approved_by, supersedes_id; index(lounge_id,state); prevent ambiguous overlapping active terms under transaction | Platform approval; owner can inspect own approved terms |
| branch_feature_overrides | lounge_id FK, feature_key, allowed/limit, effective window, reason, approved_by; unique scoped version; append history via audit rather than silent overwrite | Restricted time-bounded override; never privilege escalation |

Keep actual technical capabilities and owner activation separate, reusing reviewed Bridge assessment/integration records when that work is promoted. Entitlement query must combine plan version, active term, override, technical support, owner activation, health and server authorization. A kill switch denies new risky work; it cannot erase existing bookings/debt/receipts. Add RLS/grants with explicit tenant predicates, default-deny direct client writes, audit material changes and index foreign keys. Avoid sensitive free-form contracts in public/API fields. Define retention/export and revision provenance. Numbers/currencies/pricing remain configurable business hypotheses, not Flutter constants.

Trials around90days, six/twelve-month partnerships and exceptional two-year terms are options to negotiate, not defaults to hardcode. Disclose post-trial commercial terms early. Record measurable co-marketing obligations and review dates. Offer extensions based on completed use/cooperation/support cost and stated willingness to pay; neither free signup nor mandatory downloads proves value.

## Expiry behavior

At expiry, prevent new nonentitled reservations/feature activations according to policy. Preserve existing accepted bookings, running session completion, debt collection, refunds, financial reconciliation, dispute history and authorized export. Do not cut off a cashier with an unpaid active session. Preserve local journal reconciliation and permit-safe drain; expiry is not automatic authority transfer. Test expiry while booking/extension/receipt collection/refund/outbox are in flight.

## Partner onboarding checklist and evidence

Record Native vs Booking choice, owner approval, branches/resources and physical capacity, actual shift operator, tariffs/hours, internet behavior, existing software/version, explicit capacity authority, confirmation SLA/backup contact, cancellation/grace policy, actual supported payment method and dispute/refund responsibility. Validate role permissions with cashier accounts; schedule rehearsal and support escalation. Install a venue-specific QR only after its destination and request/confirmation promises are verified. Never require consumer downloads as a partner obligation.

Wave gates and operational/co-marketing scorecard are in10/13. Minimal terms/configuration can run alongside Task02/03; production Local/Bridge/hardware are not prerequisites for an otherwise safe Booking-only venue.
