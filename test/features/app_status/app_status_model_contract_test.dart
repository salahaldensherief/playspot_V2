import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/features/app_status/data/models/app_status_model.dart';

void main() {
  test('maps canonical app_status columns', () {
    final model = AppStatusModel.fromJson({
      'maintenance_mode': true,
      'maintenance_message': 'Maintenance',
      'maintenance_until': '2026-09-28T01:00:00Z',
      'min_supported_version_android': '2.3.0',
      'min_supported_version_ios': '2.2.0',
      'latest_version_android': '2.5.0',
      'latest_version_ios': '2.4.0',
      'store_url_android': 'https://example.com/android',
      'store_url_ios': 'https://example.com/ios',
      'update_message': 'Update available',
    });

    expect(model.maintenanceMode, isTrue);
    expect(model.maintenanceMessage, 'Maintenance');
    expect(model.expectedEndTime, isNotNull);
    expect(model.minSupportedVersion, isNot('1.0.0'));
    expect(model.latestVersion, isNot('1.0.0'));
    expect(model.storeUrlAndroid, 'https://example.com/android');
    expect(model.storeUrlIos, 'https://example.com/ios');
  });
}
