import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import '../../features/auth/data/models/user_model.dart';

import 'caching_key.dart';

class PreferenceManager {
  static Future<void> init() async {
    await GetStorage.init(); // default box
  }

  final GetStorage _box = GetStorage();

  Future<void> saveLatitude(double latitude) =>
      _box.write(CachingKey.latitude, latitude);

  String latitude() => _box.read(CachingKey.latitude)?.toString() ?? '';

  Future<void> saveLongitude(double longitude) =>
      _box.write(CachingKey.longitude, longitude);

  String longitude() => _box.read(CachingKey.longitude)?.toString() ?? '';

  Future<void> saveFCMToken(String fcmToken) =>
      _box.write(CachingKey.fcmToken, fcmToken);

  String fcmToken() => _box.read(CachingKey.fcmToken) as String? ?? "";

  Future<void> saveIsFirstTime(bool isFirstTime) =>
      _box.write(CachingKey.isFirstTime, isFirstTime);

  bool isFirstTime() => _box.read(CachingKey.isFirstTime) as bool? ?? true;

  Future<void> saveIsOpenAsGuestUser(bool isGustUser) =>
      _box.write(CachingKey.isGuestUser, isGustUser);

  bool isOpenAsGuestUser() =>
      _box.read(CachingKey.isGuestUser) as bool? ?? false;

  Future<void> saveIsLoggedIn(bool isLoggedIn) =>
      _box.write(CachingKey.isLoggedIn, isLoggedIn);

  bool get isLoggedIn => _box.read(CachingKey.isLoggedIn) as bool? ?? false;

  Future<void> saveAuthToken(String? authToken) =>
      _box.write(CachingKey.authToken, authToken ?? '');

  String authToken() => _box.read(CachingKey.authToken) as String? ?? "";

  Future<void> saveToken(String? cooke) =>
      _box.write(CachingKey.token, cooke ?? '');

  String token() => _box.read(CachingKey.token) as String? ?? "";

  Future<void> saveFullName(String? fullName) =>
      _box.write(CachingKey.fullName, fullName ?? '');

  String? fullName() => _box.read(CachingKey.fullName) as String? ?? "";

  Future<void> savePhoneNumber(String? phone) =>
      _box.write(CachingKey.phoneNumber, phone ?? '');

  String? phoneNumber() =>
      _box.read(CachingKey.phoneNumber) as String? ??
      getUserData()?.phone ??
      "";

  Future<void> saveValue(String cachingKey, String value) =>
      _box.write(cachingKey, value);

  String getValue(String cachingKey) => _box.read(cachingKey)?.toString() ?? "";

  Future<void> saveLanguage(String lang) =>
      _box.write(CachingKey.language, lang);

  String currentLang() {
    final savedLang = _box.read(CachingKey.language) as String?;
    if (savedLang != null) return savedLang;
    if (kIsWeb) return 'en';
    try {
      return Platform.localeName.split("_").firstOrNull ?? 'en';
    } catch (_) {
      return 'en';
    }
  }

  Future<void> saveUserId(String? userId) =>
      _box.write(CachingKey.userId, userId ?? '');

  String? userId() => _box.read(CachingKey.userId) as String? ?? "";

  Future<void> savePendingReferralCode(String? code) {
    if (code == null || code.trim().isEmpty) return Future.value();
    return _box.write(
      CachingKey.pendingReferralCode,
      code.trim().toUpperCase(),
    );
  }

  String getPendingReferralCode() {
    return _box.read(CachingKey.pendingReferralCode) as String? ?? '';
  }

  Future<void> clearPendingReferralCode() {
    return _box.remove(CachingKey.pendingReferralCode);
  }

  Future<void> saveUserData(UserModel user) {
    return _box.write(CachingKey.userData, user.toJson());
  }

