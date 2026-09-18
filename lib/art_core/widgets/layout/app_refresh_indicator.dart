import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/layout/app_loader.dart';

/// Custom animated pull-to-refresh widget for PlaySpot.
///
/// - الأيقونة بتكبر بسرعة مع السحب (من 40% لحد 100%).
/// - الريفريش مبيحصلش إلا لما الأيقونة تكبر خالص (المسافة توصل [_triggerDistance]).
/// - لما توصل للحجم الكامل بتعمل "pop" + اهتزاز خفيف يعرّف اليوزر إنها جاهزة.
/// - الريفريش بيبدأ لحظة ما اليوزر يرفع إيده، مش بعد ما المحتوى يرجع مكانه.
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

  /// اليوزر وصل للحجم الكامل وهو لسه ماسك الشاشة.
  bool _armed = false;

  /// المسافة الحقيقية (بالـ px) اللي المحتوى اتشدّ بيها لتحت.
  double _pull = 0.0;

  // ================= اضبط الإحساس من هنا =================

  /// المسافة اللازمة عشان الأيقونة تكبر خالص ويبقى الريفريش جاهز.
  /// زوّدها = أصعب (أمان أكتر من الريفريش بالغلط)، قلّلها = أسهل.
  /// (المسافة دي بعد الـ friction بتاع الـ bouncing، فالإصبع بيتحرك تقريبًا ضعفها.)
  static const double _triggerDistance = 72.0;

  /// الحجم اللي الأيقونة بتبدأ بيه أول ما اليوزر يشدّ (عشان تحس إنها بتكبر بسرعة).
  static const double _minScale = 0.4;

  static const double _maxPull = 140.0;

  // =======================================================

  Future<void> _startRefresh() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
      _armed = false;
    });

    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _pull = 0.0;
        });
      }
    }
  }

  void _onDrag(double pulled) {
    final bool armedNow = pulled >= _triggerDistance;
    if (armedNow && !_armed) {
      HapticFeedback.selectionClick();
    }
    setState(() {
      _pull = pulled.clamp(0.0, _maxPull);
      _armed = armedNow;
    });
  }

  void _setPull(double pulled) {
    final double value = pulled.clamp(0.0, _maxPull);
    if (value == _pull) return;
    setState(() => _pull = value);
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_isRefreshing) return false;

    // تجاهل أي سكرول جوّاني (زي carousel أفقي أو ليست جوه الصفحة).
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final double pixels = notification.metrics.pixels;
      final double pulled = pixels < 0 ? -pixels : 0.0;

      if (notification.dragDetails != null) {
        // إيد اليوزر لسه على الشاشة
        _onDrag(pulled);
      } else if (_armed) {
        // اليوزر رفع إيده وكان وصل للحجم الكامل → ابدأ ريفريش
        _startRefresh();
      } else {
        // رفع إيده قبل ما توصل → الأيقونة بترجع تصغر مع المحتوى
        _setPull(pulled);
      }
    } else if (notification is ScrollEndNotification) {
      if (_armed) {
        _startRefresh();
      } else {
        _setPull(0.0);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _isRefreshing
        ? 1.0
        : (_pull / _triggerDistance).clamp(0.0, 1.0);
    final bool visible = _isRefreshing || _pull > 0;
    final bool ready = _armed || _isRefreshing;

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
          if (visible)
            Positioned(
              top: 10.h,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  // "pop" صغير لما توصل للحجم الكامل
                  child: AnimatedScale(
                    scale: _armed ? 1.12 : 1.0,
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOutBack,
                    // الحجم بيمشي مع الإصبع مباشرة (من غير تأخير أنيميشن)
                    child: Transform.scale(
                      scale: _minScale + (1 - _minScale) * progress,
                      child: Opacity(
                        opacity: (progress * 2).clamp(0.0, 1.0),
                        child: Container(
                          padding: EdgeInsets.all(7.r),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.neonBlue.withValues(
                                alpha: ready ? 0.9 : 0.35 + 0.35 * progress,
                              ),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.neonBlue.withValues(
                                  alpha: ready ? 0.45 : 0.3 * progress,
                                ),
                                blurRadius: 10.r,
                                spreadRadius: 1.5.r,
                              ),
                            ],
                          ),
                          child: const AppLoader(size: 22, strokeWidth: 2.5),
                        ),
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
