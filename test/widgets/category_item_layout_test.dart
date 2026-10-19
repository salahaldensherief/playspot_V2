import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/features/home/presentation/widgets/category_item.dart';

void main() {
  testWidgets('category cards fit a narrow phone and remain tappable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 116,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                CategoryItem(
                  name: 'ألعاب الكمبيوتر والبلايستيشن',
                  icon: Icons.sports_esports,
                  isSelected: true,
                  onTap: () => selected = true,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(CategoryItem));
    expect(selected, isTrue);
  });
}
