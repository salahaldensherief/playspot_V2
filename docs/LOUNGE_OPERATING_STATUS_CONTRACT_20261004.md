# Public lounge operating status — 2026-10-04

## Product rule

When a lounge's connection fails during an open shift, show a temporary technical issue and offer booking by calling the lounge's actual public telephone number. Do not label this situation as a manual closure. A manually closed lounge or a lounge without an open shift remains closed. The customer's own connectivity is not evidence of the lounge's connectivity.

## Deployed contract

`public.get_lounge_operating_status(p_lounge_id uuid)` returns exactly:

```json
{"status":"technical_issue","can_book_online":false,"contact_phone":"01000000000"}
```

The phone above is a synthetic test value, not a production contact. Status values are `open`, `closed`, `technical_issue`, and `unavailable`. An approved, active, manually open lounge reports `technical_issue` only when there is an open shift and its valid writer has explicitly disabled online operation or its heartbeat has expired. Manual closure takes precedence. Inactive venues and unknown identifiers return `unavailable`. No cashier, device, or shift identity is exposed. The public phone is returned only for the technical issue; a blank phone returns null.

The writer heartbeat lease is 90 seconds. A connection loss can therefore take up to lease expiry to become visible. Venues without an initialized writer retain their existing availability behavior; this RPC does not independently monitor an arbitrary venue's Internet router. Do not promise immediate automatic detection for those venues.

The Mobile screen must localize the message (Arabic example: «هناك عطل فني مؤقت. يمكنك الحجز بالاتصال بالصالة على …»), display the actual returned phone, and offer a validated `tel:` action only when a phone exists. Missing phone and request failure need separate states. Keep online booking disabled. Refresh status when reopening the page and before checkout; do not turn a cached technical state into an online booking permission. Mobile frontend work is assigned separately and is not claimed complete by this backend change.

## Offline booking holds

`guard_cashier_online_hold` rejects new or renewed active holds while a configured writer is offline or its heartbeat has expired. Released holds remain releasable. It validates room/lounge scope and uses a nonblocking shared writer lock and advisory lock to avoid deadlocking concurrent online/offline operations. Legacy venues without a writer retain existing hold policy. The guard is private and not executable by API roles.

## Verification

- Native PostgreSQL 17.11 isolated fixtures: `node supabase/tests/lounge_operating_status.test.mjs`, exit 0, 10 checks passed.
- Native PostgreSQL 17.11 isolated fixtures: `node supabase/tests/offline_booking_hold_guard.test.mjs`, exit 0, 8 checks passed, including two-connection lock contention.
- Tests cover connected/open, expired heartbeat/open shift, explicit offline/open shift, no shift, manual closure, inactive venue, banned writer, absent phone, unknown venue, narrow public response and grants, hold renewal/release/scope/legacy behavior, and private function access.
- Live read-only metadata checks confirmed the RPC, public execute grant, hold trigger, and both migration history records. No production booking, cash receipt, or shift was created or altered for these tests.
- Applied migrations: `20261004153152_lounge_public_operating_status.sql` and `20261004154405_offline_booking_hold_guard.sql`.

## Remaining client verification

The Mobile agent instructions include this exact contract. A real Mobile screenshot of each state and an actual telephone-link test are still required. Backend fixtures and deployment metadata do not prove the Mobile UI is complete, nor do they establish automatic offline readiness of all venues.
