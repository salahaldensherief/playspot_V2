# Session close repair — 2026-10-01

Migration 20261001100000_session_close_shift_and_ledger_integrity.sql follows the
wallet integrity correction and the phase 2 open-time pricing schema. Written and
locally engine-tested only; not applied live and not yet connected to frontend.

Keeps complete_booking_session(p_booking_id uuid,p_action_by uuid default null)
returning json. Requires auth.uid(), actual sessions_control capability and matching
actor when supplied. New close locks an open shift of the same lounge. Repeating an
already closed session returns its persisted billing without recalculation, even
when that shift has subsequently closed; capability checks still apply.

Responses include success/booking_id/lounge_id/status/final_total/amount_paid/
amount_due/payment_status/idempotent/closed_at/billing_minutes. Collected money comes
from completed payment ledger records rather than an unverified paid status flag.
No payment or shift receipt is inserted by closing play. After collection, a refreshed
receipt reflects new money while the final billing total stays immutable.

Elapsed partial minutes round up before the billing quantum. The maximum session
length is an operational stop/warning policy, not a free billing ceiling. Time beyond
it remains billed. The old 1440-minute billing constraint becomes positive-only so
an overrun can still be closed; no existing rows are rewritten. The replacement check
is NOT VALID for historical rows and enforces future writes. Plan explicit validation
and historical audit in isolated staging before production rollout.

Snapshot values are checked before mutation. Original legacy no-snapshot fallback
remains for compatibility and must be reviewed/reconciled before deploying to older
running sessions; this does not retroactively create an authoritative snapshot.
Maintenance rooms stay unavailable. A room with another active session is not freed.
New close acquires its room lock before the availability check.

Combined suite: 60 passing sequential checks (46 wallet/payment + 14 closure checks).
Includes null/anonymous/unauthorized/spoofed actor, closed shift, no implicit collection,
ledger-derived paid/due, no max-cap free time, partial-minute quantum, invalid snapshot,
repeat total stability, >24-hour overrun and occupied/maintenance preservation.
PGlite PG18.3 synthetic fixture is not a PG17 production schema mirror or proof of
multi-connection races. Validate real constraints/triggers, start/close/shift lock
interactions, timezone boundaries and historical snapshots in isolated staging.

UI must parse the response strictly, verify booking identity and refresh server state.
Do not reconstruct collected or due from booking.payment_status. Existing Flutter
completion calls already use this signature; exposing the new financial fields needs
a reviewed model/state integration after deployed-contract verification.

No production rollback should restore a free-billing or fabricated-paid implementation.
Disable close UI if rollout fails, preserve stored final totals, then forward-correct
and reconcile. Do not delete sessions, payments, shifts or wallet ledgers.
