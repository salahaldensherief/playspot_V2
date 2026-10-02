# Local cache audit — 2026-10-02

## Verified correction

LocalCacheServiceImpl previously called SharedPreferences.clear on logout.
It now owns only nonempty cache_* keys and serializes writes/removals/clear.
Audio, language, unrelated legacy auth keys and non-cache preferences survive.
Clear waits for writes already queued through this instance. A failed logout
cleanup returns a localized CacheFailure; it is attempted once even when the
remote logout fails. Optional reference cache writes/removals remain best effort.
Malformed entries are not destructively removed during a synchronous read.

Eleven new tests cover retained settings/auth, key normalization, unauthorized
key access, invalid data, delayed writes, failed cleanup and all four remote/local
logout outcomes. The complete suite has 491 passes and two live skips; analyze
has 21 existing infos, no warnings/errors (exit 1). This is a cache cleanup fix,
not proof of encrypted, account-isolated reference data.

## Remaining storage release blockers

Dashboard LocalCacheService still stores JSON in plaintext SharedPreferences.
cache_onboarding_lounge_draft_v1 includes contact phone/address/location and has
no actor identity. LoungeCacheHelper caches owner name/email and payment contact
details. Existing global cache keys do not establish account ownership.
Encryption must not blindly assign an old unscoped draft to the next account.

The mobile PreferenceManager also writes profile/name/phone, location, Apple
profile and FCM data to GetStorage. Its auth-token setters exist but have no
active external callers in the inspected source; the new Supabase auth adapters
use FlutterSecureStorage. Historical credentials are not all automatically
removed by that change.

Further migration requires encrypted Hive payloads, secure key retention,
endpoint/actor scopes and verified migration before retiring known legacy data.
Unidentified legacy records must remain isolated for explicit ownership review.
Account switches must invalidate pending reads/writes before opening a new scope;
clearing a queue alone cannot identify responses started by a different account.
Financial journal/outbox files must never be deleted as profile cache cleanup.

Mobile AuthRepository now attempts profile cleanup once even if remote signOut
returns a failure, preserving the remote failure or a localized CacheFailure.
Four repository cases plus Arabic/English error visibility and successful route
navigation pass; the complete mobile suite has 213 passes and 109 existing infos
(no warnings/errors, analyzer exit 1).

Mobile remote signOut still waits for notification/social cleanup before Supabase
logout. Those provider implementations swallow many exceptions, but an unbounded
wait can delay local logout. A complete fix needs independent local session
invalidation and bounded provider lifecycle without letting late cleanup affect
a subsequent login. Dashboard LoginCubit also currently discards logout's result;
the repository cleanup failure is not yet surfaced by that UI. These flows remain
release checks; cleanup tests alone do not establish complete offline logout.

## Offline integration still pending

Canonical room/stock/booking/shift snapshots and cached UI action/read adapters
are not yet connected. A heartbeat timeout alone cannot guarantee capacity is
consistent when a cloud booking transaction races an unexpected disconnect.
Bootstrap/fencing and confirmation ordering require real concurrent tests before
enabling offline walk-in actions. Current immutable grants last 24 hours; this
is not unlimited offline authorization. No hosted SQL is deployed here.
