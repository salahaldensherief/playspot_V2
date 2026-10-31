import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:playspot/features/profile/data/datasources/remote/support_remote_data_source.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder<dynamic> {}

void main() {
  late MockSupabaseClient mockSupabase;
  late MockPostgrestFilterBuilder mockBuilder;
  late SupportRemoteDataSource dataSource;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockBuilder = MockPostgrestFilterBuilder();
    dataSource = SupportRemoteDataSourceImpl(mockSupabase);
  });

  group('Batch 4 — SupportRemoteDataSource Unit Tests', () {
    test('getSupportSettings returns map on success', () async {
      when(
        () => mockSupabase.rpc('get_public_support_settings'),
      ).thenAnswer((_) => mockBuilder);
      when(
        () => mockBuilder.then<dynamic>(any(), onError: any(named: 'onError')),
      ).thenAnswer((invocation) async {
        final callback =
            invocation.positionalArguments.first
                as FutureOr<dynamic> Function(dynamic);
        return callback({
          'whatsapp_phone': '01000000000',
          'support_phone': '01000000000',
          'support_email': 'support@playspot.app',
        });
      });

      final settings = await dataSource.getSupportSettings();

      expect(settings['whatsapp_phone'], equals('01000000000'));
      expect(settings['support_email'], equals('support@playspot.app'));
    });

    test('getSupportSettings preserves request failure for retry UI', () async {
      when(
        () => mockSupabase.rpc('get_public_support_settings'),
      ).thenThrow(const PostgrestException(message: 'RPC not found'));

      await expectLater(
        dataSource.getSupportSettings(),
        throwsA(isA<PostgrestException>()),
      );
    });
    for (final name in ['get_public_policies', 'get_public_faqs']) {
      test(
        '$name preserves request failure instead of empty content',
        () async {
          when(
            () => mockSupabase.rpc(name, params: any(named: 'params')),
          ).thenThrow(const PostgrestException(message: 'synthetic outage'));
          await expectLater(
            name == 'get_public_policies'
                ? dataSource.getPolicies('ar')
                : dataSource.getFaqs('ar'),
            throwsA(isA<PostgrestException>()),
          );
        },
      );
    }
  });
}
