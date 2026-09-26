import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/features/profile/data/models/loyalty_mission_model.dart';
import 'package:playspot/features/profile/data/models/loyalty_status_model.dart';

void main() {
  group('Batch 2 — Loyalty & Referral Models Unit Tests', () {
    test('LoyaltyStatusModel JSON serialization and progressRatio calculation', () {
      final json = {
        'points_balance': 750,
        'current_level': 'Silver',
        'next_level_points': 1000,
        'multiplier': 1.2,
      };

      final model = LoyaltyStatusModel.fromJson(json);

      expect(model.pointsBalance, equals(750));
      expect(model.currentLevel, equals('Silver'));
      expect(model.nextLevelPoints, equals(1000));
      expect(model.progressRatio, equals(0.75));
      expect(model.pointsRemaining, equals(250));
    });

    test('LoyaltyMissionModel progress calculation and completion status', () {
      const mission = LoyaltyMissionModel(
        id: 'mission_1',
        title: 'Book 3 Gaming Sessions',
        description: 'Book sessions to earn rewards',
        titleEn: 'Book 3 Gaming Sessions',
        titleAr: 'احجز ٣ جلسات ألعاب',
        pointsReward: 100,
        targetProgress: 3,
        currentProgress: 2,
        isCompleted: false,
      );

      expect(mission.currentProgress, equals(2));
      expect(mission.targetProgress, equals(3));
      expect(mission.isCompleted, isFalse);
    });
  });
}
