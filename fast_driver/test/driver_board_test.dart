import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fast_driver/services/ride_service.dart';
import 'package:fast_driver/services/delivery_service.dart';
import 'package:fast_driver/screens/driver/driver_home_screen.dart';
import 'package:fast_driver/screens/onboarding/welcome_screen.dart';

import 'dart:convert';

import 'package:fast_driver/screens/onboarding/verification_screen.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fast_driver/app/theme.dart';
import 'package:fast_driver/main.dart';
import 'package:fast_driver/services/driver_account_service.dart';
import 'package:fast_driver/screens/driver/driver_pages.dart';
import 'package:fast_driver/screens/driver/driver_job_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async => call.method == 'getAll' ? <String, Object>{} : true,
        );
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
      ),
    );
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final font in [
      ('Manrope', 'assets/fonts/Manrope-ExtraBold.ttf'),
      ('Outfit', 'assets/fonts/Outfit-SemiBold.ttf'),
    ]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
  });
  tearDownAll(() async => Supabase.instance.dispose());
  final now = DateTime(2026, 10, 22, 12);
  List<Map<String, dynamic>> sample() => [
    {
      'id': 'one',
      'status': 'completed',
      'fare_ugx': 7000,
      'pickup_address': 'Main Campus, Arua',
      'dropoff_address': 'Arua Park',
      'started_at': now.subtract(const Duration(minutes: 30)).toIso8601String(),
      'completed_at': now
          .subtract(const Duration(minutes: 10))
          .toIso8601String(),
    },
    {
      'id': 'two',
      'status': 'completed',
      'fare_ugx': 8000,
      'pickup_address': 'Market',
      'dropoff_address': 'West Nile College',
      'completed_at': now.subtract(const Duration(days: 2)).toIso8601String(),
    },
    {
      'id': 'three',
      'status': 'cancelled',
      'fare_ugx': 50000,
      'pickup_address': 'Cancelled pickup',
      'dropoff_address': 'Cancelled destination',
      'accepted_at': now.toIso8601String(),
    },
    {
      'id': 'four',
      'status': 'in_progress',
      'fare_ugx': 10000,
      'pickup_address': 'Active pickup',
      'dropoff_address': 'Active destination',
      'accepted_at': now.toIso8601String(),
    },
    {
      'id': 'five',
      'status': 'completed',
      'pickup_address': 'School Gate',
      'dropoff_address': 'Hospital',
      'completed_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
    },
  ];
  test('Earnings count completed jobs only and exclude unknown fares from averages', () {
    final totals = DriverTotals(sample(), now: now);
    expect(totals.count, 2);
    expect(totals.pricedCount, 1);
    expect(totals.gross, 7000);
    expect(totals.seconds, 1200);
    expect(DriverTotals(sample(), now: now, days: 7).gross, 15000);
  });
  testWidgets(
    'Driver history filters cancelled and completed and opens the real record',
    (tester) async {
      String? opened;
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          theme: AppTheme.theme,
          home: Scaffold(
            body: DriverHistory(
              jobs: sample(),
              onRefresh: () async {},
              onOpen: (job) => opened = job['id'],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Cancelled').first);
      await tester.pumpAndSettle();
      expect(find.text('Cancelled pickup'), findsOneWidget);
      expect(find.text('Main Campus, Arua'), findsNothing);
      await tester.tap(find.text('Cancelled pickup'));
      expect(opened, 'three');
      await tester.tap(find.text('Completed').first);
      await tester.pumpAndSettle();
      expect(find.text('Main Campus, Arua'), findsOneWidget);
      expect(find.text('Cancelled pickup'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Wallet makes unavailable payments explicit', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        theme: AppTheme.theme,
        home: const DriverWallet(),
      ),
    );
    expect(find.text('Not enabled'), findsOneWidget);
    await tester.tap(find.text('Withdraw'));
    await tester.pumpAndSettle();
    expect(find.text('Withdrawals unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Board pages fit a small screen with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final page in <Widget>[
      DriverEarnings(jobs: sample(), onRefresh: () async {}),
      DriverProfile(
        profile: const {'full_name': 'Test Driver', 'phone': '+256700123456'},
        onChanged: () async {},
        onLogout: () async {},
      ),
      const DriverSupport(),
      DriverTripCompleted(job: sample().first, onHome: () {}),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          theme: AppTheme.theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Scaffold(body: page),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
    'Design previews use sample records, not fake account data in production',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pages = <String, Widget>{
        'earnings': Scaffold(
          appBar: AppBar(title: const Text('Earnings')),
          body: DriverEarnings(jobs: sample(), onRefresh: () async {}),
        ),
        'history': Scaffold(
          appBar: AppBar(title: const Text('Ride History')),
          body: DriverHistory(
            jobs: sample(),
            onRefresh: () async {},
            onOpen: (_) {},
          ),
        ),
        'profile': Scaffold(
          appBar: AppBar(title: const Text('My Profile')),
          body: DriverProfile(
            profile: const {
              'full_name': 'Test Driver',
              'phone': '+256700123456',
              'email': 'driver@example.com',
            },
            onChanged: () async {},
            onLogout: () async {},
          ),
        ),
        'wallet': const DriverWallet(),
        'support': const DriverSupport(),
      };
      for (final item in pages.entries) {
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              key: UniqueKey(),
              debugShowCheckedModeBanner: false,
              theme: AppTheme.theme,
              home: item.value,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory('build/design_previews')
            ..createSync(recursive: true);
          File('${dir.path}/FastDriver-${item.key}.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'Dashboard and its four navigation destinations render with backend records',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late SupabaseClient client;
      await tester.runAsync(() async {
        client = SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            final Object body = request.url.path.endsWith('/profiles')
                ? [
                    {
                      'id': 'driver-1',
                      'full_name': 'Test Driver',
                      'phone': '+256700123456',
                      'is_online': false,
                    },
                  ]
                : request.url.queryParameters.containsKey('status')
                ? []
                : request.url.path.endsWith('/rides')
                ? sample()
                : [];
            return http.Response(
              jsonEncode(body),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        );
        final payload = base64Url
            .encode(
              utf8.encode(jsonEncode({'sub': 'driver-1', 'exp': 4102444800})),
            )
            .replaceAll('=', '');
        await client.auth.recoverSession(
          jsonEncode({
            'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.signature',
            'refresh_token': 'test',
            'token_type': 'bearer',
            'expires_at': 4102444800,
            'user': {
              'id': 'driver-1',
              'aud': 'authenticated',
              'created_at': '2026-01-01T00:00:00Z',
              'app_metadata': {'driver_approved': true},
              'user_metadata': {},
            },
          }),
        );
      });
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            key: UniqueKey(),
            debugShowCheckedModeBanner: false,
            theme: AppTheme.theme,
            home: DriverHomeScreen(
              accountService: DriverAccountService(client: client),
              rideService: RideService(client: client),
              deliveryService: DeliveryService(client: client),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text('Welcome back, Test Driver'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final dir = Directory('build/design_previews')
          ..createSync(recursive: true);
        File('${dir.path}/FastDriver-dashboard.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      for (final destination in ['Earnings', 'History', 'Profile', 'Home']) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(destination),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
        expect(tester.takeException(), isNull);
        if (destination == 'Earnings') {
          expect(find.text('Recorded trip fares'), findsOneWidget);
        }
        if (destination == 'History') expect(find.text('All'), findsOneWidget);
        if (destination == 'Profile') {
          expect(find.text('Personal Info'), findsOneWidget);
        }
      }
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await client.dispose();
      });
    },
  );
  testWidgets('Signed out driver gate stays on welcome', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        theme: AppTheme.theme,
        home: const DriverAuthGate(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });
  testWidgets('Editable user metadata cannot bypass driver approval', (
    tester,
  ) async {
    final payload = base64Url
        .encode(
          utf8.encode(jsonEncode({'sub': 'unapproved', 'exp': 4102444800})),
        )
        .replaceAll('=', '');
    await Supabase.instance.client.auth.recoverSession(
      jsonEncode({
        'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.signature',
        'refresh_token': 'test-refresh',
        'token_type': 'bearer',
        'expires_at': 4102444800,
        'user': {
          'id': 'unapproved',
          'app_metadata': {},
          'user_metadata': {
            'role': 'driver',
            'driver_onboarding_required': false,
          },
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        theme: AppTheme.theme,
        home: const DriverAuthGate(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(VerificationScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
