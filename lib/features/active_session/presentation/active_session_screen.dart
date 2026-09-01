import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import '../data/models/active_session_model.dart';
import 'active_session_cubit.dart';
import 'active_session_state.dart';
import 'widgets/active_session_body.dart';
import 'widgets/lounge_review_bottom_sheet.dart';

class ActiveSessionScreen extends StatelessWidget {
  const ActiveSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ActiveSessionCubit, ActiveSessionState>(
      listenWhen: (prev, curr) =>
          prev.extendStatus != curr.extendStatus ||
          prev.orderStatus != curr.orderStatus ||
          prev.staffRequestStatus != curr.staffRequestStatus ||
          (prev.status != curr.status && curr.status == ActiveSessionStatus.empty),
      listener: (context, state) {
        if (state.extendStatus == ActionStatus.success) {
          GameHudToast.show(
            context,
            AppStrings.sessionExtendedSuccess.tr(),
            type: ToastType.success,
          );
        }
        if (state.orderStatus == ActionStatus.success) {
          GameHudToast.show(
            context,
            AppStrings.orderPlacedSuccess.tr(),
            type: ToastType.success,
          );
        }
        if (state.staffRequestStatus == ActionStatus.success) {
          GameHudToast.show(
            context,
            AppStrings.staffNotifiedSuccess.tr(),
            type: ToastType.success,
          );
        }
        if (state.errorMessage != null &&
            (state.extendStatus == ActionStatus.error ||
                state.orderStatus == ActionStatus.error ||
                state.staffRequestStatus == ActionStatus.error)) {
          GameHudToast.show(
            context,
            state.errorMessage!,
            type: ToastType.error,
          );
        }

        if (state.status == ActiveSessionStatus.empty && state.session != null) {
          _showReviewBottomSheet(context, state.session!);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: AppText(
            text: AppStrings.activeSession.tr(),
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppColors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const ActiveSessionBody(),
      ),
    );
  }

  void _showReviewBottomSheet(BuildContext context, ActiveSessionModel session) {
    final cubit = context.read<ActiveSessionCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LoungeReviewBottomSheet(
        loungeName: session.loungeName,
        onSubmit: (rating, comment) => cubit.submitReview(rating: rating, comment: comment),
      ),
    ).then((_) {
      if (context.mounted) Navigator.pop(context);
    });
  }
}
