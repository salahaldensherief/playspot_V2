# Comprehensive Codebase Audit Report: PlaySpot Mobile App
**Repository:** `salahaldensherief/playspot_V2`  
**Target Branch:** `dev` (Audit Branch: `comprehensive_codebase_audit_report` at commit `d0cd9ed`)  
**Audit Date:** 2026-10-05  
**Supabase Project Ref:** `tgpdexoitemmpruepgyt`  
**Auditor:** Senior Mobile Systems & Security Engineer (PlaySpot Engineering)

---

## 1. Executive Summary

### 1.1 Verdict on Production Readiness

> **VERDICT: NOT PRODUCTION READY (BLOCKING RELEASE)**
>
> The PlaySpot Mobile application **cannot be released to production** in its current state. While core user journey layouts, navigation hierarchies, and local unit test suites (381 passing tests) are present, the application contains **multiple critical system breaks** at the boundary between the client and Supabase backend.
>
> Most critically:
> 1. **Manual transfer checkout is fundamentally broken**: Receipt image attachment invokes a non-existent database RPC (`attach_my_booking_receipt`), causing **100% of manual transfer bookings** to flag as receipt upload failures.
> 2. **Session extension violates server authority**: It calls a non-existent RPC (`extend_booking_session`) while attempting to submit a client-calculated financial cost with arbitrary fallback rates.
> 3. **Points and loyalty are non-functional**: Every points RPC call (`get_user_points_balance`, `redeem_points`, `get_points_transactions_page`) targets non-existent backend functions, which silent `catch` blocks degrade to `0` balance and empty transactions.
> 4. **Customer booking cancellation fails**: The client targets `cancel_my_booking`, which does not exist in the database schema.
> 5. **Severe security exposures**: Authentication tokens, full user profiles, phone numbers, and fine-grained GPS locations are stored unencrypted on disk via `GetStorage`.
> 6. **Operational midnight flaw**: Sessions crossing midnight calculate end times incorrectly and prematurely expire on overnight bookings.
>
> These issues directly endanger financial reconciliation, user trust, account privacy, and booking integrity.

---

### 1.2 The 10 Most Serious Problems

| # | Finding ID | Severity | Problem Title | Primary Impact |
|---|---|---|---|---|
| **1** | `MOB-01` | **CRITICAL** | **Receipt Attachment RPC Missing from Backend** | Manual transfer bookings (Vodafone Cash / InstaPay) always flag `paymentProofUploadFailed: true` because `attach_my_booking_receipt` does not exist in Supabase migrations. |
| **2** | `MOB-02` | **CRITICAL** | **Session Extension RPC Gap & Client-Authoritative Pricing** | Active session extension calls non-existent `extend_booking_session` RPC and submits client-calculated financial values (`p_additional_cost`) with arbitrary fallbacks (50 EGP/hr). |
| **3** | `MOB-03` | **CRITICAL** | **Points & Loyalty System RPCs Missing with Silent Fallback to 0** | Balance, history, and redemption RPCs do not exist in the backend schema; silent catch blocks return `0` points, rendering the loyalty system dead. |
| **4** | `MOB-04` | **CRITICAL** | **Customer Booking Cancellation Invokes Non-Existent RPC** | `cancel_my_booking` RPC does not exist in the database; customer cancellation attempts always fail with PostgreSQL error `42883`. |
| **5** | `MOB-05` | **CRITICAL** | **Tournament System RPC Gaps (Feed, Registration, Match Proofs)** | `get_visible_tournaments`, `register_for_tournament`, and `submit_match_result` are absent from backend migrations, breaking tournament participation. |
| **6** | `MOB-06` | **CRITICAL** | **Legacy Direct Booking Insert Fallback & Canteen Order Swallowing** | Dead fallback code in `createBooking` attempts client-authoritative table inserts (blocked by RLS) and silently swallows canteen order failures. |
| **7** | `MOB-07` | **HIGH** | **Plaintext Storage of Auth Tokens & PII in Unencrypted GetStorage** | `PreferenceManager` writes JWTs, session tokens, user profile JSON, phone numbers, and GPS coordinates to plaintext disk files instead of secure storage. |
| **8** | `MOB-08` | **HIGH** | **Double-Tap Re-entry Race Condition on Payment Submission** | Neither `processPayment` in `CheckoutCubit` nor `_handleSubmit` in the wallet sheet guards against rapid double-taps during in-flight payment execution. |
| **9** | `MOB-09` | **HIGH** | **Active Session Auto-Navigation Push Loop on Tab Switch** | Every tab switch in `MainScreen` triggers `loadActiveSession()`, and a `BlocListener` unconditionally pushes `ActiveSessionScreen`, trapping users with active sessions. |
| **10** | `MOB-10` | **HIGH** | **N+1 Sequential Network Queries for Booking Availability** | `BookingCubit` sequentially queries bookings room-by-room despite the underlying RPC returning all lounge bookings, multiplying latency by N rooms. |

