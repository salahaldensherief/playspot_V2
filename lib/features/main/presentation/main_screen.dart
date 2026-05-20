import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/features/home/presentation/home_screen.dart';
import 'package:playspot/features/search/presentation/search_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const Center(
      child: Text("Bookings", style: TextStyle(color: Colors.white)),
    ),
    const Center(
      child: Text("Profile", style: TextStyle(color: Colors.white)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        height: 90.h,
        decoration: BoxDecoration(
          color: AppColors.backgroundAlt,
          border: Border(
            top: BorderSide(color: AppColors.borderDefault, width: 0.5.w),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          backgroundColor: AppColors.backgroundAlt,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.neonBlue,

          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: TextStyle(fontSize: 12.sp),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(TablerIcons.home),
              activeIcon: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonBlue.withOpacity(0.1),
                      blurRadius: 6,
                      spreadRadius: .1,
                    ),
                  ],
                ),
                child: const Icon(TablerIcons.home),
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.calendar_today_outlined),
              activeIcon: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonBlue.withOpacity(0.1),
                      blurRadius: 6,
                      spreadRadius: .1,
                    ),
                  ],
                ),
                child: const Icon(Icons.calendar_today),
              ),
              label: 'Bookings',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline),
              activeIcon: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonBlue.withOpacity(0.1),
                      blurRadius: 6,
                      spreadRadius: .1,
                    ),
                  ],
                ),
                child: const Icon(Icons.person),
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
