import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../art_core/utils/version_utils.dart';
import '../../domain/entities/app_status_entity.dart';
import '../../domain/entities/app_status_type.dart';
import '../../domain/usecases/check_app_status_usecase.dart';
import '../../domain/usecases/stream_app_status_usecase.dart';
import 'app_status_state.dart';

class AppStatusCubit extends Cubit<AppStatusState> {
  final CheckAppStatusUseCase _checkAppStatusUseCase;
  final StreamAppStatusUseCase _streamAppStatusUseCase;
  StreamSubscription<AppStatusEntity>? _statusSubscription;

  AppStatusCubit({
    required CheckAppStatusUseCase checkAppStatusUseCase,
    required StreamAppStatusUseCase streamAppStatusUseCase,
  })  : _checkAppStatusUseCase = checkAppStatusUseCase,
        _streamAppStatusUseCase = streamAppStatusUseCase,
        super(const AppStatusState());

  /// Initial startup status check and starting realtime listener
  Future<AppStatusType> checkAndListen() async {
    emit(state.copyWith(isLoading: true));

    String currentVersion = '1.0.0';
    try {
      final info = await PackageInfo.fromPlatform();
      currentVersion = info.version;
      dev.log('[AppStatusCubit] Current Installed App Version: $currentVersion');
    } catch (e) {
      dev.log('[AppStatusCubit] PackageInfo error: $e');
    }

    emit(state.copyWith(currentAppVersion: currentVersion));

    final result = await _checkAppStatusUseCase();

    AppStatusType calculatedType = AppStatusType.normal;
    result.fold(
      (failure) {
        dev.log('[AppStatusCubit] Check status failed: ${failure.message}');
        emit(state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
          statusType: AppStatusType.normal,
        ));
      },
      (entity) {
        calculatedType = _evaluateStatusType(
          entity: entity,
          currentVersion: currentVersion,
          hasActiveSession: state.hasActiveSession,
          isSoftUpdateDismissed: state.isSoftUpdateDismissed,
        );

        dev.log('[AppStatusCubit] Evaluated Status Type: $calculatedType');
        emit(state.copyWith(
          isLoading: false,
          statusEntity: entity,
          statusType: calculatedType,
        ));
      },
    );

    _startRealtimeListener();
    return calculatedType;
  }

  void _startRealtimeListener() {
    _statusSubscription?.cancel();
    _statusSubscription = _streamAppStatusUseCase().listen(
      (updatedEntity) {
        dev.log('[AppStatusCubit Realtime] Maintenance: ${updatedEntity.maintenanceMode}, MinVersion: ${updatedEntity.minSupportedVersion}');

        final calculatedType = _evaluateStatusType(
          entity: updatedEntity,
          currentVersion: state.currentAppVersion,
          hasActiveSession: state.hasActiveSession,
          isSoftUpdateDismissed: state.isSoftUpdateDismissed,
        );

        emit(state.copyWith(
          statusEntity: updatedEntity,
          statusType: calculatedType,
        ));
      },
      onError: (err) {
        dev.log('[AppStatusCubit Realtime Error] $err');
      },
    );
  }

  /// Updates active session status from ActiveSessionCubit
  void updateActiveSessionStatus({required bool hasActiveSession}) {
    if (state.hasActiveSession == hasActiveSession) return;

    dev.log('[AppStatusCubit] Active Session status changed: $hasActiveSession');
    final entity = state.statusEntity;

    if (entity != null) {
      final calculatedType = _evaluateStatusType(
        entity: entity,
        currentVersion: state.currentAppVersion,
        hasActiveSession: hasActiveSession,
        isSoftUpdateDismissed: state.isSoftUpdateDismissed,
      );

      emit(state.copyWith(
        hasActiveSession: hasActiveSession,
        statusType: calculatedType,
      ));
    } else {
      emit(state.copyWith(hasActiveSession: hasActiveSession));
    }
  }

  void dismissSoftUpdate() {
    emit(state.copyWith(
      isSoftUpdateDismissed: true,
      statusType: AppStatusType.normal,
    ));
  }

  /// Priorities:
  /// 1. Maintenance Mode == true
  ///    - If user has an active session: allow user to finish active session while showing warning banner.
  ///    - Else: route to MaintenanceScreen.
  /// 2. Current Version < minSupportedVersion -> Force Update Screen.
  /// 3. Current Version < latestVersion && !isSoftUpdateDismissed -> Soft Update Dialog.
  /// 4. Otherwise -> Normal.
  AppStatusType _evaluateStatusType({
    required AppStatusEntity entity,
    required String currentVersion,
    required bool hasActiveSession,
    required bool isSoftUpdateDismissed,
  }) {
    if (entity.maintenanceMode) {
      // If maintenance mode is active, maintenance screen takes priority unless user has an active session
      if (hasActiveSession) {
        // Return normal or softUpdate for UI navigation, but maintenance banner will be rendered!
        if (VersionUtils.isLowerThan(currentVersion, entity.minSupportedVersion)) {
          return AppStatusType.forceUpdate;
        }
        return AppStatusType.normal;
      }
      return AppStatusType.maintenance;
    }

    if (VersionUtils.isLowerThan(currentVersion, entity.minSupportedVersion)) {
      return AppStatusType.forceUpdate;
    }

    if (VersionUtils.isLowerThan(currentVersion, entity.latestVersion) && !isSoftUpdateDismissed) {
      return AppStatusType.softUpdate;
    }

    return AppStatusType.normal;
  }

  @override
  Future<void> close() {
    _statusSubscription?.cancel();
    return super.close();
  }
}