---

## 2. Complete Table of Audit Findings

| ID | Area | Severity | File : Line | Evidence (Code Excerpt) | Confirmation Level | Actual Impact on Users or Money | Proposed Fix | Effort |
|---|---|---|---|---|---|---|---|---|
| **MOB-01** | Money & Booking | **Critical** | `lib/features/checkout/presentation/checkout_cubit.dart:486-490`, `lib/features/booking/data/datasources/remote/booking_remote_data_source.dart:270-274` | `await _client.rpc('attach_my_booking_receipt', params: {'p_booking_id': bookingId, 'p_receipt_url': receiptPath});` | Confirmed by reading code & migrations | 100% of Vodafone Cash and InstaPay bookings report receipt attachment failure to the customer. | Either implement `attach_my_booking_receipt` in Supabase or upload receipt prior to `create_my_booking_checkout` and pass `p_receipt_url`. | **M** |
| **MOB-02** | Session & Money | **Critical** | `lib/features/active_session/data/datasources/remote/active_session_remote_data_source.dart:407-414`, `lib/features/active_session/domain/entities/active_session.dart:104-113` | `await _client.rpc('extend_booking_session', params: {'p_booking_id': bookingId, 'p_additional_minutes': additionalMinutes, 'p_additional_cost': additionalCost});` | Confirmed by reading code & migrations | Crashes on session extension. Violates server authority by submitting client-computed financial cost with fallback rate `50.0 EGP/hr`. | Standardize on the existing server function `request_booking_extension(p_booking_id, p_requested_minutes)` and remove client price calculation. | **M** |
| **MOB-03** | Points & Loyalty | **Critical** | `lib/features/profile/data/datasources/remote/profile_remote_data_source.dart:121-128, 147-173, 196-204` | `final response = await _supabase.rpc('get_user_points_balance', params: {'p_user_id': user.id}); ... catch (e) { return 0; }` | Confirmed by reading code & migrations | Customers see `0` points balance and empty transaction history; redemption fails silently. | Align with backend team to implement authoritative loyalty schema and RPCs or deprecate UI points display until deployed. | **L** |
| **MOB-04** | Booking Lifecycle | **Critical** | `lib/features/my_bookings/data/datasources/remote/my_bookings_remote_data_source.dart:61-68` | `await _client.rpc('cancel_my_booking', params: {'p_booking_id': bookingId, 'p_reason': 'Cancelled by user'});` | Confirmed by reading code & migrations | Customers cannot cancel their reservations in-app. Action throws PostgreSQL `42883` error. | Implement `cancel_my_booking` RPC in backend migrations with appropriate hold release and refund/voucher rules. | **M** |
| **MOB-05** | Tournaments | **Critical** | `lib/features/tournaments/data/datasources/remote/tournaments_remote_data_source.dart:107-111, 295-299, 417-425` | `await _client.rpc('get_visible_tournaments', ...); await _client.rpc('register_for_tournament', ...); await _client.rpc('submit_match_result', ...);` | Confirmed by reading code & migrations | Tournaments screen, registration, and match result reporting fail completely with RPC not found exceptions. | Deploy missing tournament RPC migrations or wrap with fallback table queries adhering to RLS policies. | **L** |
| **MOB-06** | Money & Booking | **Critical** | `lib/features/booking/data/datasources/remote/booking_remote_data_source.dart:396-435, 471-477` | `response = await _client.from('bookings').insert(bookingPayload)... catch (e) { dev.log("place_canteen_order RPC in createBooking failed: $e"); }` | Confirmed by reading code & migrations | Legacy dead path allows client-side total pricing, fails on RLS, and swallows canteen item failure while returning booking success. | Delete legacy `createBooking` method from repository and data source; route all bookings strictly through `create_my_booking_checkout`. | **S** |
| **MOB-07** | Security & Privacy | **High** | `lib/core/cache/preference_manager.dart:16-98` | `Future<void> saveAuthToken(String? authToken) => _box.write(CachingKey.AUTH_TOKEN, authToken ?? ''); Future<void> saveUserData(UserModel user) => _box.write(CachingKey.UserData, user.toJson());` | Confirmed by reading code | Plaintext tokens and user PII (names, phones, GPS coordinates) exposed on device filesystem, violating OWASP Mobile M2. | Migrate all tokens and PII to `FlutterSecureStorage` via existing `SecureAuthValueStore`. Keep only non-sensitive UI flags in `GetStorage`. | **M** |
| **MOB-08** | Money & Booking | **High** | `lib/features/checkout/presentation/checkout_cubit.dart:366-384`, `lib/features/checkout/presentation/widgets/vodafone_cash_bottom_sheet.dart:215-252` | In `processPayment`: missing check for `state.status == CheckoutStatus.loading`. In `_handleSubmit`: missing check for `_isUploading`. | Confirmed by reading code | Rapid taps submit duplicate checkout RPC calls with same hold token, leading to race condition crashes or double charge confusion. | Add atomic re-entrancy guards in both `_handleSubmit` and `processPayment` before async execution. | **S** |
| **MOB-09** | Performance & UX | **High** | `lib/features/main/presentation/main_screen.dart:61-62, 134, 172-180` | `BlocListener<ActiveSessionCubit, ActiveSessionState>( listenWhen: (prev, curr) => prev.status != ActiveSessionStatus.loaded && curr.status == ActiveSessionStatus.loaded && curr.session != null, listener: (context, state) { context.pushNamed(RouterKeys.activeSession); })` | Confirmed by reading code | Users who have an active session get forcibly hijacked and pushed to `ActiveSessionScreen` every time they switch tabs or navigate back. | Remove auto-push listener; rely strictly on `ActiveSessionBanner` on Home screen for user-initiated navigation. | **S** |
| **MOB-10** | Performance & Supabase | **High** | `lib/features/booking/presentation/booking_cubit.dart:163-178`, `lib/features/my_bookings/presentation/quick_rebook_cubit.dart:89-103` | `for (final rid in roomIds) { final result = await _bookingRepository.getRoomBookingsForDate(loungeId, date, roomId: rid); ... }` | Confirmed by reading code & migrations | Lounge with 10 rooms triggers 10 sequential RPC network requests for identical data that `get_room_bookings_for_operational_date` returns in one call. | Call `getRoomBookingsForDate` once per lounge/date and partition slots in-memory across room IDs. | **M** |
| **MOB-11** | Business Logic | **High** | `lib/core/models/payment_model.dart:6-7`, `lib/features/lounge_details/data/models/room_model.dart:13-15`, `lib/features/booking/data/models/booking_params.dart` | `final double amount; final double? discountAmount; final double hourlyRateSingle;` (189 occurrences) | Confirmed by running regex scan | IEEE-754 floating-point inaccuracies when calculating discounts, additions, and currency totals. | Standardize monetary representation to integer piastres (e.g. `int priceInPiastres`) or dedicated decimal value objects. | **L** |
| **MOB-12** | Money & Booking | **High** | `lib/features/active_session/data/datasources/remote/active_session_remote_data_source.dart:464-474` | `await _client.rpc('place_canteen_order', params: {'p_booking_id': bookingId, 'p_items': formattedItems});` | Confirmed by reading code & migrations | Missing `p_idempotency_key` parameter supported by database RPC. Retried network calls cause duplicate canteen charges. | Generate and pass a client UUID idempotency key `p_idempotency_key: const Uuid().v4()` with every canteen order submission. | **S** |
| **MOB-13** | Business Logic | **High** | `lib/features/active_session/data/models/active_session_model.dart:228-230, 270-294`, `lib/features/my_bookings/data/models/booking_dates_decoder.dart:22-29` | `final fullIso = "${dateStr}T$timeStr"; ... if (local.isAfter(defaultStart)) return local; ... return defaultStart.add(const Duration(minutes: 30));` | Confirmed by reading code | For overnight gaming lounge bookings crossing midnight (e.g. 23:00 to 02:00), end time is rejected as before start time and clamped to 30 mins. Timezones without offset drift with client device clock. | Calculate cross-midnight end times by adding 1 day if end time is numerically earlier than start time. Parse in Cairo timezone (`Africa/Cairo`). | **M** |
| **MOB-14** | Performance & State | **Medium** | `lib/features/notifications/data/datasources/remote/notifications_remote_data_source.dart:73-100` | `_channel = _client.channel('public:notifications:user_$userId')...` | Confirmed by reading code | Calling `streamUserNotifications` multiple times overwrites `_channel` reference without disposing the old channel, leaking WebSocket channels. | Add idempotent cleanup before instantiating new channel: call `_cleanupRealtime()` before creating a new subscription. | **S** |
| **MOB-15** | Supabase & Networking | **Medium** | `lib/features/active_session/data/datasources/remote/active_session_remote_data_source.dart:74-130` | `final rpcRes = await _client.rpc('get_active_session_details', ...); ... catch (e) { dev.log("[LIVESESSION_DS] RPC get_active_session_details failed: $e, falling back to selectQuery"); }` | Confirmed by reading code & migrations | Every single active session load produces an unnecessary failing network request before executing the fallback select query. | Remove dead call to `get_active_session_details` or implement it in database migrations. | **S** |
| **MOB-16** | Security & Privacy | **Medium** | `lib/features/tournaments/data/datasources/remote/tournaments_remote_data_source.dart:323-334, 399-414` | `final bytes = await proofFile.readAsBytes(); ... proofUrl = await _client.storage.from('tournament-result-proofs').createSignedUrl(storagePath, 60 * 60 * 24 * 365);` | Confirmed by reading code | Bypasses `StorageService`. Large image uploads read entire file into RAM risking mobile OOM crashes. 1-year signed URLs create unnecessary data exposure. | Validate file size (<5MB) before read, use streaming upload, route through `StorageService`, and restrict signed URLs to 1 hour max. | **S** |
| **MOB-17** | Security & iOS Config | **Medium** | `ios/Runner/Info.plist:75-78` | `<key>NSLocationAlwaysUsageDescription</key> <string>We need your location to show nearby gaming lounges.</string>` | Confirmed by reading code | Requests background "Always" location tracking without iOS 11 required paired keys or legitimate background location need. No Arabic `InfoPlist.strings`. | Remove `NSLocationAlwaysUsageDescription`, keep only `NSLocationWhenInUseUsageDescription`, and add localized `ar.lproj/InfoPlist.strings`. | **S** |
| **MOB-18** | Architecture | **Medium** | `lib/art_core/router/app_router.dart:395` | `create: (context) => sl<SearchCubit>()..search(),` | Confirmed by reading code | Cascaded network call inside `GoRoute.builder` `create:` executes asynchronous side-effect during widget tree construction, violating Rule 2. | Remove `..search()` cascade; trigger `search()` inside `SearchScreen.initState()` after mounting. | **S** |
| **MOB-19** | Error Handling | **Medium** | `lib/features/profile/data/datasources/remote/support_remote_data_source.dart:29, 56`, `lib/core/services/social_auth_service.dart:70, 77` | `} catch (_) {}` (48 occurrences in codebase) | Confirmed by running regex scan | Failures in FAQs, policies, and auth are suppressed, leaving screens empty with no error state or retry button. | Replace empty catch blocks with structured error logging (`AppLogger.error`) and propagate localized failures. | **M** |
| **MOB-20** | Error Handling & UX | **Medium** | `lib/features/my_bookings/presentation/my_bookings_cubit.dart:78`, `lib/features/profile/presentation/profile/profile_cubit.dart:123` | `emit(state.copyWith(status: MyBookingsStatus.failure, errorMessage: e.toString()));` | Confirmed by reading code | Raw database exception strings (e.g. `PostgrestException(message: ..., code: 42883)`) are exposed directly to the end user. | Map exceptions to user-friendly localized messages (`AppLocalizations`) via `Failure` domain hierarchy. | **S** |
| **MOB-21** | Localization & RTL | **Medium** | `lib/art_core/widgets/lounge/lounge_category_icon.dart:14`, `lib/core/utils/booking_error_formatter.dart`, 58 files with raw Arabic | `padding: EdgeInsets.only(right: AppSizes.w4)` and hardcoded Arabic strings in logic files. | Confirmed by running code scan | Violates RTL directional mirroring rules; English locale users see Arabic strings in formatters and validators. | Replace `EdgeInsets.only(right: ...)` with `EdgeInsetsDirectional.only(end: ...)`. Move all hardcoded strings into `ar.json` / `en.json`. | **M** |
| **MOB-22** | Code Quality | **Medium** | Codebase wide (e.g. `lib/features/lounge_details/...`) | 109 analyzer issues: 45 `deprecated_member_use`, 33 `constant_identifier_names`, 17 `curly_braces_in_flow_control_structures`. | Confirmed by running `flutter analyze` | Technical debt, reliance on deprecated APIs (`WillPopScope`, old ThemeData text styles). | Apply `dart fix --apply` (resolves 71 issues) and manually resolve remaining deprecations. | **S** |
| **MOB-23** | Quality & Testing | **Medium** | `lib/features/checkout/`, `lib/features/tournaments/`, `lib/features/auth/` | Total line coverage: 23.87% (5,966 / 24,991 lines). Checkout coverage is only 9.22%, Tournaments 2.78%, Auth 4.56%. | Confirmed by running `flutter test --coverage` | Critical financial and checkout failure paths lack regression safety nets. | Add unit and bloc tests for checkout failure paths, receipt handling, and hold expiration scenarios. | **L** |
| **MOB-24** | Dependencies | **Low** | `pubspec.lock`, `pubspec.yaml` | 44 upgradable dependencies locked, including `equatable` (3.0.0), `flutter_secure_storage` (11.2.0), `supabase_flutter` (2.9.1). | Confirmed by running `flutter pub outdated` | Running behind upstream maintenance and security patches. | Plan controlled dependency upgrade cycle in separate PR, verifying test suites after upgrades. | **M** |
| **MOB-25** | Extensibility | **Medium** | `lib/features/booking/presentation/booking_cubit.dart`, `lib/core/services/deep_link_service.dart` | Hardcoded hourly pricing assumptions; no package pass redemption; deep linking only handles basic referral query parameter. | Confirmed by reading code | Architecture will break upon introducing hour packages, peak/off-peak pricing, and custom lounge/tournament deep links. | Decouple room pricing from fixed hourly formulas to server quotes; generalize deep link router to handle route paths. | **L** |

