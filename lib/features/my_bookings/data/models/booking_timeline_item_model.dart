import 'dart:convert';
import '../../domain/entities/booking_timeline_item.dart';

class BookingTimelineItemModel extends BookingTimelineItem {
  const BookingTimelineItemModel({
    required super.id,
    required super.eventCode,
    required super.titleAr,
    required super.titleEn,
    required super.occurredAt,
    super.payload,
  });

  factory BookingTimelineItemModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString() ?? '';
    final rawCode = json['event_code']?.toString() ?? json['event_type']?.toString() ?? 'unknown_event';
    final titleAr = json['title_ar']?.toString() ?? json['title']?.toString() ?? '';
    final titleEn = json['title_en']?.toString() ?? json['title']?.toString() ?? '';

    DateTime parsedDate;
    final rawDate = json['occurred_at'] ?? json['created_at'];
    if (rawDate != null) {
      parsedDate = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    Map<String, dynamic>? parsedPayload;
    final rawPayload = json['payload'];
    if (rawPayload is Map) {
      parsedPayload = Map<String, dynamic>.from(rawPayload);
    } else if (rawPayload is String && rawPayload.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPayload);
        if (decoded is Map) {
          parsedPayload = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        parsedPayload = null;
      }
    }

    return BookingTimelineItemModel(
      id: rawId.isNotEmpty ? rawId : DateTime.now().microsecondsSinceEpoch.toString(),
      eventCode: rawCode,
      titleAr: titleAr,
      titleEn: titleEn,
      occurredAt: parsedDate,
      payload: parsedPayload,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_code': eventCode,
      'title_ar': titleAr,
      'title_en': titleEn,
      'occurred_at': occurredAt.toIso8601String(),
      'payload': payload,
    };
  }
}
