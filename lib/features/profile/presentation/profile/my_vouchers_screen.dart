import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';
import 'package:playspot/art_core/widgets/layout/app_state_view.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import 'package:playspot/art_core/widgets/layout/app_loader.dart';
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
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.goNamed(RouterKeys.home);
              }
            },
          ),
          title: AppText(
            text: "my_rewards".tr(),
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
          buildWhen: (previous, current) =>
              previous.myVouchers != current.myVouchers ||
              previous.status != current.status,
          builder: (context, state) {
            if (state.status == ProfileStatus.loading) {
              return const AppLoader(size: 40);
            }

            final vouchers = state.myVouchers;
            
            return TabBarView(
              children: [
                _buildVoucherList(context, vouchers.where((v) => v['status'] == 'active').toList()),
                _buildVoucherList(context, vouchers.where((v) => v['status'] == 'used').toList()),
                _buildVoucherList(context, vouchers.where((v) => v['status'] == 'expired').toList()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildVoucherList(BuildContext context, List<Map<String, dynamic>> vouchers) {
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
        final String code = voucher['code']?.toString() ?? '';
        
        return GlassContainer(
          borderRadius: 20,
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Opacity(
              opacity: isInactive ? 0.5 : 1.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Reward Title & Expiry countdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: AppText(
                          text: _getRewardText(voucher),
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isInactive) ...[
                        SizedBox(width: 8.w),
                        _buildExpiryCountdown(voucher['expires_at']),
                      ],
                    ],
                  ),
                  SizedBox(height: 12.h),

                  // Voucher Code Banner with Copy Action
                  GestureDetector(
                    onTap: () => _copyCode(context, code),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: AppColors.neonBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: AppColors.neonBlue.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.local_offer_outlined,
                            color: AppColors.neonBlue,
                            size: 18.sp,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: AppText(
                              text: code,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.neonBlue,
                              letterSpacing: 1.0,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: AppColors.neonBlue.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.copy_rounded,
                                  color: AppColors.neonBlue,
                                  size: 13.sp,
                                ),
                                SizedBox(width: 4.w),
                                AppText(
                                  text: "copyCode".tr(),
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.neonBlue,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 10.h),

                  // Expiry Date Footer
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: AppText(
                          text: isUsed 
                              ? "Used on ${DateFormat('dd MMM yyyy').format(DateTime.parse(voucher['used_at']))}"
                              : isExpired 
                                  ? "Expired on ${DateFormat('dd MMM yyyy').format(DateTime.parse(voucher['expires_at']))}"
                                  : "Valid until ${DateFormat('dd MMM yyyy').format(DateTime.parse(voucher['expires_at']))}",
                          fontSize: 12.sp,
                          color: AppColors.textSecondary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _copyCode(BuildContext context, String code) {
    if (code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("codeCopied".tr()),
        backgroundColor: AppColors.neonBlue,
        duration: const Duration(seconds: 2),
      ),
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
      mainAxisSize: MainAxisSize.min,
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
