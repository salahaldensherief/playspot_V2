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

  factory AppStatusModel.fromJson(Map<String, dynamic> json) {
    return AppStatusModel(
      maintenanceMode: json['maintenance_mode'] ?? false,
      maintenanceTitle: json['maintenance_title'] as String?,
      maintenanceMessage: json['maintenance_message'] as String?,
      expectedEndTime: json['expected_end_time'] != null
          ? DateTime.tryParse(json['expected_end_time'].toString())
          : null,
      minSupportedVersion: (json['min_supported_version'] as String?) ?? '1.0.0',
      latestVersion: (json['latest_version'] as String?) ?? '1.0.0',
      storeUrlAndroid: json['store_url_android'] as String?,
      storeUrlIos: json['store_url_ios'] as String?,
      updateMessage: json['update_message'] as String?,
      announcementId: json['announcement_id'] as String?,
      announcementTitle: json['announcement_title'] as String?,
      announcementBody: json['announcement_body'] as String?,
      announcementImageUrl: json['announcement_image_url'] as String?,
      announcementActionUrl: json['announcement_action_url'] as String?,
      contactSupportNumber: json['contact_support_number'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maintenance_mode': maintenanceMode,
      'maintenance_title': maintenanceTitle,
      'maintenance_message': maintenanceMessage,
      'expected_end_time': expectedEndTime?.toIso8601String(),
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
