import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/core/utils/localized_duration_formatter.dart';

void main() {
  group('LocalizedDurationFormatter Tests', () {
    group('formatRemainingTime - Arabic', () {
      test('expired session returns Arabic session ended string', () {
        expect(
          LocalizedDurationFormatter.formatRemainingTime(
            Duration.zero,
            isArabic: true,
          ),
          'انتهت الجلسة',
        );
        expect(
          LocalizedDurationFormatter.formatRemainingTime(
            const Duration(seconds: -10),
            isArabic: true,
          ),
          'انتهت الجلسة',
        );
      });

      test('formats hours and minutes correctly with Arabic dual and plural', () {
        // 1 hour and 1 minute
        expect(
          LocalizedDurationFormatter.formatRemainingTime(
            const Duration(hours: 1, minutes: 1),
            isArabic: true,
          ),
          'متبقي ساعة واحدة و دقيقة واحدة',
        );

        // 2 hours and 2 minutes
        expect(
          LocalizedDurationFormatter.formatRemainingTime(
            const Duration(hours: 2, minutes: 2),
            isArabic: true,
          ),
          'متبقي ساعتان و دقيقتان',
        );

        // 3 hours and 5 minutes (plural 3-10)
        expect(
          LocalizedDurationFormatter.formatRemainingTime(
            const Duration(hours: 3, minutes: 5),
            isArabic: true,
          ),
          'متبقي 3 ساعات و 5 دقائق',
        );

        // 11 hours and 15 minutes (singular accusative > 10)
        expect(
          LocalizedDurationFormatter.formatRemainingTime(
            const Duration(hours: 11, minutes: 15),
            isArabic: true,
          ),
          'متبقي 11 ساعة و 15 دقيقة',
        );
      });

      test('formats hours only correctly in Arabic', () {
        expect(
          LocalizedDurationFormatter.formatRemainingTime(
            const Duration(hours: 1),
            isArabic: true,
          ),
          'متبقي ساعة واحدة',
        );
        expect(
          LocalizedDurationFormatter.formatRemainingTime(
            const Duration(hours: 2),
            isArabic: true,
          ),
          'متبقي ساعتان',
        );
        expect(
          LocalizedDurationFormatter.formatRemainingTime(
            const Duration(hours: 4),
            isArabic: true,
          ),
          'متبقي 4 ساعات',
        );
      });

      test('formats minutes and seconds correctly in Arabic', () {
        expect(
          LocalizedDurationFormatter.formatRemainingTime(
            const Duration(minutes: 5, seconds: 30),
            isArabic: true,
          ),
          'متبقي 5 دقائق و 30 ثانية',
        );
        expect(
          LocalizedDurationFormatter.formatRemainingTime(
            const Duration(seconds: 45),
            isArabic: true,
          ),
          'متبقي 45 ثانية',
        );
        expect(
          LocalizedDurationFormatter.formatRemainingTime(
            const Duration(seconds: 2),
            isArabic: true,
          ),
          'متبقي ثانيتان',
        );
        expect(
          LocalizedDurationFormatter.formatRemainingTime(
            const Duration(seconds: 1),
            isArabic: true,
          ),
          'متبقي ثانية واحدة',
        );
      });
    });

    group('formatRemainingTime - English', () {
      test('expired session returns English session ended string', () {
        expect(
          LocalizedDurationFormatter.formatRemainingTime(
            Duration.zero,
            isArabic: false,
          ),
          'Session ended',
        );
      });

      test('formats hours and minutes in English', () {
        expect(
          LocalizedDurationFormatter.formatRemainingTime(
            const Duration(hours: 2, minutes: 15),
            isArabic: false,
          ),
          '2 h 15 m remaining',
        );
      });

      test('formats minutes and seconds in English', () {
        expect(
          LocalizedDurationFormatter.formatRemainingTime(
            const Duration(minutes: 10, seconds: 5),
            isArabic: false,
          ),
          '10 m 5s remaining',
        );
      });

      test('formats seconds only in English', () {
        expect(
          LocalizedDurationFormatter.formatRemainingTime(
            const Duration(seconds: 30),
            isArabic: false,
          ),
          '30s remaining',
        );
      });
    });
  });
}
