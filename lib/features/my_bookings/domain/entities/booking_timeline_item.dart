import 'package:equatable/equatable.dart';

class BookingTimelineItem extends Equatable {
  final String id;
  final String eventCode;
  final String titleAr;
  final String titleEn;
  final DateTime occurredAt;
  final Map<String, dynamic>? payload;

  const BookingTimelineItem({
    required this.id,
    required this.eventCode,
    required this.titleAr,
    required this.titleEn,
    required this.occurredAt,
    this.payload,
  });

  String getTitle(String lang) {
    final cleanLang = lang.toLowerCase().trim();
    if (cleanLang == 'ar') {
      if (titleAr.trim().isNotEmpty) return titleAr;
      if (titleEn.trim().isNotEmpty) return titleEn;
    } else {
      if (titleEn.trim().isNotEmpty) return titleEn;
      if (titleAr.trim().isNotEmpty) return titleAr;
    }
    return _getFallbackTitle(lang);
  }

  String _getFallbackTitle(String lang) {
    final isAr = lang.toLowerCase().trim() == 'ar';
    switch (eventCode.toLowerCase().trim()) {
      case 'booking_created':
      case 'created':
        return isAr ? 'تم الحجز' : 'Booking Placed';
      case 'booking_confirmed':
      case 'booking_approved':
      case 'approved':
      case 'confirmed':
        return isAr ? 'تمت الموافقة' : 'Booking Approved';
      case 'booking_checked_in':
      case 'check_in':
      case 'checked_in':
      case 'session_started':
        return isAr ? 'الدخول' : 'Session Checked In';
      case 'booking_extension_requested':
        return isAr ? 'طلب تمديد الوقت' : 'Extension Requested';
      case 'booking_extension_approved':
      case 'session_extended':
      case 'extended':
      case 'extension':
        return isAr ? 'تمت الموافقة على التمديد' : 'Time Extension Approved';
      case 'booking_extension_rejected':
        return isAr ? 'تم رفض طلب التمديد' : 'Extension Rejected';
      case 'booking_completed':
      case 'completed':
        return isAr ? 'تم الإكمال' : 'Completed';
      case 'booking_cancelled':
      case 'cancelled':
        return isAr ? 'تم الإلغاء' : 'Cancelled';
      default:
        return isAr ? 'تحديث بالحجز' : 'Booking Activity';
    }
  }

  @override
  List<Object?> get props => [
        id,
        eventCode,
        titleAr,
        titleEn,
        occurredAt,
        payload,
      ];
}
