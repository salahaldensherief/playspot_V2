import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/art_core/widgets/text_field/app_text_field.dart';

void main() {
  testWidgets('single line input keeps its height while typing', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: AppTextField(
                  controller: controller,
                  label: 'Name',
                  hint: 'Enter a name',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = tester.getSize(find.byType(AppTextField)).height;

    await tester.enterText(find.byType(TextFormField), 'Salah');
    await tester.pumpAndSettle();
    final after = tester.getSize(find.byType(AppTextField)).height;

    expect(after, before);
  });

  testWidgets('input keeps its height when a clear icon appears', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) => AppTextField(
                    controller: controller,
                    hint: 'Search',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    suffixIcon: value.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: controller.clear,
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = tester.getSize(find.byType(AppTextField)).height;

    await tester.enterText(find.byType(TextFormField), 'Salah');
    await tester.pumpAndSettle();
    final after = tester.getSize(find.byType(AppTextField)).height;

    expect(after, before);
  });

  testWidgets('validation does not enlarge the input box while typing', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: AppTextField(
                  controller: controller,
                  label: 'Email',
                  validator: (value) => value != null && value.contains('@')
                      ? null
                      : 'Invalid email',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final field = find.byType(TextFormField);
    final before = tester.getSize(field).height;

    await tester.enterText(field, 's');
    await tester.pumpAndSettle();
    final after = tester.getSize(field).height;

    expect(after, before);
    expect(find.text('Invalid email'), findsOneWidget);
    final inputDecorator = find.descendant(
      of: field,
      matching: find.byType(InputDecorator),
    );
    expect(
      tester.widget<InputDecorator>(inputDecorator).decoration.border,
      isA<OutlineInputBorder>(),
    );
  });

  testWidgets('password visibility control stays inside the input', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 320, child: AppTextField(isPassword: true)),
          ),
        ),
      ),
    );

    final inputDecorator = find.byType(InputDecorator);
    final visibilityButton = find.descendant(
      of: inputDecorator,
      matching: find.byType(IconButton),
    );
    expect(visibilityButton, findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isTrue,
    );

    await tester.tap(visibilityButton);
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isFalse,
    );
  });
}
