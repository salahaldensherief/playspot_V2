import 'package:equatable/equatable.dart';

class CanteenComboComponent extends Equatable {
  final String extraId;
  final String nameAr;
  final String? nameEn;
  final double price;
  final int quantity;

  const CanteenComboComponent({
    required this.extraId,
    required this.nameAr,
    this.nameEn,
    this.price = 0.0,
    required this.quantity,
  });

  String getName(bool isArabic) {
    if (isArabic) {
      return nameAr.isNotEmpty ? nameAr : (nameEn ?? '');
    }
    return (nameEn != null && nameEn!.isNotEmpty) ? nameEn! : nameAr;
  }

  @override
  List<Object?> get props => [extraId, nameAr, nameEn, price, quantity];
}

class CanteenCombo extends Equatable {
  final String id;
  final String nameAr;
  final String? nameEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final double price;
  final double separateItemsPrice;
  final double savings;
  final String? imageUrl;
  final bool isAvailable;
  final List<CanteenComboComponent> items;

  const CanteenCombo({
    required this.id,
    required this.nameAr,
    this.nameEn,
    this.descriptionAr,
    this.descriptionEn,
    required this.price,
    this.separateItemsPrice = 0.0,
    this.savings = 0.0,
    this.imageUrl,
    this.isAvailable = true,
    this.items = const [],
  });

  String getName(bool isArabic) {
    if (isArabic) {
      return nameAr.isNotEmpty ? nameAr : (nameEn ?? '');
    }
    return (nameEn != null && nameEn!.isNotEmpty) ? nameEn! : nameAr;
  }

  String getDescription(bool isArabic) {
    if (isArabic) {
      return descriptionAr ?? descriptionEn ?? '';
    }
    return descriptionEn ?? descriptionAr ?? '';
  }

  @override
  List<Object?> get props => [
        id,
        nameAr,
        nameEn,
        descriptionAr,
        descriptionEn,
        price,
        separateItemsPrice,
        savings,
        imageUrl,
        isAvailable,
        items,
      ];
}