---

## 3. Measurements and Metrics

### 3.1 What Was Actually Measured

| Command / Tool | Execution Result | Exact Numbers & Metrics | Notes & Caveats |
|---|---|---|---|
| `git status & branch` | Exit Code 0 | Clean working tree on branch `comprehensive_codebase_audit_report` tracking `dev` commit `d0cd9ed`. | Head matches remote `origin/dev`. |
| `flutter pub outdated` | Exit Code 0 | **44 upgradable packages** locked in `pubspec.lock`. Direct upgradable: `cached_network_image`, `connectivity_plus`, `equatable` (3.0.0), `firebase_core`, `firebase_messaging`, `flutter_cache_manager`, `flutter_local_notifications`, `flutter_secure_storage` (11.2.0), `geolocator`, `get_it`, `go_router`, `google_fonts`, `intl`, `package_info_plus`, `share_plus`, `supabase_flutter` (2.9.1), `table_calendar`, `url_launcher`. | 2 major updates (`equatable`, `flutter_secure_storage`) require migration testing. |
| `flutter pub deps` | Exit Code 0 | Full dependency tree resolved; 0 dependency conflicts. | No conflicting transitive dependency overrides detected. |
| `flutter analyze` | Exit Code 0 (non-fatal) | **109 total issues**: 45 `deprecated_member_use`, 33 `constant_identifier_names`, 17 `curly_braces_in_flow_control_structures`, 3 `use_null_aware_elements`, 2 `use_super_parameters`, 2 `unnecessary_underscores`, 2 `unnecessary_import`, 2 `prefer_initializing_formals`, 1 `unnecessary_this`, 1 `unnecessary_const`, 1 `file_names`. | Saved full log to scratch directory for Phase 2 reference. |
| `dart fix --dry-run` | Exit Code 0 | **71 proposed fixes across 23 files** automatically fixable. | Mechanical fixes: missing braces, super params, null aware elements. |
| `flutter test --coverage` | Exit Code 0 | **381/381 tests passed** (0 failures, 0 skipped). Total lines: 24,991; Hit lines: 5,966; **Overall coverage: 23.87%**. | Test coverage by module: Checkout: **9.22%**, Tournaments: **2.78%**, Search: **1.16%**, Auth: **4.56%**, App Status: **4.66%**, Profile: **17.10%**, Booking: **28.19%**, Active Session: **28.68%**, My Bookings: **34.31%**, Lounge Details: **53.40%**, Art Core: **30.07%**, Core: **37.11%**. |
| `python3 rpc_scan.py` | Exit Code 0 | **62 unique `.rpc()` call sites** in `lib/`. 27 exist in database migrations, **35 missing or mismatched** in backend migrations. | Mapped all 62 RPCs directly to SQL migrations. |
| `python3 table_mutations.py` | Exit Code 0 | **18 direct table mutation sites** (`.insert()`, `.update()`, `.delete()`). | Identified dead fallback client writes to `bookings`. |
| `python3 empty_catches.py` | Exit Code 0 | **48 empty catch blocks** (`catch (_) {}`). | Suppressing critical networking and parsing exceptions. |
| `python3 localization_check.py` | Exit Code 0 | `ar.json` (699 keys), `en.json` (699 keys). **Parity: 100%**. 58 files have hardcoded Arabic strings outside localization. | Keys match, but extensive strings in logic and dialogs are hardcoded. |

