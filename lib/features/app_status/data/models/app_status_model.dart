import 'package:flutter/foundation.dart';

import '../../domain/entities/app_status_entity.dart';

class AppStatusModel extends AppStatusEntity {
  const AppStatusModel({
    required super.maintenanceMode,
    super.maintenanceTitle,
    super.maintenanceMessage,
    super.maintenanceMessageAr,
    super.maintenanceMessageEn,
    super.expectedEndTime,
    required super.minSupportedVersion,
    required super.latestVersion,
    super.storeUrlAndroid,
    super.storeUrlIos,
    super.updateMessage,
    super.updateMessageAr,
    super.updateMessageEn,
    super.announcementId,
    super.announcementTitle,
    super.announcementBody,
    super.announcementImageUrl,
    super.announcementActionUrl,
    super.contactSupportNumber,
  });

  factory AppStatusModel.fromJson(
    Map<String, dynamic> json, {
    TargetPlatform? platform,
  }) {
    final effectivePlatform = platform ?? defaultTargetPlatform;
    final useIos = !kIsWeb && effectivePlatform == TargetPlatform.iOS;

    final maintenanceMessage = json['maintenance_message']?.toString();
    final updateMessage = json['update_message']?.toString();

    final minVersion = useIos
        ? json['min_supported_version_ios']
        : json['min_supported_version_android'];
    final latestVersion = useIos
        ? json['latest_version_ios']
        : json['latest_version_android'];

    return AppStatusModel(
      maintenanceMode: json['maintenance_mode'] as bool? ?? false,
      maintenanceTitle: json['maintenance_title']?.toString(),
      maintenanceMessage: maintenanceMessage,
      maintenanceMessageAr:
          json['maintenance_message_ar']?.toString() ?? maintenanceMessage,
      maintenanceMessageEn:
          json['maintenance_message_en']?.toString() ?? maintenanceMessage,
      expectedEndTime:
          json['maintenance_until'] != null
              ? DateTime.tryParse(json['maintenance_until'].toString())
              : json['expected_end_time'] != null
              ? DateTime.tryParse(json['expected_end_time'].toString())
              : null,
      minSupportedVersion:
          minVersion?.toString() ??
          json['min_supported_version']?.toString() ??
          '1.0.0',
      latestVersion:
          latestVersion?.toString() ??
          json['latest_version']?.toString() ??
          '1.0.0',
      storeUrlAndroid: json['store_url_android']?.toString(),
      storeUrlIos: json['store_url_ios']?.toString(),
      updateMessage: updateMessage,
      updateMessageAr:
          json['update_message_ar']?.toString() ?? updateMessage,
      updateMessageEn:
          json['update_message_en']?.toString() ?? updateMessage,
      announcementId: json['announcement_id']?.toString(),
      announcementTitle: json['announcement_title']?.toString(),
      announcementBody: json['announcement_body']?.toString(),
      announcementImageUrl: json['announcement_image_url']?.toString(),
      announcementActionUrl: json['announcement_action_url']?.toString(),
      contactSupportNumber: json['contact_support_number']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maintenance_mode': maintenanceMode,
      'maintenance_message': maintenanceMessage,
      'maintenance_message_ar': maintenanceMessageAr,
      'maintenance_message_en': maintenanceMessageEn,
      'maintenance_until': expectedEndTime?.toIso8601String(),
      'store_url_android': storeUrlAndroid,
      'store_url_ios': storeUrlIos,
      'update_message': updateMessage,
      'update_message_ar': updateMessageAr,
      'update_message_en': updateMessageEn,
      'announcement_id': announcementId,
      'announcement_title': announcementTitle,
      'announcement_body': announcementBody,
      'announcement_image_url': announcementImageUrl,
      'announcement_action_url': announcementActionUrl,
      'contact_support_number': contactSupportNumber,
    };
  }
}
