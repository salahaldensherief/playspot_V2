import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/features/home/data/models/category_model.dart';

void main() {
  group('CategoryModel discovery activity contract', () {
    test('decodes canonical discovery activity payload', () {
      final model = CategoryModel.fromJson({
        'id': 'activity-id',
        'name_ar': 'Table Tennis',
        'name_en': 'Table Tennis',
        'icon_key': 'sports_tennis',
      });

      expect(model.id, 'activity-id');
      expect(model.nameAr, 'Table Tennis');
      expect(model.nameEn, 'Table Tennis');
      expect(model.iconKey, 'sports_tennis');
      expect(model.icon, Icons.sports_tennis);
    });

    test('uses a neutral sports icon for billiards', () {
      final model = CategoryModel.fromJson({
        'id': 'billiard-id',
        'name_ar': 'Billiard / Pool',
        'name_en': 'Billiard / Pool',
        'icon_key': 'sports_pool',
      });

      expect(model.icon, Icons.sports);
    });
  });
}