---

### 3.2 What Was Not Measured and Why

1. **`flutter build apk --analyze-size`**:
   - **Reason**: The developer machine's Android Studio JBR defaults to OpenJDK 25.0.3 (`class file version 69.0`), which causes Gradle 8.14 to abort (`Unsupported class file major version 69`). Resolving this requires reconfiguring the developer's global Flutter configuration (`flutter config --jdk-dir`) or system Java environment, which is prohibited under the Phase 1 read-and-measure constraint.
2. **Live DevTools Profiling (Home → Booking → Active Session FPS, Rebuilds, Memory)**:
   - **Reason**: While a physical iPhone (`iPhone Salah`, iOS 18.7.10) is connected via network/cable, there was no active debugging session running, no Apple Developer provisioning certificate configured for unsigned CLI deployment, and no Android emulator running. To strictly honor the instruction *"Never claim you ran a test, measured FPS, or tried a device if you did not. State explicitly what was not checked and why"*, live FPS profiling was not executed.

---

## 4. App-Versus-Schema Gaps

The table below lists all 35 RPC calls found in the mobile codebase that **do not exist** in the `supabase/migrations/` repository files for Supabase project `tgpdexoitemmpruepgyt`.

| # | RPC Name Called by Mobile App | Calling File & Line | Expected Parameters in App | Current Database Status in Migrations | Consequence / User Impact |
|---|---|---|---|---|---|
| **1** | `attach_my_booking_receipt` | `booking_remote_data_source.dart:271` | `p_booking_id`, `p_receipt_url` | **MISSING** | Receipt attachment fails on every manual transfer booking; customer warned of upload failure. |
| **2** | `cancel_my_booking` | `my_bookings_remote_data_source.dart:62` | `p_booking_id`, `p_reason` | **MISSING** | Customer cancellation fails with PostgreSQL error `42883`. |
| **3** | `extend_booking_session` | `active_session_remote_data_source.dart:408` | `p_booking_id`, `p_additional_minutes`, `p_additional_cost` | **MISSING** (Backend has `request_booking_extension(uuid, int)`) | Session extension fails. Submits client-computed financial values. |
| **4** | `get_active_session_details` | `active_session_remote_data_source.dart:75` | `p_booking_id` | **MISSING** | Extra failing network request on every active session screen load before falling back to table select. |
| **5** | `get_user_points_balance` | `profile_remote_data_source.dart:121` | `p_user_id` | **MISSING** | Throws error; silent catch block returns 0 points. Balance always shows 0. |
| **6** | `get_points_transactions_page` | `profile_remote_data_source.dart:147` | `p_page`, `p_page_size` | **MISSING** | Throws error; falls back to missing `get_points_history`. |
| **7** | `get_points_history` | `profile_remote_data_source.dart:158` | (none) | **MISSING** | Throws error; silent catch block returns empty transactions list. |
| **8** | `redeem_points` | `profile_remote_data_source.dart:196` | `p_user_id`, `p_redemption_option_id` | **MISSING** | Points redemption fails; returns `{'success': false}`. |
| **9** | `get_loyalty_status` | `profile_remote_data_source.dart:425` | `p_user_id` | **MISSING** | Loyalty tier data fails to load. |
| **10** | `get_my_vouchers` | `profile_remote_data_source.dart:84` | (none) | **MISSING** | Silent catch returns empty list `[]`; user sees no vouchers. |
| **11** | `validate_voucher` | `profile_remote_data_source.dart:94` | `p_voucher_id` | **MISSING** (Backend has `validate_voucher_by_code`) | Validation by voucher ID fails. |
| **12** | `consume_voucher` | `profile_remote_data_source.dart:56, 73` | `p_voucher_id` | **MISSING** (Backend has `consume_voucher_by_code`) | Voucher consumption fails if called by ID. |
| **13** | `get_visible_tournaments` | `tournaments_remote_data_source.dart:108` | `p_latitude`, `p_longitude` | **MISSING** | Tournaments list fails to load. |
| **14** | `get_home_tournament` | `tournaments_remote_data_source.dart:212` | (none) | **MISSING** | Home screen tournament banner fails to load. |
| **15** | `register_for_tournament` | `tournaments_remote_data_source.dart:296` | `p_tournament_id` | **MISSING** | Tournament registration impossible. |
| **16** | `submit_match_result` | `tournaments_remote_data_source.dart:418` | `p_match_id`, `p_score_player1`, `p_score_player2`, `p_proof_image_url` | **MISSING** | Players cannot submit match scores. |
| **17** | `withdraw_from_tournament` | `tournaments_remote_data_source.dart:480` | `p_participant_id` | **MISSING** | Players cannot withdraw from tournaments. |
| **18** | `check_in_tournament_participant` | `tournaments_remote_data_source.dart:363` | `p_participant_id` | **MISSING** | Check-in fails. |
| **19** | `get_tournament_audit_logs_page` | `tournaments_remote_data_source.dart:537` | `p_tournament_id`, `p_page`, `p_page_size` | **MISSING** | Audit logs fail to load. |
| **20** | `get_notifications_page` | `notifications_remote_data_source.dart:22` | `p_page`, `p_page_size` | **MISSING** | Notifications list fails to load. |
| **21** | `mark_notification_read` | `notifications_remote_data_source.dart:45` | `p_notification_id` | **MISSING** | Notification read status update fails. |
| **22** | `mark_all_notifications_read` | `notifications_remote_data_source.dart:59` | (none) | **MISSING** | Mark all read fails. |
| **23** | `get_public_support_settings` | `support_remote_data_source.dart:21` | (none) | **MISSING** | Returns empty map `{}`; support contact info blank. |
| **24** | `get_public_policies` | `support_remote_data_source.dart:37, 48` | `p_lang` / `lang` | **MISSING** | Returns empty list `[]`; policies screen blank. |
| **25** | `get_public_faqs` | `support_remote_data_source.dart:65, 76` | `p_lang` / `lang` | **MISSING** | Returns empty list `[]`; FAQs screen blank. |
| **26** | `create_support_ticket` | `support_remote_data_source.dart:94` | `p_subject`, `p_message`, `p_category` | **MISSING** | Support ticket submission fails. |
| **27** | `delete_user_account` | `profile_remote_data_source.dart:475` | (none) | **MISSING** | Account deletion fails (App Store guideline 5.1.1(v) risk). |
| **28** | `get_available_cities` | `home_remote_data_source_impl.dart:82` | (none) | **MISSING** | City filter returns empty. |
| **29** | `get_active_promos` | `home_remote_data_source_impl.dart:104` | (none) | **MISSING** | Promos carousel returns empty. |
| **30** | `get_lounge_categories` | `home_remote_data_source_impl.dart:126` | (none) | **MISSING** | Categories list fails to load via RPC. |
| **31** | `get_lounge_bookings_page` | `lounge_details_remote_data_source.dart:84` | `p_lounge_id`, `p_page`, `p_page_size` | **MISSING** | Paginated bookings fail. |
| **32** | `get_lounge_reviews_page` | `lounge_details_remote_data_source.dart:198` | `p_lounge_id`, `p_page`, `p_page_size` | **MISSING** | Paginated reviews fail. |
| **33** | `get_lounge_role_permissions_page`| `lounge_details_remote_data_source.dart:240` | `p_lounge_id`, `p_page`, `p_page_size` | **MISSING** | Role permissions check fails. |
| **34** | `get_active_lounge_requests_page` | `lounge_details_remote_data_source.dart:282` | `p_lounge_id`, `p_page`, `p_page_size` | **MISSING** | Active requests query fails. |
| **35** | `get_users_public_info` | `profile_remote_data_source.dart:610` | `p_user_ids` | **MISSING** | User info lookup fails. |

