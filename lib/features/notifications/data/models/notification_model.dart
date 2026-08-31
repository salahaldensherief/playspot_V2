import 'package:equatable/equatable.dart';

enum NotificationType { booking, offer, loyalty, system }

class NotificationModel extends Equatable {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final NotificationType type;
  final String? status; // pending, upcoming, cancelled

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    required this.type,
    this.status,
  });

  @override
  List<Object?> get props => [id, title, body, createdAt, isRead, type, status];

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final title = json['title'] as String? ?? '';
    final body = json['body'] as String? ?? '';
    String? status = json['data']?['status'] as String?;

    // Fallback logic to infer status from text if not provided in payload
    if (status == null) {
      final text = (title + body).toLowerCase();
      if (text.contains('declined') || text.contains('cancelled') || text.contains('refused') || text.contains('مرفوض') || text.contains('إلغاء')) {
        status = 'cancelled';
      } else if (text.contains('approved') || text.contains('confirmed') || text.contains('مقبول') || text.contains('تأكيد')) {
        status = 'upcoming';
      } else if (text.contains('request') || text.contains('received') || text.contains('pending') || text.contains('طلب') || text.contains('انتظار')) {
        status = 'pending';
      }
    }

    return NotificationModel(
      id: json['id'] as String,
      title: title,
      body: body,
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
      type: _parseType(json['type'] as String? ?? ''),
      status: status,
    );
  }

  static NotificationType _parseType(String type) {
    switch (type) {
      case 'booking':
        return NotificationType.booking;
      case 'offer':
        return NotificationType.offer;
      case 'loyalty':
        return NotificationType.loyalty;
      case 'system':
      default:
        return NotificationType.system;
    }
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? createdAt,
    bool? isRead,
    NotificationType? type,
    String? status,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      status: status ?? this.status,
    );
  }
}
