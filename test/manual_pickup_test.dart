import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:smart_ride/app/theme.dart';
import 'package:smart_ride/screens/home/where_to_screen.dart';
import 'package:smart_ride/services/location_service.dart';
import 'package:smart_ride/services/route_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'branding_navigation_test.dart' show FakeMap;

final manualPickup = PlaceResult(
  displayName: 'Arua Primary School, Uganda',
  placeId: 'school',
  lat: 3.02,
  lon: 30.91,
);
final destination = PlaceResult(
  displayName: 'Arua Market, Uganda',
  placeId: 'market',
  lat: 3.03,
  lon: 30.92,
);

class ManualLocation extends LocationService {
  final gps = Completer<Position>();
  int gpsCalls = 0;
  @override
  Future<Position> getCurrentPosition() {
    gpsCalls++;
    return gps.future;
  }

  @override
  Future<List<PlaceResult>> searchPlaces(
    String query, {
    bool expanded = false,
  }) async => [manualPickup];
  @override
  Future<PlaceResult?> resolvePlace(PlaceResult place) async => place;
  @override
  Future<String> reverseGeocode(double lat, double lon) async => 'GPS location';
}

class ManualRoutes extends RouteService {
  final starts = <LatLng>[];
  @override
  Future<RouteResult> getRoute(
    LatLng start,
    LatLng end, {
    String vehicleType = 'car',
  }) async {
    starts.add(start);
    return RouteResult(
      points: [start, end],
      distanceMeters: 1500,
      durationSeconds: 300,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (c) async => c.method == 'getAll' ? <String, Object>{} : true,
        );
    GoogleMapsFlutterPlatform.instance = FakeMap();
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  Future<void> open(
    WidgetTester tester,
    ManualLocation location,
    ManualRoutes routes, {
    PlaceResult? pickup,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: WhereToScreen(
          vehicleType: 'motorcycle',
          initialPickup: pickup,
          initialDestination: destination,
          locationService: location,
          routeService: routes,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> chooseManual(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, 'Arua Primary');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    await tester.tap(find.text(manualPickup.displayName));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'manual pickup works while GPS is pending and late GPS cannot replace it',
    (tester) async {
      final location = ManualLocation(), routes = ManualRoutes();
      await open(tester, location, routes);
      await chooseManual(tester);
      expect(routes.starts.last, const LatLng(3.02, 30.91));
      location.gps.complete(
        Position(
          latitude: 0.3,
          longitude: 32.5,
          timestamp: DateTime.now(),
          accuracy: 5,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        ),
      );
      await tester.pump();
      final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(
        map.markers.firstWhere((m) => m.markerId.value == 'pickup').position,
        const LatLng(3.02, 30.91),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        manualPickup.displayName,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('manual pickup recovers from denied GPS', (tester) async {
    final location = ManualLocation(), routes = ManualRoutes();
    await open(tester, location, routes);
    location.gps.completeError(StateError('Permission denied'));
    await tester.pump();
    await chooseManual(tester);
    expect(routes.starts.last, const LatLng(3.02, 30.91));
    expect(
      find.text('Location access is unavailable. Choose your pickup manually.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('pickup selected on Home skips GPS and loads selected route', (
    tester,
  ) async {
    final location = ManualLocation(), routes = ManualRoutes();
    await open(tester, location, routes, pickup: manualPickup);
    await tester.pump();
    expect(location.gpsCalls, 0);
    expect(routes.starts.single, const LatLng(3.02, 30.91));
    expect(tester.takeException(), isNull);
  });
}
