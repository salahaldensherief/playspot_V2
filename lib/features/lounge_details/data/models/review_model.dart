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
    final userData = (json['profiles'] ?? json['users']) as Map<String, dynamic>?;
    return ReviewModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: userData?['name']?.toString() ?? userData?['full_name']?.toString() ?? 'User',
      userAvatar: userData?['avatar_url']?.toString(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      comment: json['comment']?.toString() ?? json['review']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : DateTime.now(),
    );
  }
}
