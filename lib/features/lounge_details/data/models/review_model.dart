import 'package:equatable/equatable.dart';

class ReviewModel extends Equatable {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  const ReviewModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, userId, userName, userAvatar, rating, comment, createdAt];

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    final userData = json['users'] as Map<String, dynamic>?;
    return ReviewModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userName: userData?['name'] ?? 'User',
      userAvatar: userData?['avatar_url'],
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
