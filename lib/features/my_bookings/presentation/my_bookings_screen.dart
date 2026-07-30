import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/theme/app_sizes.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../../../../art_core/widgets/layout/app_state_view.dart';
import '../../../../core/di.dart';
import '../../../core/di/modules/auth_module.dart';
import 'my_bookings_cubit.dart';
import 'my_bookings_state.dart';
import 'widgets/booking_card.dart';

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MyBookingsCubit(sl())..getMyBookings(),
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: AppColors.scaffoldBackground,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: AppText(
              text: "My Bookings",
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
              fontFamily: 'Orbitron',
            ),
            bottom: TabBar(
              indicatorColor: AppColors.neonBlue,
              labelColor: AppColors.neonBlue,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: AppColors.borderDefault,
              labelStyle:
                  TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: "Upcoming"),
                Tab(text: "Past"),
                Tab(text: "Cancelled"),
              ],
            ),
          ),
          body: BlocBuilder<MyBookingsCubit, MyBookingsState>(
            builder: (context, state) {
              if (state.status == MyBookingsStatus.loading &&
                  state.upcomingBookings.isEmpty &&
                  state.pastBookings.isEmpty &&
                  state.cancelledBookings.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state.status == MyBookingsStatus.failure) {
                return AppStateView.error(
                  title: state.errorMessage ?? "Error loading bookings",
                  onRetry: () => context.read<MyBookingsCubit>().getMyBookings(),
                );
              }

              return TabBarView(
                children: [
                  _buildBookingsList(
                    context,
                    state.upcomingBookings,
                    "No upcoming bookings",
                    Icons.calendar_today_outlined,
                  ),
                  _buildBookingsList(
                    context,
                    state.pastBookings,
                    "No past bookings",
                    Icons.history_rounded,
                  ),
                  _buildBookingsList(
                    context,
                    state.cancelledBookings,
                    "No cancelled bookings",
                    Icons.cancel_presentation_outlined,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBookingsList(
    BuildContext context,
    List bookings,
    String emptyMessage,
    IconData emptyIcon,
  ) {
    return RefreshIndicator(
      onRefresh: () => context.read<MyBookingsCubit>().getMyBookings(),
      color: AppColors.neonBlue,
      backgroundColor: AppColors.cardBackground,
      child: bookings.isEmpty
          ? SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: 0.7.sh,
                child: AppStateView.empty(
                  title: emptyMessage,
                  icon: emptyIcon,
                ),
              ),
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(AppSizes.screenPadding),
              itemCount: bookings.length,
              separatorBuilder: (context, index) =>
                  SizedBox(height: AppSizes.s16),
              itemBuilder: (context, index) {
                final booking = bookings[index];
                return BookingCard(
                  booking: booking,
                  onCancel: () =>
                      context.read<MyBookingsCubit>().cancelBooking(booking.id),
                );
              },
            ),
    );
  }
}
