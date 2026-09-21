import 'dart:io';
import 'package:playspot/art_core/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class StorageService {
  Future<String?> uploadFile({
    required String bucket,
    required String path,
    required File file,
  });
}

class SupabaseStorageServiceImpl implements StorageService {
  final SupabaseClient _supabase;

  SupabaseStorageServiceImpl(this._supabase);

  @override
  Future<String?> uploadFile({
    required String bucket,
    required String path,
    required File file,
  }) async {
    try {
      await _supabase.storage.from(bucket).upload(
            path,
            file,
            fileOptions: const FileOptions(upsert: true),
          );
      return _supabase.storage.from(bucket).getPublicUrl(path);
    } catch (e, st) {
      AppLogger.error('[StorageService] Upload failed', e, st);
      return null;
    }
  }
}
