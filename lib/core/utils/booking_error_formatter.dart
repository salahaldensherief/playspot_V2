/// Translates database and booking errors into localized user-friendly messages.
String getBookingErrorMessage(Object error, bool isEnglish) {
  final message = error.toString().toLowerCase();

  if (message.contains('jwt expired') ||
      message.contains('unauthorized') ||
      message.contains('not authenticated') ||
      message.contains('session_expired')) {
    return isEnglish
        ? 'Session expired. Please log in again to complete your action.'
        : 'انتهت صلاحية الجلسة. يرجى تسجيل الدخول مجدداً لإتمام العملية.';
  }

  if (message.contains('permission denied') ||
      message.contains('row-level security') ||
      message.contains('rls policy')) {
    return isEnglish
        ? 'Access denied. Please ensure you are logged in with a valid account.'
        : 'تم رفض الوصول. يرجى التأكد من تسجيل الدخول بحساب صالح.';
  }

  if (message.contains('no_open_shift')) {
    return isEnglish
        ? 'No open shift is available for this lounge.'
        : 'لا توجد وردية مفتوحة لهذه الصالة حالياً.';
  }

  if (message.contains('outside working hours')) {
    return isEnglish
        ? 'The selected time is outside the lounge working hours.'
        : 'الوقت المختار خارج مواعيد عمل الصالة.';
  }

  if (message.contains('overlappingbookingerror') ||
      message.contains('exclusion constraint') ||
      message.contains('no_overlapping_room_bookings') ||
      message.contains('prevent_room_booking_overlap')) {
    return isEnglish
        ? 'This time slot is already booked. Please select another time or room.'
        : 'هذا الوقت محجوز بالفعل. يرجى اختيار وقت آخر أو غرفة أخرى.';
  }

  if (message.contains('timeout') || message.contains('socketexception')) {
    return isEnglish
        ? 'Connection timed out. Please check your internet connection and try again.'
        : 'انتهت مهلة الاتصال. يرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى.';
  }

  return isEnglish
      ? 'Unable to complete the operation.'
      : 'تعذر إتمام العملية.';
}
