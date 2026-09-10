import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import 'package:playspot/art_core/widgets/layout/app_loader.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/features/my_bookings/presentation/widgets/booking_card.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/theme/app_sizes.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../../../../art_core/widgets/layout/app_state_view.dart';
import '../../../../art_core/widgets/layout/app_dialog.dart';
import 'my_bookings_cubit.dart';
import 'my_bookings_state.dart';

class MyBookingsScreen extends StatelessWidget {
  final bool isTab;
  final String? highlightedBookingId;

  const MyBookingsScreen({
    super.key,
    this.isTab = false,
    this.highlightedBookingId,
  });

  @override
  Widget build(BuildContext context) {
    bool hasCubit = false;
    try {
      BlocProvider.of<MyBookingsCubit>(context, listen: false);
      hasCubit = true;
    } catch (_) {}

    if (hasCubit) {
      return _MyBookingsScreenContent(
        isTab: isTab,
        highlightedBookingId: highlightedBookingId,
      );
    }

    return BlocProvider(
      create: (context) => sl<MyBookingsCubit>()..getMyBookings(),
      child: _MyBookingsScreenContent(
        isTab: isTab,
        highlightedBookingId: highlightedBookingId,
      ),
    );
  }
}

class _MyBookingsScreenContent extends StatefulWidget {
  final bool isTab;
  final String? highlightedBookingId;

  const _MyBookingsScreenContent({
    required this.isTab,
    this.highlightedBookingId,
  });

  @override
  State<_MyBookingsScreenContent> createState() =>
      _MyBookingsScreenContentState();
}

class _MyBookingsScreenContentState extends State<_MyBookingsScreenContent>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Map<String, GlobalKey> _cardKeys = {};
  bool _hasHighlighted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<MyBookingsCubit>().refreshBookingsIfStale();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _checkAndHighlightBooking(MyBookingsState state) {
    final targetId = widget.highlightedBookingId;
    if (targetId == null || targetId.isEmpty || _hasHighlighted) return;

    int targetTabIndex = -1;
    if (state.upcomingBookings.any((b) => b.id == targetId)) {
      targetTabIndex = 0;
    } else if (state.pastBookings.any((b) => b.id == targetId)) {
      targetTabIndex = 1;
    } else if (state.cancelledBookings.any((b) => b.id == targetId)) {
      targetTabIndex = 2;
    }

    if (targetTabIndex != -1) {
      _hasHighlighted = true;
      if (_tabController.index != targetTabIndex) {
        _tabController.animateTo(targetTabIndex);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final key = _cardKeys[targetId];
        if (key != null && key.currentContext != null) {
          Scrollable.ensureVisible(
            key.currentContext!,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.3,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: (!widget.isTab || context.canPop() || Navigator.canPop(context))
            ? IconButton(
                onPressed: () {
                  if (context.canPop() || Navigator.canPop(context)) {
                    context.pop();
                  } else {
                    context.goNamed(RouterKeys.home);
                  }
                },
                icon: const Icon(TablerIcons.chevron_left, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              )
            : null,
        title: AppText(
          text: AppStrings.myBookings.tr(),
          fontSize: 24.sp,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
          fontFamily: 'Orbitron',
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.neonBlue,
          labelColor: AppColors.neonBlue,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: AppColors.borderDefault,
          labelStyle: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
          tabs: [
            Tab(text: AppStrings.upcoming.tr()),
            Tab(text: AppStrings.past.tr()),
            Tab(text: AppStrings.cancelled.tr()),
          ],
        ),
      ),
      body: BlocConsumer<MyBookingsCubit, MyBookingsState>(
        listenWhen: (previous, current) =>
            previous.status != current.status ||
            previous.upcomingBookings != current.upcomingBookings ||
            previous.pastBookings != current.pastBookings ||
            previous.cancelledBookings != current.cancelledBookings,
        listener: (context, state) {
          _checkAndHighlightBooking(state);
        },
        buildWhen: (previous, current) =>
            previous.status != current.status ||
            previous.upcomingBookings != current.upcomingBookings ||
            previous.pastBookings != current.pastBookings ||
            previous.cancelledBookings != current.cancelledBookings,
        builder: (context, state) {
          _checkAndHighlightBooking(state);

          if (state.status == MyBookingsStatus.loading &&
              state.upcomingBookings.isEmpty &&
              state.pastBookings.isEmpty &&
              state.cancelledBookings.isEmpty) {
            return const AppLoader(size: 40);
          }

          if (state.status == MyBookingsStatus.failure) {
            return AppStateView.error(
              title: state.errorMessage ?? AppStrings.errorLoadingBookings.tr(),
              onRetry: () =>
                  context.read<MyBookingsCubit>().refreshBookingsIfStale(force: true),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildBookingsList(
                context,
                state.upcomingBookings,
                AppStrings.noUpcomingBookings,
                Icons.calendar_today_outlined,
              ),
              _buildBookingsList(
                context,
                state.pastBookings,
                AppStrings.noPastBookings,
                Icons.history_rounded,
              ),
              _buildBookingsList(
                context,
                state.cancelledBookings,
                AppStrings.noCancelledBookings,
                Icons.cancel_presentation_outlined,
              ),
            ],
          );
        },
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
      onRefresh: () =>
          context.read<MyBookingsCubit>().refreshBookingsIfStale(force: true),
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
              itemCount: bookings.length + 1,
              separatorBuilder: (context, index) =>
                  SizedBox(height: AppSizes.s16),
              itemBuilder: (context, index) {
                if (index == bookings.length) {
                  return const SafeBottomSpacer(
                      extraPadding: 150, androidOnly: false);
                }
                final booking = bookings[index];
                final isHighlighted = booking.id == widget.highlightedBookingId;
                final cardKey = _cardKeys.putIfAbsent(booking.id, () => GlobalKey());

                return KeyedSubtree(
                  key: cardKey,
                  child: BookingCard(
                    booking: booking,
                    isHighlighted: isHighlighted,
                    onCancel: () =>
                        _showCancelConfirmation(context, booking.id),
                  ),
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
      onConfirm: () =>
          context.read<MyBookingsCubit>().cancelBooking(bookingId),
    );
  }
}
