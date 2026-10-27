import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_ride/services/location_service.dart';
import 'package:smart_ride/services/route_service.dart';

void main() {
  test('Place labels remove codes without removing real village names', () {
    expect(readablePlaceLabel('XW7T+SH, Arua, Uganda'), 'Arua, Uganda');
    expect(readablePlaceLabel('8FVC9G8F+6X'), 'Selected location');
    expect(
      readablePlaceLabel('Koboko Market, Uganda'),
      'Koboko Market, Uganda',
    );
    expect(
      PlaceResult(displayName: 'XW7T+SH, Arua', placeId: 'p').displayName,
      'Arua',
    );
  });

  test(
    'Selecting a named landmark keeps its name and exact coordinates',
    () async {
      final service = LocationService(
        apiKey: 'test',
        client: MockClient(
          (uri) async => http.Response(
            jsonEncode({
              'status': 'OK',
              'result': {
                'name': 'Local Clinic',
                'formatted_address': 'XW7T+SH, Arua, Uganda',
                'geometry': {
                  'location': {'lat': 3.03, 'lng': 30.91},
                },
              },
            }),
            200,
          ),
        ),
      );
      final result = await service.resolvePlace(
        PlaceResult(
          displayName: 'Local Clinic, Arua, Uganda',
          placeId: 'clinic',
        ),
      );
      expect(result!.displayName, 'Local Clinic, Arua, Uganda');
      expect(result.lat, 3.03);
      expect(result.lon, 30.91);
    },
  );

  test(
    'Reverse geocoding prefers a street over the first coded address',
    () async {
      final service = LocationService(
        apiKey: 'test',
        client: MockClient(
          (uri) async => http.Response(
            jsonEncode({
              'status': 'OK',
              'results': [
                {
                  'types': ['plus_code'],
                  'formatted_address': 'XW7T+SH, Arua, Uganda',
                },
                {
                  'types': ['route'],
                  'formatted_address': 'School Road, Arua, Uganda',
                },
              ],
            }),
            200,
          ),
        ),
      );
      expect(await service.reverseGeocode(3, 30), 'School Road, Arua, Uganda');
    },
  );

  test(
    'Broader search keeps small Ugandan landmarks and rejects foreign matches',
    () async {
      final service = LocationService(
        apiKey: 'test',
        client: MockClient((uri) async {
          if (uri.url.path.contains('autocomplete')) {
            expect(uri.url.queryParameters['components'], 'country:ug');
            expect(uri.url.queryParameters.containsKey('types'), false);
            return http.Response(
              jsonEncode({'status': 'ZERO_RESULTS', 'predictions': []}),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'status': 'OK',
              'results': [
                {
                  'place_id': 'local',
                  'name': 'Village Primary School',
                  'formatted_address': 'XW7T+SH, Arua, Uganda',
                },
                {
                  'place_id': 'foreign',
                  'name': 'Village School',
                  'formatted_address': 'Nairobi, Kenya',
                },
              ],
            }),
            200,
          );
        }),
      );
      final results = await service.searchPlaces('Village Primary');
      expect(results, hasLength(1));
      expect(
        results.single.displayName,
        'Village Primary School, Arua, Uganda',
      );
    },
  );

  test(
    'Shortest road distance wins over fastest route and sums all legs',
    () async {
      Map<String, Object> leg(int distance, int duration) => {
        'distance': {'value': distance},
        'duration': {'value': duration},
      };
      final service = RouteService(
        apiKey: 'test',
        client: MockClient((uri) async {
          expect(uri.url.queryParameters['alternatives'], 'true');
          expect(uri.url.queryParameters['mode'], 'bicycling');
          return http.Response(
            jsonEncode({
              'status': 'OK',
              'routes': [
                {
                  'legs': [leg(1000, 30), leg(2000, 40)],
                  'overview_polyline': {
                    'points': '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
                  },
                },
                {
                  'legs': [leg(2000, 100)],
                  'overview_polyline': {
                    'points': '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
                  },
                },
              ],
            }),
            200,
          );
        }),
      );
      final route = await service.getRoute(
        const LatLng(3, 30),
        const LatLng(3.1, 30.1),
        vehicleType: 'bicycle',
      );
      expect(route.distanceMeters, 2000);
      expect(route.durationSeconds, 100);
      expect(route.points, hasLength(3));
    },
  );
}
