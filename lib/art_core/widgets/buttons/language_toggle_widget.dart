import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:playspot/art_core/presentation/locale_cubit.dart';
import 'package:playspot/art_core/theme/app_colors.dart';

class LanguageToggleWidget extends StatelessWidget {
  final bool isCompact;

  const LanguageToggleWidget({
    super.key,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocaleCubit, Locale>(
      builder: (context, currentLocale) {
        final isArabic = currentLocale.languageCode == 'ar';
        final targetLanguageLabel = isArabic ? 'EN' : 'عربي';

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              context.read<LocaleCubit>().toggleLocale(context);
            },
            borderRadius: BorderRadius.circular(18.r),
            splashColor: AppColors.primary.withValues(alpha: 0.2),
            highlightColor: AppColors.primary.withValues(alpha: 0.1),
            child: Container(
              height: 34.h,
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              decoration: BoxDecoration(
                color: AppColors.cardBackground.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1.w,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.3),
                    blurRadius: 6.r,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  FaIcon(
                    FontAwesomeIcons.globe,
                    size: 14.sp,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    targetLanguageLabel,
                    style: TextStyle(
                      fontFamily: isArabic ? 'Orbitron' : 'Cairo',
                      color: AppColors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
