import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../art_core/router/router_keys.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../../core/di.dart';
import '../../domain/entities/app_status_entity.dart';
import '../../domain/entities/app_status_type.dart';
import '../cubit/app_status_cubit.dart';
import '../cubit/app_status_state.dart';
import '../screens/maintenance_screen.dart';

class MaintenanceRuntimeGate extends StatelessWidget {
  final AppStatusEntity? initialStatusEntity;

  const MaintenanceRuntimeGate({
    super.key,
    this.initialStatusEntity,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<AppStatusCubit>(),
      child: BlocListener<AppStatusCubit, AppStatusState>(
        listenWhen: (previous, current) =>
            previous.statusType != current.statusType,
        listener: (context, state) {
          switch (state.statusType) {
            case AppStatusType.maintenance:
              break;
            case AppStatusType.forceUpdate:
              context.goNamed(
                RouterKeys.forceUpdate,
                extra: {
                  'entity': state.statusEntity,
                  'version': state.currentAppVersion,
                },
              );
              break;
            case AppStatusType.normal:
            case AppStatusType.softUpdate:
            case AppStatusType.maintenanceRestricted:
              final user = sl<AuthRepository>().getCurrentUser();
              context.goNamed(
                user == null ? RouterKeys.signIn : RouterKeys.home,
              );
              break;
          }
        },
        child: MaintenanceScreen(
          statusEntity:
              context.watch<AppStatusCubit>().state.statusEntity ??
              initialStatusEntity,
        ),
      ),
    );
  }
}
