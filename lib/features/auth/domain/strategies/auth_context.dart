import 'auth_strategy.dart';
import '../../data/models/user_model.dart';
import '../../../../art_core/exceptions/app_exceptions.dart';

/// Context class for Authentication Strategy Pattern.
/// Encapsulates strategy selection and execution, shielding caller classes
/// from provider-specific authentication logic (Open/Closed Principle).
class AuthContext {
  final Map<AuthProviderType, AuthStrategy> _strategies = {};

  AuthContext(List<AuthStrategy> strategies) {
    for (final strategy in strategies) {
      _strategies[strategy.providerType] = strategy;
    }
  }

  /// Register or override an authentication strategy
  void registerStrategy(AuthStrategy strategy) {
    _strategies[strategy.providerType] = strategy;
  }

  /// Executes authentication using the strategy registered for [provider]
  Future<UserModel> authenticate({
    required AuthProviderType provider,
    Map<String, dynamic> credentials = const {},
  }) async {
    final strategy = _strategies[provider];
    if (strategy == null) {
      throw AppException('Unsupported auth provider: $provider');
    }
    return strategy.authenticate(credentials);
  }
}
