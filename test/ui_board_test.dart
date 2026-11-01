import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ride/app/board_widgets.dart';
import 'package:smart_ride/screens/account/customer_pages.dart';
import 'package:smart_ride/screens/home/trip_completed_screen.dart';
import 'package:smart_ride/screens/home/schedule_ride_screen.dart';

void main() {
  test('fare formatting uses actual data and handles unconfirmed fares', () {
    expect(ugx(null), 'To be confirmed');
    expect(ugx(12000), 'UGX 12,000');
    expect(ugx(0), 'UGX 0');
  });

  testWidgets('wallet has honest inactive state without invented money', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WalletScreen(
          loadWallet: () async => {
            'account': null,
            'transactions': <Map<String, dynamic>>[],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Not activated'), findsOneWidget);
    expect(find.text('UGX 50,000'), findsNothing);
    await tester.tap(find.text('Top Up').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('not available yet'), findsOneWidget);
  });

  testWidgets('completed ride submits selected rating and comment once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int? sentRating;
    String? sentComment;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripCompletedScreen(
            ride: const {
              'id': 'test-ride',
              'fare_ugx': 12000,
              'distance_km': 4.5,
              'started_at': '2026-10-19T08:00:00Z',
              'completed_at': '2026-10-19T08:14:00Z',
            },
            driver: const {'full_name': 'Test Driver'},
            loadReview: () async => null,
            submitReview: (rating, comment) async {
              sentRating = rating;
              sentComment = comment;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Submit'));
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
      isNull,
    );
    await tester.ensureVisible(find.byTooltip('4 stars'));
    await tester.tap(find.byTooltip('4 stars'));
    await tester.enterText(find.byType(TextField), 'Good trip');
    await tester.ensureVisible(find.text('Submit'));
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(sentRating, 4);
    expect(sentComment, 'Good trip');
    expect(find.text('Rating submitted'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
      isNull,
    );
  });

  testWidgets(
    'schedule and shared ride introductions match reference and fit small phones',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: ScheduleRideScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Schedule a Ride'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Cash'), 200);
      expect(find.text('Cash'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const MaterialApp(home: SharedRideScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Share a ride and save'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
