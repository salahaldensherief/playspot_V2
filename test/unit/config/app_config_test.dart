import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/core/constants/app_config.dart';

void main() {
  group('AppConfig Unit Tests', () {
    test('supabaseUrl should not be empty and should have a valid URL format', () {
      expect(AppConfig.supabaseUrl.isNotEmpty, isTrue);
      expect(AppConfig.supabaseUrl.startsWith('http'), isTrue);
    });

    test('supabaseAnonKey should not be empty', () {
      expect(AppConfig.supabaseAnonKey.isNotEmpty, isTrue);
    });

    test('appName and appVersion should be properly defined', () {
      expect(AppConfig.appName, 'PlaySpot');
      expect(AppConfig.appVersion.isNotEmpty, isTrue);
    });
  });
}
