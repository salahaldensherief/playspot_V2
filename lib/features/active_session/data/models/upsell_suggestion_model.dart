import '../../domain/entities/upsell_suggestion.dart';

class UpsellSuggestionModel extends UpsellSuggestion {
  const UpsellSuggestionModel({
    required super.ruleId,
    required super.suggestionType,
    required super.targetId,
    required super.nameAr,
    super.nameEn,
    required super.originalPrice,
    required super.discountPercent,
    required super.finalPrice,
    super.imageUrl,
  });

  factory UpsellSuggestionModel.fromJson(Map<String, dynamic> json) {
    return UpsellSuggestionModel(
      ruleId: json['rule_id']?.toString() ?? '',
      suggestionType: json['suggestion_type']?.toString() ?? 'extra',
      targetId: json['target_id']?.toString() ?? '',
      nameAr: json['name_ar']?.toString() ?? '',
      nameEn: json['name_en']?.toString(),
      originalPrice: (json['original_price'] as num?)?.toDouble() ?? 0.0,
      discountPercent: (json['discount_percent'] as num?)?.toDouble() ?? 0.0,
      finalPrice: (json['final_price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['image_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rule_id': ruleId,
      'suggestion_type': suggestionType,
      'target_id': targetId,
      'name_ar': nameAr,
      'name_en': nameEn,
      'original_price': originalPrice,
      'discount_percent': discountPercent,
      'final_price': finalPrice,
      'image_url': imageUrl,
    };
  }
}
