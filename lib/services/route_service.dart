import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  double get distanceKm => distanceMeters / 1000;
  double get durationMinutes => durationSeconds / 60;

  RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  String get distanceLabel => distanceMeters >= 1000
      ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
      : '${distanceMeters.round()} m';

  String get durationLabel {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remMinutes = minutes % 60;
    return '${hours}h ${remMinutes}min';
  }
}

/// Fetches the shortest available route between two points using the
/// Google Directions API. Requires GOOGLE_MAPS_API_KEY in .env, with the
/// Directions API enabled for it in Google Cloud.
class RouteService {
  RouteService({this._client, String? apiKey}) : _keyOverride = apiKey;
  final http.Client? _client;
  final String? _keyOverride;
  String get _apiKey => _keyOverride ?? dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  /// The Directions API's 'driving' mode covers motorcycle, car, and tuktuk
  /// (all use the road network); only bicycles get a distinct 'bicycling'
  /// route — same split as before.
  static String _modeFor(String vehicleType) {
    return vehicleType == 'bicycle' ? 'bicycling' : 'driving';
  }

  Future<RouteResult> getRoute(
    LatLng start,
    LatLng end, {
    String vehicleType = 'car',
  }) async {
    final mode = _modeFor(vehicleType);
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=${start.latitude},${start.longitude}'
      '&destination=${end.latitude},${end.longitude}'
      '&mode=$mode&alternatives=true&key=$_apiKey',
    );

    final response = await (_client?.get(uri) ?? http.get(uri)).timeout(
      const Duration(seconds: 10),
    );
    if (response.statusCode != 200) {
      throw Exception('Could not fetch route.');
    }

    final data = jsonDecode(response.body);
    if (data['status'] != 'OK' || (data['routes'] as List).isEmpty) {
      throw Exception('No route found.');
    }

    final routes = List<Map<String, dynamic>>.from(data['routes']);
    double total(Map<String, dynamic> route, String field) =>
        (route['legs'] as List).fold<double>(
          0,
          (sum, leg) => sum + (leg[field]['value'] as num).toDouble(),
        );
    // Google ranks by preference/time; explicitly select distance instead.
    // This is the shortest of Google's returned alternatives, not every road.
    routes.sort((a, b) {
      final distance = total(a, 'distance').compareTo(total(b, 'distance'));
      return distance != 0
          ? distance
          : total(a, 'duration').compareTo(total(b, 'duration'));
    });
    final route = routes.first;
    final points = _decodePolyline(route['overview_polyline']['points']);

    return RouteResult(
      points: points,
      distanceMeters: total(route, 'distance'),
      durationSeconds: total(route, 'duration'),
    );
  }

  /// Decodes Google's encoded polyline format into a list of LatLng points.
  /// Standard algorithm — see:
  /// https://developers.google.com/maps/documentation/utilities/polylinealgorithm
  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }
}
