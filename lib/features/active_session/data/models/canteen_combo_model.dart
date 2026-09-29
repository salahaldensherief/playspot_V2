import '../../domain/entities/canteen_combo.dart';

class CanteenComboComponentModel extends CanteenComboComponent {
  const CanteenComboComponentModel({
    required super.extraId,
    required super.nameAr,
    super.nameEn,
    super.price,
    required super.quantity,
  });

  factory CanteenComboComponentModel.fromJson(Map<String, dynamic> json) {
    return CanteenComboComponentModel(
      extraId: json['extra_id']?.toString() ?? '',
      nameAr: json['name_ar']?.toString() ?? '',
      nameEn: json['name_en']?.toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'extra_id': extraId,
      'name_ar': nameAr,
      'name_en': nameEn,
      'price': price,
      'quantity': quantity,
    };
  }
}

class CanteenComboModel extends CanteenCombo {
  const CanteenComboModel({
    required super.id,
    required super.nameAr,
    super.nameEn,
    super.descriptionAr,
    super.descriptionEn,
    required super.price,
    super.separateItemsPrice,
    super.savings,
    super.imageUrl,
    super.isAvailable,
    super.items,
  });

  factory CanteenComboModel.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List?)
            ?.map((e) => CanteenComboComponentModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    return CanteenComboModel(
      id: json['id']?.toString() ?? '',
      nameAr: json['name_ar']?.toString() ?? '',
      nameEn: json['name_en']?.toString(),
      descriptionAr: json['description_ar']?.toString(),
      descriptionEn: json['description_en']?.toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      separateItemsPrice: (json['separate_items_price'] as num?)?.toDouble() ?? 0.0,
      savings: (json['savings'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['image_url']?.toString(),
      isAvailable: json['is_available'] == true,
      items: itemsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_ar': nameAr,
      'name_en': nameEn,
      'description_ar': descriptionAr,
      'description_en': descriptionEn,
      'price': price,
      'separate_items_price': separateItemsPrice,
      'savings': savings,
      'image_url': imageUrl,
      'is_available': isAvailable,
      'items': items.map((e) => (e as CanteenComboComponentModel).toJson()).toList(),
    };
  }
}
