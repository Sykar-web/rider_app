import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ride/app/theme.dart';
import 'package:smart_ride/fast_driver/screens/onboarding/driver_application_form.dart';
import 'package:smart_ride/fast_driver/services/driver_application_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApplicationFake extends DriverApplicationService {
  ApplicationFake({this.pending = false})
    : super(client: SupabaseClient('https://example.supabase.co', 'test', authOptions: const AuthClientOptions(autoRefreshToken: false)));
  final bool pending;
  Map<String, dynamic>? saved;
  @override
  Future<Map<String, dynamic>> load() async => {
    'profile': {
      'full_name': 'James Okello',
      'phone': '+256772345678',
      'email': 'james@example.com',
      'avatar_path': 'user/existing-photo.jpg',
    },
    'data': <String, dynamic>{},
    'status': pending ? 'pending' : 'draft',
  };
  @override
  Future<void> save(Map<String, dynamic> details, {bool submit = false}) async {
    saved = details;
  }
}

void main() {
  testWidgets(
    'existing passenger only supplies missing details, keeps photo and saves a draft',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = ApplicationFake();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: DriverApplicationForm(service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('James Okello'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Arua');
      await tester.scrollUntilVisible(
        find.text('Continue'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(service.saved?['full_name'], 'James Okello');
      expect(service.saved?['home_area'], 'Arua');
      expect(service.saved?['uses_shared_photo'], true);
      expect(find.text('Add missing profile photo'), findsNothing);
      expect(find.text('National ID front'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('licence_number')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const ValueKey('licence_number')),
        'DL123456',
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('licence_expiry')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const ValueKey('licence_expiry')),
        '2030-12-31',
      );
      await tester.scrollUntilVisible(
        find.text('Continue'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        find.text('Add the missing documents to continue.'),
        findsOneWidget,
      );
      expect(find.text('Vehicle details'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending application offers passenger use without granting driver access',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: DriverApplicationForm(service: ApplicationFake(pending: true)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Application under review'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Continue as passenger'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Continue as passenger'), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      expect(find.text('Submit for approval'), findsNothing);
      await tester.ensureVisible(find.text('View application'));
      await tester.tap(find.text('View application'));
      await tester.pumpAndSettle();
      expect(find.text('Application details'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
