import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../theme/app_colors.dart';
import '../../text/font_manager.dart';
abstract class ButtonStyleConfig {
  Color get backgroundColor;
  Color get disabledColor;
  TextStyle get textStyle;
  double get borderRadius;
  double? get width;
  double get height;
  EdgeInsets get padding;
  EdgeInsets get margin;
  bool get isOutlined;
  Gradient? get gradient;
  Color? get glowColor;
  Color? get borderColor;
}

abstract class ButtonAnimationConfig {
  Color get loadingColor;
  Duration get animationDuration;
}

class ButtonConfig implements ButtonStyleConfig, ButtonAnimationConfig {
  @override
  final Color backgroundColor;
  @override
  final Color disabledColor;
  @override
  final TextStyle textStyle;
  @override
  final double borderRadius;
  @override
  final double? width;
  @override
  final double height;
  @override
  final EdgeInsets padding;
  @override
  final EdgeInsets margin;
  @override
  final Color loadingColor;
  @override
  final Duration animationDuration;
  @override
  final bool isOutlined;
  @override
  final Gradient? gradient;
  @override
  final Color? glowColor;
  @override
  final Color? borderColor;

  ButtonConfig({
    this.backgroundColor = AppColors.primary,
    this.disabledColor = AppColors.disableButton,
    this.gradient,
    this.glowColor,
    this.borderColor,
    TextStyle? textStyle,
    this.borderRadius = 12.0,
    this.width,
    this.height = 50.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0),
    this.margin = EdgeInsets.zero,
    this.loadingColor = AppColors.white,
    this.animationDuration = const Duration(milliseconds: 200),
    this.isOutlined = false,
  }) : textStyle = textStyle ??
      TextStyle(
        color: Colors.white,
        fontSize: 15.5.sp,
        fontWeight: FontWeight.w600,
        fontFamily: FontsManager.fontFamily,
      );

  ButtonConfig.secondary({
    Color? backgroundColor,
    this.disabledColor = AppColors.splashHint,
    this.gradient,
    this.glowColor,
    this.borderColor,
    TextStyle? textStyle,
    this.borderRadius = 12.0,
    this.width,
    this.height = 50.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0),
    this.margin = EdgeInsets.zero,
    this.loadingColor = AppColors.primary,
    this.animationDuration = const Duration(milliseconds: 200),
    this.isOutlined = false,
  }) : backgroundColor = backgroundColor ?? AppColors.cardBackground,
        textStyle = textStyle ??
            TextStyle(
              color: AppColors.primary,
              fontSize: 15.5.sp,
              fontWeight: FontWeight.w600,
              fontFamily: FontsManager.fontFamily,
            );

  ButtonConfig.outlined({
    this.backgroundColor = AppColors.primary,
    this.disabledColor = AppColors.black,
    this.gradient,
    this.glowColor,
    this.borderColor,
    TextStyle? textStyle,
    this.borderRadius = 12.0,
    this.width,
    this.height = 50.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0),
    this.margin = EdgeInsets.zero,
    this.loadingColor = AppColors.primary,
    this.animationDuration = const Duration(milliseconds: 200),
    this.isOutlined = true,
  }) : textStyle = textStyle ??
      TextStyle(
        color: AppColors.primary,
        fontSize: 15.5.sp,
        fontWeight: FontWeight.w600,
        fontFamily: FontsManager.fontFamily,
      );

  ButtonConfig.gradient({
    required Gradient gradient,
    Color? glowColor,
    this.disabledColor = AppColors.disableButton,
    TextStyle? textStyle,
    this.borderRadius = 12.0,
    this.width,
    this.height = 50.0,
    this.borderColor,

    this.padding = const EdgeInsets.symmetric(horizontal: 16.0),
    this.margin = EdgeInsets.zero,
    this.loadingColor = AppColors.white,
    this.animationDuration = const Duration(milliseconds: 200),
  }) : backgroundColor = Colors.transparent,
        isOutlined = false,
        gradient = gradient,
        glowColor = glowColor,

        textStyle = textStyle ??
            TextStyle(
              color: Colors.white,
              fontSize: 15.5.sp,
              fontWeight: FontWeight.w600,
              fontFamily: FontsManager.fontFamily,
            );
}