import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_theme.dart';
import 'package:playspot/features/my_bookings/domain/entities/booking_timeline_item.dart';
import 'package:playspot/features/my_bookings/presentation/booking_timeline_cubit.dart';
import 'package:playspot/features/my_bookings/presentation/booking_timeline_state.dart';
import 'package:playspot/features/my_bookings/presentation/widgets/booking_timeline_widget.dart';

class MockBookingTimelineCubit extends Mock implements BookingTimelineCubit {}

void main() {
  late MockBookingTimelineCubit mockCubit;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    mockCubit = MockBookingTimelineCubit();
    when(() => mockCubit.fetchTimeline(any(), isArabic: any(named: 'isArabic'))).thenAnswer((_) async {});
  });

  Widget buildTestableWidget(Widget child, Size screenSize) {
    return MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(size: screenSize),
        child: ScreenUtilInit(
          designSize: Size(screenSize.width, screenSize.height),
          builder: (context, _) => Scaffold(
            body: SingleChildScrollView(
              child: BlocProvider<BookingTimelineCubit>.value(
                value: mockCubit,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('BookingTimelineWidget Tests across 390, 900, 1440 resolutions', () {
    final now = DateTime.now();
    final sampleItems = [
      BookingTimelineItem(
        id: '1',
        eventCode: 'booking_created',
        titleAr: 'تم الحجز',
        titleEn: 'Booking Placed',
        occurredAt: now,
      ),
      BookingTimelineItem(
        id: '2',
        eventCode: 'unknown_custom_event',
        titleAr: '',
        titleEn: '',
        occurredAt: now,
      ),
    ];

    testWidgets('renders success timeline correctly on mobile (390 width) without overflow', (tester) async {
      when(() => mockCubit.state).thenReturn(BookingTimelineState(
        status: RequestStatus.success,
        items: sampleItems,
      ));
      when(() => mockCubit.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestableWidget(
        const BookingTimelineWidget(bookingId: 'booking-1'),
        const Size(390, 844),
      ));
      await tester.pump();

      expect(find.text(AppStrings.bookingTimelineTitle.tr()), findsOneWidget);
      expect(find.text('تم الحجز'), findsOneWidget);
      expect(find.text('تحديث بالحجز'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders error view with retry button on tablet/desktop (1440 width) without overflow', (tester) async {
      when(() => mockCubit.state).thenReturn(const BookingTimelineState(
        status: RequestStatus.failure,
        errorMessage: 'خطأ في الاتصال بالشبكة',
      ));
      when(() => mockCubit.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestableWidget(
        const BookingTimelineWidget(bookingId: 'booking-1'),
        const Size(1440, 900),
      ));
      await tester.pump();

      expect(find.text('خطأ في الاتصال بالشبكة'), findsOneWidget);
      expect(find.text(AppStrings.retry.tr()), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
