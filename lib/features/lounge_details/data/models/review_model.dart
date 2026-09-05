import 'package:equatable/equatable.dart';

class ReviewModel extends Equatable {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final double rating;
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
    final userData = (json['profiles'] ?? json['users'] ?? json['user'] ?? json['profile']) as Map<String, dynamic>?;

    return ReviewModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      userName: userData?['name']?.toString() ??
          userData?['full_name']?.toString() ??
          userData?['username']?.toString() ??
          json['user_name']?.toString() ??
          json['userName']?.toString() ??
          'User',
      userAvatar: userData?['avatar_url']?.toString() ??
          userData?['avatar']?.toString() ??
          json['user_avatar']?.toString(),
      rating: (json['rating'] as num?)?.toDouble() ??
          (json['score'] as num?)?.toDouble() ??
          (json['stars'] as num?)?.toDouble() ??
          0.0,
      comment: json['comment']?.toString() ??
          json['review']?.toString() ??
          json['text']?.toString() ??
          json['feedback']?.toString() ??
          json['notes']?.toString(),
      createdAt: _parseDate(json['created_at'] ?? json['createdAt'] ?? json['updated_at']),
    );
  }

  static DateTime _parseDate(dynamic dateRaw) {
    if (dateRaw == null) return DateTime.now();
    try {
      if (dateRaw is String) return DateTime.parse(dateRaw);
      if (dateRaw is int) return DateTime.fromMillisecondsSinceEpoch(dateRaw);
    } catch (_) {}
    return DateTime.now();
  }
}
