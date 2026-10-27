import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// A simple place search result, now backed by the Google Places API.
class PlaceResult {
  final String displayName;
  final String placeId;
  final double? lat;
  final double? lon;

  PlaceResult({
    required this.displayName,
    required this.placeId,
    this.lat,
    this.lon,
  });
}

/// Handles GPS location access and place search/geocoding for Smart Ride.
/// Uses Google Places Autocomplete for search and the Google
/// Geocoding API for reverse geocoding. Requires GOOGLE_MAPS_API_KEY to be
/// set in .env — the same key used for the native Maps SDKs, as long as the
/// Places API and Geocoding API are also enabled for it in Google Cloud.
class LocationService {
  String get _apiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  final Map<String, List<PlaceResult>> _searchCache = {};
  String _sessionToken = DateTime.now().microsecondsSinceEpoch.toString();

  /// Requests location permission if needed, then returns the user's
  /// current GPS position. Throws if permission is denied or location
  /// services are off — callers should catch and show a friendly message.
  ///
  /// Uses [LocationAccuracy.best] and waits briefly for GPS to lock on
  /// rather than accepting the very first (often rough, network-based) fix.
  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable GPS.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission permanently denied. Enable it in your device settings.',
      );
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 12),
      ),
    );
  }

  /// A live stream of position updates at best accuracy. With the move to
  /// google_maps_flutter, the map's own myLocationEnabled handles the blue
  /// dot natively — this stream is kept for any other UI that wants raw
  /// position updates (e.g. a "distance to driver" readout later).
  Stream<Position> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 3, // meters — refresh every 3m of movement
      ),
    );
  }

  /// Reverse-geocodes coordinates into a human-readable address using the
  /// Google Geocoding API.
  Future<String> reverseGeocode(double lat, double lon) async {
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?latlng=$lat,$lon&key=$_apiKey',
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) return 'Current location';

    final data = jsonDecode(response.body);
    if (data['status'] != 'OK' || (data['results'] as List).isEmpty) {
      return 'Current location';
    }
    return data['results'][0]['formatted_address'] ?? 'Current location';
  }

  /// Returns fast type-ahead suggestions restricted to Uganda. Autocomplete
  /// is intentionally used here because it is much faster than Text Search
  /// while the user is typing. Coordinates are fetched only for the selected
  /// result with [resolvePlace].
  Future<List<PlaceResult>> searchPlaces(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.length < 2) return [];
    final cached = _searchCache[normalized];
    if (cached != null) return cached;

    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      '?input=${Uri.encodeComponent(query.trim())}'
      '&components=country:ug&language=en'
      '&sessiontoken=$_sessionToken&key=$_apiKey',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') return [];

    final List predictions = data['predictions'] ?? [];
    final results = predictions
        .take(8)
        .map(
          (item) => PlaceResult(
            displayName: item['description'] ?? '',
            placeId: item['place_id'] ?? '',
          ),
        )
        .where((place) => place.placeId.isNotEmpty)
        .toList();
    _searchCache[normalized] = results;
    if (_searchCache.length > 40) _searchCache.remove(_searchCache.keys.first);
    return results;
  }

  /// Resolves a selected autocomplete prediction to its exact coordinates.
  Future<PlaceResult?> resolvePlace(PlaceResult place) async {
    if (place.lat != null && place.lon != null) return place;
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=${Uri.encodeComponent(place.placeId)}'
      '&fields=geometry,formatted_address,name'
      '&sessiontoken=$_sessionToken&key=$_apiKey',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body);
    if (data['status'] != 'OK') return null;
    final result = data['result'];
    final location = result['geometry']?['location'];
    if (location == null) return null;
    _sessionToken = DateTime.now().microsecondsSinceEpoch.toString();
    return PlaceResult(
      displayName:
          result['formatted_address'] ?? result['name'] ?? place.displayName,
      placeId: place.placeId,
      lat: (location['lat'] as num).toDouble(),
      lon: (location['lng'] as num).toDouble(),
    );
  }
}
