import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/assets_manager.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';

import '../../../art_core/app_strings.dart';
import '../../../art_core/theme/app_colors.dart';
import '../../../art_core/widgets/buttons/app_button.dart';
import '../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../art_core/widgets/buttons/res/button_style_config.dart';
import '../../../art_core/widgets/text/app_text.dart';

class _OnboardingItem {
  final String image;
  final String title;
  final String desc;
  final Color accentColor;

  const _OnboardingItem({
    required this.image,
    required this.title,
    required this.desc,
    required this.accentColor,
  });
}

class OnBoardingPage extends StatefulWidget {
  const OnBoardingPage({super.key});

  @override
  State<OnBoardingPage> createState() => _OnBoardingPageState();
}

class _OnBoardingPageState extends State<OnBoardingPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<_OnboardingItem> boardingData = [
      _OnboardingItem(
        image: AssetsManager.onboarding1,
        title: AppStrings.onboardingTitle1.tr(),
        desc: AppStrings.onboardingDesc1.tr(),
        accentColor: AppColors.primary,
      ),
      _OnboardingItem(
        image: AssetsManager.onboarding2,
        title: AppStrings.onboardingTitle2.tr(),
        desc: AppStrings.onboardingDesc2.tr(),
        accentColor: AppColors.purple,
      ),
      _OnboardingItem(
        image: AssetsManager.onboarding3,
        title: AppStrings.onboardingTitle3.tr(),
        desc: AppStrings.onboardingDesc3.tr(),
        accentColor: const Color(0xFF00D4FF),
      ),
    ];

    final Color currentAccent = boardingData[_currentIndex].accentColor;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        AssetsManager.logoLightMode,
                        height: 28.h,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  if (_currentIndex < boardingData.length - 1)
                    GestureDetector(
                      onTap: () => context.goNamed(RouterKeys.signIn),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(
                            color: AppColors.white.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        child: AppText(
                          text: AppStrings.skip.tr(),
                          color: AppColors.textSecondary,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    SizedBox(height: 32.h),
                ],
              ),
            ),

            // Main Page Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: boardingData.length,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemBuilder: (context, index) {
                  final item = boardingData[index];

                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Image Container with Neon Frame & Ambient Glow
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Ambient Glow behind the card
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              width: 260.w,
                              height: 260.h,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: item.accentColor.withValues(alpha: 0.25),
                                boxShadow: [
                                  BoxShadow(
                                    color: item.accentColor.withValues(alpha: 0.35),
                                    blurRadius: 80,
                                    spreadRadius: 20,
                                  ),
                                ],
                              ),
                            ),

                            // Main Image Card with Gradient Border
                            Container(
                              height: 340.h,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28.r),
                                gradient: LinearGradient(
                                  colors: [
                                    item.accentColor.withValues(alpha: 0.6),
                                    AppColors.purple.withValues(alpha: 0.2),
                                    item.accentColor.withValues(alpha: 0.1),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.all(2.r),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.scaffoldBackground,
                                  borderRadius: BorderRadius.circular(26.r),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(26.r),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.asset(
                                        item.image,
                                        fit: BoxFit.cover,
                                      ),

                                      // Subtle gradient overlay for contrast
                                      Positioned.fill(
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.transparent,
                                                Colors.black
                                                    .withValues(alpha: 0.2),
                                                Colors.black
                                                    .withValues(alpha: 0.65),
                                              ],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              stops: const [0.4, 0.7, 1.0],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 28.h),

                        // Title
                        AppText(
                          text: item.title,
                          color: AppColors.white,
                          fontSize: 23.sp,
                          fontWeight: FontWeight.w900,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                        ),

                        SizedBox(height: 10.h),

                        // Description
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10.w),
                          child: AppText(
                            color: AppColors.textSecondary,
                            text: item.desc,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w400,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            SizedBox(height: 12.h),

            // Page Indicator Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                boardingData.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  width: _currentIndex == index ? 28.w : 7.w,
                  height: 7.h,
                  decoration: BoxDecoration(
                    boxShadow: [
                      if (_currentIndex == index)
                        BoxShadow(
                          color: currentAccent.withValues(alpha: 0.8),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                    ],
                    color: _currentIndex == index
                        ? currentAccent
                        : AppColors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),
            ),

            SizedBox(height: 24.h),

            // Action Button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: AppButton(
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
                buttonConfig: _currentIndex == boardingData.length - 1
                    ? ButtonConfig.gradient(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00D4FF), Color(0xFF9B59B6)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        glowColor: const Color(0xFF00D4FF),
                        borderRadius: 20.r,
                        width: double.infinity,
                        height: 52.h,
                      )
                    : ButtonConfig(
                        textStyle: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        borderColor: AppColors.textSecondary.withValues(alpha: 0.4),
                        isOutlined: true,
                        backgroundColor: AppColors.buttonPrimary2,
                        borderRadius: 18.r,
                        width: double.infinity,
                        height: 52.h,
                      ),
                content: ButtonContent(
                  label: _currentIndex == boardingData.length - 1
                      ? AppStrings.getStarted.tr()
                      : AppStrings.next.tr(),
                ),
              ),
            ),

            SizedBox(height: 16.h),
            const SafeBottomSpacer(),
          ],
        ),
      ),
    );
  }
}



