# Isolated local Supabase acceptance — 30 October 2026

This is a new environment, not a restored hosted service or a financial merge.

## Identity and storage

- WSL distribution: `PlaySpotAcceptance20261030`; Windows registry BasePath verified as `D:\PlaySpotIsolated20261030\wsl`.
- Fresh Ubuntu Base 24.04.5 AMD64 rootfs: SHA256 `e77b6f10c2590cef872b33ee9f635a0e3fd1f57fb074c0e52b5c7f56147a0c86`, downloaded from Canonical and verified against its HTTPS SHA256SUMS. The abandoned larger WSL-image download is preserved separately and was not imported.
- Linux root mount observed as `/dev/sdd`; a new ext4.vhdx resides at the BasePath. No old disk attached/migrated, no host virtualization/security setting changed. `docker-desktop` remains stopped; Windows Docker context was not switched.
- Docker Engine 29.1.3 installed inside this guest from Ubuntu packages, with package service autostart suppressed by guest-only policy-rc.d. Guest daemon ID `a5425fa1-5622-4997-8e86-a80a06cec53d`, DockerRootDir `/var/lib/playspot-docker`, exec root `/run/playspot-docker`, socket `unix:///run/playspot-docker.sock`. Managed containerd state is in the dedicated guest. This is separate storage and a separate daemon, not merely a Docker context.
- Pinned Supabase CLI 2.122.0 Linux AMD64 archive SHA256 `59ed066847b98d7461c60e9109d40cab6b9756177ce06ebb05b51338519f5136`, verified against official release checksums. Installed `/opt/playspot-tools/supabase`.
- Project `/opt/playspot-acceptance/project`, ID `playspot-acceptance-20261030`. Intended API/DB/Studio/mail ports 56621/56622/56623/56624; shadow 56620. Intended client origins: Dashboard 51651, Mobile Web 51652. These are planned until actual binding verification succeeds.

## Reproducible startup and stop

Prerequisites are the dedicated distribution, installed Docker and verified pinned CLI. Do not substitute Docker Desktop or a different daemon. Re-import on another machine only into a new unused path; never unregister an existing distribution or reset storage.

1. Copy this directory's config.toml to `/opt/playspot-acceptance/project/supabase/config.toml`, stack.sh to `/opt/playspot-acceptance/stack.sh`, and daemon.sh to `/opt/playspot-acceptance/daemon.sh`. Keep scripts LF. The config contains no credentials or hosted URLs. Do not copy repository migrations/seeds into this project's supabase directory.
2. Start a foreground daemon session **only in the dedicated distribution**:
   `wsl -d PlaySpotAcceptance20261030 --exec sh /opt/playspot-acceptance/daemon.sh`
   Keep it running. Check registry BasePath first as stack.ps1 does. The first attempt with a custom bridge name failed safely because Docker requires that interface to be precreated; the corrected daemon uses its fresh guest's default bridge. No host interface/firewall/security change was made.
3. From PowerShell run `./tooling/local-supabase/stack.ps1 start`. It verifies the distro storage path and daemon data-root, creates only the dedicated internal bridge with default published HostIP 127.0.0.1, and invokes pinned CLI start with `--network-id`. Image downloads use the guest daemon's network; service containers use the internal network without external routes.
4. Run `./tooling/local-supabase/stack.ps1 verify`. It checks each actual container network attachment and PortBindings, and Windows listeners. Do not connect clients if a non-loopback binding or unexpected container/network is found. Stop this new stack; do not change host firewall settings as a workaround.
5. Stop only this project using `./tooling/local-supabase/stack.ps1 stop`. This keeps new project backups/volumes; no `--no-backup`, `--all`, prune, reset or global shutdown. To stop the owned daemon, interrupt its foreground session gracefully. Do not terminate other distributions.

CLI output can contain keys. stack.sh redirects it to private/start.log (0700 directory/077 umask). To save status, run inside the dedicated guest with the same DOCKER_HOST: `umask 077; /opt/playspot-tools/supabase status --workdir /opt/playspot-acceptance/project -o json > /opt/playspot-acceptance/private/status.json`. Never print that file or copy its service-role key into Flutter.

Auth uses local origins only, external providers/SMS/functions/analytics disabled, email confirmations disabled and mail captured locally. No hosted account material imported. The internal service network blocks external traffic, including old SQL webhooks. The separately reviewed disable-local-notification-egress.sql makes the known notification trigger a no-op in this environment only; it is not a production migration or a claim of identical trigger behavior.

## Baseline review and restoration gate

`node tooling/local-supabase/audit-baseline.mjs SNAPSHOT PAYOUT_SOURCE REPORT` audits the preserved schema-only snapshot without executing SQL. Expected SHA256 is pinned. baseline-review.json records 458 functions, 85 triggers, 167 policies, 1,475 grants, nine **review candidates** with hashes, and zero applied migrations. No customer data or managed Auth schema is imported. The snapshot contains only public/private schemas but depends on managed Auth roles/functions/users, public PostGIS geography, btree_gist, vault and pg_net. It omits the Auth-user profile trigger, extension-owned spatial_ref_sys triggers and cron jobs; their existence cannot be inferred from the dump.

