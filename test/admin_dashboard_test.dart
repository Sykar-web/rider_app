import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ride/app/theme.dart';
import 'package:smart_ride/services/admin_service.dart';
import 'package:smart_ride/screens/admin/admin_dashboard_screen.dart';

class FakeAdmin extends AdminService {
  bool allowed = true, accepted = false, expired = false;
  String? lastPin;
  int reads = 0;
  final events = StreamController<bool>.broadcast();
  @override
  bool get allowedAccount => allowed;
  @override
  Stream<bool> get accountChanges => events.stream;
  @override
  Future<Map<String, dynamic>> unlock(String pin) async {
    lastPin = pin;
    return {
      'ok': accepted,
      'expires_at': DateTime.now()
          .add(const Duration(minutes: 15))
          .toIso8601String(),
    };
  }

  @override
  Future<Map<String, dynamic>> data(
    String section, {
    String search = '',
    int page = 0,
  }) async {
    reads++;
    if (expired) throw AdminAccessExpired();
    return {
      'stats': {'accounts': 12},
      'rows': [],
    };
  }

  @override
  Future<void> lock() async {}
}

void main() {
  testWidgets('admin account sees PIN gate and server approval is required', (
    tester,
  ) async {
    final service = FakeAdmin();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: AdminDashboardScreen(service: service),
      ),
    );
    expect(find.text('Admin PIN'), findsOneWidget);
    expect(service.reads, 0);
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Unlock dashboard'));
    await tester.pumpAndSettle();
    expect(service.lastPin, '1234');
    expect(service.reads, 0);
    expect(find.text('PIN not accepted. Try again.'), findsOneWidget);
    service.accepted = true;
    await tester.enterText(find.byType(TextField), '9876');
    await tester.tap(find.text('Unlock dashboard'));
    await tester.pumpAndSettle();
    expect(service.lastPin, '9876');
    expect(find.text('FastRide operations'), findsOneWidget);
    expect(service.reads, 1);
    await tester.tap(find.byTooltip('Lock dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Admin PIN'), findsOneWidget);
    expect(find.text('12'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await service.events.close();
  });
  testWidgets('other accounts cannot load or unlock dashboard', (tester) async {
    final service = FakeAdmin()..allowed = false;
    await tester.pumpWidget(
      MaterialApp(home: AdminDashboardScreen(service: service)),
    );
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(service.reads, 0);
    await tester.pumpWidget(const SizedBox());
    await service.events.close();
  });
  testWidgets('server expiry clears private dashboard content', (tester) async {
    final service = FakeAdmin()
      ..accepted = true
      ..expired = true;
    await tester.pumpWidget(
      MaterialApp(home: AdminDashboardScreen(service: service)),
    );
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Unlock dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Admin PIN'), findsOneWidget);
    expect(find.text('FastRide operations'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await service.events.close();
  });
}
