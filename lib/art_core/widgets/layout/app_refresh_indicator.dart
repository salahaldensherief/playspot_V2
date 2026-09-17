import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/layout/app_loader.dart';

/// Custom animated pull-to-refresh widget for PlaySpot that directly renders
/// a compact, animated [AppLoader] in a glowing badge when pulling down content.
class AppRefreshIndicator extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  State<AppRefreshIndicator> createState() => _AppRefreshIndicatorState();
}

class _AppRefreshIndicatorState extends State<AppRefreshIndicator> {
  bool _isRefreshing = false;
  double _dragOffset = 0.0;
  static const double _triggerThreshold = 55.0;

  Future<void> _startRefresh() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
    });

    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _dragOffset = 0.0;
        });
      }
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_isRefreshing) return false;

    if (notification is OverscrollNotification) {
      if (notification.overscroll < 0) {
        setState(() {
          _dragOffset = (_dragOffset - notification.overscroll * 0.4)
              .clamp(0.0, 90.0);
        });
      }
    } else if (notification is ScrollUpdateNotification) {
      if (notification.metrics.extentBefore == 0 &&
          notification.scrollDelta != null &&
          notification.scrollDelta! < 0) {
        setState(() {
          _dragOffset = (_dragOffset - notification.scrollDelta! * 0.4)
              .clamp(0.0, 90.0);
        });
      }
    } else if (notification is ScrollEndNotification) {
      if (_dragOffset >= _triggerThreshold) {
        _startRefresh();
      } else {
        setState(() {
          _dragOffset = 0.0;
        });
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_isRefreshing ? 1.0 : (_dragOffset / _triggerThreshold)).clamp(0.0, 1.0);
    final activeHeight = _isRefreshing ? _triggerThreshold : _dragOffset;

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: Stack(
        children: [
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
            ),
            child: widget.child,
          ),
          if (activeHeight > 0)
            Positioned(
              top: 10.h,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedScale(
                  scale: progress,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: progress,
                    child: Container(
                      padding: EdgeInsets.all(7.r),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.neonBlue.withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonBlue.withValues(alpha: 0.3 * progress),
                            blurRadius: 10.r,
                            spreadRadius: 1.5.r,
                          ),
                        ],
                      ),
                      child: const AppLoader(
                        size: 22,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
