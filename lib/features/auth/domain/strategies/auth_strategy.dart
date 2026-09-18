import '../../data/models/user_model.dart';

/// Enum representing supported authentication providers in the application.
enum AuthProviderType {
  email,
  google,
  facebook,
}

/// Abstract Strategy interface for authentication.
/// Each authentication provider implements this contract, following the Strategy Pattern
/// and Single Responsibility Principle (SRP).
abstract class AuthStrategy {
  /// Unique provider type identifying the strategy
  AuthProviderType get providerType;

  /// Authenticates user and returns the [UserModel]
  Future<UserModel> authenticate(Map<String, dynamic> credentials);
}
