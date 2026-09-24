/// Form validation utilities for manual payment and payment proof submission
class PaymentFormValidators {
  PaymentFormValidators._();

  /// Validates sender account (11-digit Egyptian phone number or valid InstaPay handle)
  static bool isValidSenderAccount(String? value) {
    if (value == null) return false;
    final clean = value.trim();
    if (clean.isEmpty) return false;

    // Egyptian 11-digit phone number (starts with 010, 011, 012, 015)
    final egPhoneRegExp = RegExp(r'^01[0125][0-9]{8}$');
    if (egPhoneRegExp.hasMatch(clean)) return true;

    // InstaPay handle (e.g. name@instapay, name@bank or handle >= 3 chars without spaces)
    final instaPayRegExp = RegExp(r'^[a-zA-Z0-9._-]+(@[a-zA-Z0-9.-]+)?$');
    if (clean.length >= 3 && instaPayRegExp.hasMatch(clean)) return true;

    return false;
  }

  /// Returns error string for sender account if invalid, or null if valid.
  static String? validateSenderAccount(String? value, {bool isArabic = true}) {
    if (!isValidSenderAccount(value)) {
      return isArabic
          ? 'يرجى إدخال رقم محفظة مصري صحيح (11 رقم) أو عنوان InstaPay (مثال: name@instapay)'
          : 'Please enter a valid 11-digit Egyptian phone or InstaPay handle (e.g., name@instapay)';
    }
    return null;
  }

  /// Validates transaction reference number (mandatory, min 6 characters, rejects trivial inputs)
  static bool isValidTransactionReference(String? value) {
    if (value == null) return false;
    final clean = value.trim().toLowerCase();
    if (clean.length < 6) return false;

    // List of known trivial/dummy reference inputs to reject
    final trivialInputs = <String>{
      '123456',
      '1234567',
      '12345678',
      '123456789',
      '000000',
      '111111',
      '222222',
      '333333',
      '444444',
      '555555',
      '666666',
      '777777',
      '888888',
      '999999',
      'qwerty',
      'abcdef',
      'none',
      'null',
      'test',
      'payment',
      'instapay',
      'vodafone',
      'cash',
      'transfer',
      'proof',
      'receipt',
    };

    if (trivialInputs.contains(clean)) return false;

    // Reject if all characters are identical (e.g., "aaaaaa", "0000000")
    final chars = clean.split('');
    if (chars.every((char) => char == chars.first)) return false;

    return true;
  }

  /// Returns error string for transaction reference if invalid, or null if valid.
  static String? validateTransactionReference(String? value, {bool isArabic = true}) {
    if (!isValidTransactionReference(value)) {
      return isArabic
          ? 'يرجى إدخال رقم مرجعي صحيح للعملية (6 أرقام/حروف على الأقل بدون قيم وهمية)'
          : 'Please enter a valid transaction reference (at least 6 characters, no dummy values)';
    }
    return null;
  }
}
