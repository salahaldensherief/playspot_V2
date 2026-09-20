/// Translates database and booking errors into localized user-friendly messages.
String getBookingErrorMessage(Object error, bool isEnglish) {
  final message = error.toString().toLowerCase();

  if (message.contains('تم حظر حسابك لمخالفة الشروط') ||
      message.contains('account is banned') ||
      message.contains('user is banned')) {
    return isEnglish
        ? 'Your account has been suspended for violating terms and conditions.'
        : 'تم حظر حسابك لمخالفة الشروط والأحكام.';
  }

  if (message.contains('لا يمكنك الحجز في هذه الصالة بناءً على سياسة الإدارة') ||
      message.contains('lounge_banned') ||
      message.contains('banned from lounge')) {
    return isEnglish
        ? 'You cannot book at this lounge based on management policy.'
        : 'لا يمكنك الحجز في هذه الصالة بناءً على سياسة الإدارة.';
  }

  if (message.contains('هذه الصالة موقوفة حالياً') ||
      message.contains('lounge is suspended') ||
      message.contains('is_active = false')) {
    return isEnglish
        ? 'This lounge is currently suspended.'
        : 'هذه الصالة موقوفة حالياً.';
  }

  if (message.contains('cash payment is disabled for this lounge') ||
      message.contains('cash_disabled')) {
    return isEnglish
        ? 'Cash payment is disabled for this lounge.'
        : 'الدفع الكاش غير متاح في هذه الصالة.';
  }

  if (message.contains('first booking must use manual_transfer') ||
      message.contains('first_booking_manual_transfer_required')) {
    return isEnglish
        ? 'First booking must be confirmed using manual transfer (E-Wallet / InstaPay).'
        : 'أول حجز يجب تأكيده بتحويل مسبق عبر المحفظة أو InstaPay.';
  }

  if (message.contains('sender_wallet_phone is required for manual_transfer') ||
      message.contains('sender_wallet_phone_required')) {
    return isEnglish
        ? 'Sender wallet/phone number is required for manual transfer.'
        : 'يجب إدخال رقم المحفظة الذي تم التحويل منه.';
  }

  if (message.contains('permission denied') ||
      message.contains('row-level security') ||
      message.contains('rls policy') ||
      message.contains('rls')) {
    return isEnglish
        ? 'You do not have permission to perform this action.'
        : 'لا تملك صلاحية تنفيذ هذا الإجراء.';
  }

  if (message.contains('jwt expired') ||
      message.contains('unauthorized') ||
      message.contains('not authenticated') ||
      message.contains('session_expired')) {
    return isEnglish
        ? 'Session expired. Please log in again to complete your action.'
        : 'انتهت صلاحية الجلسة. يرجى تسجيل الدخول مجدداً لإتمام العملية.';
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
