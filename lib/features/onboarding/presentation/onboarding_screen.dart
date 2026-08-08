import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/widgets/text/font_manager.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../art_core/app_strings.dart';
import '../../../art_core/theme/app_colors.dart';
import '../../../art_core/widgets/buttons/app_button.dart';
import '../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../art_core/widgets/buttons/res/button_style_config.dart';
import '../../../art_core/widgets/text/app_text.dart';

class OnBoardingPage extends StatefulWidget {
  const OnBoardingPage({super.key});

  @override
  State<OnBoardingPage> createState() => _OnBoardingPageState();
}

class _OnBoardingPageState extends State<OnBoardingPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> boardingData = [
      {
        "icon": TablerIcons.map_pin,
        "title": AppStrings.onboardingTitle1.tr(),
        "desc": AppStrings.onboardingDesc1.tr(),
      },
      {
        "icon": Icons.calendar_today,
        "title": AppStrings.onboardingTitle2.tr(),
        "desc": AppStrings.onboardingDesc2.tr(),
      },
      {
        "icon": Icons.shield_outlined,
        "title": AppStrings.onboardingTitle3.tr(),
        "desc": AppStrings.onboardingDesc3.tr(),
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 60.h),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: boardingData.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (_, index) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      child: Icon(
                        boardingData[index]["icon"] as IconData,
                        size: 90.sp,
                        color: _currentIndex==0? AppColors.primary:AppColors.purple,
                      ),
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: _currentIndex==0?AppColors.primary.withOpacity(0.1):AppColors.purple.withOpacity(0.1),
                            blurRadius: 40,
                            offset: const Offset(0, 0),
                          ),
                          BoxShadow(
                            color: _currentIndex==0?AppColors.primary.withOpacity(0.1):AppColors.purple.withOpacity(0.1),
                            blurRadius: 70,
                            offset: const Offset(0, 0),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),
                    AppText(
                      text: boardingData[index]["title"]!,
                      color: AppColors.white,
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w900,
                      textAlign: TextAlign.center,
                      maxLines: 4,
                    ),
                    SizedBox(height: 10.h),
                    AppText(
                      color:  AppColors.textSecondary,
                      text: boardingData[index]["desc"]!,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w400,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                    ),
                  ],
                );
              },
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              boardingData.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                margin: EdgeInsets.symmetric(horizontal: 4.w),
                width: _currentIndex == index ? 30.w : 6.w,
                height: 6.h,
                decoration: BoxDecoration(
                  boxShadow: [
                    if (_currentIndex == index)
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.8),
                        blurRadius: 6,
                        offset: const Offset(0, 0),
                      ),
                  ],
                  color: _currentIndex == index
                      ? AppColors.primary
                      : Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
          ),
          SizedBox(height: 25.h),
          AppButton(
            behavior: TapBehavior(
              onTap: () {
                if (_currentIndex == boardingData.length - 1) {
                  context.goNamed(RouterKeys.signIn);
                } else {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                }
              },
            ),
            buttonConfig: _currentIndex == 2
                ? ButtonConfig.gradient(
                    gradient: LinearGradient(
                      colors: const [Color(0xFF00D4FF), Color(0xFF9B59B6)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    glowColor: _currentIndex == boardingData.length - 1
                        ? const Color(0xFF00D4FF)
                        : null,
                    borderRadius: 20.r,
                    width: 340.w,
                    height: 50.h,
                  )
                : ButtonConfig(
              textStyle: TextStyle(
                color: _currentIndex == -1? AppColors.black:AppColors.white
              ),
                    borderColor: AppColors.textSecondary,
                    isOutlined: true,
                    backgroundColor: AppColors.buttonPrimary2,
                    borderRadius: 15.r,
                    width: 340.w,
                    height: 50.h,
                  ),
            content: ButtonContent(

              label: _currentIndex == boardingData.length - 1
                  ? AppStrings.getStarted.tr()
                  : AppStrings.next.tr(),
            ),
          ),
          SizedBox(height: 20.h),
          const SafeBottomSpacer(),
        ],
      ),
    );
  }
}
