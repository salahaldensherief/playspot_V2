import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../active_session_cubit.dart';
import '../active_session_state.dart';
import 'timer_section.dart';
import 'station_info.dart';
import 'quick_actions.dart';
import 'active_session_action_bar.dart';
import 'billing_breakdown.dart';

class ActiveSessionBody extends StatelessWidget {
  const ActiveSessionBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveSessionCubit, ActiveSessionState>(
      buildWhen: (prev, curr) => 
          prev.status != curr.status || 
          prev.session != curr.session || 
          prev.errorMessage != curr.errorMessage,
      builder: (context, state) {
        if (state.status == ActiveSessionStatus.loading && state.session == null) {
          return const Center(child: CircularProgressIndicator(color: AppColors.neonBlue));
        }
        if (state.status == ActiveSessionStatus.empty && state.session == null) {
          return Center(child: AppText(text: AppStrings.noUpcomingBookings.tr()));
        }
        if (state.status == ActiveSessionStatus.error && state.session == null) {
          return Center(child: AppText(text: state.errorMessage ?? AppStrings.somethingWentWrong.tr()));
        }

        return RefreshIndicator(
          onRefresh: () => context.read<ActiveSessionCubit>().loadActiveSession(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(20.w),
            child: Column(
              children: [
                const TimerSection(),
                SizedBox(height: 32.h),
                StationInfo(session: state.session!),
                SizedBox(height: 24.h),
                const QuickActions(),
                SizedBox(height: 24.h),
                const ActiveSessionActionBar(),
                SizedBox(height: 24.h),
                BillingBreakdownWidget(session: state.session!),
                SizedBox(height: 32.h),
              ],
            ),
          ),
        );
      },
    );
  }
}
