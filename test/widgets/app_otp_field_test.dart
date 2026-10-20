import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/art_core/widgets/otp/app_otp_field.dart';

void main() {
  testWidgets('backspace in an empty OTP box focuses the previous box', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          home: Scaffold(body: AppOtpField(controller: controller)),
        ),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '1');
    await tester.pump();
    bool hasFocus(int index) => tester
        .widget<EditableText>(
          find.descendant(
            of: fields.at(index),
            matching: find.byType(EditableText),
          ),
        )
        .focusNode
        .hasFocus;
    expect(hasFocus(1), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(hasFocus(0), isTrue);
    expect(controller.text, '1');
  });
}
