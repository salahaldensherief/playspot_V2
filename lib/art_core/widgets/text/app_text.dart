import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';

import '../../extension/globlX.dart';
import '../../theme/app_colors.dart';
import 'font_manager.dart';

class AppText extends StatefulWidget {
  final String text;
  final String? fontFamily;
  final double? fontSize;
  final double? height;
  final Color? color;
  final FontWeight? fontWeight;
  final int? maxLines;
  final TextAlign? textAlign;
  final TextDecoration? textDecoration;
  final TextOverflow? overflow;
  final double? textSizeFactor;
  final double? textSizePercentage;
  final TextStyle? style;
  final void Function()? onTap;
  final List<Shadow> shadows;
  final bool showAllTextOnTap;
  final TextDirection? textDirection;
  final String? showMoreText;
  final String? showLessText;
  final TextStyle? showMoreStyle;
  final double? letterSpacing;

  const AppText({
    super.key,
    required this.text,
    this.onTap,
    this.fontSize,
    this.height,
    this.color,
    this.fontWeight,
    this.maxLines,
    this.textAlign,
    this.textDecoration,
    this.fontFamily,
    this.overflow,
    this.textSizeFactor,
    this.textSizePercentage,
    this.style,
    this.shadows = const [],
    this.showAllTextOnTap = false,
    this.textDirection,
    this.showMoreText,
    this.showLessText,
    this.showMoreStyle,
    this.letterSpacing,
  });

  @override
  State<AppText> createState() => _AppTextState();
}

class _AppTextState extends State<AppText> {
  bool _showAll = false;

  void _handleTap() {
    if (widget.showAllTextOnTap) {
      setState(() {
        _showAll = !_showAll;
      });
    }
    widget.onTap?.call();
  }

  TextStyle _getTextStyle() {
    final defaultColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.primary;
    final defaultFontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;

    return widget.style ??
        TextStyle(
          fontSize: widget.fontSize ?? 14.sp,
          decorationColor: widget.color ?? defaultColor,
          color: widget.color ?? defaultColor,
          fontWeight: widget.fontWeight ?? FontWeight.w400,
          height: widget.height ?? 1.4.h,
          fontFamily: widget.fontFamily ?? defaultFontFamily ?? FontsManager.fontFamily,
          decoration: widget.textDecoration,
          shadows: widget.shadows,
          letterSpacing: widget.letterSpacing,
        );
  }

  bool _isTextOverflowing(String text, TextStyle style, int maxLines, double maxWidth) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: maxLines,
      textDirection: widget.textDirection ?? _getTextDirection() ,
    );
    textPainter.layout(maxWidth: maxWidth);
    return textPainter.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = _getTextStyle();
    final displayText = widget.text.isNotNullOrEmptyX ? widget.text : "";

    if (widget.showAllTextOnTap && widget.maxLines != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final isOverflowing = _isTextOverflowing(
              displayText,
              textStyle,
              widget.maxLines!,
              constraints.maxWidth
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _handleTap,
                child: Text(
                  displayText,
                  style: textStyle,
                  maxLines: _showAll ? null : widget.maxLines,
                  overflow: _showAll ? TextOverflow.visible : (widget.overflow ?? TextOverflow.ellipsis),
                  textAlign: widget.textAlign ?? TextAlign.start,
                ),
              ),

              if (isOverflowing) ...[
                SizedBox(height: 2.h),
                GestureDetector(
                  onTap: _handleTap,
                  child: Text(
                    _showAll
                        ? (widget.showLessText ??AppStrings.showLess)
                        : (widget.showMoreText ?? AppStrings.showMore),
                    style: widget.showMoreStyle?? textStyle.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                      decorationThickness: 0.5,
                    ),
                    textAlign: widget.textAlign ?? TextAlign.start,
                  ),
                ),
              ],
            ],
          );
        },
      );
    }

    return InkWell(
      onTap: widget.onTap,
      child: Text(
        displayText,
        style: textStyle,
        maxLines: widget.maxLines,
        overflow: widget.overflow ?? TextOverflow.ellipsis,
        textAlign: widget.textAlign ?? TextAlign.start,
      ),
    );
  }

  TextDirection _getTextDirection() {
    if (widget.textDirection != null) {
      return widget.textDirection!;
    }

    if (widget.text.isEmpty) {
      return TextDirection.ltr;
    }

    int checkedLetters = 0;
    int arabicCount = 0;

    for (final rune in widget.text.runes) {
      // تجاهل المسافات والأرقام والرموز
      if ((rune >= 0x0041 && rune <= 0x005A) || // A-Z
          (rune >= 0x0061 && rune <= 0x007A) || // a-z
          (rune >= 0x0600 && rune <= 0x06FF) || // Arabic
          (rune >= 0xFB50 && rune <= 0xFDFF) || // Arabic Presentation Forms-A
          (rune >= 0xFE70 && rune <= 0xFEFF)) { // Arabic Presentation Forms-B

        checkedLetters++;

        // لو الحرف عربي
        if ((rune >= 0x0600 && rune <= 0x06FF) ||
            (rune >= 0xFB50 && rune <= 0xFDFF) ||
            (rune >= 0xFE70 && rune <= 0xFEFF)) {
          arabicCount++;
        }

        // وقف بعد 3 حروف
        if (checkedLetters == 3) break;
      }
    }

    // لو حرف واحد على الأقل عربي من أول 3
    return arabicCount > 0 ? TextDirection.rtl : TextDirection.ltr;
  }

// TextDirection _getTextDirection() {
//   if (widget.textDirection != null) {
//     return widget.textDirection!;
//   }
//
//   if (widget.text.isEmpty) {
//     return TextDirection.ltr;
//   }
//
//   for (final rune in widget.text.runes) {
//     if (rune >= 0x0600 && rune <= 0x06FF) {
//       print('Arabic detected in: ${widget.text}');
//       return TextDirection.rtl;
//     }
//     if ((rune >= 0x0041 && rune <= 0x005A) || (rune >= 0x0061 && rune <= 0x007A)) {
//       print('English detected in: ${widget.text}');
//       return TextDirection.ltr;
//     }
//   }
//
//   return TextDirection.ltr;
// }

}