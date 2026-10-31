# Consolidated disposable development backend

This directory is local-only infrastructure, not a hosted migration or deployment.
Supabase CLI **2.122.0**, PostgreSQL 17, Auth, PostgREST, Storage, Realtime,
Kong, Studio and local mail run in the existing **dedicated** WSL distro
`PlaySpotAcceptance20261030`, storage `D:/PlaySpotIsolated20261030/wsl`, Docker
socket `/run/playspot-docker.sock`, data-root `/var/lib/playspot-docker`.
Docker Desktop and its disks are never started, attached or changed.

## Start and stop

From the Mobile repository, with the dedicated daemon already running:

```powershell
npm ci --prefix supabase/tests/runtime
./tooling/dev-stack/start.ps1 -DashboardRoot PATH_TO_DASHBOARD -Initialize
```

Use `-Initialize` **once on an empty new application database only**. It refuses
an existing application or Auth users; it never resets/replays the database.
On subsequent starts omit that switch. Run `verify.ps1` independently.
`stop.ps1` stops only containers belonging to this project; it keeps all volumes.
The existing acceptance project on 56621 remains separate and untouched.

API 56821, PostgreSQL 56822, Studio 56823, local mail 56824 are loopback only.
All nine containers must have exactly one dedicated **internal** Docker network.
Actual guest and Windows listeners are checked, not inferred from config.
Fixed relays are necessary because this daemon does not publish ports from an
internal bridge. The relays cannot target arbitrary destinations.

Generated `.env.dev-local.json` contains only the local public client key.
Select **PlaySpot Dashboard - Consolidated dev (Chrome)** or
**PlaySpot Mobile - Consolidated dev (Chrome)**. No hosted selection/fallback.
The native Android profile additionally needs a selected device and explicit
loopback port forwarding; browser builds do not establish device acceptance.

For a browser build that additionally blocks hosted subresources, build each
client with `flutter build web --no-web-resources-cdn --dart-define-from-file=.env.dev-local.json`.
From Mobile run:

```powershell
node tooling/local-supabase/local-web-server.mjs PATH_TO_DASHBOARD/build/web dashboard 56821
node tooling/local-supabase/local-web-server.mjs PATH_TO_MOBILE/build/web mobile 56821
```

URLs are http://127.0.0.1:51751 and http://127.0.0.1:51752. This explicit selection
sets the CSP to the new local API; it never permits hosted connections. Default
server behavior remains the original acceptance ports 51651/51652 and API 56621.

## Reproducible baseline and reference data

`manifest.json` pins a versioned **application-schema-only** checkpoint and 13
reviewed prerequisite/forward deltas. The checkpoint contains no customer rows,
credentials or managed-schema replacements. Its preserved export provenance and
one intentional local notification transport replacement are recorded there.
No private export path is required to initialize this versioned baseline.

The historical migrations are **not** an empty-database migration chain: initial
core DDL is absent and timestamp 20260927000010 is duplicated. Do not replay all
files or claim hosted migration-ledger equivalence. Managed Supabase schemas and
roles come from the CLI images. Auth triggers attach only the role-fixed profile
creator before notification settings; metadata cannot choose an elevated role.

Schema exports omit reference rows. `synthetic-permissions.json` is an explicit
**local fixture** catalogue derived from client keys and server requirements,
with every global role default FALSE. The synthetic lounge owner receives a
scoped fixture template; cashier grants go through the real audited owner RPC.
This does not reconstruct or certify Production's actual permission defaults.
Synthetic passwords/server keys remain in the private runtime directory.

Scheduled jobs must be absent, SMS/external providers disabled, local mail only,
and notification delivery explicitly suppressed behind a private local marker.
Notification rows remain real; external FCM/push delivery is **not** verified.
Edge runtime remains disabled pending isolated module/runtime verification.

## Real local API journey

Run `journey.mjs PRIVATE_DIRECTORY REPORT_JSON`, then the existing shared probes
in `tooling/local-supabase`: `retry-probe.mjs`, `refund-probe.mjs`,
`reconcile-refund.mjs`, `finish-refund-journey.mjs` (same two arguments, in order).
These assert the selected loopback identity before requests. The journey creates
synthetic bookings, collections and refund attestations, ending with a closed
shift and zero-net ledger. No external cash/wallet transfer occurs.

This is authenticated API/database evidence shaped from the two client contracts.
It is not a browser cash checkout, installed-device E2E, complete Storage receipt
acceptance, Edge-runtime execution or hosted compatibility claim.
