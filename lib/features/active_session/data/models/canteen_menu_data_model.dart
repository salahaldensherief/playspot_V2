import 'package:equatable/equatable.dart';
import '../../../lounge_details/data/models/extra_model.dart';
import '../../domain/entities/canteen_combo.dart';
import 'canteen_combo_model.dart';

class CanteenMenuData extends Equatable {
  final List<ExtraModel> extras;
  final List<CanteenCombo> combos;

  const CanteenMenuData({
    this.extras = const [],
    this.combos = const [],
  });

  factory CanteenMenuData.fromJson(Map<String, dynamic> json) {
    final extrasList = (json['extras'] as List?)
            ?.map((e) => ExtraModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    final combosList = (json['combos'] as List?)
            ?.map((e) => CanteenComboModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    return CanteenMenuData(
      extras: extrasList,
      combos: combosList,
    );
  }

  @override
  List<Object?> get props => [extras, combos];
}
