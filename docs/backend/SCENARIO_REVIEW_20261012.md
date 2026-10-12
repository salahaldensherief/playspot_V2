# Booking and payment scenario review — 12 October 2026

## Reproduced defects and fixes

- Explicit manual-transfer confirmation was silently treated as cash when the selected payment option changed. The confirmed method now takes precedence.
- Repeated confirmation after a committed checkout dispatched creation again. A committed booking blocks further creation; an independent mutation lock remains held through proof upload.
- A quote for a previous checkout could arrive while a new checkout awaited profile data. Initialization invalidates old quotes and resets checkout data; realtime listeners also have generation guards.
- Changing the booking date during hold acquisition accepted the old hold for the new selection. Selection changes invalidate the request; abandoned successful holds are released instead of navigating to checkout.
- Closing My Bookings during refresh/cancellation caused emit-after-close errors, including queued refreshes. Disposed requests are ignored and no queued fetch is started.
- Room play-mode title overflowed at 360px with Arabic text scale 1.6. Only the title became flexible; ordinary card dimensions, colors, option placement and typography remain unchanged. Offer-edge tests follow the current user design (directional end).

## Boundaries and rules

Follow AGENTS.md as the primary rules document; its focused changes and safe server authority take precedence over conflicting legacy ceremony. Cubits retain existing repository boundaries, pending mutations are guarded separately from display statuses, stale responses are ignored, and server monetary values remain authoritative. No business SQL was changed for these client race fixes. Catalogue deletion migration from PR46 remains a deployment prerequisite for the Dashboard client.

These focused changes do not certify every legacy file as fully compliant. Whole-project analysis and formatting checks are recorded in the task report, including existing informational lint/format debt. The full regression suites cover the shared server payment, partial balance, authorization and idempotency contracts; real Auth/Realtime booking verification uses only the isolated local stack.

## Project-wide safe cleanup

Format all lib/test Dart files. Apply behavior-preserving lint fixes, rename internal cache identifiers and the global extension file, and preserve every existing serialized cache key. Replace legacy opacity calls with the same rounded 8-bit alpha used before; do not change the user color palette. Update ticker visibility calls with the equivalent enabled value. Keep deprecated theme-background, OTP keyboard and SVG APIs for a separate reviewed migration rather than silently changing theme/input behavior.

The ordinary 360px Arabic overview, room list and expanded-room screenshots were byte-identical to the user dev baseline before broad cleanup. Final capture comparison and exact-head CI are recorded in the task report.
