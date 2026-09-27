import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../art_core/router/router_keys.dart';
import '../../../active_session/presentation/active_session_cubit.dart';
import '../../../active_session/presentation/active_session_state.dart';
import '../cubit/app_status_cubit.dart';
import '../cubit/app_status_state.dart';
import '../../domain/entities/app_status_type.dart';

class AppStatusRuntimeGuard extends StatelessWidget {
  final Widget child;

  const AppStatusRuntimeGuard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<ActiveSessionCubit, ActiveSessionState>(
          listenWhen: (previous, current) =>
              previous.status != current.status ||
              previous.session?.bookingId != current.session?.bookingId,
          listener: (context, state) {
            context.read<AppStatusCubit>().updateActiveSessionStatus(
              hasActiveSession:
                  state.status == ActiveSessionStatus.loaded &&
                  state.session != null,
            );
          },
        ),
        BlocListener<AppStatusCubit, AppStatusState>(
          listenWhen: (previous, current) =>
              previous.statusType != current.statusType ||
              previous.statusEntity != current.statusEntity,
          listener: (context, state) {
            switch (state.statusType) {
              case AppStatusType.maintenance:
                context.goNamed(
                  RouterKeys.maintenance,
                  extra: state.statusEntity,
                );
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
              case AppStatusType.maintenanceRestricted:
              case AppStatusType.softUpdate:
                break;
            }
          },
        ),
      ],
      child: child,
    );
  }
}
