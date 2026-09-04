import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/art_core/widgets/rating/rating_widgets.dart';

void main() {
  Widget createWidgetUnderTest(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  group('RatingDisplayWidget Tests', () {
    testWidgets('renders 5 star icons for rating 4.5', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        const RatingDisplayWidget(rating: 4.5, starSize: 20),
      ));

      // Should render 4 full stars, 1 half star
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
      expect(find.byIcon(Icons.star_half_rounded), findsOneWidget);
    });

    testWidgets('renders full stars and empty stars for integer rating 3.0', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        const RatingDisplayWidget(rating: 3.0, starSize: 20),
      ));

      // 3 full stars (colored warning) + 2 empty stars (colored white opacity) -> total 5 Icons of star_rounded
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));
      expect(find.byIcon(Icons.star_half_rounded), findsNothing);
    });

    testWidgets('renders exact fill mode when useExactFill is true', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        const RatingDisplayWidget(rating: 4.5, useExactFill: true, starSize: 20),
      ));

      expect(find.byType(RatingDisplayWidget), findsOneWidget);
      expect(find.byType(ClipRect), findsNWidgets(5));
    });
  });

  group('InteractiveRatingInput Tests', () {
    testWidgets('allows selecting rating via callback', (WidgetTester tester) async {
      double selectedRating = 0;

      await tester.pumpWidget(createWidgetUnderTest(
        InteractiveRatingInput(
          initialRating: 3.0,
          starSize: 40,
          onRatingChanged: (rating) {
            selectedRating = rating;
          },
        ),
      ));

      expect(find.byType(InteractiveRatingInput), findsOneWidget);

      // Tap on the widget to simulate changing rating
      await tester.tap(find.byType(InteractiveRatingInput));
      await tester.pumpAndSettle();

      expect(selectedRating, greaterThan(0));
    });
  });
}
