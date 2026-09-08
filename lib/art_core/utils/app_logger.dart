import 'package:flutter/foundation.dart';

/// Centralized logger utility for the application adhering to AGENT_RULES.md (Rule 12).
class AppLogger {
  const AppLogger._();

  static void info(String message) {
    if (kDebugMode) {
      debugPrint('ℹ️ [INFO] $message');
    }
  }

  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('🔍 [DEBUG] $message');
    }
  }

  static void warning(String message) {
    if (kDebugMode) {
      debugPrint('⚠️ [WARNING] $message');
    }
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('❌ [ERROR] $message');
      if (error != null) {
        debugPrint('   Details: $error');
      }
      if (stackTrace != null) {
        debugPrint('   StackTrace: $stackTrace');
      }
    }
  }
}
