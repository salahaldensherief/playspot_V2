import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/features/app_status/data/models/app_status_model.dart';

void main() {
  const payload = <String, dynamic>{
    'maintenance_mode': true,
    'maintenance_message': 'legacy maintenance',
    'maintenance_message_ar': 'صيانة عربية',
    'maintenance_message_en': 'English maintenance',
    'maintenance_until': '2026-10-01T12:00:00Z',
    'min_supported_version_android': '2.1.0',
    'min_supported_version_ios': '2.2.0',
    'latest_version_android': '2.5.0',
    'latest_version_ios': '2.6.0',
    'update_message': 'legacy update',
    'update_message_ar': 'تحديث عربي',
    'update_message_en': 'English update',
    'store_url_android': 'https://example.com/android',
    'store_url_ios': 'https://example.com/ios',
  };

  test('maps Android app-status version contract', () {
    final model = AppStatusModel.fromJson(
      payload,
      platform: TargetPlatform.android,
    );

    expect(model.maintenanceMode, isTrue);
    expect(model.minSupportedVersion, '2.1.0');
    expect(model.latestVersion, '2.5.0');
    expect(model.maintenanceMessageFor('ar'), 'صيانة عربية');
    expect(model.maintenanceMessageFor('en'), 'English maintenance');
    expect(model.updateMessageFor('ar'), 'تحديث عربي');
    expect(model.updateMessageFor('en'), 'English update');
  });

  test('maps iOS app-status version contract', () {
    final model = AppStatusModel.fromJson(
      payload,
      platform: TargetPlatform.iOS,
    );

    expect(model.minSupportedVersion, '2.2.0');
    expect(model.latestVersion, '2.6.0');
    expect(model.storeUrlIos, 'https://example.com/ios');
  });

  test('falls back to legacy single-language messages', () {
    final model = AppStatusModel.fromJson(
      const {
        'maintenance_mode': false,
        'maintenance_message': 'legacy maintenance',
        'update_message': 'legacy update',
      },
      platform: TargetPlatform.android,
    );

    expect(model.maintenanceMessageFor('ar'), 'legacy maintenance');
    expect(model.maintenanceMessageFor('en'), 'legacy maintenance');
    expect(model.updateMessageFor('ar'), 'legacy update');
    expect(model.updateMessageFor('en'), 'legacy update');
    expect(model.minSupportedVersion, '1.0.0');
    expect(model.latestVersion, '1.0.0');
  });
}
