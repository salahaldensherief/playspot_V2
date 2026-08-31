import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/booking_status.dart';
import '../data/repos/active_session_repo.dart';
import '../data/models/active_session_model.dart';
import '../data/models/order_item_model.dart';
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
        final now = DateTime.now();
        final remaining = state.session!.endTime.difference(now);
        
        if (remaining.inSeconds <= 0 && state.status == ActiveSessionStatus.loaded) {
          _timer?.cancel();
          emit(state.copyWith(
            remainingTime: Duration.zero,
            status: ActiveSessionStatus.empty, // Signal UI to close/show review
          ));
        } else {
          emit(state.copyWith(remainingTime: remaining));
        }
      }
    });
  }

  void _subscribeToRealtime(String bookingId) {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = _repo.streamActiveSession(bookingId).listen((updatedSession) {
      if (updatedSession.status == BookingStatus.completed) {
        _timer?.cancel();
        emit(state.copyWith(status: ActiveSessionStatus.empty));
      } else {
        loadActiveSession();
      }
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

    final result = await _repo.extendTime(state.session!.bookingId, additionalMinutes, cost);

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

  Future<void> requestStaffAssistance(String type, String? notes) async {
    if (state.session == null) return;

    emit(state.copyWith(staffRequestStatus: ActionStatus.loading));

    final result = await _repo.requestStaffAssistance(
      bookingId: state.session!.bookingId,
      callType: type,
      notes: notes,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        staffRequestStatus: ActionStatus.error,
        errorMessage: failure.message,
      )),
      (_) => emit(state.copyWith(staffRequestStatus: ActionStatus.success)),
    );
  }

  Future<void> submitReview({
    required double rating,
    String? comment,
  }) async {
    if (state.session == null) return;

    final result = await _repo.submitLoungeReview(
      loungeId: state.session!.loungeId,
      bookingId: state.session!.bookingId,
      rating: rating,
      comment: comment,
    );

    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (_) => null,
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
