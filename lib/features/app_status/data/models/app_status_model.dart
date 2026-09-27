import 'package:flutter/foundation.dart';

import '../../domain/entities/app_status_entity.dart';

class AppStatusModel extends AppStatusEntity {
  const AppStatusModel({
    required super.maintenanceMode,
    super.maintenanceTitle,
    super.maintenanceMessage,
    super.expectedEndTime,
    required super.minSupportedVersion,
    required super.latestVersion,
    super.storeUrlAndroid,
    super.storeUrlIos,
    super.updateMessage,
    super.announcementId,
    super.announcementTitle,
    super.announcementBody,
    super.announcementImageUrl,
    super.announcementActionUrl,
    super.contactSupportNumber,
  });

  static bool get _useIosContract =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  factory AppStatusModel.fromJson(Map<String, dynamic> json) {
    final isIos = _useIosContract;
    final minVersion = isIos
        ? json['min_supported_version_ios']
        : json['min_supported_version_android'];
    final latestVersion = isIos
        ? json['latest_version_ios']
        : json['latest_version_android'];

    return AppStatusModel(
      maintenanceMode: json['maintenance_mode'] as bool? ?? false,
      maintenanceTitle: json['maintenance_title']?.toString(),
      maintenanceMessage:
          json['maintenance_message']?.toString() ??
          json['maintenance_message_en']?.toString() ??
          json['maintenance_message_ar']?.toString(),
      expectedEndTime:
          DateTime.tryParse(
            (json['maintenance_until'] ?? json['expected_end_time'] ?? '')
                .toString(),
          ),
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
      updateMessage:
          json['update_message']?.toString() ??
          json['update_message_en']?.toString() ??
          json['update_message_ar']?.toString(),
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
      'maintenance_title': maintenanceTitle,
      'maintenance_message': maintenanceMessage,
      'maintenance_until': expectedEndTime?.toIso8601String(),
      'min_supported_version': minSupportedVersion,
      'latest_version': latestVersion,
      'store_url_android': storeUrlAndroid,
      'store_url_ios': storeUrlIos,
      'update_message': updateMessage,
      'announcement_id': announcementId,
      'announcement_title': announcementTitle,
      'announcement_body': announcementBody,
      'announcement_image_url': announcementImageUrl,
      'announcement_action_url': announcementActionUrl,
      'contact_support_number': contactSupportNumber,
    };
  }
}
