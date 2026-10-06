import 'package:equatable/equatable.dart';

class AppStatusEntity extends Equatable {
  final bool maintenanceMode;
  final String? maintenanceTitle;
  final String? maintenanceMessage;
  final String? maintenanceMessageAr;
  final String? maintenanceMessageEn;
  final DateTime? expectedEndTime;
  final String minSupportedVersion;
  final String latestVersion;
  final String? storeUrlAndroid;
  final String? storeUrlIos;
  final String? updateMessage;
  final String? updateMessageAr;
  final String? updateMessageEn;
  final String? announcementId;
  final String? announcementTitle;
  final String? announcementBody;
  final String? announcementImageUrl;
  final String? announcementActionUrl;
  final String? contactSupportNumber;

  const AppStatusEntity({
    required this.maintenanceMode,
    this.maintenanceTitle,
    this.maintenanceMessage,
    this.maintenanceMessageAr,
    this.maintenanceMessageEn,
    this.expectedEndTime,
    required this.minSupportedVersion,
    required this.latestVersion,
    this.storeUrlAndroid,
    this.storeUrlIos,
    this.updateMessage,
    this.updateMessageAr,
    this.updateMessageEn,
    this.announcementId,
    this.announcementTitle,
    this.announcementBody,
    this.announcementImageUrl,
    this.announcementActionUrl,
    this.contactSupportNumber,
  });

  String? maintenanceMessageFor(String languageCode) {
    final localized = languageCode.toLowerCase() == 'ar'
        ? maintenanceMessageAr
        : maintenanceMessageEn;
    return _nonEmpty(localized) ?? _nonEmpty(maintenanceMessage);
  }

  String? updateMessageFor(String languageCode) {
    final localized = languageCode.toLowerCase() == 'ar'
        ? updateMessageAr
        : updateMessageEn;
    return _nonEmpty(localized) ?? _nonEmpty(updateMessage);
  }

  static String? _nonEmpty(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  @override
  List<Object?> get props => [
        maintenanceMode,
        maintenanceTitle,
        maintenanceMessage,
        maintenanceMessageAr,
        maintenanceMessageEn,
        expectedEndTime,
        minSupportedVersion,
        latestVersion,
        storeUrlAndroid,
        storeUrlIos,
        updateMessage,
        updateMessageAr,
        updateMessageEn,
        announcementId,
        announcementTitle,
        announcementBody,
        announcementImageUrl,
        announcementActionUrl,
        contactSupportNumber,
      ];
}
