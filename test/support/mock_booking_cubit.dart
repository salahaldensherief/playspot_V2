import 'package:bloc_test/bloc_test.dart';
import 'package:playspot/features/booking/presentation/booking_cubit.dart';
import 'package:playspot/features/booking/presentation/booking_state.dart';

class MockBookingCubit extends MockCubit<BookingState>
    implements BookingCubit {}
