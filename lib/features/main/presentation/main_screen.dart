import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/features/home/presentation/home_screen.dart';
import 'package:playspot/features/search/presentation/search_screen.dart';
import 'package:playspot/features/profile/presentation/profile_screen.dart';
import 'package:playspot/features/my_bookings/presentation/my_bookings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      const MyBookingsScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
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
            bottom: 30.h,
            child: _buildGlassNavBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassNavBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24.w),
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
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(34.r),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1.0,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.01),
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
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            width: 50.w,
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
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
          SizedBox(height: 4.h),
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