---

## 5. Prioritized Fix Plan

Following user instructions, fixes are strictly prioritized into phases. Every fix item defines explicit **Done Criteria** and a **Verification Test**.

### Phase 2.1: Critical Financial & Booking Flow Fixes

#### Fix 1: Eliminate Receipt Attachment Failure on Checkout (MOB-01)
- **Problem:** `attach_my_booking_receipt` does not exist on Supabase.
- **Done Criterion:** Manual transfer checkout either uploads receipt prior to `create_my_booking_checkout` and passes `p_receipt_url: receiptPath`, OR invokes a verified backend RPC. Checkout succeeds with `paymentProofUploadFailed: false`.
- **Test:** Unit & Bloc test in `test/features/checkout/checkout_cubit_test.dart` verifying that `processPayment` with a manual transfer receipt succeeds without triggering `paymentProofUploadFailed`.

#### Fix 2: Re-align Active Session Extension with Server Authority (MOB-02)
- **Problem:** `extend_booking_session` does not exist and submits client-calculated price (`p_additional_cost`).
- **Done Criterion:** Session extension calls the existing authoritative backend RPC `request_booking_extension(p_booking_id, p_requested_minutes)` without client pricing. Remove `calculateExtensionCost` fallback calculations from client entities.
- **Test:** Test in `test/features/active_session/active_session_cubit_test.dart` asserting that requesting extension dispatches `requestExtension` with exact parameters and handles pending extension status.