  UserModel? getUserData() {
    final data = _box.read(CachingKey.userData);
    if (data != null) {
      return UserModel.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  Future<void> clearUserData() async {
    await _box.remove(CachingKey.userData);
    await _box.remove(CachingKey.userId);
    await _box.remove(CachingKey.fullName);
    await _box.remove(CachingKey.phoneNumber);
    await _box.remove(CachingKey.userDataBackup);
    await _box.remove(CachingKey.reviewedBookings);
    await _box.remove(CachingKey.cachedLounges);
    await _box.remove(CachingKey.currentAddress);
    await _box.remove(CachingKey.latitude);
    await _box.remove(CachingKey.longitude);
    await _box.remove(CachingKey.pendingReferralCode);
    await saveIsLoggedIn(false);

    // Session & Auth Cleanup: Clear local entity caches on logout
    final keys = _box.getKeys<Iterable<String>>();
    final keysToRemove = keys
        .where(
          (k) =>
              k.startsWith(CachingKey.loungeProfilesPrefix) ||
              k.startsWith(CachingKey.loungeRoomsPrefix) ||
              k.startsWith(CachingKey.loungeExtrasPrefix) ||
              k == CachingKey.categoriesCache ||
              k == CachingKey.promotionsCache,
        )
        .toList();

    for (final key in keysToRemove) {
      await _box.remove(key);
    }
  }

  // =========================
  // Apple Profile Cache (email/name first time)
  // =========================
  String _appleProfileKey(String appleUserId) =>
      '${CachingKey.appleProfilePrefix}$appleUserId';

  Future<void> saveAppleProfile({
    required String appleUserId,
    String? email,
    String? name,
  }) {
    return _box.write(_appleProfileKey(appleUserId), {
      'email': email,
      'name': name,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Map<String, dynamic>? getAppleProfile(String appleUserId) {
    final data = _box.read(_appleProfileKey(appleUserId));
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  bool? isDarkMode() => _box.read(CachingKey.isDarkMode) as bool?;

  void setDarkMode(bool? isDarkMode) =>
      _box.write(CachingKey.isDarkMode, isDarkMode);

  // --- Notification Settings ---
  Future<void> savePushEnabled(bool val) =>
      _box.write(CachingKey.pushNotifEnabled, val);
  bool pushEnabled() => _box.read(CachingKey.pushNotifEnabled) as bool? ?? true;

  Future<void> saveBookingUpdatesEnabled(bool val) =>
      _box.write(CachingKey.bookingUpdatesEnabled, val);
  bool bookingUpdatesEnabled() =>
      _box.read(CachingKey.bookingUpdatesEnabled) as bool? ?? true;

  Future<void> saveOffersEnabled(bool val) =>
      _box.write(CachingKey.offersEnabled, val);
  bool offersEnabled() => _box.read(CachingKey.offersEnabled) as bool? ?? true;

  Future<void> saveSystemNotifEnabled(bool val) =>
      _box.write(CachingKey.systemNotifEnabled, val);
  bool systemNotifEnabled() =>
      _box.read(CachingKey.systemNotifEnabled) as bool? ?? true;

  Future<void> saveTournamentsEnabled(bool val) =>
      _box.write(CachingKey.tournamentsEnabled, val);
  bool tournamentsEnabled() =>
      _box.read(CachingKey.tournamentsEnabled) as bool? ?? true;

  bool? isGuestUser() => authToken().isEmpty;

  // void saveActiveCountry(ActiveCountryModel activeCountry) =>
  //     _box.write(CachingKey.activeCountry, activeCountry.toJson());
  //
  // ActiveCountryModel? getActiveCountry() {
  //   final data = _box.read(CachingKey.activeCountry);
  //   if (data == null) return null;
  //   return ActiveCountryModel.fromJson(data);
  // }
  //
  // void logout() {
  //   LogoutService().logout();
  //   _box.remove(CachingKey.userData);
  //   _box.remove(CachingKey.userDataBackup);
  //
  //   _box.remove(CachingKey.authToken);
  //   _box.remove(CachingKey.fullName);
  //   saveIsLoggedIn(false);
  //   saveIsOpenAsGuestUser(true);
  //   GoogleAuthService().signOutFromGoogle();
  // }
  //
  // void login({required String authToken, required UserModel user, bool rememberMe = true}) {
  //   saveUserId(user.id.toString());
  //   saveIsOpenAsGuestUser(false);
  //   saveAuthToken(authToken);
  //   saveIsLoggedIn(true);
  //   saveFullName(user.name);
  //   saveUserData(user);
  // }
  //
  // void changeLanguage(BuildContext context, String lang) {
  //   if (currentLang() == lang) return;
  //   context.setLocale(Locale(lang));
  //   saveLanguage(lang);
  // }
}
