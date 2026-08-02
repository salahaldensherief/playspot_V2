import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/features/my_bookings/presentation/widgets/booking_card.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/theme/app_sizes.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../../../../art_core/widgets/layout/app_state_view.dart';
import '../../../../art_core/widgets/layout/app_dialog.dart';
import '../../../../core/di.dart';
import 'my_bookings_cubit.dart';
import 'my_bookings_state.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  late final MyBookingsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = sl<MyBookingsCubit>()..getMyBookings();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: AppColors.scaffoldBackground,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: AppText(
              text: AppStrings.myBookings.tr(),
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
              tabs: [
                Tab(text: AppStrings.upcoming.tr()),
                Tab(text: AppStrings.past.tr()),
                Tab(text: AppStrings.cancelled.tr()),
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
                  title: state.errorMessage ?? AppStrings.errorLoadingBookings.tr(),
                  onRetry: () => context.read<MyBookingsCubit>().getMyBookings(),
                );
              }

              return TabBarView(
                children: [
                  _buildBookingsList(
                    context,
                    state.upcomingBookings,
                    AppStrings.noUpcomingBookings.tr(),
                    Icons.calendar_today_outlined,
                  ),
                  _buildBookingsList(
                    context,
                    state.pastBookings,
                    AppStrings.noPastBookings.tr(),
                    Icons.history_rounded,
                  ),
                  _buildBookingsList(
                    context,
                    state.cancelledBookings,
                    AppStrings.noCancelledBookings.tr(),
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
                  onCancel: () => _showCancelConfirmation(context, booking.id),
                );
              },
            ),
    );
  }

  void _showCancelConfirmation(BuildContext context, String bookingId) {
    AppDialog.show(
      context,
      type: AppDialogType.confirm,
      title: AppStrings.cancelBookingTitle,
      description: AppStrings.cancelBookingSubtitle,
      confirmText: AppStrings.yesCancel,
      cancelText: AppStrings.keepBooking,
      onConfirm: () => context.read<MyBookingsCubit>().cancelBooking(bookingId),
    );
  }
}
