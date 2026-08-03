class RedemptionOptionModel {
  final String id;
  final String title;
  final String description;
  final int pointsCost;
  final String rewardType;
  final double rewardValue;

  RedemptionOptionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.pointsCost,
    required this.rewardType,
    required this.rewardValue,
  });

  factory RedemptionOptionModel.fromJson(Map<String, dynamic> json) {
    return RedemptionOptionModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      pointsCost: (json['points_cost'] as num?)?.toInt() ?? 0,
      rewardType: json['reward_type']?.toString() ?? '',
      rewardValue: (json['reward_value'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
