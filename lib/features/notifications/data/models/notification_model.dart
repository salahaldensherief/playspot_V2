import 'dart:convert';
import 'package:equatable/equatable.dart';

enum NotificationType { booking, offer, loyalty, system }

class NotificationModel extends Equatable {
  final String id;
  final String title;
  final String body;
  final String? titleAr;
  final String? titleEn;
  final String? bodyAr;
  final String? bodyEn;
  final DateTime createdAt;
  final bool isRead;
  final NotificationType type;
  final String? status; // pending, upcoming, cancelled
  final Map<String, dynamic>? data;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    this.titleAr,
    this.titleEn,
    this.bodyAr,
    this.bodyEn,
    required this.createdAt,
    this.isRead = false,
    required this.type,
    this.status,
    this.data,
  });

  String getTitle(String lang) {
    final cleanLang = lang.toLowerCase().trim();
    if (cleanLang == 'ar') {
      if (titleAr != null && titleAr!.trim().isNotEmpty) return titleAr!;
      if (title.trim().isNotEmpty) return title;
      if (titleEn != null && titleEn!.trim().isNotEmpty) return titleEn!;
    } else {
      if (titleEn != null && titleEn!.trim().isNotEmpty) return titleEn!;
      if (title.trim().isNotEmpty) return title;
      if (titleAr != null && titleAr!.trim().isNotEmpty) return titleAr!;
    }
    return title;
  }

  String getBody(String lang) {
    final cleanLang = lang.toLowerCase().trim();
    if (cleanLang == 'ar') {
      if (bodyAr != null && bodyAr!.trim().isNotEmpty) return bodyAr!;
      if (body.trim().isNotEmpty) return body;
      if (bodyEn != null && bodyEn!.trim().isNotEmpty) return bodyEn!;
    } else {
      if (bodyEn != null && bodyEn!.trim().isNotEmpty) return bodyEn!;
      if (body.trim().isNotEmpty) return body;
      if (bodyAr != null && bodyAr!.trim().isNotEmpty) return bodyAr!;
    }
    return body;
  }

  @override
  List<Object?> get props => [
        id,
        title,
        body,
        titleAr,
        titleEn,
        bodyAr,
        bodyEn,
        createdAt,
        isRead,
        type,
        status,
        data,
      ];

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final titleAr = json['title_ar']?.toString();
    final titleEn = json['title_en']?.toString();
    final bodyAr = json['body_ar']?.toString();
    final bodyEn = json['body_en']?.toString();

    final title = json['title']?.toString() ?? titleEn ?? titleAr ?? '';
    final body = json['body']?.toString() ?? bodyEn ?? bodyAr ?? '';
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
      id: json['id']?.toString() ?? '',
      title: title,
      body: body,
      titleAr: titleAr,
      titleEn: titleEn,
      bodyAr: bodyAr,
      bodyEn: bodyEn,
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
    final titleAr = json['title_ar']?.toString();
    final titleEn = json['title_en']?.toString();
    final bodyAr = json['body_ar']?.toString();
    final bodyEn = json['body_en']?.toString();

    String title;
    if (lang.toLowerCase().trim() == 'ar') {
      title = (titleAr != null && titleAr.isNotEmpty)
          ? titleAr
          : (json['title'] ?? titleEn ?? '').toString();
    } else {
      title = (titleEn != null && titleEn.isNotEmpty)
          ? titleEn
          : (json['title'] ?? titleAr ?? '').toString();
    }

    String body;
    if (lang.toLowerCase().trim() == 'ar') {
      body = (bodyAr != null && bodyAr.isNotEmpty)
          ? bodyAr
          : (json['body'] ?? bodyEn ?? '').toString();
    } else {
      body = (bodyEn != null && bodyEn.isNotEmpty)
          ? bodyEn
          : (json['body'] ?? bodyAr ?? '').toString();
    }

    final parsedData = _parseData(json['data']);

    return NotificationModel(
      id: json['id']?.toString() ?? '',
      title: title,
      body: body,
      titleAr: titleAr,
      titleEn: titleEn,
      bodyAr: bodyAr,
      bodyEn: bodyEn,
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
    String? titleAr,
    String? titleEn,
    String? bodyAr,
    String? bodyEn,
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
      titleAr: titleAr ?? this.titleAr,
      titleEn: titleEn ?? this.titleEn,
      bodyAr: bodyAr ?? this.bodyAr,
      bodyEn: bodyEn ?? this.bodyEn,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      status: status ?? this.status,
      data: data ?? this.data,
    );
  }
}
