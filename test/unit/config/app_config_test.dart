import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/core/constants/app_config.dart';

void main() {
  group('AppConfig Unit Tests', () {
    test('Supabase config comes only from compile-time environment', () {
      const expectedUrl = String.fromEnvironment('SUPABASE_URL');
      const expectedAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

      expect(AppConfig.supabaseUrl, expectedUrl);
      expect(AppConfig.supabaseAnonKey, expectedAnonKey);
    });

    test('app name is defined', () {
      expect(AppConfig.appName, 'PlaySpot');
    });
  });
}