#### Fix 3: Remove Dead Client Direct Booking Writes (MOB-06)
- **Problem:** `createBooking` in `booking_remote_data_source.dart` retains client-authoritative table inserts and swallows canteen order failures.
- **Done Criterion:** Completely prune legacy `createBooking` from `BookingRemoteDataSource` and `BookingRepository`. All booking creation goes through `createBookingCheckout`.
- **Test:** Verify `flutter analyze` passes with zero references to `createBooking`.

#### Fix 4: Guard Against Checkout Double-Tap Race Conditions (MOB-08)
- **Problem:** Missing re-entrancy checks allow concurrent checkout RPC requests with the same hold token.
- **Done Criterion:** `CheckoutCubit.processPayment` immediately returns if `state.status == CheckoutStatus.loading`. `VodafoneCashBottomSheet._handleSubmit` immediately returns if `_isUploading == true`.
- **Test:** Test in `checkout_cubit_test.dart` verifying that two simultaneous calls to `processPayment` trigger exactly one call to `_bookingRepository.createBookingCheckout`.

---

### Phase 2.2: Security & Privacy Hardening

#### Fix 5: Migrate Sensitive Storage from GetStorage to Secure Storage (MOB-07)
- **Problem:** Auth tokens, user JSON, phone numbers, and GPS coordinates stored in plaintext `GetStorage`.
- **Done Criterion:** All tokens (`AUTH_TOKEN`, `TOKEN`, `FCM_TOKEN`) and user PII (`UserData`, `PhoneNumber`) are read/written exclusively through `SecureAuthValueStore` (`FlutterSecureStorage`). `GetStorage` is retained only for non-sensitive local flags (e.g. `isFirstTime`, `selectedLanguage`).
- **Test:** Unit test in `test/core/cache/preference_manager_test.dart` verifying tokens are saved to and read from mocked `SecureAuthValueStore`.

