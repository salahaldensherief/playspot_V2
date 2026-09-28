import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/utils/extensions/spacing_extensions.dart';
import 'package:playspot/art_core/widgets/buttons/back_button_widget.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/features/booking/data/models/booking_params.dart';

import '../../../core/utils/booking_error_formatter.dart';
import 'booking_cubit.dart';
import 'booking_state.dart';
import 'widgets/booking_bottom_bar.dart';
import 'widgets/booking_rooms_chips.dart';
import 'widgets/booking_session_summary.dart';
import 'widgets/duration_selector.dart';
import 'widgets/time_slot_grid.dart';

class BookingScreen extends StatefulWidget {
  final BookingDetailsParams params;

  const BookingScreen({super.key, required this.params});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToDurationAndSummary() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BookingCubit, BookingState>(
      listenWhen: (previous, current) =>
          (previous.status != current.status &&
              current.status == BookingStatus.error) ||
          (previous.startTime != current.startTime &&
              current.startTime != null),
      listener: (context, state) {
        if (state.status == BookingStatus.error && state.errorMessage != null) {
          final isEnglish = context.locale.languageCode == 'en';
          final errorMsg = getBookingErrorMessage(
            state.errorMessage!,
            isEnglish,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorMsg,
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        if (state.startTime != null) {
          _scrollToDurationAndSummary();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButtonWidget(),
          title: AppText(
            text: widget.params.rooms.length > 1
                ? AppStrings.bookRoomsCount
                    .tr(args: [widget.params.rooms.length.toString()])
                : "${AppStrings.book.tr()} ${widget.params.room.getDisplayTitle(context.locale.languageCode == 'ar')}",
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: 16.allPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BookingRoomsChips(rooms: widget.params.rooms),
                    AppText(
                      text: AppStrings.selectTime.tr(),
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                    16.verticalSpace,
                    TimeSlotGrid(lounge: widget.params.lounge),
                    24.verticalSpace,
                    AppText(
                      text: AppStrings.duration.tr(),
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                    16.verticalSpace,
                    const DurationSelector(),
                    32.verticalSpace,
                    BookingSessionSummary(params: widget.params),
                    32.verticalSpace,
                  ],
                ),
              ),
            ),
            BookingBottomBar(params: widget.params),
          ],
        ),
      ),
    );
  }
}
