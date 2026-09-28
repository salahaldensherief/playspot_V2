import 'package:easy_localization/easy_localization.dart';
import '../../art_core/app_strings.dart';

class AppValidators {
  /// Converts Eastern Arabic numerals (٠-٩) to Western Arabic numerals (0-9)
  static String normalizeNumerals(String input) {
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    for (int i = 0; i < arabic.length; i++) {
      input = input.replaceAll(arabic[i], english[i]);
    }
    return input;
  }

  /// Normalizes an Egyptian phone number to standard 11-digit local format: 01xxxxxxxxx
  static String normalizePhone(String input) {
    var cleaned = normalizeNumerals(input).replaceAll(RegExp(r'[\s\-()]'), '');
    if (cleaned.startsWith('+20')) {
      cleaned = cleaned.substring(3);
      if (!cleaned.startsWith('0')) cleaned = '0$cleaned';
    } else if (cleaned.startsWith('0020')) {
      cleaned = cleaned.substring(4);
      if (!cleaned.startsWith('0')) cleaned = '0$cleaned';
    } else if (cleaned.startsWith('20') && cleaned.length == 12) {
      cleaned = cleaned.substring(2);
      if (!cleaned.startsWith('0')) cleaned = '0$cleaned';
    }
    return cleaned;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.pleaseEnterEmail.tr();
    }
    final clean = value.trim();
    final emailRegex = RegExp(r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(clean)) {
      return AppStrings.pleaseEnterValidEmail.tr();
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.pleaseEnterPassword.tr();
    }
    if (value.length < 6) {
      return AppStrings.pleaseEnterValidPassword.tr();
    }
    return null;
  }

  static String? validateConfirmPassword(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return AppStrings.pleaseEnterPassword.tr();
    }
    if (value != password) {
      return AppStrings.passwordsDoNotMatch.tr();
    }
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.pleaseEnterUsername.tr();
    }
    final clean = value.trim();
    if (clean.length < 3) {
      return AppStrings.pleaseEnterUsername.tr();
    }
    // Check if name contains numbers (Western 0-9 or Eastern Arabic ٠-٩)
    if (RegExp(r'[0-9\u0660-\u0669]').hasMatch(clean)) {
      return AppStrings.nameCannotContainNumbers.tr();
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.pleaseEnterPhoneNum.tr();
    }
    final normalized = normalizePhone(value.trim());
    // Egyptian 11-digit phone number (starts with 010, 011, 012, 015)
    final phoneRegex = RegExp(r'^01[0125][0-9]{8}$');
    if (!phoneRegex.hasMatch(normalized)) {
      return AppStrings.pleaseEnterValidPhoneNum.tr();
    }
    return null;
  }

  static String? validateNotEmpty(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return "$fieldName ${AppStrings.isRequired.tr()}";
    }
    return null;
  }
}
