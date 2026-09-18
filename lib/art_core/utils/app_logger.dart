import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Centralized logger utility for the application featuring formatted borders, colors, and clean JSON/error stacks.
class AppLogger {
  const AppLogger._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 1,
      errorMethodCount: 5,
      lineLength: 90,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTime,
    ),
  );

  static void info(String message) {
    if (kDebugMode) {
      _logger.i(message);
    }
  }

  static void debug(String message) {
    if (kDebugMode) {
      _logger.d(message);
    }
  }

  static void warning(String message) {
    if (kDebugMode) {
      _logger.w(message);
    }
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _logger.e(message, error: error, stackTrace: stackTrace);
    }
  }

  static void json(dynamic jsonObject) {
    if (kDebugMode) {
      _logger.i(jsonObject);
    }
  }
}
