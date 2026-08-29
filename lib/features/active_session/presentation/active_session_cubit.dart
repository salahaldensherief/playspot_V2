import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repos/active_session_repo.dart';
import '../data/models/active_session_model.dart';
import 'active_session_state.dart';

class ActiveSessionCubit extends Cubit<ActiveSessionState> {
  final ActiveSessionRepository _repo;
  Timer? _timer;
  StreamSubscription? _realtimeSubscription;

  ActiveSessionCubit(this._repo) : super(const ActiveSessionState());

  Future<void> loadActiveSession() async {
    emit(state.copyWith(status: ActiveSessionStatus.loading));

    final result = await _repo.getActiveSession();

    result.fold(
      (failure) => emit(state.copyWith(
        status: ActiveSessionStatus.error,
        errorMessage: failure.message,
      )),
      (session) {
        if (session == null) {
          emit(state.copyWith(status: ActiveSessionStatus.empty));
        } else {
          emit(state.copyWith(
            status: ActiveSessionStatus.loaded,
            session: session,
          ));
          _startTimer();
          _subscribeToRealtime(session.bookingId);
          loadMenu(session.loungeId);
        }
      },
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.session != null) {
        final remaining = state.session!.endTime.difference(DateTime.now());
        emit(state.copyWith(remainingTime: remaining));
      }
    });
  }

  void _subscribeToRealtime(String bookingId) {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = _repo.streamActiveSession(bookingId).listen((updatedSession) {
      // Re-fetch to get nested data if needed, or update directly
      // Since stream might not have full joined data, it's safer to re-fetch
      loadActiveSession();
    });
  }

  Future<void> loadMenu(String loungeId) async {
    final result = await _repo.getLoungeMenu(loungeId);
    result.fold(
      (failure) => null, // Silently fail menu for now
      (menu) => emit(state.copyWith(menu: menu)),
    );
  }

  Future<void> extendTime(int additionalMinutes, double cost) async {
    if (state.session == null) return;

    emit(state.copyWith(extendStatus: ActionStatus.loading));

    final newEndTime = state.session!.endTime.add(Duration(minutes: additionalMinutes));
    final result = await _repo.extendTime(state.session!.bookingId, newEndTime, cost);

    result.fold(
      (failure) => emit(state.copyWith(
        extendStatus: ActionStatus.error,
        errorMessage: failure.message,
      )),
      (_) {
        emit(state.copyWith(extendStatus: ActionStatus.success));
        loadActiveSession();
      },
    );
  }

  Future<void> placeOrder(List<OrderItemModel> items) async {
    if (state.session == null) return;

    emit(state.copyWith(orderStatus: ActionStatus.loading));

    final result = await _repo.placeOrder(state.session!.bookingId, items);

    result.fold(
      (failure) => emit(state.copyWith(
        orderStatus: ActionStatus.error,
        errorMessage: failure.message,
      )),
      (_) {
        emit(state.copyWith(orderStatus: ActionStatus.success));
        loadActiveSession();
      },
    );
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _realtimeSubscription?.cancel();
    return super.close();
  }
}
