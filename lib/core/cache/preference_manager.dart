import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:get_storage/get_storage.dart';
import '../../features/auth/data/models/user_model.dart';

import 'caching_key.dart';

class PreferenceManager {
  static Future<void> init() async {
    await GetStorage.init(); // default box
  }

  final GetStorage _box = GetStorage();

  Future<void> saveLatitude(double latitude) => _box.write(CachingKey.LATITUDE, latitude);

  String latitude() => _box.read(CachingKey.LATITUDE)?.toString() ?? '';

  Future<void> saveLongitude(double longitude) => _box.write(CachingKey.LONGITUDE, longitude);

  String longitude() => _box.read(CachingKey.LONGITUDE)?.toString() ?? '';

  Future<void> saveFCMToken(String fcmToken) => _box.write(CachingKey.FCM_TOKEN, fcmToken);

  String fcmToken() => _box.read(CachingKey.FCM_TOKEN) as String? ?? "";

  Future<void> saveIsFirstTime(bool isFirstTime) => _box.write(CachingKey.IS_FIRST_TIME, isFirstTime);

  bool isFirstTime() => _box.read(CachingKey.IS_FIRST_TIME) as bool? ?? true;

  Future<void> saveIsOpenAsGuestUser(bool isGustUser) => _box.write(CachingKey.IS_GUEST_USER, isGustUser);

  bool isOpenAsGuestUser() => _box.read(CachingKey.IS_GUEST_USER) as bool? ?? false;

  Future<void> saveIsLoggedIn(bool isLoggedIn) => _box.write(CachingKey.IS_LOGGED_IN, isLoggedIn);

  bool get isLoggedIn => _box.read(CachingKey.IS_LOGGED_IN) as bool? ?? false;

  Future<void> saveAuthToken(String? authToken) => _box.write(CachingKey.AUTH_TOKEN, authToken ?? '');

  String authToken() => _box.read(CachingKey.AUTH_TOKEN) as String? ?? "";

  Future<void> saveToken(String? cooke) => _box.write(CachingKey.TOKEN, cooke ?? '');

  String token() => _box.read(CachingKey.TOKEN) as String? ?? "";

  // bool get isSubscribed => (getUserData()?.isSubscribe ?? false);

  Future<void> saveFullName(String? fullName) => _box.write(CachingKey.FullName, fullName ?? '');

  String? fullName() => _box.read(CachingKey.FullName) as String? ?? "";

  // String? phoneNumber() => getUserData()?.mobileNumber ?? '';
  //
  // String? countryCode() => getUserData()?.countryCode ?? '';

  Future<void> saveValue(String cachingKey, String value) => _box.write(cachingKey, value);

  String getValue(String cachingKey) => _box.read(cachingKey) as String;

  Future<void> saveLanguage(String lang) => _box.write(CachingKey.LANGUAGE, lang);

  String currentLang() =>
      _box.read(CachingKey.LANGUAGE) as String? ?? Platform.localeName.split("_").firstOrNull ?? 'en';

  Future<void> saveUserId(String? userId) => _box.write(CachingKey.UserId, userId ?? '');

  String? userId() => _box.read(CachingKey.UserId) as String? ?? "";

  Future<void> saveUserData(UserModel user) {
    return _box.write(CachingKey.UserData, user.toJson());
  }

  UserModel? getUserData() {
    final data = _box.read(CachingKey.UserData);
    if (data != null) {
      return UserModel.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  Future<void> clearUserData() async {
    await _box.remove(CachingKey.UserData);
    await _box.remove(CachingKey.UserId);
    await _box.remove(CachingKey.FullName);
    await saveIsLoggedIn(false);
  }


  // =========================
  // Apple Profile Cache (email/name first time)
  // =========================
  String _appleProfileKey(String appleUserId) => '${CachingKey.AppleProfilePrefix}$appleUserId';

  Future<void> saveAppleProfile({required String appleUserId, String? email, String? name}) {
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

  // UserModel? getUserData() {
  //   final data = _box.read(CachingKey.UserData);
  //   if (data == null) return null;
  //   return UserModel.fromJson(data);
  // }

  bool? isDarkMode() => _box.read(CachingKey.IS_DARK_MODE) as bool?;

  void setDarkMode(bool? isDarkMode) => _box.write(CachingKey.IS_DARK_MODE, isDarkMode);

  bool? isGuestUser() => authToken().isEmpty;

  // void saveActiveCountry(ActiveCountryModel activeCountry) =>
  //     _box.write(CachingKey.ActiveCountry, activeCountry.toJson());
  //
  // ActiveCountryModel? getActiveCountry() {
  //   final data = _box.read(CachingKey.ActiveCountry);
  //   if (data == null) return null;
  //   return ActiveCountryModel.fromJson(data);
  // }
  //
  // void logout() {
  //   LogoutService().logout();
  //   _box.remove(CachingKey.UserData);
  //   _box.remove(CachingKey.UserDataBackup);
  //
  //   _box.remove(CachingKey.AUTH_TOKEN);
  //   _box.remove(CachingKey.FullName);
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
