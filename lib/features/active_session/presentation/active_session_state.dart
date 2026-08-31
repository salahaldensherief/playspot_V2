import 'package:equatable/equatable.dart';
import '../data/models/active_session_model.dart';
import '../../lounge_details/data/models/extra_model.dart';

enum ActiveSessionStatus { initial, loading, loaded, empty, error }
enum ActionStatus { initial, loading, success, error }

class ActiveSessionState extends Equatable {
  final ActiveSessionStatus status;
  final ActiveSessionModel? session;
  final List<ExtraModel> menu;
  final ActionStatus extendStatus;
  final ActionStatus orderStatus;
  final ActionStatus staffRequestStatus;
  final String? errorMessage;
  final Duration remainingTime;

  const ActiveSessionState({
    this.status = ActiveSessionStatus.initial,
    this.session,
    this.menu = const [],
    this.extendStatus = ActionStatus.initial,
    this.orderStatus = ActionStatus.initial,
    this.staffRequestStatus = ActionStatus.initial,
    this.errorMessage,
    this.remainingTime = Duration.zero,
  });

  ActiveSessionState copyWith({
    ActiveSessionStatus? status,
    ActiveSessionModel? session,
    List<ExtraModel>? menu,
    ActionStatus? extendStatus,
    ActionStatus? orderStatus,
    ActionStatus? staffRequestStatus,
    String? errorMessage,
    Duration? remainingTime,
  }) {
    return ActiveSessionState(
      status: status ?? this.status,
      session: session ?? this.session,
      menu: menu ?? this.menu,
      extendStatus: extendStatus ?? this.extendStatus,
      orderStatus: orderStatus ?? this.orderStatus,
      staffRequestStatus: staffRequestStatus ?? this.staffRequestStatus,
      errorMessage: errorMessage ?? this.errorMessage,
      remainingTime: remainingTime ?? this.remainingTime,
    );
  }

  @override
  List<Object?> get props => [
        status,
        session,
        menu,
        extendStatus,
        orderStatus,
        staffRequestStatus,
        errorMessage,
        remainingTime,
      ];
}
