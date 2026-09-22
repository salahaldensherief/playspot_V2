import 'package:equatable/equatable.dart';
import '../domain/entities/active_session.dart';
import '../../lounge_details/data/models/extra_model.dart';

enum ActiveSessionStatus { initial, loading, loaded, empty, error }
enum ActionStatus { initial, loading, success, error }

class ActiveSessionState extends Equatable {
  final ActiveSessionStatus status;
  final ActiveSession? session;
  final ActiveSession? completedSession;
  final List<ExtraModel> menu;
  final ActionStatus extendStatus;
  final ActionStatus orderStatus;
  final ActionStatus staffRequestStatus;
  final String? errorMessage;

  const ActiveSessionState({
    this.status = ActiveSessionStatus.initial,
    this.session,
    this.completedSession,
    this.menu = const [],
    this.extendStatus = ActionStatus.initial,
    this.orderStatus = ActionStatus.initial,
    this.staffRequestStatus = ActionStatus.initial,
    this.errorMessage,
  });

  ActiveSessionState copyWith({
    ActiveSessionStatus? status,
    ActiveSession? session,
    ActiveSession? completedSession,
    List<ExtraModel>? menu,
    ActionStatus? extendStatus,
    ActionStatus? orderStatus,
    ActionStatus? staffRequestStatus,
    String? errorMessage,
  }) {
    return ActiveSessionState(
      status: status ?? this.status,
      session: session ?? this.session,
      completedSession: completedSession ?? this.completedSession,
      menu: menu ?? this.menu,
      extendStatus: extendStatus ?? this.extendStatus,
      orderStatus: orderStatus ?? this.orderStatus,
      staffRequestStatus: staffRequestStatus ?? this.staffRequestStatus,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        session,
        completedSession,
        menu,
        extendStatus,
        orderStatus,
        staffRequestStatus,
        errorMessage,
      ];
}
