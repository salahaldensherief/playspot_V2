import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:playspot/art_core/assets_manager.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import '../../theme/app_colors.dart';

class LogoWidget extends StatefulWidget {
  final double? width;
  final double? height;
  final double? fontSize;
  final Color? color;
  final bool animate;

  const LogoWidget({
    super.key,
    this.width,
    this.height,
    this.fontSize,
    this.color,
    this.animate = false,
  });

  @override
  State<LogoWidget> createState() => _LogoWidgetState();
}

class _LogoWidgetState extends State<LogoWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _wobble;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _wobble = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.30), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.30, end: -0.30), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.30, end: 0.30), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.30, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.animate) _startLoop();
  }

  void _startLoop() async {
    while (mounted && widget.animate) {
      await _controller.forward();
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) break;
      _controller.reset();
    }
  }

  @override
  void didUpdateWidget(LogoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !oldWidget.animate) {
      _startLoop();
    } else if (!widget.animate) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppText(
          fontSize: widget.fontSize ?? 23.sp,
          color: AppColors.white,
          text: 'PlaySp',
        ),
        widget.animate
            ? AnimatedBuilder(
          animation: _wobble,
          builder: (context, child) {
            return Transform.rotate(
              angle: _wobble.value,
              child: child,
            );
          },
          child: _icon(),
        )
            : _icon(),
        AppText(
          fontSize: widget.fontSize ?? 23.sp,
          color: AppColors.white,
          text: 't',
        ),
      ],
    );
  }

  Widget _icon() {
    return SvgPicture.asset(
      AssetsManager.joystickIcon,
      colorFilter: ColorFilter.mode(
        widget.color ?? AppColors.white,
        BlendMode.srcIn,
      ),
      width: widget.width ?? 24,
      height: widget.height ?? 24,
    );
  }
}