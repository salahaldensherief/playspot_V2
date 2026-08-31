import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';
import 'package:playspot/art_core/widgets/layout/app_state_view.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import '../../../../art_core/app_strings.dart';
import 'profile_cubit.dart';
import 'profile_state.dart';

class MyVouchersScreen extends StatelessWidget {
  const MyVouchersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: AppText(
            text: "my_rewards".tr(), // Adjust key as needed
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          bottom: TabBar(
            indicatorColor: AppColors.neonBlue,
            labelColor: AppColors.neonBlue,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [
              Tab(text: "available".tr()),
              Tab(text: "used".tr()),
              Tab(text: "expired".tr()),
            ],
          ),
        ),
        body: BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, state) {
            if (state.status == ProfileStatus.loading) {
              return const Center(child: CircularProgressIndicator(color: AppColors.neonBlue));
            }

            final vouchers = state.myVouchers;
            
            return TabBarView(
              children: [
                _buildVoucherList(vouchers.where((v) => v['status'] == 'active').toList()),
                _buildVoucherList(vouchers.where((v) => v['status'] == 'used').toList()),
                _buildVoucherList(vouchers.where((v) => v['status'] == 'expired').toList()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildVoucherList(List<Map<String, dynamic>> vouchers) {
    if (vouchers.isEmpty) {
      return AppStateView.empty(title: "no_vouchers".tr());
    }

    return ListView.separated(
      padding: EdgeInsets.all(20.w),
      itemCount: vouchers.length + 1,
      separatorBuilder: (context, index) => SizedBox(height: 16.h),
      itemBuilder: (context, index) {
        if (index == vouchers.length) return const SafeBottomSpacer();
        
        final voucher = vouchers[index];
        final isExpired = voucher['status'] == 'expired';
        final isUsed = voucher['status'] == 'used';
        final isInactive = isExpired || isUsed;
        
        return GlassContainer(
          borderRadius: 20,
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Opacity(
              opacity: isInactive ? 0.6 : 1.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: AppColors.neonBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: AppText(
                          text: voucher['code'],
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.neonBlue,
                        ),
                      ),
                      if (!isInactive)
                        _buildExpiryCountdown(voucher['expires_at']),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  AppText(
                    text: _getRewardText(voucher),
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  SizedBox(height: 4.h),
                  AppText(
                    text: isUsed 
                        ? "Used on ${DateFormat('dd MMM yyyy').format(DateTime.parse(voucher['used_at']))}"
                        : isExpired 
                            ? "Expired on ${DateFormat('dd MMM yyyy').format(DateTime.parse(voucher['expires_at']))}"
                            : "Valid until ${DateFormat('dd MMM yyyy').format(DateTime.parse(voucher['expires_at']))}",
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getRewardText(Map<String, dynamic> voucher) {
    if (voucher['reward_type'] == 'free_hour') {
      return "1 Free Hour";
    }
    return "${voucher['reward_value']} EGP Discount";
  }

  Widget _buildExpiryCountdown(String expiresAt) {
    final expiry = DateTime.parse(expiresAt);
    final daysLeft = expiry.difference(DateTime.now()).inDays;
    final isUrgent = daysLeft < 5;

    return Row(
      children: [
        Icon(
          Icons.timer_outlined,
          size: 14.sp,
          color: isUrgent ? AppColors.danger : AppColors.textSecondary,
        ),
        SizedBox(width: 4.w),
        AppText(
          text: "$daysLeft days left",
          fontSize: 11.sp,
          color: isUrgent ? AppColors.danger : AppColors.textSecondary,
        ),
      ],
    );
  }
}
