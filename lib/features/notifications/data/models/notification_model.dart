import 'dart:convert';
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
  final Map<String, dynamic>? data;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    required this.type,
    this.status,
    this.data,
  });

  @override
  List<Object?> get props =>
      [id, title, body, createdAt, isRead, type, status, data];

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final title = json['title'] as String? ?? '';
    final body = json['body'] as String? ?? '';
    final parsedData = _parseData(json['data']);
    String? status = parsedData?['status'] as String?;

    // Fallback logic to infer status from text if not provided in payload
    if (status == null) {
      final text = (title + body).toLowerCase();
      if (text.contains('declined') ||
          text.contains('cancelled') ||
          text.contains('refused') ||
          text.contains('مرفوض') ||
          text.contains('إلغاء')) {
        status = 'cancelled';
      } else if (text.contains('approved') ||
          text.contains('confirmed') ||
          text.contains('مقبول') ||
          text.contains('تأكيد')) {
        status = 'upcoming';
      } else if (text.contains('request') ||
          text.contains('received') ||
          text.contains('pending') ||
          text.contains('طلب') ||
          text.contains('انتظار')) {
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
      data: parsedData,
    );
  }

  factory NotificationModel.fromRawRecord(
    Map<String, dynamic> json,
    String lang,
  ) {
    final title =
        json['title_$lang'] ?? json['title'] ?? json['title_en'] ?? '';
    final body = json['body_$lang'] ?? json['body'] ?? json['body_en'] ?? '';
    final parsedData = _parseData(json['data']);

    return NotificationModel(
      id: json['id'] as String,
      title: title.toString(),
      body: body.toString(),
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
      type: _parseType(json['type'] as String? ?? ''),
      data: parsedData,
    );
  }

  static Map<String, dynamic>? _parseData(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    return null;
  }

  static NotificationType _parseType(String type) {
    final t = type.toLowerCase().trim();
    if (t.contains('booking')) {
      return NotificationType.booking;
    } else if (t.contains('offer') || t.contains('promo')) {
      return NotificationType.offer;
    } else if (t.contains('loyalty')) {
      return NotificationType.loyalty;
    } else {
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
    Map<String, dynamic>? data,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      status: status ?? this.status,
      data: data ?? this.data,
    );
  }
}
