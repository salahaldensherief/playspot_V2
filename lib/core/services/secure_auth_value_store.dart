import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/serialized_task_queue.dart';

class SecureAuthValueStore {
  final FlutterSecureStorage storage;
  final String namespace;
  final _queue = SerializedTaskQueue();
  SecureAuthValueStore({required this.storage, required this.namespace});

  Future<String?> read(
    String key, {
    required Future<String?> Function() legacyRead,
    required Future<void> Function() legacyRemove,
  }) => _queue.run(() async {
    var value = await storage.read(key: '$namespace:$key');
    if (value == null) {
      value = await legacyRead();
      if (value != null) await _verifiedWrite(key, value);
    }
    await legacyRemove();
    return value;
  });

  Future<void> write(
    String key,
    String value, {
    required Future<void> Function() legacyRemove,
  }) => _queue.run(() async {
    await _verifiedWrite(key, value);
    await legacyRemove();
  });

  Future<void> remove(
    String key, {
    required Future<void> Function() legacyRemove,
  }) => _queue.run(() async {
    await legacyRemove();
    await storage.delete(key: '$namespace:$key');
  });

  Future<void> _verifiedWrite(String key, String value) async {
    final scopedKey = '$namespace:$key';
    await storage.write(key: scopedKey, value: value);
    if (await storage.read(key: scopedKey) != value) {
      throw StateError('auth.secure_storage_unverified');
    }
  }
}
