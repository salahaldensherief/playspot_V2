import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Observes transport without changing payloads, retries, or response streams.
/// Bodies, headers, query values and storage object paths never enter the log.
class RequestDiagnosticsClient extends http.BaseClient {
  RequestDiagnosticsClient({
    http.Client? inner,
    this.enabled = kDebugMode,
    void Function(String)? sink,
  }) : _inner = inner ?? http.Client(),
       _sink = sink ?? debugPrint;

  final http.Client _inner;
  final bool enabled;
  final void Function(String) _sink;
  int _sequence = 0;

  void _emit(Map<String, Object?> event) {
    // Diagnostics must never make a successful operation fail.
    try {
      _sink('[NET] ${jsonEncode(event)}');
    } catch (_) {}
  }

  String _operation(Uri uri) {
    final parts = uri.pathSegments;
    if (parts.length == 4 && parts[0] == 'rest' && parts[2] == 'rpc') {
      return 'rpc/${_identifier(parts[3])}';
    }
    if (parts.length >= 3 && parts[0] == 'rest') {
      return 'table/${_identifier(parts[2])}';
    }
    if (parts.length >= 3 && parts[0] == 'functions') {
      return 'function/${_identifier(parts[2])}';
    }
    if (parts.length >= 3 && parts[0] == 'auth') {
      return 'auth/${_identifier(parts[2])}';
    }
    return parts.isEmpty ? 'http' : _identifier(parts.first);
  }

  String _identifier(String value) =>
      RegExp(r'^[a-zA-Z0-9_\-]{1,80}$').hasMatch(value) ? value : 'redacted';

  String? _errorCode(List<int> bytes) {
    try {
      final body = jsonDecode(utf8.decode(bytes));
      if (body is Map) {
        final code = body['code'] ?? body['error_code'] ?? body['error'];
        if (code is String && RegExp(r'^[a-zA-Z0-9_]{1,64}$').hasMatch(code)) {
          return code;
        }
      }
    } catch (_) {}
    return null;
  }

  String _transportCause(Object error) {
    // Classify locally; never print exception text (it can contain signed URLs).
    final text = error.toString().toLowerCase();
    if (text.contains('failed host lookup') ||
        text.contains('name resolution')) {
      return 'dns';
    }
    if (text.contains('handshake') || text.contains('certificate')) {
      return 'tls';
    }
    if (text.contains('timeout') || text.contains('timed out')) {
      return 'timeout';
    }
    if (text.contains('connection refused')) return 'connection_refused';
    if (text.contains('network is unreachable')) return 'network_unreachable';
    return 'transport';
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!enabled) return _inner.send(request);
    final id = ++_sequence;
    final watch = Stopwatch()..start();
    final context = <String, Object?>{
      'id': id,
      'method': request.method,
      'host': request.url.host,
      'operation': _operation(request.url),
    };
    _emit({...context, 'phase': 'start'});
    try {
      final response = await _inner.send(request);
      _emit({
        ...context,
        'phase': 'headers',
        'status': response.statusCode,
        'ms': watch.elapsedMilliseconds,
      });
      return http.StreamedResponse(
        _observe(response.stream, response.statusCode, watch, context),
        response.statusCode,
        contentLength: response.contentLength,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (error) {
      _emit({
        ...context,
        'phase': 'transport_error',
        'type': error.runtimeType.toString(),
        'cause': _transportCause(error),
        'ms': watch.elapsedMilliseconds,
      });
      rethrow;
    }
  }

  Stream<List<int>> _observe(
    Stream<List<int>> stream,
    int status,
    Stopwatch watch,
    Map<String, Object?> context,
  ) async* {
    var size = 0;
    var complete = false;
    var failed = false;
    final errorBytes = <int>[];
    try {
      await for (final chunk in stream) {
        size += chunk.length;
        if (status >= 400 && errorBytes.length < 4096) {
          errorBytes.addAll(chunk.take(4096 - errorBytes.length));
        }
        yield chunk;
      }
      complete = true;
    } catch (error) {
      failed = true;
      _emit({
        ...context,
        'phase': 'stream_error',
        'type': error.runtimeType.toString(),
        'cause': _transportCause(error),
        'ms': watch.elapsedMilliseconds,
      });
      rethrow;
    } finally {
      _emit({
        ...context,
        'phase': failed ? 'failed' : (complete ? 'end' : 'cancelled'),
        'status': status,
        'ms': watch.elapsedMilliseconds,
        'bytes': size,
        if (status >= 400) 'code': _errorCode(errorBytes),
      });
    }
  }

  @override
  void close() => _inner.close();
}
