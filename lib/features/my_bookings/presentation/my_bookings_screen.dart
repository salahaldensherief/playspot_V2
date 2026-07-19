import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../../../../core/di.dart';
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
              labelStyle: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: "Upcoming"),
                Tab(text: "Past"),
                Tab(text: "Cancelled"),
              ],
            ),
          ),
          body: BlocBuilder<MyBookingsCubit, MyBookingsState>(
            builder: (context, state) {
              if (state.status == MyBookingsStatus.loading) {
                return const Center(child: CircularProgressIndicator());
              }

              return TabBarView(
                children: [
                  _buildBookingsList(context, state.upcomingBookings, "No upcoming bookings"),
                  _buildBookingsList(context, state.pastBookings, "No past bookings"),
                  _buildBookingsList(context, state.cancelledBookings, "No cancelled bookings"),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBookingsList(BuildContext context, List bookings, String emptyMessage) {
    if (bookings.isEmpty) {
      return Center(
        child: AppText(
          text: emptyMessage,
          color: AppColors.textSecondary,
          fontSize: 14.sp,
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(16.w),
      itemCount: bookings.length,
      separatorBuilder: (context, index) => SizedBox(height: 16.h),
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return BookingCard(
          booking: booking,
          onCancel: () => context.read<MyBookingsCubit>().cancelBooking(booking.id),
        );
      },
    );
  }
}
