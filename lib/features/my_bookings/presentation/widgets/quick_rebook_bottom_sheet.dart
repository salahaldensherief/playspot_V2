import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../../art_core/app_strings.dart';
import '../../../../../art_core/router/router_keys.dart';
import '../../../../../art_core/theme/app_colors.dart';
import '../../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../../../art_core/widgets/buttons/res/button_style_config.dart';
import '../../../../../art_core/widgets/layout/app_loader.dart';
import '../../../../../art_core/widgets/layout/glass_container.dart';
import '../../../../../art_core/widgets/text/app_text.dart';
import '../../../../../core/di.dart';
import 'package:playspot/features/booking/data/models/booking_params.dart';
import '../../data/models/booking_model.dart';
import '../quick_rebook_cubit.dart';
import '../quick_rebook_state.dart';
import 'quick_rebook_actions.dart';
import 'quick_rebook_addons_section.dart';
import 'quick_rebook_header.dart';
import 'quick_rebook_setup_summary.dart';
import 'quick_rebook_slots_section.dart';

class QuickRebookBottomSheet extends StatelessWidget {
  final BookingModel booking;

  const QuickRebookBottomSheet({super.key, required this.booking});

  static Future<void> show(BuildContext context, BookingModel booking) async {
    final cubit = sl<QuickRebookCubit>();
    unawaited(cubit.initQuickRebook(booking));

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: QuickRebookBottomSheet(booking: booking),
        ),
      );
    } finally {
      await cubit.close();
    }
  }

  Future<void> _proceedToQuickCheckout(BuildContext context) async {
    final router = GoRouter.of(context);
    final checkoutParams = await context
        .read<QuickRebookCubit>()
        .prepareCheckout();

    if (!context.mounted || checkoutParams == null) return;

    Navigator.of(context).pop();
    router.pushNamed(RouterKeys.checkout, extra: checkoutParams);
  }

  void _navigateToCustomize(BuildContext context, QuickRebookState state) {
    final lounge = state.lounge;
    final room = state.room;
    if (lounge == null || room == null) return;

    final isArabic = context.locale.languageCode == 'ar';
    final addons = <Map<String, dynamic>>[];

    for (final entry in state.selectedAddonQuantities.entries) {
      final matches = state.availableExtras.where(
        (extra) => extra.id == entry.key,
      );
      if (matches.isEmpty) continue;

      final extra = matches.first;
      addons.add({
        'id': extra.id,
        'extra_id': extra.id,
        'name': isArabic ? extra.nameAr : extra.nameEn,
        'quantity': entry.value,
        'unit_price': extra.price,
      });
    }

    final params = BookingDetailsParams(
      lounge: lounge,
      rooms: [room],
      selectedDate: state.selectedDate,
      extras: addons,
      playMode: state.pastBooking?.playMode ?? 'single',
      extraControllers: state.pastBooking?.extraControllers ?? 0,
    );

    Navigator.of(context).pop();
    context.pushNamed(RouterKeys.bookingDetails, extra: params);
  }

  void _browseLounge(BuildContext context) {
    final loungeId = booking.loungeId;

    Navigator.of(context).pop();
    if (loungeId != null && loungeId.isNotEmpty) {
      context.pushNamed(
        RouterKeys.loungeDetails,
        extra: {'loungeId': loungeId},
      );
      return;
    }

    context.goNamed(RouterKeys.home);
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 28,
      child: Container(
        padding: EdgeInsets.only(
          left: 20.w,
          right: 20.w,
          top: 16.h,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
        ),
        decoration: BoxDecoration(
          color: AppColors.scaffoldBackground.withValues(alpha: 0.96),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.3)),
        ),
        child: BlocBuilder<QuickRebookCubit, QuickRebookState>(
          buildWhen: (previous, current) => previous != current,
          builder: (context, state) {
            switch (state.status) {
              case QuickRebookStatus.initial:
              case QuickRebookStatus.loading:
                return _buildLoading();
              case QuickRebookStatus.error:
              case QuickRebookStatus.unavailable:
                return _buildUnavailable(context, state);
              case QuickRebookStatus.ready:
                return _buildReady(context, state);
            }
          },
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return SizedBox(
      height: 280.h,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AppLoader(size: 40),
          SizedBox(height: 16.h),
          AppText(
            text: AppStrings.quickRebookChecking.tr(),
            fontSize: 13.sp,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailable(BuildContext context, QuickRebookState state) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy_rounded, color: AppColors.warning, size: 48.sp),
          SizedBox(height: 12.h),
          AppText(
            text: state.status == QuickRebookStatus.error
                ? AppStrings.somethingWentWrong.tr()
                : AppStrings.quickRebookUnavailableTitle.tr(),
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          SizedBox(height: 6.h),
          AppText(
            text: state.status == QuickRebookStatus.error
                ? 'quickRebookSlotsLoadFailed'.tr()
                : AppStrings.quickRebookUnavailableMessage.tr(),
            fontSize: 12.sp,
            color: AppColors.textSecondary,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20.h),
          if (state.status == QuickRebookStatus.error) ...[
            AppButton(
              content: ButtonContent(label: AppStrings.retry.tr()),
              buttonConfig: ButtonConfig(
                height: 44.h,
                backgroundColor: AppColors.neonBlue,
                borderRadius: 12.r,
              ),
              behavior: ButtonBehavior.tap(
                onTap: () => context.read<QuickRebookCubit>().changeDate(
                  state.selectedDate,
                ),
              ),
            ),
            SizedBox(height: 12.h),
          ],
          AppButton(
            content: ButtonContent(
              label: AppStrings.quickRebookBrowseLounge.tr(),
            ),
            buttonConfig: ButtonConfig(
              height: 44.h,
              backgroundColor: AppColors.neonBlue,
              borderRadius: 12.r,
            ),
            behavior: ButtonBehavior.tap(onTap: () => _browseLounge(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildReady(BuildContext context, QuickRebookState state) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              margin: EdgeInsets.only(bottom: 16.h),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          QuickRebookHeader(onClose: () => Navigator.of(context).pop()),
          SizedBox(height: 18.h),
          QuickRebookSetupSummary(booking: booking, state: state),
          SizedBox(height: 16.h),
          QuickRebookSlotsSection(state: state),
          if (state.availableExtras.isNotEmpty) ...[
            SizedBox(height: 18.h),
            QuickRebookAddonsSection(state: state),
          ],
          SizedBox(height: 18.h),
          QuickRebookActions(
            canCheckout: state.selectedSlot != null,
            onCheckout: () => _proceedToQuickCheckout(context),
            onCustomize: () => _navigateToCustomize(context, state),
          ),
        ],
      ),
    );
  }
}
