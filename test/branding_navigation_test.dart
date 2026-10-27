import 'package:smart_ride/screens/home/activity_screen.dart';
import 'package:smart_ride/screens/home/home_service_carousel.dart';

import 'dart:async';

import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import 'package:smart_ride/services/route_service.dart';
import 'package:smart_ride/screens/home/searching_screen.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
// Native map rendering is replaced only in widget tests.
// ignore: depend_on_referenced_packages
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_ride/app/theme.dart';
import 'package:smart_ride/app/board_widgets.dart';
import 'package:smart_ride/app/profile_photo.dart';
import 'package:smart_ride/screens/account/payment_methods_screen.dart';
import 'package:smart_ride/screens/home/booking_shell.dart';
import 'package:smart_ride/screens/splash_screen.dart';

class DisabledLocation extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => false;
}

class FakeMap extends GoogleMapsFlutterPlatform {
  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
  }) {
    return const ColoredBox(
      key: Key('test-map'),
      color: Color(0xFFE7F2EC),
      child: Center(
        child: Icon(Icons.map_outlined, size: 64, color: Color(0xFF92B9AD)),
      ),
    );
  }
}

ThemeData get testTheme => AppTheme.theme;

Future<void> savePreview(
  WidgetTester tester,
  GlobalKey key,
  String filename,
) async {
  await tester.runAsync(() async {
    for (final asset in [
      'assets/branding/home_hero.png',
      for (final name in ['car', 'local', 'van', 'bus', 'delivery'])
        'assets/branding/service_$name.png',
      'assets/icon/app_icon_foreground.png',
      for (final v in ['car', 'motorcycle', 'van', 'bus', 'bicycle', 'tuktuk'])
        'assets/vehicles/$v.png',
    ]) {
      await precacheImage(AssetImage(asset), key.currentContext!);
    }
  });
  await tester.pump();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final folder = Directory('build/fast_ride_previews');
    await folder.create(recursive: true);
    await File('${folder.path}/$filename')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Load real glyphs for local layout previews; tests remain portable.
    final localFont = File(r'C:\Windows\Fonts\segoeui.ttf');
    if (Platform.isWindows && await localFont.exists()) {
      final bytes = await localFont.readAsBytes();
      await (FontLoader(
        'PreviewSans',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => Directory.systemTemp.path,
        );
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope-ExtraBold.ttf'))).load();
    await (FontLoader(
      'Outfit',
    )..addFont(rootBundle.load('assets/fonts/Outfit-SemiBold.ttf'))).load();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async => call.method == 'getAll' ? <String, Object>{} : true,
        );
    GeolocatorPlatform.instance = DisabledLocation();
    GoogleMapsFlutterPlatform.instance = FakeMap();
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
    );
  });
  tearDownAll(() async => Supabase.instance.dispose());

  testWidgets(
    'Board navigation opens booking, profile, support and ride history',
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
            debugShowCheckedModeBanner: false,
            theme: testTheme,
            home: const BookingShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('My Rides'), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(5));
      await savePreview(tester, key, 'home.png');
      await tester.tap(find.text('Enter destination'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('test-map')), findsOneWidget);
      expect(find.text('Choose a Ride'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(TextField).first).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('test-map'))).dy),
      );
      await savePreview(tester, key, 'choose_ride.png');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      expect(find.text('Personal Information'), findsOneWidget);
      await savePreview(tester, key, 'profile.png');
      await tester.tap(find.text('Support').last);
      await tester.pumpAndSettle();
      expect(find.text('Help Centre'), findsOneWidget);
      await savePreview(tester, key, 'support.png');
      await tester.tap(find.text('My Rides').last);
      await tester.pumpAndSettle();
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      expect(find.byType(HomeServiceCarousel), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Splash shows the slogan beneath the icon and then opens the app',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: testTheme,
          home: RepaintBoundary(
            key: key,
            child: const SplashScreen(child: Text('Login destination')),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();
      expect(find.text('FastRide'), findsOneWidget);
      final slogan = find.text('Move Safe, Move Fast');
      expect(slogan, findsOneWidget);
      expect(
        tester.getTopLeft(slogan).dy,
        greaterThan(tester.getCenter(find.byType(Image)).dy),
      );
      await savePreview(tester, key, 'splash.png');
      await tester.pump(const Duration(milliseconds: 2200));
      expect(find.text('Login destination'), findsOneWidget);
    },
  );
  testWidgets('Cash stays available and unavailable methods explain why', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: const PaymentMethodsScreen(selecting: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cash'), findsOneWidget);
    await tester.tap(find.text('Mobile Money'));
    await tester.pumpAndSettle();
    expect(find.byType(BoardDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.byType(BoardDialog), findsNothing);
  });

  testWidgets('Confirmation returns the selected answer with the app theme', (
    tester,
  ) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                answer = await boardConfirm(
                  context,
                  title: 'Cancel booking?',
                  message: 'Your booking will be cancelled.',
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
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Go back'));
    await tester.pumpAndSettle();
    expect(answer, false);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(answer, true);
  });

  testWidgets(
    'Profile picture offers device selection without uploading on dismissal',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: const Scaffold(body: ProfilePhoto(editable: true)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ProfilePhoto));
      await tester.pumpAndSettle();
      expect(find.text('Choose from device'), findsOneWidget);
      expect(find.text('JPG, PNG or WebP · maximum 5 MB'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Waiting map preserves the booked road route and follows driver roads',
    (tester) async {
      final ride = StreamController<Map<String, dynamic>?>();
      addTearDown(ride.close);
      final selected = RouteResult(
        points: const [
          maps.LatLng(3, 30),
          maps.LatLng(3.02, 30.04),
          maps.LatLng(3.1, 30.1),
        ],
        distanceMeters: 12000,
        durationSeconds: 900,
      );
      final approach = RouteResult(
        points: const [
          maps.LatLng(3.2, 30.2),
          maps.LatLng(3.15, 30.1),
          maps.LatLng(3, 30),
        ],
        distanceMeters: 8000,
        durationSeconds: 700,
      );
      final requested = <String, dynamic>{
        'id': 'test',
        'status': 'requested',
        'pickup_lat': 3,
        'pickup_lng': 30,
        'dropoff_lat': 3.1,
        'dropoff_lng': 30.1,
        'vehicle_type': 'car',
      };
      var requests = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: SearchingScreen(
            rideId: 'test',
            pickupAddress: 'Village',
            dropoffAddress: 'Market',
            initialRoute: selected,
            rideStream: ride.stream,
            profileStream: (_) => Stream.value({
              'full_name': 'Driver',
              'current_lat': 3.2,
              'current_lng': 30.2,
            }),
            routeLoader: (start, end, vehicle) async {
              requests++;
              expect(end, const maps.LatLng(3, 30));
              return approach;
            },
          ),
        ),
      );
      ride.add(requested);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester
            .widget<maps.GoogleMap>(find.byType(maps.GoogleMap))
            .polylines
            .single
            .points,
        selected.points,
      );
      expect(requests, 0);
      ride.add({...requested, 'status': 'accepted', 'driver_id': 'driver'});
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester
            .widget<maps.GoogleMap>(find.byType(maps.GoogleMap))
            .polylines
            .single
            .points,
        approach.points,
      );
      expect(requests, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Failed directions never draw a direct pickup destination line', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: SearchingScreen(
          rideId: 'test',
          pickupAddress: 'Village',
          dropoffAddress: 'Market',
          rideStream: Stream.value({
            'id': 'test',
            'status': 'requested',
            'pickup_lat': 3,
            'pickup_lng': 30,
            'dropoff_lat': 3.1,
            'dropoff_lng': 30.1,
          }),
          routeLoader: (_, end, vehicle) async => throw StateError('No route'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.widget<maps.GoogleMap>(find.byType(maps.GoogleMap)).polylines,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('My Rides shows active bookings by default and filters history', (
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
          theme: AppTheme.theme,
          home: ActivityScreen(
            loadBookings: () async => [
              {
                'id': 'a',
                'status': 'requested',
                'pickup_address': 'Village Pickup',
                'dropoff_address': 'Town Market',
                'requested_at': '2026-10-20T10:00:00Z',
                'vehicle_type': 'car',
              },
              {
                'id': 'b',
                'status': 'completed',
                'pickup_address': 'School Gate',
                'dropoff_address': 'Arua Hospital',
                'requested_at': '2026-10-19T10:00:00Z',
                'vehicle_type': 'bus',
                'fare_ugx': 10000,
              },
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Village Pickup'), findsOneWidget);
    await savePreview(tester, key, 'my_rides.png');
    await tester.tap(find.text('Completed').first);
    await tester.pumpAndSettle();
    expect(find.text('Village Pickup'), findsNothing);
    expect(find.text('School Gate'), findsOneWidget);
    await tester.tap(find.text('Upcoming'));
    await tester.pumpAndSettle();
    expect(find.text('Village Pickup'), findsOneWidget);
    expect(find.text('School Gate'), findsNothing);
    await tester.tap(find.text('Cancelled'));
    await tester.pumpAndSettle();
    expect(find.text('No cancelled bookings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Service slideshow advances and opens the matching booking service',
    (tester) async {
      String? vehicle;
      bool? delivery;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: Scaffold(
            body: HomeServiceCarousel(
              onProfile: () {},
              onNotifications: () {},
              onService: (v, d) {
                vehicle = v;
                delivery = d;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text('Beat the everyday rush'), findsOneWidget);
      await tester.tap(find.text('Book a moto →'));
      expect(vehicle, 'motorcycle');
      expect(delivery, false);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