#### Fix 6: Audit & Correct iOS Info.plist Location Permissions (MOB-17)
- **Problem:** Requesting `NSLocationAlwaysUsageDescription` without App Store justification or iOS 11 required keys.
- **Done Criterion:** Remove `NSLocationAlwaysUsageDescription` from `ios/Runner/Info.plist`. Retain only `NSLocationWhenInUseUsageDescription`. Add localized `ar.lproj/InfoPlist.strings`.
- **Test:** Validate `ios/Runner/Info.plist` against Apple App Store submission schema rules.

#### Fix 7: Restrict Storage Signed URLs & Add Upload Size Caps (MOB-16)
- **Problem:** Tournament receipt uploads bypass `StorageService`, lack size checks, and use 365-day signed URLs.
- **Done Criterion:** Route tournament uploads through `StorageService`, enforce 5MB maximum file length before reading bytes, and limit signed URLs to 1 hour (3600 seconds).
- **Test:** Unit test verifying upload rejects files exceeding 5MB before reading bytes.

---

### Phase 2.3: Lifecycle, State & Performance Optimizations

#### Fix 8: Remove Active Session Auto-Navigation Push Loop (MOB-09)
- **Problem:** Every tab switch triggers `loadActiveSession()` and forcibly pushes `ActiveSessionScreen`.
- **Done Criterion:** Remove the auto-push `BlocListener` in `MainScreen`. Users access active sessions voluntarily via the persistent banner or drawer.
- **Test:** Widget test in `test/features/main/main_screen_test.dart` verifying that tab switching with an active session does not trigger route navigation.

