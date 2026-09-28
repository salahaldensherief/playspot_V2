import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/layout/app_loader.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import '../active_session_cubit.dart';
import '../active_session_state.dart';

class ExtensionPromptCard extends StatefulWidget {
  final int initialMinutes;
  final VoidCallback onDismiss;

  const ExtensionPromptCard({
    super.key,
    this.initialMinutes = 30,
    required this.onDismiss,
  });

  @override
  State<ExtensionPromptCard> createState() => _ExtensionPromptCardState();
}

class _ExtensionPromptCardState extends State<ExtensionPromptCard>
    with SingleTickerProviderStateMixin {
  late int _selectedMinutes;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _selectedMinutes = widget.initialMinutes;
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    _slideController.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ActiveSessionCubit>();
    final expectedCost = cubit.calculateExtensionCost(_selectedMinutes);

    return SlideTransition(
      position: _slideAnimation,
      child: SafeArea(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: AppColors.neonBlue, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: AppColors.neonBlue.withValues(alpha: 0.08),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: AppColors.neonBlue.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.timer_rounded,
                      color: AppColors.neonBlue,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          text: AppStrings.extendTime.tr(),
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        SizedBox(height: 2.h),
                        AppText(
                          text: AppStrings.sessionExpiringPromptSubtitle.tr(),
                          fontSize: 11.5.sp,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    onPressed: _handleDismiss,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              SizedBox(height: 14.h),

              // Quick Extension Chips (+15m, +30m, +60m)
              Row(
                children: [15, 30, 60].map((mins) {
                  final isSelected = _selectedMinutes == mins;
                  final chipCost = cubit.calculateExtensionCost(mins);
                  final label = mins == 60 ? AppStrings.hr1.tr() : (mins == 15 ? AppStrings.min15.tr() : AppStrings.min30.tr());

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedMinutes = mins;
                        });
                      },
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 4.w),
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.neonBlue.withValues(alpha: 0.2)
                              : AppColors.mutedBackground,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: isSelected ? AppColors.neonBlue : AppColors.divider,
                            width: isSelected ? 1.8 : 1.0,
                          ),
                        ),
                        child: Column(
                          children: [
                            AppText(
                              text: label,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? AppColors.neonBlue : Colors.white,
                            ),
                            SizedBox(height: 4.h),
                            AppText(
                              text: '${chipCost.toInt()} ${AppStrings.egpSymbol.tr()}',
                              fontSize: 11.sp,
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              SizedBox(height: 14.h),

              // Cost summary & Confirm Button
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          text: AppStrings.expectedCost.tr(),
                          fontSize: 11.sp,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(height: 2.h),
                        AppText(
                          text: '${expectedCost.toInt()} ${AppStrings.egpSymbol.tr()}',
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w900,
                          color: AppColors.neonBlue,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
                  BlocBuilder<ActiveSessionCubit, ActiveSessionState>(
                    builder: (context, state) {
                      final isLoading = state.extendStatus == ActionStatus.loading;
                      return AppButton(
                        content: ButtonContent(
                          label: isLoading ? null : AppStrings.confirmExtensionTitle.tr(),
                          body: isLoading
                              ? SizedBox(
                                  width: 20.w,
                                  height: 20.w,
                                  child: const AppLoader(size: 20, strokeWidth: 2),
                                )
                              : null,
                        ),
                        behavior: ButtonBehavior.tap(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            cubit.requestExtension(_selectedMinutes);
                            _handleDismiss();
                          },
                        ),
                        buttonConfig: ButtonConfig(
                          height: 42.h,
                          width: 140.w,
                          backgroundColor: AppColors.neonBlue,
                          borderRadius: 12.r,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
