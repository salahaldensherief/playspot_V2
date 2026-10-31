# Recovery backup inventory — 31 October 2026

## Current boundary

**NO VERIFIED PRODUCTION RECOVERY BACKUP.** The owner subsequently prohibited all Production connections, configuration changes and recovery operations. The owned pending read-only export client was stopped immediately. No further Production requests are authorized under this checkpoint. No hosted migration, schema/data mutation, ledger repair, reset or backup configuration change was performed. A previous metadata-only Production catalog match is historical evidence, not permission to reconnect.

## Local search actually performed

Read-only filename/metadata search of C:/Users/salah, D:/ and E:/ for SQL, dump, backup, compressed backup and cluster markers: respectively 4,843, 2,173 and zero matches before classification. Most matches are source migrations, fixture clusters and tool/editor state. System folders/recycle-bin entries and one VS Code askpass path denied access; they were not bypassed. C:/Windows/system recovery, unattached disks and remote cloud accounts were not searched or mounted. All three mounted drives were reported Fixed; no removable drive was reported.

Known archive inspection covered D:/CodexBackups, D:/PlaySpotTransfer and local Downloads, 277 archive/backup-suffix files including dependency packages. ZIP central-directory checks did not identify PostgreSQL custom dumps, compressed SQL data backups or physical-cluster backup markers. This is not proof that every arbitrarily named or encrypted file is free of database data. PlaySpotTransfer.zip is a source transfer archive, not a verified database backup. Existing Git bundles and code archives are not counted as recovery evidence.

Seven common rclone, pgBackRest, WAL-G, restic and Windows FileHistory configuration locations were checked; none existed. No mapped SMB drives were returned. Five matching scheduled tasks were Windows application-list/registry/cloud-restore maintenance, not a verified PlaySpot database backup task. No remote storage was accessed or configured. Unknown/offline/owner-only external backup storage remains unknown.

Raw local evidence: task outputs/backup-inventory-{0,1,2}-20261031.json, backup-known-archives-20261031.json, backup-schema-classification-20261031.json, backup-storage-config-inventory-20261031.json and backup-scheduled-task-inventory-20261031.json. Paths and metadata only; customer rows and credentials are excluded from this report.

## Classified artifacts

Timestamps below are UTC, file modification times rather than proof of backup creation time.

| Exact path | Modified UTC | Bytes | Verified coverage/integrity | Restore status |
| --- | --- | ---: | --- | --- |
| D:/PlaySpotReleaseSecrets/production-recovery-20261031/production-full-20261031-attempt3.pgdump | 2026-10-31 11:39:14 | 3,457,024 | Interrupted custom archive. TOC lists 141 TABLE DATA entries including auth.users, bookings and payments, but complete archive read fails: block ID 8225 missing, possibly corrupt archive. | **Rejected**, no successful isolated restore. Never use as recovery backup. |
| D:/PlaySpotReleaseSecrets/production-recovery-20261031/production-full-20261031.pgdump | 2026-10-31 11:31:47 | 0 | Initial read-only attempt failed on Auth schema permission. | Empty, unusable. |
| D:/PlaySpotReleaseSecrets/production-recovery-20261031/production-full-20261031-attempt2.pgdump | 2026-10-31 11:32:41 | 0 | Stalled client stopped; preserved empty output. | Empty, unusable. |
| C:/Users/salah/Documents/Codex/2026-10-21/files-pasted-by-the-user-playspot/financial-schema-local/playspot_schema_20261025.sql | 2026-10-24 21:36:06 | 1,342,424 | SHA-256 08d6c1d70278da715a5af80bc3a832358d098f9dd72eb1b6c2f56935ed5293ca; zero COPY data blocks or INSERT statements. | Schema-only; historical fixture restores do not recover customer data. |
| C:/Users/salah/Documents/Codex/2026-10-21/files-pasted-by-the-user-playspot/financial-schema-local/playspot_schema_tail_20261026.sql | 2026-10-25 22:20:26 | 383,717 | Function/ACL fragment; zero COPY data blocks or INSERT statements. | Not a full database backup. |
| D:/PlaySpotFix20261015/private/source_schema.private.sql | 2026-10-15 19:24:01 | 1,414,203 | Zero COPY data blocks or INSERT statements. | Schema-only; not a data recovery candidate. |
| D:/CodexBackups/Docker/codex-docker-original.vhdx | 2026-10-26 10:56:30 | 15,799,943,168 | Opaque preserved Docker disk; actual database coverage and consistency unknown. Not attached, altered or migrated. | No verified Production restoration procedure; not counted as backup. |

Interrupted archive SHA-256: `5941A93BA0FEFDC529A4BA5772042FC02736B2134F2D4B0738A3B2A05E746C9C`. A TOC listing alone passed, but full decompression/read exited 1. No restore was attempted from this invalid archive. No customer data from it was imported into the acceptance stack. Sensitive artifacts remain outside Git in owner/SYSTEM-only storage; no credentials or customer rows were printed.

## Recovery procedure and next prerequisite

There is **no tested restoration procedure for a complete Production data backup**. Do not substitute a source checkout, schema dump, empty file, partial archive, local synthetic cluster or WALG-enabled flag.

A future valid candidate must first pass full integrity reading, then a separately isolated offline restore with required Supabase-managed roles/extensions, outbound jobs/integrations disabled, row/constraint/ledger coverage checked and restoration logs retained. That is a proposed validation gate, not completed evidence. Backup coverage must distinguish database/Auth/schema/roles from actual Storage object files, which database dumps do not contain.

Production rollout remains stopped. The smallest owner decision, if no independent complete backup is available, is a **specific authorization for a supported read-only full-backup acquisition with secure backup-capable credentials and an isolated restore test**. This checkpoint grants no such new connection/configuration permission. No new backup configuration, spending, permission changes or credential rotation is assumed.
