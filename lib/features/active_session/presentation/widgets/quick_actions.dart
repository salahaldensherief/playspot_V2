import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../active_session_cubit.dart';
import '../active_session_state.dart';
import 'action_card.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveSessionCubit, ActiveSessionState>(
      buildWhen: (prev, curr) => prev.extendStatus != curr.extendStatus,
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              text: AppStrings.extendTime.tr(),
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ActionCard(label: AppStrings.min30.tr(), mins: 30, cost: 25.0, isLoading: state.extendStatus == ActionStatus.loading),
                ActionCard(label: AppStrings.hr1.tr(), mins: 60, cost: 45.0, isLoading: state.extendStatus == ActionStatus.loading),
                ActionCard(label: AppStrings.hr2.tr(), mins: 120, cost: 80.0, isLoading: state.extendStatus == ActionStatus.loading),
              ],
            ),
          ],
        );
      },
    );
  }
}
