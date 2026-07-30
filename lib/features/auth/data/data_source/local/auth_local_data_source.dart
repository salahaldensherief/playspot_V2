import '../../../../../core/cache/preference_manager.dart';
import '../../models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<void> saveUserData(UserModel user);
  UserModel? getCachedUser();
  Future<void> clearUserData();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final PreferenceManager _preferenceManager;

  AuthLocalDataSourceImpl(this._preferenceManager);

  @override
  Future<void> saveUserData(UserModel user) async {
    await _preferenceManager.saveUserId(user.id);
    await _preferenceManager.saveFullName(user.name);
    await _preferenceManager.saveIsLoggedIn(true);
    await _preferenceManager.saveUserData(user);
  }

  @override
  UserModel? getCachedUser() {
    return _preferenceManager.getUserData();
  }

  @override
  Future<void> clearUserData() async {
    await _preferenceManager.clearUserData();
  }
}
