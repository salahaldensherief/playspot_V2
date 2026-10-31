# Canteen reconciliation release boundary

Read-only hosted catalog inspection on 2026-10-01 found one deployed
`place_canteen_order(uuid,jsonb,text)` overload. It validates booking ownership or
`private.can_operate_playspot_lounge`, orders stock updates by product ID, checks
active/available products in the booking's venue, and updates booking addons.
This is different from the unshipped commercial source; do not describe the
source defects below as confirmed defects in that deployed function.

The hosted schema has no combo tables or combo line columns. The repository's
20260929150000 combo source and 20260930200000 commercial source therefore cannot
be substituted for the deployed function without coordinated schema validation.

## Blocking source findings

- The six-argument commercial overload permits an unauthenticated caller when
  `p_user_id` is supplied, lacks venue-operation authorization, and looks up extras
  and combos without consistently binding them to the chosen venue.
- That overload clamps invalid quantities to one, can select another cashier's
  shift, and drops combo parent/component provenance from order lines.
- The four-argument combo implementation accepts `p_idempotency_key` but never
  uses it. Retrying an operation can charge or decrement inventory again.
- The combo implementation inserts child lines before their master order exists.
  Compatibility depends on actual foreign-key deferrability; it is not established
  by catalog-only tests. Components also require tenant and availability checks.
- Neither draft is a verified offline reconciliation endpoint. A supplied amount
  or locally cached stock is never authoritative at synchronization time.

## Required implementation before connecting the outbox

Use a reviewed canonical operation endpoint with actor/device/permit/shift binding,
durable unique operation receipts and strict per-permit sequencing. Replay must
return the original receipt without repeating stock or money changes; changing a
payload under an existing ID must fail. Validate all lines and lock stock in stable
product-ID order, including combo components. Persist the parent before children,
retain combo provenance, and update booking totals atomically. No counter order may
silently invent a cash payment. Partial collection needs an explicit ledger entry
and cannot use the existing full-booking-payment helper unchanged.

Native PostgreSQL tests must cover cross-venue/disabled caller rejection, empty or
fractional quantities, inactive/unavailable products, combo components, stock
rollback, reversed product lock order, concurrent last-item purchases, response-loss
replay, payload conflict, closed/wrong shift and partial-payment aggregation.
Only after those pass should the UI use the real reconciliation RPC.

This inspection performed no hosted writes, function calls with business effects,
SQL deployment, migration or dev/main merge.
