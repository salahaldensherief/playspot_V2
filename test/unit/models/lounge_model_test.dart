import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';

void main() {
  group('LoungeModel Unit Tests', () {
    final testJson = {
      'id': 'lounge_001',
      'name': 'Gamed Lounge',
      'name_ar': 'جيمد لوانج',
      'name_en': 'Gamed Lounge',
      'image_url': 'https://example.com/lounge.jpg',
      'rating': 4.8,
      'distance_km': 2.5,
      'price_per_hour': 60.0,
      'is_open': true,
      'location': 'Fifth Settlement',
      'city': 'Cairo',
      'total_reviews': 120,
      'available_rooms': 5,
      'description_ar': 'وصف بالعربي',
      'description_en': 'Description in English',
      'opening_time': '10:00:00',
      'closing_time': '02:00:00',
      'has_discount': true,
      'discount_percentage': 20,
      'discount_title_ar': 'خصم 20%',
      'discount_title_en': '20% Off',
    };

    test('should parse LoungeModel correctly from JSON', () {
      final model = LoungeModel.fromJson(testJson);

      expect(model.id, 'lounge_001');
      expect(model.name, 'Gamed Lounge');
      expect(model.nameAr, 'جيمد لوانج');
      expect(model.rating, 4.8);
      expect(model.distance, 2.5);
      expect(model.pricePerHour, 60.0);
      expect(model.isOpen, isTrue);
      expect(model.hasDiscount, isTrue);
      expect(model.discountPercentage, 20);
    });

    test('getName should return localized name based on isArabic parameter', () {
      final model = LoungeModel.fromJson(testJson);

      expect(model.getName(true), 'جيمد لوانج');
      expect(model.getName(false), 'Gamed Lounge');
    });

    test('getDescription should return correct localized description', () {
      final model = LoungeModel.fromJson(testJson);

      expect(model.getDescription(true), 'وصف بالعربي');
      expect(model.getDescription(false), 'Description in English');
    });

    test('toJson should convert LoungeModel back to Map correctly', () {
      final model = LoungeModel.fromJson(testJson);
      final jsonMap = model.toJson();

      expect(jsonMap['id'], 'lounge_001');
      expect(jsonMap['name'], 'Gamed Lounge');
      expect(jsonMap['price_per_hour'], 60.0);
      expect(jsonMap['has_discount'], isTrue);
    });
  });
}