Before restoration: verify new PG version, managed roles/Auth tables, required extensions and a clean application catalog through catalog-review.sql, using the verified daemon's exact database container and psql, not an arbitrary DB URL. Install only missing reviewed extensions in their required schemas (PostGIS must match public.geography), compare baseline-owned objects against fresh managed objects and resolve conflicts explicitly. The original dump is immutable. Do not replace managed auth/storage/realtime/supabase_migrations schemas, copy production grants over managed roles, or replay the entire migration directory.

A reviewed restore must use ON_ERROR_STOP and a transaction with the notification egress override before any synthetic user/data insertion. Record every local divergence. Then inspect effective function signatures/search_path/definer/grants, table RLS and policy hashes, including anon versus authenticated behavior. Apply only specifically reviewed missing migrations in dependency order to this new disposable environment. Atomic checkout precedes movement ledger replacement; permission boundary and pre-session transfer guard must be coordinated with deposit/mixed cash; refund depends on movement/checkout/policy. Open Time partial-status correction comes from the separate unmerged 28184d1a branch and requires explicit order review. Refund/payout source f27c78dc remains unmerged. Candidates are not an approved replay list.

No restoration has been performed at this checkpoint. The old 3,607/3,607 catalog result is historical evidence, not verification of this managed stack.

## Synthetic Auth and first journey

After services/bindings pass and baseline review is complete, use auth-probe.mjs PRIVATE_STATUS PRIVATE_ACCOUNTS REPORT. Its only API is literal http://127.0.0.1:56621, redirects forbidden, server key stays in Node and passwords are generated into a private file, never logged. It creates three synthetic confirmed-email identities and proves actual password sign-ins. It explicitly does not assign business roles or claim authorization; a partial account file fails closed for review/recovery.

Next seed profiles/branch membership/permissions, owner venue, eligible rooms, refund policy and the cashier's open shift according to the reviewed real schema. Never grant owner powers through user-editable metadata. Run customer booking checkout via Mobile's actual hold/quote/create contract; verify a synthetic deposit with the authorized cashier; start/complete via Dashboard; collect remaining balance through the atomic contract. Assert booking paid amount equals signed movements equals payment aggregate and shift collections minus recorded returns; separately verify commission and custody. Follow with outsider denial, revoked cashier, lost receipt replay, concurrent cashiers, cancellation without assumed refund, then explicit actual-refund attestation/reversal. No real bank transfer is implied by synthetic attestation.

write-client-config.ps1 validates private status and writes only the public URL/key to ignored .env.isolated.json files, preserving any nonempty existing settings. Mobile also gets PLAYSPOT_LOCAL_ACCEPTANCE=true; this disables Firebase/Crashlytics/push initialization and runtime font downloads, and refuses any backend except the exact loopback API. Build Web with --no-web-resources-cdn to serve engine resources locally. Use a local CSP/server that disallows external connect/img/frame destinations before full browser acceptance; do not claim the opt-in flag blocks every possible feature integration. Device-specific acceptance remains separate. No connected client has been launched here.

## Count reconciliation

suite-count-evidence.json hashes four actual logs and checks each printed PASS line against its summary: old verification/restack 32, later rc/refinement 35. aa8628f4262f198e79f158399fae20d1b9221c7b added the two refund-initiation versus payout commit orders and one payout waiting for refund-execution scenario. These are dated synthetic PostgreSQL results, not freshly rerun financial E2E and not a reason to edit tests to target a number.

## Acceptance matrix

| Stage | Evidence |
| --- | --- |
| Separate Linux runtime and daemon storage | Created and identity/root verified |
| Supabase services/actual ports | Image acquisition in progress; not accepted |
| Baseline/effective RLS and grants | Offline audit done; no restore/application SQL applied |
| Client loopback configuration | Dashboard 21 offline validation checks passed; Mobile 2 policy tests passed; ignored keys blank |
| Mobile opt-in code | Touched-file analysis no issues; Web release build passed in 127.2s, exit 0 with --no-web-resources-cdn. Existing optional Wasm/font warnings remain |
| Auth sign-in/business authorization | NOT EXECUTED |
| Cross-client financial journey/refund | NOT EXECUTED |
| Hosted compatibility/device acceptance | NOT VERIFIED; excluded hosted operations remain untouched |

Sources: https://supabase.com/docs/guides/local-development ; https://supabase.com/docs/guides/self-hosting/docker ; https://docs.docker.com/reference/cli/dockerd/ ; https://learn.microsoft.com/en-us/windows/wsl/use-custom-distro ; https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ . The official changelog markdown fetch returned unsupported content-type; no API behavior was inferred from that failure. CLI flags/configuration were checked against the installed pinned CLI help and generated config, not guessed.

Mobile complete Flutter suite: 629 passed / 1 skipped, exit 0 (115s). Two local-target policy tests are included. Formatting passed with zero changes; no dependency versions changed (offline pub get only). Generated platform registrants from this new worktree are preserved and excluded from source commits. Mobile Web release compilation passed in 127.2s; no public key was supplied to that compile-only check, so it was not a connected runtime. Acceptance state remains pending services/baseline/Auth/journey.

Containerd root was independently observed as /var/lib/playspot-docker/containerd/daemon and state as /run/playspot-docker/containerd/daemon, with no TCP socket. This confirms its storage is inside the new guest too. There is no custom host .wslconfig and no host setting was changed.
