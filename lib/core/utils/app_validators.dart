import 'package:easy_localization/easy_localization.dart';
import '../../art_core/app_strings.dart';

class AppValidators {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.pleaseEnterEmail.tr();
    }
    final emailRegex = RegExp(r'^[\w.-]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
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
      return "passwordsDoNotMatch".tr(); // Use the key directly if not in AppStrings
    }
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.pleaseEnterUsername.tr();
    }
    if (value.trim().length < 3) {
      return AppStrings.pleaseEnterUsername.tr();
    }
    // Check if name contains numbers
    if (RegExp(r'[0-9]').hasMatch(value)) {
      return "nameCannotContainNumbers".tr();
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.pleaseEnterPhoneNum.tr();
    }
    // Simple phone regex, adjust as needed for Egypt (usually 11 digits starting with 01)
    final phoneRegex = RegExp(r'^01[0125][0-9]{8}$');
    if (!phoneRegex.hasMatch(value)) {
      return "pleaseEnterValidPhoneNum".tr();
    }
    return null;
  }

  static String? validateNotEmpty(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return "$fieldName ${"isRequired".tr()}";
    }
    return null;
  }
}
