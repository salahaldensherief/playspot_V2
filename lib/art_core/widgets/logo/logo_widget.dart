import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:playspot/art_core/assets_manager.dart';
import '../../theme/app_colors.dart';

class LogoWidget extends StatefulWidget {
  final double? width;
  final double? height;
  final double? fontSize;
  final Color? color;
  final Color? textColor;
  final Color? iconColor;
  final bool animate;

  const LogoWidget({
    super.key,
    this.width,
    this.height,
    this.fontSize,
    this.color,
    this.textColor,
    this.iconColor,
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
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.25), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.25, end: -0.25), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.25, end: 0.25), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.25, end: 0.0), weight: 1),
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
    final effectiveFontSize = widget.fontSize ?? 26.sp;
    final textStyleColor = widget.textColor ?? widget.color ?? AppColors.white;
    final joystickIconColor = widget.iconColor ?? AppColors.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'PlaySp',
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontSize: effectiveFontSize,
            fontWeight: FontWeight.w400,
            color: textStyleColor,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(width: 3.w),
        widget.animate
            ? AnimatedBuilder(
                animation: _wobble,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _wobble.value,
                    child: child,
                  );
                },
                child: _icon(effectiveFontSize, joystickIconColor),
              )
            : _icon(effectiveFontSize, joystickIconColor),
        SizedBox(width: 3.w),
        Text(
          't',
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontSize: effectiveFontSize,
            fontWeight: FontWeight.w400,
            color: textStyleColor,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _icon(double fontSize, Color iconColor) {
    final iconSize = widget.height ?? widget.width ?? (fontSize * 0.92);

    return SvgPicture.asset(
      AssetsManager.joystickIcon,
      colorFilter: ColorFilter.mode(
        iconColor,
        BlendMode.srcIn,
      ),
      width: iconSize,
      height: iconSize,
    );
  }
}
