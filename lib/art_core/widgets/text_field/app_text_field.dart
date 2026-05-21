import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../assets_manager.dart';
import '../../theme/app_colors.dart';
import '../svg_icon/svg_icon_widget.dart';

class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? initialText;
  final Function(String)? onChanged;
  final String? errorText;
  final String? label;
  final String? hint;
  final TextStyle? hintStyle, textInputStyle, textStyle, labelStyle;
  final bool isSelectable;
  final bool readOnly;
  final int? maxLines, maxLength, minLines;
  final String? Function(String?)? validator;
  final bool isPassword, isRequired;
  final TextInputType? textInputType;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;
  final IconData? prefixIcon;
  final VoidCallback? onTap;
  final Color? fillColor;
  final bool filled;
  final bool enableBorder;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? boxShadow;
  final List<TextInputFormatter>? inputFormatters;
  final String? hintIcon;
  final double? borderRadius;

  const AppTextField({
    super.key,
    this.readOnly = false,
    this.boxShadow,
    this.minLines = 1,
    this.maxLines = 1,
    this.onTap,
    this.hint,
    this.label,
    this.textInputType,
    this.textInputAction,
    this.suffixIcon,
    this.prefixIcon,
    this.isPassword = false,
    this.isRequired = false,
    this.validator,
    this.onChanged,
    this.errorText,
    this.initialText,
    this.borderRadius,
    this.hintStyle,
    this.isSelectable = false,
    this.controller,
    this.maxLength,
    this.fillColor,
    this.filled = true,
    this.enableBorder = true,
    this.contentPadding,
    this.textInputStyle,
    this.textStyle,
    this.labelStyle,
    this.margin,
    this.inputFormatters,
    this.hintIcon,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool obscureText;
  String? _internalErrorText;

  @override
  void initState() {
    super.initState();
    obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null || _internalErrorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.label != null)
                Flexible(
                  child: Text(
                    widget.label!,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    style: widget.labelStyle ??
                        TextStyle(
                          fontSize: 14.sp,
                          color: hasError ? AppColors.danger : AppColors.textSecondary, // 🎨 label color changes on error
                          fontWeight: FontWeight.w400,
                          height: 1,
                        ),
                  ),
                ),
              const SizedBox(width: 2.0),
              if (widget.isRequired)
                const Text(
                  "*",
                  style: TextStyle(color: AppColors.danger), // 🎨 required star
                ),
            ],
          ),
        ),
        SizedBox(height: widget.label != null ? 10.0 : 0),
        Container(
          margin: widget.margin ?? EdgeInsets.zero,
          padding: widget.contentPadding ?? const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: widget.fillColor ?? AppColors.cardBackground, // 🎨 card bg
            border: widget.enableBorder
                ? Border.all(
              color: hasError
                  ? AppColors.danger          // 🎨 error border
                  : AppColors.borderDefault,  // 🎨 default border
              width: 1.0,
            )
                : null,
            borderRadius: BorderRadius.circular(widget.borderRadius ?? 12.r),
            boxShadow: widget.boxShadow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.label != null) const SizedBox(height: 4),
                    Padding(
                      padding: REdgeInsets.only(
                        left: (widget.prefixIcon != null) ? 25.0 : 0,
                        top: 0,
                        bottom: 0,
                      ),
                      child: TextFormField(
                        inputFormatters: widget.inputFormatters,
                        controller: widget.controller,
                        initialValue: widget.initialText,
                        textAlign: TextAlign.start,
                        readOnly: widget.readOnly,
                        minLines: widget.minLines,
                        maxLines: widget.maxLines,
                        maxLength: widget.maxLength,
                        obscureText: obscureText,
                        keyboardType: widget.textInputType,
                        textInputAction: widget.textInputAction,
                        onChanged: (val) {
                          if (_internalErrorText != null) {
                            setState(() {
                              _internalErrorText = null;
                            });
                          }
                          widget.onChanged?.call(val);
                        },
                        validator: (val) {
                          final error = widget.validator?.call(val);
                          // We don't update state here anymore as it can cause issues during build/layout
                          return error;
                        },
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        onTap: widget.onTap,
                        scrollPadding: EdgeInsets.zero,
                        // onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(), // Temporarily disabled to debug focus issues
                        style: widget.textInputStyle ??
                            widget.textStyle ??
                            TextStyle(
                              fontSize: 14.sp,
                              color: AppColors.textPrimary, // 🎨 input text
                            ),
                        cursorColor: AppColors.neonBlue, // 🎨 cursor color

                        decoration: InputDecoration(
                          prefixIcon: widget.hintIcon != null
                              ? Padding(
                            padding: REdgeInsets.only(
                              right: 8.0,
                              bottom: 2.0,
                            ),
                            child: SvgIconWidget(
                              path: widget.hintIcon!,
                              color: AppColors.textSecondary, // 🎨 prefix icon
                            ),
                          )
                              : null,
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 0,
                            minHeight: 0,
                          ),
                          suffix: widget.suffixIcon,
                          hintText: widget.hint ?? "Enter your text",
                          hintStyle: widget.hintStyle ??
                              TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.hintText, // 🎨 hint text
                                fontWeight: FontWeight.w400,
                                height: 1,
                              ),
                          fillColor: widget.filled
                              ? (widget.fillColor ?? AppColors.cardBackground) // 🎨 fill
                              : null,
                          filled: widget.filled,
                          border: InputBorder.none,
                          contentPadding:
                          widget.contentPadding ?? EdgeInsets.zero,
                          isCollapsed: true,
                          errorText: widget.errorText,
                          errorStyle: const TextStyle(
                            color: AppColors.danger, // 🎨 error text
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (widget.isPassword) ...[
                Padding(
                  padding: REdgeInsets.only(
                    top: 15.h, // Fixed consistent padding
                    right: 5,
                  ),
                  child: SvgIconWidget(
                    path: obscureText
                        ? AssetsManager.eyeOff
                        : AssetsManager.eye,
                    color: AppColors.textSecondary, // 🎨 eye icon
                    onTap: () {
                      setState(() {
                        obscureText = !obscureText;
                      });
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}