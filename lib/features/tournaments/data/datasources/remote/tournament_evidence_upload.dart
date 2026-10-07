import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Evidence is immutable: each attempt creates a new object, never an upsert.
class TournamentEvidenceUpload {
  final String path;
  final FileOptions options;
  const TournamentEvidenceUpload._(this.path, this.options);

  factory TournamentEvidenceUpload({
    required String tournamentId,
    required String scopeId,
    required String filePath,
  }) {
    final safeSegment = RegExp(r'^[a-zA-Z0-9_-]+$');
    if (!safeSegment.hasMatch(tournamentId) || !safeSegment.hasMatch(scopeId)) {
      throw const FormatException('Invalid tournament evidence scope');
    }
    final extension = filePath.split('.').last.toLowerCase();
    final contentType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      _ => throw const FormatException('Use a JPG, PNG, WebP or PDF evidence file'),
    };
    final random = Random.secure();
    final nonce = List.generate(16, (_) => random.nextInt(256)
        .toRadixString(16).padLeft(2, '0')).join();
    return TournamentEvidenceUpload._(
      '$tournamentId/$scopeId/$nonce.$extension',
      FileOptions(contentType: contentType, upsert: false),
    );
  }
}
