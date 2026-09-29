import 'package:equatable/equatable.dart';
import '../domain/entities/active_session.dart';
import '../domain/entities/canteen_combo.dart';
import '../domain/entities/out_of_stock_item.dart';
import '../domain/entities/upsell_suggestion.dart';
import '../../lounge_details/data/models/extra_model.dart';

enum ActiveSessionStatus { initial, loading, loaded, empty, error }
enum ActionStatus { initial, loading, success, error }

class ActiveSessionState extends Equatable {
  final ActiveSessionStatus status;
  final ActiveSession? session;
  final ActiveSession? completedSession;
  final List<ExtraModel> menu;
  final List<CanteenCombo> combos;
  final List<UpsellSuggestion> upsellSuggestions;
  final int upsellImpressionsCount;
  final List<OutOfStockItem> unavailableItems;
  final ActionStatus menuStatus;
  final ActionStatus extendStatus;
  final ActionStatus orderStatus;
  final ActionStatus staffRequestStatus;
  final String? errorMessage;

  const ActiveSessionState({
    this.status = ActiveSessionStatus.initial,
    this.session,
    this.completedSession,
    this.menu = const [],
    this.combos = const [],
    this.upsellSuggestions = const [],
    this.upsellImpressionsCount = 0,
    this.unavailableItems = const [],
    this.menuStatus = ActionStatus.initial,
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
    List<CanteenCombo>? combos,
    List<UpsellSuggestion>? upsellSuggestions,
    int? upsellImpressionsCount,
    List<OutOfStockItem>? unavailableItems,
    ActionStatus? menuStatus,
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
      combos: combos ?? this.combos,
      upsellSuggestions: upsellSuggestions ?? this.upsellSuggestions,
      upsellImpressionsCount: upsellImpressionsCount ?? this.upsellImpressionsCount,
      unavailableItems: unavailableItems ?? this.unavailableItems,
      menuStatus: menuStatus ?? this.menuStatus,
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
        combos,
        upsellSuggestions,
        upsellImpressionsCount,
        unavailableItems,
        menuStatus,
        extendStatus,
        orderStatus,
        staffRequestStatus,
        errorMessage,
      ];
}
