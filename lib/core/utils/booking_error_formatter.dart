import 'package:easy_localization/easy_localization.dart';
import '../../art_core/app_strings.dart';

/// Translates database and booking errors into localized user-friendly messages.
String getBookingErrorMessage(Object error, bool isEnglish) {
  final message = error.toString();
  if (message.contains('NO_OPEN_SHIFT')) {
    return isEnglish
        ? 'No open shift is available for this lounge.'
        : 'لا توجد وردية مفتوحة لهذه الصالة حالياً.';
  }
  if (message.contains('outside working hours')) {
    return isEnglish
        ? 'The selected time is outside the lounge working hours.'
        : 'الوقت المختار خارج مواعيد عمل الصالة.';
  }
  if (message.contains('overlappingBookingError') ||
      message.contains('exclusion constraint') ||
      message.contains('no_overlapping_room_bookings') ||
      message.contains('prevent_room_booking_overlap')) {
    return isEnglish
        ? 'This time slot is already booked. Please select another time or room.'
        : 'هذا الوقت محجوز بالفعل. يرجى اختيار وقت آخر أو غرفة أخرى.';
  }
  return isEnglish
      ? 'Unable to complete the booking.'
      : 'تعذر إتمام الحجز.';
}
