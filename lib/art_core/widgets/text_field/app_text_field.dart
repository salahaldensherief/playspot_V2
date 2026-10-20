import 'package:playspot/art_core/widgets/text/app_text.dart';
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

  @override
  void initState() {
    super.initState();
    obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;

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
                  child: AppText(
                    text: widget.label!,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    style:
                        widget.labelStyle ??
                        TextStyle(
                          fontSize: 14.sp,
                          color: hasError
                              ? AppColors.danger
                              : AppColors
                                    .textSecondary, // 🎨 label color changes on error
                          fontWeight: FontWeight.w400,
                          height: 1,
                        ),
                  ),
                ),
              const SizedBox(width: 2.0),
              if (widget.isRequired)
                const AppText(
                  text: "*",
                  style: TextStyle(color: AppColors.danger), // 🎨 required star
                ),
            ],
          ),
        ),
        SizedBox(height: widget.label != null ? 10.0 : 0),
        Container(
          margin: widget.margin ?? EdgeInsets.zero,
          decoration: widget.boxShadow == null
              ? null
              : BoxDecoration(boxShadow: widget.boxShadow),
          // The decoration belongs to InputDecorator so validation messages
          // are laid out below the outlined input instead of inside its box.
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
                    TextFormField(
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
                      onChanged: widget.onChanged,
                      validator: widget.validator,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      onTap: widget.onTap,
                      scrollPadding: EdgeInsets.zero,
                      onTapOutside: (event) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      style:
                          widget.textInputStyle ??
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
                                  color:
                                      AppColors.textSecondary, // 🎨 prefix icon
                                ),
                              )
                            : widget.prefixIcon != null
                            ? Icon(
                                widget.prefixIcon,
                                color: AppColors.textSecondary,
                              )
                            : null,
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 0,
                          minHeight: 0,
                        ),
                        suffix: widget.suffixIcon,
                        suffixIcon: widget.isPassword
                            ? IconButton(
                                onPressed: () =>
                                    setState(() => obscureText = !obscureText),
                                icon: SvgIconWidget(
                                  path: obscureText
                                      ? AssetsManager.eyeOff
                                      : AssetsManager.eye,
                                  color: AppColors.textSecondary,
                                ),
                              )
                            : null,
                        hintText: widget.hint,
                        hintStyle:
                            widget.hintStyle ??
                            TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.hintText, // 🎨 hint text
                              fontWeight: FontWeight.w400,
                              height: 1,
                            ),
                        fillColor: widget.filled
                            ? (widget.fillColor ??
                                  AppColors.cardBackground) // 🎨 fill
                            : null,
                        filled: widget.filled,
                        border: _outlineBorder(AppColors.borderDefault),
                        enabledBorder: _outlineBorder(AppColors.borderDefault),
                        focusedBorder: _outlineBorder(AppColors.neonBlue),
                        errorBorder: _outlineBorder(AppColors.danger),
                        focusedErrorBorder: _outlineBorder(AppColors.danger),
                        disabledBorder: _outlineBorder(AppColors.borderDefault),
                        contentPadding:
                            widget.contentPadding ??
                            EdgeInsets.symmetric(
                              vertical: 16.h,
                              horizontal: 18.w,
                            ),
                        // Reserve the validation line before typing so the
                        // next field does not jump when an error appears.
                        helperText: widget.validator == null ? null : ' ',
                        errorText: widget.errorText,
                        errorStyle: const TextStyle(
                          color: AppColors.danger, // 🎨 error text
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  InputBorder _outlineBorder(Color color) {
    if (!widget.enableBorder) return InputBorder.none;
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(widget.borderRadius ?? 12.r),
      borderSide: BorderSide(color: color),
    );
  }
}
