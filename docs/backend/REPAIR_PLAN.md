# Backend repair and client integration plan

Source of truth: playspot_V2/supabase/migrations. Dashboard does not apply migrations.
Branch: fix/backend-financial-contracts, based on backend/playspot-core-v2 at 87201c8.
Seven earlier phases are an implementation inventory, not accepted release evidence.
No existing migration is rewritten. New corrections follow all prior dependencies.

1. P0 financial integrity: repair wallet ownership, trusted collection, authoritative
   payment totals, atomic ledger/shift/payment recording, replay validation and bounded
   reversal. Audit package/canteen payment routes and direct write grants next.
2. P0 operational core: end/start/extend authorization and open-shift locking; remove
   implicit payment on session close; actual ledger amounts; no free billing max cap.
3. P0 rooms: atomic room/activity configuration, explicit override, tenant boundaries,
   unavailable/maintenance preservation, whitelist and existing client transition.
4. Onboarding/KYC: authenticated lounge-scoped durable drafts, complete data and
   protected documents, atomic versioned submission, exact pending-version decisions,
   rejection reason and resubmission. Approval does not open online bookings.
5. Future requests: owner policies, unpaid/unconfirmed capacity semantics, destination
   confidentiality without shift, confirmation hold/checkout and staff follow-up worker.
6. Waitlist/smart rebook: exact desired time/resource intent, deduplication, fair claim
   hold, real notification worker/retries/preferences, re-quote and timezone handling.
7. Activities/resources: shared booking/availability/shift engine and gradual migration.
8. Commercial: membership/hour ledgers and reversals, pricing rule precedence/snapshots,
   deposits/no-shows, owner growth and revenue definitions, consented CRM worker,
   inventory-backed canteen combos, group capacity/privacy, cash versus play hours,
   promotion eligibility/budgets, event quotes/resources/deposits, audit/loss prevention,
   configurable loyalty/referrals and safe tournament growth.
9. Optional offline: single enrolled writer, expiring online presence gate enforced by
   hold/checkout, encrypted Hive outbox, idempotent reconciliation; LAN is future optional.
10. PlaySpot Pass remains disabled pending approved economics and settlement terms.

Each slice needs adversarial auth/tenant/capability cases, open-shift lifecycle tests,
rollback and same-ID retries, genuine multi-connection concurrency tests and deployed
contract checks. Publish code and client contracts separately from applying SQL.

Current tested slices are wallet integrity, safe cash collection/full wallet reversal, and session closure with ledger-derived amounts and uncapped elapsed billing. The combined isolated suite passes 60 sequential checks; production-schema and multi-connection verification remain outstanding.
The remaining phases above are not implemented by this correction. The Flutter work
already exists in separate handoff branches; this backend phase does not modify it.
