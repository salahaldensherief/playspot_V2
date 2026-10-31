import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/features/tournaments/data/models/tournament_model.dart';
import 'package:playspot/features/tournaments/presentation/bracket/bracket_match_node.dart';
import 'package:playspot/features/tournaments/presentation/bracket/tournament_bracket_view.dart';

void main() {
  test(
    'waiting playoff is not a bye and legacy records remain bracket matches',
    () {
      final bronze = TournamentMatchModel.fromJson({
        'match_type': 'third_place',
        'status': 'scheduled',
      });
      expect(bronze.isThirdPlace, isTrue);
      expect(bronze.isBye, isFalse);
      expect(TournamentMatchModel.fromJson({}).isThirdPlace, isFalse);
      expect(
        TournamentMatchModel.fromJson({'status': 'walkover'}).isBye,
        isTrue,
      );
    },
  );
  for (final rtl in [false, true]) {
    testWidgets(
      'bronze has its own node and preserves the championship final ($rtl)',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final matches = [
          TournamentMatchModel.fromJson({
            'id': 'final',
            'round_number': 3,
            'match_order': 1,
            'status': 'scheduled',
          }),
          TournamentMatchModel.fromJson({
            'id': 'bronze',
            'round_number': 3,
            'match_order': 2,
            'match_type': 'third_place',
            'status': 'scheduled',
          }),
        ];
        String? opened;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: TournamentBracketView(
                  matches: matches,
                  onMatchTap: (m) => opened = m.id,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BracketMatchNode), findsNWidgets(2));
        expect(find.text(AppStrings.thirdPlace.tr()), findsOneWidget);
        final bronzeNode = find.byWidgetPredicate(
          (w) => w is BracketMatchNode && w.match.id == 'bronze',
        );
        final finalNode = find.byWidgetPredicate(
          (w) => w is BracketMatchNode && w.match.id == 'final',
        );
        expect(
          tester.getTopLeft(bronzeNode).dy,
          greaterThan(tester.getBottomLeft(finalNode).dy),
        );
        await tester.ensureVisible(bronzeNode);
        await tester.pumpAndSettle();
        await tester.longPress(bronzeNode);
        expect(opened, 'bronze');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
