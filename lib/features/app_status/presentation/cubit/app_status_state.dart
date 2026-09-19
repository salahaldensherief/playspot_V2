import 'package:equatable/equatable.dart';
import '../../domain/entities/app_status_entity.dart';
import '../../domain/entities/app_status_type.dart';

class AppStatusState extends Equatable {
  final bool isLoading;
  final AppStatusEntity? statusEntity;
  final AppStatusType statusType;
  final String currentAppVersion;
  final bool isSoftUpdateDismissed;
  final bool hasActiveSession;
  final String? errorMessage;

  const AppStatusState({
    this.isLoading = false,
    this.statusEntity,
    this.statusType = AppStatusType.normal,
    this.currentAppVersion = '1.0.0',
    this.isSoftUpdateDismissed = false,
    this.hasActiveSession = false,
    this.errorMessage,
  });

  AppStatusState copyWith({
    bool? isLoading,
    AppStatusEntity? statusEntity,
    AppStatusType? statusType,
    String? currentAppVersion,
    bool? isSoftUpdateDismissed,
    bool? hasActiveSession,
    String? errorMessage,
  }) {
    return AppStatusState(
      isLoading: isLoading ?? this.isLoading,
      statusEntity: statusEntity ?? this.statusEntity,
      statusType: statusType ?? this.statusType,
      currentAppVersion: currentAppVersion ?? this.currentAppVersion,
      isSoftUpdateDismissed: isSoftUpdateDismissed ?? this.isSoftUpdateDismissed,
      hasActiveSession: hasActiveSession ?? this.hasActiveSession,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        statusEntity,
        statusType,
        currentAppVersion,
        isSoftUpdateDismissed,
        hasActiveSession,
        errorMessage,
      ];
}
