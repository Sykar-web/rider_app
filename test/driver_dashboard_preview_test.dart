import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ride/fast_driver/app/theme.dart';
import 'package:smart_ride/fast_driver/screens/driver/driver_home_screen.dart';
import 'package:smart_ride/fast_driver/screens/driver/driver_pages.dart';
import 'package:smart_ride/fast_driver/services/driver_account_service.dart';
import 'package:smart_ride/fast_driver/services/ride_service.dart';
import 'package:smart_ride/fast_driver/services/delivery_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'branding_navigation_test.dart' show savePreview;

class DashboardAccount extends DriverAccountService {
  @override
  Future<Map<String, dynamic>> profile() async => {
    'full_name': 'James Okello',
    'is_online': false,
  };
  @override
  Future<List<Map<String, dynamic>>> jobs() async => [];
}

class DashboardRides extends RideService {
  @override
  Stream<List<Map<String, dynamic>>> watchOpenRides({String? vehicleType}) =>
      Stream.value([]);
  @override
  Future<Map<String, dynamic>?> getActiveRide() async => null;
}

class DashboardDeliveries extends DeliveryService {
  @override
  Stream<List<Map<String, dynamic>>> watchOpenDeliveries() => Stream.value([]);
  @override
  Future<Map<String, dynamic>?> getActiveDelivery() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async => call.method == 'getAll' ? <String, Object>{} : true,
        );
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
    );
    for (final font in {
      'Asap': 'assets/fonts/Asap-Variable.ttf',
      'Outfit': 'assets/fonts/Outfit-SemiBold.ttf',
      'Manrope': 'assets/fonts/Manrope-ExtraBold.ttf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });
  tearDownAll(() => Supabase.instance.dispose());
  testWidgets(
    'driver profile keeps one styled switch; information lives in Settings',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            theme: AppTheme.theme,
            home: Scaffold(
              body: DriverProfile(
                profile: const {'full_name': 'James Okello'},
                onChanged: () async {},
                onLogout: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(FilledButton, 'Switch to passenger'),
        findsOneWidget,
      );
      expect(find.text('Personal Info'), findsNothing);
      expect(find.text('Vehicle Info'), findsNothing);
      expect(
        find.text('One profile across passenger and driver modes'),
        findsNothing,
      );
      await savePreview(tester, key, 'driver_profile.png');
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Vehicle Information'), findsOneWidget);
      for (final label in [
        'Switch to passenger',
        'Switch to Passenger Mode',
        'Activity update preference',
        'Help & Support',
        'App Language',
        'About',
      ]) {
        expect(find.text(label), findsNothing);
      }
      await savePreview(tester, key, 'driver_settings.png');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('driver home stays a dashboard and requests live under Trips', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          home: DriverHomeScreen(
            accountService: DashboardAccount(),
            rideService: DashboardRides(),
            deliveryService: DashboardDeliveries(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('James Okello'), findsOneWidget);
    expect(find.text('Today’s earnings'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Ride requests'), findsNothing);
    await savePreview(tester, key, 'driver_dashboard.png');
    await tester.tap(find.text('Trips').last);
    await tester.pumpAndSettle();
    expect(find.text('Rides'), findsOneWidget);
    expect(find.text('Deliveries'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
