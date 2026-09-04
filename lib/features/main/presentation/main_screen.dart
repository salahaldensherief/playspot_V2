import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/art_core/utils/extensions/spacing_extensions.dart';
import 'package:playspot/features/home/presentation/home_cubit.dart';
import 'package:playspot/features/home/presentation/home_screen.dart';
import 'package:playspot/features/profile/presentation/profile/profile_cubit.dart';
import 'package:playspot/features/profile/presentation/profile/profile_screen.dart';
import 'package:playspot/features/my_bookings/presentation/my_bookings_screen.dart';

import '../../../art_core/router/router_keys.dart';
import '../../active_session/presentation/active_session_cubit.dart';
import '../../active_session/presentation/active_session_state.dart';
import '../../my_bookings/presentation/my_bookings_cubit.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex;
  late final List<Widget> _screens;
  
  final Map<int, DateTime> _lastRefreshTime = {};
  static const Duration _refreshThreshold = Duration(minutes: 1);

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _screens = [
      const HomeScreen(),
      const MyBookingsScreen(isTab: true),
      const ProfileScreen(),
    ];
    
    // 🚀 تنفيذ التحديث الأول عند دخول الشاشة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshModuleData(_selectedIndex);
      _lastRefreshTime[_selectedIndex] = DateTime.now();
    });
  }

  void _onItemTapped(int index, {bool force = false}) {
    final now = DateTime.now();
    final lastRefresh = _lastRefreshTime[index];

    // 🔄 تحقق هل التاب محتاج تحديث (أول مرة يدخله أو فات دقيقة) أو تحديث إجباري مع احترام وقت الحد الأدنى (5 ثواني)
    final bool shouldRefresh = force || 
                               lastRefresh == null || 
                               now.difference(lastRefresh) > _refreshThreshold;

    // حماية إضافية: منع التحديث المتتالي في أقل من 5 ثواني حتى لو force: true
    final bool recentlyRefreshed = lastRefresh != null && now.difference(lastRefresh) < const Duration(seconds: 5);

    if (shouldRefresh && !recentlyRefreshed) {
      _lastRefreshTime[index] = now;
      _refreshModuleData(index);
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
          context.read<HomeCubit>().refreshHome();
          break;
        case 1:
          context.read<MyBookingsCubit>().getMyBookings();
          break;
        case 2:
          context.read<ProfileCubit>().getUserData();
          break;
      }
      // Always refresh active session check
      context.read<ActiveSessionCubit>().loadActiveSession();
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
      // 🚀 تحديث إجباري لو جاي من نافيجيشن خارجي (زي بعد الحجز)
      _onItemTapped(widget.initialIndex, force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final double navBarBottom = Platform.isAndroid 
        ? (bottomPadding > 0 ? bottomPadding + 10.h : 20.h)
        : 30.h;

    return BlocListener<ActiveSessionCubit, ActiveSessionState>(
      listenWhen: (prev, curr) => 
          prev.status != ActiveSessionStatus.loaded && curr.status == ActiveSessionStatus.loaded && curr.session != null,
      listener: (context, state) {
        try {
          context.pushNamed(RouterKeys.activeSession);
        } catch (_) {}
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: BlocBuilder<ActiveSessionCubit, ActiveSessionState>(
          buildWhen: (prev, curr) => prev.status != curr.status,
          builder: (context, state) {
            if (state.status != ActiveSessionStatus.loaded) return const SizedBox.shrink();
          
          return Container(
            margin: EdgeInsets.only(bottom: 70.h),
            child: FloatingActionButton.extended(
              onPressed: () => context.pushNamed(RouterKeys.activeSession),
              backgroundColor: AppColors.neonBlue,
              icon: const Icon(TablerIcons.device_gamepad_2, color: Colors.black),
              label: Text(
                "Active Session",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Orbitron",
                ),
              ),
            ),
          );
        },
      ),
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
    )
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
