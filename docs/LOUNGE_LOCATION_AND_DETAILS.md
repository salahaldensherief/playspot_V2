# Lounge coordinates, distance and comparison UI — 2026-10-02

This phase runs in the isolated `fix/lounge-location-and-details` worktree,
starting from mobile `dev` 74d6f73. Original mobile/dashboard checkouts and the
other feature worktrees were not edited.

## Verified backend contract

Read-only inspection of the connected Supabase project confirmed that
`discover_lounges(p_lat, p_lng, ...)` computes:

```sql
ST_Distance(location_point, ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography) / 1000
```

This is an RPC calculation per request, not a distance-maintaining trigger.
Longitude goes first inside the spatial point; returned `distance_km` is already
in kilometers. No geospatial distance trigger was found on lounges/profiles.
The inspected active lounge has a WGS84 point; lounge coordinates are stored in
`location_point`, not separate lounge latitude/longitude columns.

A synthetic read-only PostGIS calculation between Cairo points
(30.0444, 31.2357) and (30.0131, 31.2156) returned 3.97464437794 km.
The Flutter datasource test uses a local HTTP transport and synthetic data;
no automated test writes to or authenticates against the live project.

The shared coordinate decoder now supports WGS84 EWKB/WKB (both byte orders),
GeoJSON Point, WKT and complete flat lat/lng pairs. It rejects incomplete mixed
pairs, nonfinite/out-of-range values, non-point shapes and unsupported SRIDs.
Zero coordinates are valid. Coordinates and explicit kilometer units survive
cache round trips; the old `>=100` unit guess was removed.

## Location refresh and offline estimates

- Denied/unavailable GPS does not block lounge discovery. The RPC receives both
  coordinates as null; unknown distance stays hidden rather than becoming zero.
- Local movement greater than 500 meters refreshes discovery. Requests use a
  coherent coordinate pair, coordinate writes are serialized, and old responses
  cannot overwrite a newer request. Stream errors are contained; explicit resume
  can subscribe again, and leaving/closing cancels the subscription.
- Home no longer writes profile GPS on every bootstrap/refresh. The existing
  sign-in/sign-up location update remains outside the reactive location stream.
- While offline or awaiting fresh data, cached venue coordinates support local
  spherical Haversine distance estimates and nearest/rating sorting. Estimates
  carry `distance_is_approximate`, display `≈`, and explain that they use the last
  available location. Missing endpoints hide distance. The live RPC result
  replaces the estimate and its cache after reconnect/manual refresh.
- This is straight-line distance, not travel time or road distance. GPS accuracy
  and cached-location age still affect any client-side estimate.

## Directions

The shared Directions service accepts only coordinates. It constructs:

```text
https://www.google.com/maps/dir/?api=1&destination=LAT,LNG&dir_action=navigate
```

It does not use lounge names, address searches, `maps_link`, stored origins or
API keys. Both external-app and browser fallback preserve the same destination;
false returns/exceptions are handled. The button guards duplicate taps, clears
loading and shows localized errors when coordinates are missing or launch fails.
Booking joins decode `lounges.location_point`; booking cards pass that decoded
pair. Tournament buttons now pass their model coordinates rather than a name.

Native Google Maps opening and a signed-in post-booking journey remain device
smoke checks; launch behavior was validated with an injected platform launcher.
Tournament models with only nested spatial data need their own adapter review.

## Lounge/room presentation

The page presents the complete address, directions, canonical aggregate rating
and review count, real description, operating hours/overnight closing, configured
payment channels and first-booking prepayment policy. Room comparisons derive
room count, known capacities, base rates, activities and localized equipment
from actual room data. No parking/Wi-Fi/lounge-wide amenities were invented:
there is no such amenities contract in the inspected schema.

Room cards hide unknown specifications and absent feature/gallery sections.
The fabricated racing/VR equipment text is removed; real screen sizes such as
50 inches remain visible. Occupied rooms can be inspected without enabling
booking or leaving an empty disabled action area. Only present room-type filters
appear. Current date/controller/play-mode settings are read at booking time;
loading/unavailable/stale selections cannot proceed.

The actual screen is split into independent leaf components and has a persistent
back/header bar. Arabic uses Tajawal; controls support large text and 48px touch
targets. Date cards and translated section titles wrap instead of clipping.
Shared typography honors an explicit inherited font size. Tablet/wide content
uses a readable centered width; mobile actions stack vertically.

## Validation and limits

- Full mobile suite: **268 tests passed** (`flutter test --no-pub --concurrency=2`).
- Analyze: **0 errors, 0 warnings; 108 pre-existing info diagnostics**, exit 1.
  No current-phase files have analyzer diagnostics. Whole-repository lint cleanup
  was kept outside this feature phase.
- Formatter ran on 108 changed/new Dart files. The two large legacy callers
  retain only minimal argument changes rather than unrelated formatting churn.
- 20 actual-screen cases: widths 360/600/768/1024/1440 × Arabic/English × text
  scales 1.0/1.6. Every case checks overflow, RTL/LTR, persistent back navigation
  and inspection of an occupied room. 60 production-widget PNG captures use
  synthetic fixtures; they are not mockup images or live-account screenshots.
- 20 selection changes: zero rebuilds of LoungeDetailsScreen,
  LoungeDetailsContent and LoungeInfoSection; host elapsed 337512 µs.
- 100 cached-lounge estimates: host elapsed 6122 µs in a debug unit test.
  Neither measurement is native device GPU/FPS evidence.
- Generated plugin changes were only line endings. The test backup changed from
  empty to `{}`. Own worktree artifacts were inspected and restored; they are
  excluded from feature commits. Original checkout artifacts were not touched.

Capture reproduction on Windows (choose an evidence directory outside Git):

```powershell
$env:PLAYSPOT_SCREENSHOT_DIR = 'D:\PlaySpotEvidence\lounge-details'
New-Item -ItemType Directory -Force -Path $env:PLAYSPOT_SCREENSHOT_DIR
flutter test --no-pub --concurrency=2
```

No hosted SQL/migration, dev/main merge or force push was performed. This phase
does not certify the wider offline cashier synchronization, availability lease,
KYC rollout, backend payment integration or encrypted PII-cache rollout. Existing
room-promotion cache fidelity also remains outside the distance/UI phase.

Primary contract references:
[Supabase PostGIS](https://supabase.com/docs/guides/database/extensions/postgis),
[Google Maps URLs](https://developers.google.com/maps/documentation/urls/get-started).