#### Fix 9: Eliminate N+1 Booking Slot Queries (MOB-10)
- **Problem:** `BookingCubit` loops through `roomIds` issuing sequential network requests for the same lounge data.
- **Done Criterion:** Call `getRoomBookingsForDate` once per lounge and partition slots in-memory across room IDs.
- **Test:** Unit test in `test/features/booking/booking_cubit_test.dart` asserting that fetching availability for 5 rooms triggers exactly 1 repository RPC call.

#### Fix 10: Fix Cross-Midnight End Time Clamping & Timezones (MOB-13)
- **Problem:** Overnight bookings (e.g. 23:00 to 02:00) clamped to 30 mins because end time is earlier than start time.
- **Done Criterion:** In `ActiveSessionModel` and `BookingDatesDecoder`, if end time is numerically less than or equal to start time, add 24 hours (1 day). Parse timestamps with Cairo offset (`+02:00` or `+03:00` depending on DST).
- **Test:** Unit test verifying a session starting at 23:00 and ending at 02:00 parses end time on `day + 1` with a duration of 180 minutes.

---

### Phase 2.4: Code Quality & Static Analysis Cleanup

#### Fix 11: Resolve 109 Flutter Analyzer Warnings (MOB-22)
- **Problem:** 109 warnings (45 deprecated members, 33 constant naming, 17 flow control braces).
- **Done Criterion:** Run `dart fix --apply` and manually resolve remaining warnings until `flutter analyze` outputs `0 issues`.
- **Test:** `flutter analyze --no-fatal-infos` exits with code 0.

#### Fix 12: Remove Provider Side-Effect in App Router (MOB-18)
- **Problem:** `create: (context) => sl<SearchCubit>()..search()` inside `app_router.dart:395`.
- **Done Criterion:** Remove `..search()` cascade; initiate search cleanly in `SearchScreen.initState()`.
- **Test:** Verify `app_router.dart` contains zero cascade `..` method invocations in provider `create:` blocks.

---

## 6. Backend Requests Required for Backend Team

The following backend requests must be provided to the backend engineer (stored in `docs/audits/backend_requests.md`):

1. **`attach_my_booking_receipt(p_booking_id uuid, p_receipt_url text)`**:
   - Provide SECURITY DEFINER function to link an uploaded receipt URL to an existing booking owned by `auth.uid()`, transitioning status to `payment_submitted`.
2. **`cancel_my_booking(p_booking_id uuid, p_reason text)`**:
   - Provide customer cancellation function validating cancellation window policies, releasing holds/slots, and logging cancellation reason.
3. **Points & Loyalty System Schema & RPCs**:
   - Deploy missing tables/RPCs: `get_user_points_balance(p_user_id uuid)`, `get_points_transactions_page(p_page int, p_page_size int)`, `redeem_points(...)`.
4. **Tournaments RPCs**:
   - Deploy `get_visible_tournaments(p_latitude float, p_longitude float)`, `register_for_tournament(p_tournament_id uuid)`, `submit_match_result(p_match_id uuid, p_score_player1 int, p_score_player2 int, p_proof_image_url text)`.
5. **Support & FAQs RPCs**:
   - Deploy `get_public_support_settings()`, `get_public_policies(p_lang text)`, `get_public_faqs(p_lang text)`.
