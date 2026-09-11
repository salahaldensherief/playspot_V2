import 'package:equatable/equatable.dart';

class LoyaltyStatusModel extends Equatable {
  final int pointsBalance;
  final String currentLevel;
  final int nextLevelPoints;
  final double multiplier;

  const LoyaltyStatusModel({
    required this.pointsBalance,
    required this.currentLevel,
    required this.nextLevelPoints,
    required this.multiplier,
  });

  factory LoyaltyStatusModel.fromJson(Map<String, dynamic> json) {
    return LoyaltyStatusModel(
      pointsBalance: ((json['points_balance'] ?? json['points'] ?? json['total_points']) as num?)?.toInt() ?? 0,
      currentLevel: json['current_level']?.toString() ?? json['level']?.toString() ?? json['tier_name']?.toString() ?? json['tier']?.toString() ?? 'Bronze',
      nextLevelPoints: ((json['next_level_points'] ?? json['points_to_next_level'] ?? json['next_tier_points']) as num?)?.toInt() ?? 0,
      multiplier: ((json['multiplier'] ?? json['level_multiplier'] ?? json['tier_multiplier']) as num?)?.toDouble() ?? 1.0,
    );
  }

  int get pointsRemaining {
    if (nextLevelPoints <= 0) return 0;
    if (nextLevelPoints > pointsBalance) {
      return nextLevelPoints - pointsBalance;
    }
    return nextLevelPoints;
  }

  double get progressRatio {
    if (nextLevelPoints <= 0) return 1.0;
    if (nextLevelPoints > pointsBalance) {
      return (pointsBalance / nextLevelPoints).clamp(0.0, 1.0);
    }
    final target = pointsBalance + nextLevelPoints;
    return target > 0 ? (pointsBalance / target).clamp(0.0, 1.0) : 1.0;
  }

  Map<String, dynamic> toJson() => {
    'points_balance': pointsBalance,
    'current_level': currentLevel,
    'next_level_points': nextLevelPoints,
    'multiplier': multiplier,
  };

  @override
  List<Object?> get props => [pointsBalance, currentLevel, nextLevelPoints, multiplier];
}
