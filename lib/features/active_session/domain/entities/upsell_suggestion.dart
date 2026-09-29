import 'package:equatable/equatable.dart';

class UpsellSuggestion extends Equatable {
  final String ruleId;
  final String suggestionType; // 'combo' or 'extra'
  final String targetId;
  final String nameAr;
  final String? nameEn;
  final double originalPrice;
  final double discountPercent;
  final double finalPrice;
  final String? imageUrl;

  const UpsellSuggestion({
    required this.ruleId,
    required this.suggestionType,
    required this.targetId,
    required this.nameAr,
    this.nameEn,
    required this.originalPrice,
    required this.discountPercent,
    required this.finalPrice,
    this.imageUrl,
  });

  bool get isCombo => suggestionType.toLowerCase().trim() == 'combo';

  String getName(bool isArabic) {
    if (isArabic) {
      return nameAr.isNotEmpty ? nameAr : (nameEn ?? '');
    }
    return (nameEn != null && nameEn!.isNotEmpty) ? nameEn! : nameAr;
  }

  @override
  List<Object?> get props => [
        ruleId,
        suggestionType,
        targetId,
        nameAr,
        nameEn,
        originalPrice,
        discountPercent,
        finalPrice,
        imageUrl,
      ];
}
