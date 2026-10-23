import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/art_core/widgets/logo/logo_widget.dart';

void main() {
  testWidgets('splash wordmark keeps Orbitron in Arabic', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => const MaterialApp(
          locale: Locale('ar'),
          home: Scaffold(body: Center(child: LogoWidget())),
        ),
      ),
    );

    for (final wordmarkPart in ['PlaySp', 't']) {
      final text = tester.widget<Text>(find.text(wordmarkPart));
      expect(text.style?.fontFamily, 'Orbitron');
      expect(text.style?.fontWeight, FontWeight.w400);
    }
  });
}
