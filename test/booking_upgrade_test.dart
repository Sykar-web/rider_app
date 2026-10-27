import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ride/models/booking_summary.dart';
import 'package:smart_ride/services/bus_service.dart';
import 'package:smart_ride/screens/home/ride_booking_details_sheet.dart';

const departure = BusSchedule(
  id: 'test-departure',
  company: 'Test operator',
  departureTime: '06:00',
  arrivalTime: '14:00',
  durationMinutes: 480,
  serviceClass: 'ordinary',
  totalSeats: 5,
);

void main() {
  test('seat layout respects partial last rows and maximum bus capacity', () {
    expect(busSeatLabels(5), ['1A', '1B', '1C', '1D', '2A']);
    expect(busSeatLabels(0), isEmpty);
    expect(busSeatLabels(80).last, '20D');
  });

  test(
    'recovered bookings retain all seats and do not invent a seat for a car',
    () {
      final summary = BookingSummary.text({
        'booking_reference': 'FR-EXAMPLE',
        'status': 'requested',
        'pickup_address': 'Arua',
        'dropoff_address': 'Kampala',
        'seat_numbers': ['1A', '2A'],
        'travel_date': '2026-12-01',
        'booking_details': {
          'company': 'Test operator',
          'departure_time': '06:00',
        },
      });
      expect(summary, contains('Seats 1A, 2A'));
      expect(summary, contains('Awaiting confirmation'));
      expect(summary, contains('Departure: 06:00'));
      expect(BookingSummary.reservation({'vehicle_type': 'car'}), isEmpty);
      expect(BookingSummary.isActive({'status': 'cancelled'}), isFalse);
    },
  );

  testWidgets(
    'bus booking requires departure and seats and supports multiple seats',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      RideBookingDetails? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.push<RideBookingDetails>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        body: RideBookingDetailsSheet(
                          vehicleType: 'bus',
                          loadSchedules: () async => [departure],
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNull,
      );
      await tester.tap(find.text('Test operator'));
      await tester.pumpAndSettle();
      expect(find.text('2A'), findsOneWidget);
      expect(find.text('2B'), findsNothing);
      await tester.tap(find.text('1A'));
      await tester.tap(find.text('2A'));
      await tester.pump();
      await tester.ensureVisible(find.text('Request reservation'));
      await tester.tap(find.text('Request reservation'));
      await tester.pumpAndSettle();
      expect(result?.seatNumbers, ['1A', '2A']);
      expect(result?.details['passenger_count'], 2);
      expect(result?.busScheduleId, 'test-departure');
    },
  );

  testWidgets('failed timetable shows retry and can recover', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RideBookingDetailsSheet(
            vehicleType: 'bus',
            loadSchedules: () async {
              if (calls++ == 0) throw Exception('network failure');
              return [departure];
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('network failure'), findsNothing);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Test operator'), findsOneWidget);
  });

  testWidgets('whole-bus requests do not require or transmit selected seats', (
    tester,
  ) async {
    RideBookingDetails? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.push<RideBookingDetails>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      body: RideBookingDetailsSheet(
                        vehicleType: 'bus',
                        loadSchedules: () async => [departure],
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test operator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Whole bus'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Request reservation'));
    await tester.tap(find.text('Request reservation'));
    await tester.pumpAndSettle();
    expect(result?.reservationType, 'whole_bus');
    expect(result?.seatNumbers, isNull);
    expect(result?.seatNumber, isNull);
    expect(result?.busScheduleId, departure.id);
  });
}
