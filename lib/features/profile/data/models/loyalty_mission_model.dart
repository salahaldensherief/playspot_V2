import 'package:equatable/equatable.dart';

class LoyaltyMissionModel extends Equatable {
  final String id;
  final String title;
  final String description;
  final int pointsReward;
  final String? iconUrl;
  final int targetProgress;
  final int currentProgress;
  final bool isCompleted;

  const LoyaltyMissionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.pointsReward,
    this.iconUrl,
    required this.targetProgress,
    required this.currentProgress,
    required this.isCompleted,
  });

  factory LoyaltyMissionModel.fromJson(Map<String, dynamic> json, {Map<String, dynamic>? progressJson}) {
    final currentProg = progressJson != null
        ? ((progressJson['current_progress'] ?? progressJson['progress'] ?? progressJson['current_count']) as num?)?.toInt() ?? 0
        : 0;
    final targetProg = ((json['target_progress'] ?? json['target_count'] ?? json['target']) as num?)?.toInt() ?? 1;
    final completed = progressJson != null
        ? (progressJson['is_completed'] as bool? ?? (currentProg >= targetProg && targetProg > 0))
        : false;

    return LoyaltyMissionModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? json['mission_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      pointsReward: ((json['points_reward'] ?? json['reward_points'] ?? json['points']) as num?)?.toInt() ?? 0,
      iconUrl: json['icon_url']?.toString(),
      targetProgress: targetProg,
      currentProgress: currentProg,
      isCompleted: completed,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'points_reward': pointsReward,
    'icon_url': iconUrl,
    'target_progress': targetProgress,
    'current_progress': currentProgress,
    'is_completed': isCompleted,
  };

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        pointsReward,
        iconUrl,
        targetProgress,
        currentProgress,
        isCompleted,
      ];
}
