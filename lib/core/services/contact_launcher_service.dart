import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactLauncherService {
  ContactLauncherService._();

  /// Launches WhatsApp directly with the target phone number and prefilled message.
  static Future<bool> launchWhatsApp({
    required String phone,
    String message = '',
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final formattedPhone = cleanPhone.startsWith('01') ? '2$cleanPhone' : cleanPhone;
    final encodedMessage = Uri.encodeComponent(message);

    final waMeUri = Uri.parse("https://wa.me/$formattedPhone?text=$encodedMessage");
    if (await canLaunchUrl(waMeUri)) {
      return await launchUrl(waMeUri, mode: LaunchMode.externalApplication);
    }

    final schemeUri = Uri.parse("whatsapp://send?phone=$formattedPhone&text=$encodedMessage");
    if (await canLaunchUrl(schemeUri)) {
      return await launchUrl(schemeUri, mode: LaunchMode.externalApplication);
    }

    return false;
  }

  /// Launches the native phone dialer with the target phone number.
  static Future<bool> launchPhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse("tel:$cleanPhone");
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Launches the native email client with recipient, subject, and optional body.
  static Future<bool> launchEmail({
    required String email,
    String subject = 'PlaySpot Support',
    String body = '',
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        if (subject.isNotEmpty) 'subject': subject,
        if (body.isNotEmpty) 'body': body,
      },
    );
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Copies text/number to system clipboard with haptic feedback.
  static Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    await HapticFeedback.lightImpact();
  }
}
