class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => 'AppException: $message ${code != null ? '(code: $code)' : ''}';
}

// ─── Auth Exceptions ──────────────────────────────────────────
class EmailAlreadyInUseException extends AppException {
  const EmailAlreadyInUseException()
      : super('Email already in use', code: 'email_already_in_use');
}

class InvalidCredentialsException extends AppException {
  const InvalidCredentialsException()
      : super('Invalid email or password', code: 'invalid_credentials');
}

class UserNotFoundException extends AppException {
  const UserNotFoundException()
      : super('User not found', code: 'user_not_found');
}

class GoogleSignInCancelledException extends AppException {
  const GoogleSignInCancelledException()
      : super('Google sign in cancelled', code: 'google_cancelled');
}

class FacebookSignInCancelledException extends AppException {
  const FacebookSignInCancelledException()
      : super('Facebook sign in cancelled', code: 'facebook_cancelled');
}

class NetworkException extends AppException {
  const NetworkException()
      : super('No internet connection', code: 'network_error');
}

class ServerException extends AppException {
  const ServerException([String message = 'Server error'])
      : super(message, code: 'server_error');
}

class UnknownException extends AppException {
  const UnknownException([String message = 'Something went wrong'])
      : super(message, code: 'unknown');
}