import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/features/tournaments/data/datasources/remote/tournament_evidence_upload.dart';

void main() {
  for (final format in {'jpg': 'image/jpeg', 'JPEG': 'image/jpeg',
    'png': 'image/png', 'webp': 'image/webp', 'pdf': 'application/pdf'}.entries) {
    test('uploads ${format.key} as a new immutable object with correct MIME', () {
      final upload = TournamentEvidenceUpload(tournamentId: 'tournament-id',
        scopeId: 'user-id', filePath: '/tmp/proof.${format.key}');
      expect(upload.options.upsert, isFalse);
      expect(upload.options.contentType, format.value);
      expect(upload.path, startsWith('tournament-id/user-id/'));
    });
  }
  test('consecutive attempts cannot overwrite one another', () {
    final first = TournamentEvidenceUpload(tournamentId: 't', scopeId: 'u', filePath: 'proof.jpg');
    final second = TournamentEvidenceUpload(tournamentId: 't', scopeId: 'u', filePath: 'proof.jpg');
    expect(first.path, isNot(second.path));
  });
  test('rejects unsupported files and unsafe scopes before network access', () {
    expect(() => TournamentEvidenceUpload(tournamentId: 't', scopeId: 'u',
      filePath: 'proof.exe'), throwsFormatException);
    expect(() => TournamentEvidenceUpload(tournamentId: '../t', scopeId: 'u',
      filePath: 'proof.jpg'), throwsFormatException);
  });
}
