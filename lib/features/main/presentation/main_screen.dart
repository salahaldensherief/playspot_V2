import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/art_core/utils/extensions/spacing_extensions.dart';
import 'package:playspot/features/home/presentation/home_cubit.dart';
import 'package:playspot/features/home/presentation/home_screen.dart';
import 'package:playspot/features/profile/presentation/profile_cubit.dart';
import 'package:playspot/features/profile/presentation/profile_screen.dart';
import 'package:playspot/features/my_bookings/presentation/my_bookings_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex;
  late final List<Widget> _screens;
  
  // ⏱️ تتبع وقت آخر تحديث لكل تاب (Home=0, Bookings=1, Profile=2)
  final Map<int, DateTime> _lastRefreshTime = {};
  static const Duration _refreshThreshold = Duration(minutes: 1);

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _screens = [
      const HomeScreen(),
      const MyBookingsScreen(),
      const ProfileScreen(),
    ];
    // تسجيل وقت البداية كأول تحديث
    _lastRefreshTime[_selectedIndex] = DateTime.now();
  }

  void _onItemTapped(int index) {
    final now = DateTime.now();
    final lastRefresh = _lastRefreshTime[index];

    // 🔄 تحقق هل التاب محتاج تحديث (أول مرة يدخله أو فات دقيقة)
    if (lastRefresh == null || now.difference(lastRefresh) > _refreshThreshold) {
      _refreshModuleData(index);
      _lastRefreshTime[index] = now;
    }

    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
    }
  }

  void _refreshModuleData(int index) {
    debugPrint("AUTO_REFRESH: Refreshing data for module index $index");
    try {
      switch (index) {
        case 0:
          context.read<HomeCubit>().getHomeData();
          break;
        case 1:
          // MyBookingsScreen handles its own Cubit internal refresh via sl<> inside initState,
          // but we can trigger a global refresh event if needed or use a global MyBookingsCubit.
          // For now, HomeScreen and Profile are the main ones.
          break;
        case 2:
          context.read<ProfileCubit>().getUserData();
          break;
      }
    } catch (e) {
      debugPrint("AUTO_REFRESH_ERROR: $e");
    }
  }

  @override
  void dispose() {
    debugPrint("CLEAN_UP: MainScreen and Home branch disposed successfully.");
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      _onItemTapped(widget.initialIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final double navBarBottom = Platform.isAndroid 
        ? (bottomPadding > 0 ? bottomPadding + 10.h : 20.h)
        : 30.h;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _selectedIndex,
              children: _screens,
            ),
          ),
          
          Positioned(
            left: 0,
            right: 0,
            bottom: navBarBottom,
            child: _buildGlassNavBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassNavBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: 24.horizontalPadding,
      height: 68.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(34.r),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08),
                width: 1.0,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                  isDark ? Colors.white.withOpacity(0.01) : Colors.black.withOpacity(0.01),
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, TablerIcons.home, "Home"),
                _buildNavItem(1, TablerIcons.calendar, "Booking"),
                _buildNavItem(2, TablerIcons.user, "Profile"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            width: 50.w,
            duration: const Duration(milliseconds: 300),
            padding: 8.allPadding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.r12),
              color: isSelected ? AppColors.neonBlue.withOpacity(0.12) : Colors.transparent, 
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.neonBlue.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
            child: Icon(
              icon,
              color: isSelected ? AppColors.neonBlue : Colors.white.withOpacity(0.4),
              size: 20.sp,
            ),
          ),
          4.verticalSpace,
          if (isSelected)
            Text(
              label,
              style: TextStyle(
                color: AppColors.neonBlue,
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    color: AppColors.neonBlue.withOpacity(0.6),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
