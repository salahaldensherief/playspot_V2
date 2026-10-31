import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PlaySpotSecureStorage {
  const PlaySpotSecureStorage._();
  static const instance = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false, migrateWithBackup: true),
  );
}
