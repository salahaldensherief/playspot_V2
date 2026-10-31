import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/core/services/contact_launcher_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test('contact phone opens native dialer with normalized tel URI', () async {
    expect(
      await ContactLauncherService.launchPhoneCall('+20 101 234 5678'),
      isTrue,
    );
    expect(calls.map((call) => call.method), ['canLaunch', 'launch']);
    expect(calls.last.arguments['url'], 'tel:+201012345678');
    expect(calls.last.arguments['useWebView'], isFalse);
  });
  test(
    'unavailable dialer returns failure without attempting launch',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return false;
          });
      expect(
        await ContactLauncherService.launchPhoneCall('01012345678'),
        isFalse,
      );
      expect(calls.map((call) => call.method), ['canLaunch']);
    },
  );
}
