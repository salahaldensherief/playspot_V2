class RedemptionOptionModel {
  final String id;
  final String titleAr;
  final String titleEn;
  final String descriptionAr;
  final String descriptionEn;
  final int pointsCost;
  final String rewardType;
  final double rewardValue;

  RedemptionOptionModel({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.pointsCost,
    required this.rewardType,
    required this.rewardValue,
  });

  String getTitle(bool isArabic) => isArabic ? titleAr : titleEn;
  String getDescription(bool isArabic) => isArabic ? descriptionAr : descriptionEn;

  factory RedemptionOptionModel.fromJson(Map<String, dynamic> json) {
    return RedemptionOptionModel(
      id: json['id']?.toString() ?? '',
      titleAr: json['title_ar']?.toString() ?? '',
      titleEn: json['title_en']?.toString() ?? '',
      descriptionAr: json['description_ar']?.toString() ?? '',
      descriptionEn: json['description_en']?.toString() ?? '',
      pointsCost: (json['points_cost'] as num?)?.toInt() ?? 0,
      rewardType: json['reward_type']?.toString() ?? '',
      rewardValue: (json['reward_value'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
