import '../../domain/entities/tournament_entity.dart';

/// يحسب مركز كل ماتش (Y) لفرع واحد (يسار أو يمين) بمنطق الشجرة الصحيح:
/// كل ماتش في دور جديد يتمركز بالظبط في نص المسافة بين الماتشين اللي غذوه.
/// كده الخطوط بتطلع مضبوطة مهما كان عدد الأدوار أو عدد الفرق (8, 16, 32...).
class BracketLayout {
  final List<List<TournamentMatchEntity>> rounds; // من الأكتر مباريات للأقل
  final double matchHeight;
  final double firstRoundGap;

  late final List<List<double>> centersY;

  BracketLayout({
    required this.rounds,
    required this.matchHeight,
    required this.firstRoundGap,
  }) {
    centersY = _compute();
  }

  List<List<double>> _compute() {
    if (rounds.isEmpty) return [];
    final result = <List<double>>[];

    final first = <double>[];
    for (int i = 0; i < rounds.first.length; i++) {
      first.add(i * (matchHeight + firstRoundGap) + matchHeight / 2);
    }
    result.add(first);

    for (int r = 1; r < rounds.length; r++) {
      final prev = result[r - 1];
      final curr = <double>[];
      for (int i = 0; i < rounds[r].length; i++) {
        final a = prev[i * 2];
        final hasB = i * 2 + 1 < prev.length;
        final b = hasB ? prev[i * 2 + 1] : a;
        curr.add((a + b) / 2);
      }
      result.add(curr);
    }
    return result;
  }

  /// الارتفاع الفعلي اللي الفرع ده محتاجه (بيصغر لوحده لو الفرق أقل، مثلاً 8 بدل 16)
  double get contentHeight {
    if (rounds.isEmpty) return matchHeight;
    return rounds.first.length * (matchHeight + firstRoundGap) - firstRoundGap;
  }
}