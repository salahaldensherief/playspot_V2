import 'package:equatable/equatable.dart';

class AppStatusEntity extends Equatable {
  final bool maintenanceMode;
  final String? maintenanceTitle;
  final String? maintenanceMessage;
  final DateTime? expectedEndTime;
  final String minSupportedVersion;
  final String latestVersion;
  final String? storeUrlAndroid;
  final String? storeUrlIos;
  final String? updateMessage;
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
    this.expectedEndTime,
    required this.minSupportedVersion,
    required this.latestVersion,
    this.storeUrlAndroid,
    this.storeUrlIos,
    this.updateMessage,
    this.announcementId,
    this.announcementTitle,
    this.announcementBody,
    this.announcementImageUrl,
    this.announcementActionUrl,
    this.contactSupportNumber,
  });

  @override
  List<Object?> get props => [
        maintenanceMode,
        maintenanceTitle,
        maintenanceMessage,
        expectedEndTime,
        minSupportedVersion,
        latestVersion,
        storeUrlAndroid,
        storeUrlIos,
        updateMessage,
        announcementId,
        announcementTitle,
        announcementBody,
        announcementImageUrl,
        announcementActionUrl,
        contactSupportNumber,
      ];
}
