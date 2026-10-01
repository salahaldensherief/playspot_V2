# Secure Supabase auth persistence

Supabase Flutter 2.17.2 defaults to SharedPreferences/browser local storage for
sessions and SharedPreferences for PKCE verifiers. PlaySpot now supplies explicit
LocalStorage and GotrueAsyncStorage adapters backed by FlutterSecureStorage.
These adapters are shared in behavior with the mobile source.

Session JSON and new OAuth PKCE values are scoped to the configured endpoint,
including scheme, hostname, port and path. Trailing slashes normalize to the same
scope. No auth value or journal key is written to GetStorage by these adapters.

Legacy session migration is automatic only for the SDK's unambiguous standard
HTTPS project endpoint, https://<project>.supabase.co on port 443 without a path.
The selected SDK key is copied, read back exactly, then retired. Existing secure
values win over stale legacy values. Read/write/verification errors preserve the
legacy copy and propagate; there is no plaintext fallback.

Custom domains, self-hosted endpoints and alternate ports/paths retain legacy
records without importing them because the old SDK key cannot distinguish those
endpoints. They may require a fresh login and explicit migration review. Legacy
global PKCE verifiers also remain untouched and are never imported: their project
cannot be identified. An OAuth flow started before this change must restart.
This is not automatic cleanup of every historical plaintext credential.

All operations in an adapter pair share a FIFO task queue. A failed task does not
poison later tasks. Logout retires the selected legacy session before deleting
its secure session key. It does not delete encrypted cashier journals, their
encryption keys, other project sessions or non-secret settings. The queue belongs
to one client instance; cross-tab/process ordering is not guaranteed by it.

The Supabase SDK logs persistence failures from auth-change notifications rather
than propagating them to the login/logout caller. Initial restoration errors do
propagate. A successful in-memory login therefore does not by itself prove that
the device persisted it. Native platform and actual account flows need separate
verification. Existing unrelated profile caches still require a PII storage audit.

FlutterSecureStorage web support uses browser cryptography and requires a secure
context; it does not provide native Keychain/Keystore protection against scripts
running in the same origin. No security failure falls back to plaintext storage.
Full browser/XSS and iOS/Windows device verification remain release checks.

Android uses resetOnError=false so a decryption failure cannot silently erase all
stored keys, including retained financial journal keys. migrateWithBackup=true
enables the plugin's guarded cipher migration. The offline journal key vault uses
the same policy. The mobile manifest disables OS automatic cloud backup and
explicitly excludes app data from Android 12+ device transfer. This prevents
restoring encrypted state without the original non-transferable platform key;
it does not implement a cashier backup/export or unsynced-device recovery feature.

References checked on 2026-10-02:
- https://supabase.com/docs/reference/dart/initializing
- https://pub.dev/packages/flutter_secure_storage
- https://developer.android.com/identity/data/autobackup
- Installed supabase_flutter 2.17.2 local_storage.dart, supabase.dart and
  supabase_auth.dart; installed flutter_secure_storage 10.3.4.

Verification on 2026-10-02: 23 offline storage cases pass in each client. They
cover exact read-back migration, existing secure values, secure/legacy failures,
logout versus delayed writes, endpoint separation, PKCE scoping, ambiguous legacy
retention and Android no-reset/cipher-migration options.

Two native Android 16/API 36 x86_64 probe runs passed using the production storage
classes and backup XML. The first verified real plugin migration/read/write,
adapter reopen, project isolation, session/PKCE removal and retained journal key.
The second verified saved values in a new app process, then selective logout.
The package com.playspot.verification.storage_probe was separate from PlaySpot
and ran in a headless read-only AVD overlay. The probe used synthetic values and
made no Supabase requests. Installed package flags did not include ALLOW_BACKUP.
Flutter test required --no-uninstall between runs; its default cleanup erases
the app's data. This is emulator/plugin evidence, not real account authentication,
physical hardware security or complete mobile/cashier workflows.

The production mobile Android processDebugMainManifest task also passed (80
tasks). Its merged manifest retains allowBackup=false and the explicit
play_spot_data_extraction_rules reference. No production app was installed.
