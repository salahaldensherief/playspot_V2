import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_colors.dart';

class AppOtpField extends StatefulWidget {
  final int length;
  final TextEditingController controller;
  final Function(String)? onCompleted;

  const AppOtpField({
    super.key,
    this.length = 4,
    required this.controller,
    this.onCompleted,
  });

  @override
  State<AppOtpField> createState() => _AppOtpFieldState();
}

class _AppOtpFieldState extends State<AppOtpField> {
  late List<FocusNode> _focusNodes;
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(widget.length, (index) => FocusNode());
    _controllers = List.generate(widget.length, (index) => TextEditingController());
  }

  @override
  void dispose() {
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    _updateMainController();
  }

  void _updateMainController() {
    String currentOtp = "";
    for (var controller in _controllers) {
      currentOtp += controller.text;
    }
    widget.controller.text = currentOtp;

    if (currentOtp.length == widget.length) {
      widget.onCompleted?.call(currentOtp);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.length,
        (index) => Expanded(
          child: Container(
            height: 45.h,
            margin: EdgeInsets.symmetric(horizontal: 2.w), // تقليل المسافات الجانبية
            child: RawKeyboardListener(
              focusNode: FocusNode(),
              onKey: (event) {
                if (event is RawKeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.backspace &&
                    _controllers[index].text.isEmpty &&
                    index > 0) {
                  _focusNodes[index - 1].requestFocus();
                }
              },
              child: TextFormField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                onChanged: (value) => _onChanged(value, index),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.neonBlue,
                  fontSize: 16.sp, // تقليل حجم الخط ليناسب الـ 8 أرقام
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Orbitron',
                ),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(1),
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  counterText: "",
                  contentPadding: EdgeInsets.zero,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r), // حواف أقل حدة
                    borderSide: BorderSide(
                      color: AppColors.borderDefault,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(
                      color: AppColors.neonBlue,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: AppColors.cardBackground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
