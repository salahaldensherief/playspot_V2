import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:playspot/core/services/request_diagnostics_client.dart';

void main() {
  test(
    'logs correlation, RPC, timing and backend code without secrets',
    () async {
      final lines = <String>[];
      final client = RequestDiagnosticsClient(
        enabled: true,
        sink: lines.add,
        inner: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer secret-token');
          expect(request.body, contains('secret-password'));
          return http.Response(
            '{"code":"42501","message":"private@example.com secret-password"}',
            403,
            headers: {'x-private': 'secret-header'},
          );
        }),
      );
      final response = await client.post(
        Uri.parse(
          'https://test.invalid/rest/v1/rpc/booking_hold?email=private@example.com',
        ),
        headers: {'authorization': 'Bearer secret-token'},
        body: '{"password":"secret-password"}',
      );
      expect(response.statusCode, 403);
      expect(response.body, contains('private@example.com'));
      final events = lines
          .map((line) => jsonDecode(line.substring(6)))
          .toList();
      expect(events.map((e) => e['phase']), ['start', 'headers', 'end']);
      expect(events.map((e) => e['id']).toSet(), {1});
      expect(events.last['operation'], 'rpc/booking_hold');
      expect(events.last['code'], '42501');
      expect(events.last['ms'], isNonNegative);
      for (final secret in [
        'secret-token',
        'secret-password',
        'private@example.com',
        'secret-header',
      ]) {
        expect(lines.join(), isNot(contains(secret)));
      }
      client.close();
    },
  );

  test(
    'preserves transport errors without printing exception contents',
    () async {
      final lines = <String>[];
      final failure = http.ClientException('secret-token private@example.com');
      final client = RequestDiagnosticsClient(
        enabled: true,
        sink: lines.add,
        inner: MockClient((_) async => throw failure),
      );
      await expectLater(
        client.get(Uri.parse('https://test.invalid/rest/v1/rooms')),
        throwsA(same(failure)),
      );
      expect(lines.last, contains('transport_error'));
      expect(lines.join(), isNot(contains('secret-token')));
      client.close();
    },
  );

  test('preserves binary streaming and hides signed storage paths', () async {
    final lines = <String>[];
    final bytes = [0, 255, 42, 80];
    final client = RequestDiagnosticsClient(
      enabled: true,
      sink: lines.add,
      inner: MockClient((_) async => http.Response.bytes(bytes, 200)),
    );
    final result = await client.get(
      Uri.parse(
        'https://test.invalid/storage/v1/object/private/user-id/receipt.png?token=secret',
      ),
    );
    expect(result.bodyBytes, bytes);
    expect(lines.join(), isNot(contains('user-id')));
    expect(lines.join(), isNot(contains('receipt.png')));
    expect(lines.join(), isNot(contains('secret')));
    client.close();
  });

  test('disabled diagnostics produce no records', () async {
    final lines = <String>[];
    final client = RequestDiagnosticsClient(
      enabled: false,
      sink: lines.add,
      inner: MockClient((_) async => http.Response('ok', 200)),
    );
    expect((await client.get(Uri.parse('https://test.invalid'))).body, 'ok');
    expect(lines, isEmpty);
    client.close();
  });

  test('broken log sink cannot break a request', () async {
    final client = RequestDiagnosticsClient(
      enabled: true,
      sink: (_) => throw StateError('logger unavailable'),
      inner: MockClient((_) async => http.Response('ok', 200)),
    );
    expect((await client.get(Uri.parse('https://test.invalid'))).body, 'ok');
    client.close();
  });

  test('late stream failures remain visible to callers', () async {
    final lines = <String>[];
    final failure = StateError('private body');
    final client = RequestDiagnosticsClient(
      enabled: true,
      sink: lines.add,
      inner: _StreamClient(() async* {
        yield [1, 2];
        throw failure;
      }()),
    );
    final response = await client.send(
      http.Request('GET', Uri.parse('https://test.invalid')),
    );
    await expectLater(response.stream.toBytes(), throwsA(same(failure)));
    expect(lines.join(), contains('stream_error'));
    expect(lines.join(), isNot(contains('private body')));
    client.close();
  });
}

class _StreamClient extends http.BaseClient {
  _StreamClient(this.stream);
  final Stream<List<int>> stream;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(stream, 200, request: request);
}
