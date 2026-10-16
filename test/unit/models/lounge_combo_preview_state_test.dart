import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/features/active_session/domain/entities/canteen_combo.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_state.dart';

void main() {
  const combo = CanteenCombo(
    id: 'offer-1',
    nameAr: 'باقة الأصدقاء',
    price: 84.60,
    isAvailable: true,
  );

  test('lounge details carry a read-only combo preview', () {
    const state = LoungeDetailsState(combos: [combo]);
    expect(state.combos.single.id, 'offer-1');

    final changedDate = state.copyWith(selectedDate: DateTime(2026, 10, 16));
    expect(changedDate.combos, [combo]);
    expect(changedDate.selectedDate, DateTime(2026, 10, 16));

    final refresh = state.copyWith(combos: const []);
    expect(refresh.combos, isEmpty);
  });
}
