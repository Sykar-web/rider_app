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
    required String displayName,
    required this.placeId,
    this.lat,
    this.lon,
  }) : displayName = readablePlaceLabel(displayName);
}

/// Remove Google's location codes while preserving actual names and areas.
String readablePlaceLabel(
  String value, {
  String fallback = 'Selected location',
}) {
  final cleaned = value
      .replaceAll(
        RegExp(r'\b[A-Z0-9]{2,8}\+[A-Z0-9]{2,3}\b', caseSensitive: false),
        '',
      )
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .join(', ');
  return cleaned.isEmpty ? fallback : cleaned;
}

/// Handles GPS location access and place search/geocoding for Smart Ride.
/// Uses Google Places Autocomplete for search and the Google
/// Geocoding API for reverse geocoding. Requires GOOGLE_MAPS_API_KEY to be
/// set in .env — the same key used for the native Maps SDKs, as long as the
/// Places API and Geocoding API are also enabled for it in Google Cloud.
class LocationService {
  LocationService({this._client, String? apiKey}) : _keyOverride = apiKey;
  final http.Client? _client;
  final String? _keyOverride;
  String get _apiKey => _keyOverride ?? dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
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
    final response = await (_client?.get(uri) ?? http.get(uri)).timeout(
      const Duration(seconds: 6),
    );
    if (response.statusCode != 200) return 'Current location';

    final data = jsonDecode(response.body);
    if (data['status'] != 'OK' || (data['results'] as List).isEmpty) {
      return 'Current location';
    }
    final results = data['results'] as List;
    // Prefer a named street/premise over a Plus Code or broad district.
    for (final result in results) {
      final types = List<String>.from(result['types'] ?? []);
      if (types.any(
        [
          'street_address',
          'route',
          'premise',
          'establishment',
          'point_of_interest',
        ].contains,
      )) {
        final label = readablePlaceLabel(
          result['formatted_address'] ?? '',
          fallback: '',
        );
        if (label.isNotEmpty) return label;
      }
    }
    for (final result in results) {
      final parts = (result['address_components'] as List? ?? [])
          .where((part) => !(part['types'] as List).contains('plus_code'))
          .map((part) => part['long_name'] as String)
          .toSet();
      final label = readablePlaceLabel(parts.join(', '), fallback: '');
      if (label.isNotEmpty) return label;
    }
    return 'Selected location';
  }

  /// Returns fast type-ahead suggestions restricted to Uganda. Autocomplete
  /// is intentionally used here because it is much faster than Text Search
  /// while the user is typing. Coordinates are fetched only for the selected
  /// result with [resolvePlace].
  Future<List<PlaceResult>> searchPlaces(
    String query, {
    bool expanded = false,
  }) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.length < 2) return [];
    final cacheKey = '$expanded:$normalized';
    final cached = _searchCache[cacheKey];
    if (cached != null) return cached;

    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      '?input=${Uri.encodeComponent(query.trim())}'
      '&components=country:ug&language=en'
      '&sessiontoken=$_sessionToken&key=$_apiKey',
    );
    final response = await (_client?.get(uri) ?? http.get(uri)).timeout(
      const Duration(seconds: 6),
    );
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
    // Text Search broadens completed searches without slowing each keystroke.
    if (expanded || results.isEmpty) {
      final moreUri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/textsearch/json',
        {
          'query': '${query.trim()} Uganda',
          'region': 'ug',
          'language': 'en',
          'key': _apiKey,
        },
      );
      final more = await (_client?.get(moreUri) ?? http.get(moreUri)).timeout(
        const Duration(seconds: 6),
      );
      if (more.statusCode == 200) {
        final body = jsonDecode(more.body);
        for (final item in body['results'] as List? ?? []) {
          final address = (item['formatted_address'] ?? '').toString();
          // region is only a bias, so independently reject foreign results.
          if (!RegExp(
            r'(?:^|,)\s*Uganda\s*$',
            caseSensitive: false,
          ).hasMatch(address)) {
            continue;
          }
          final id = (item['place_id'] ?? '').toString();
          if (id.isEmpty || results.any((place) => place.placeId == id)) {
            continue;
          }
          final name = readablePlaceLabel(
            (item['name'] ?? '').toString(),
            fallback: '',
          );
          results.add(
            PlaceResult(
              displayName: name.isEmpty ? address : '$name, $address',
              placeId: id,
            ),
          );
        }
      }
    }
    _searchCache[cacheKey] = results;
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
    final response = await (_client?.get(uri) ?? http.get(uri)).timeout(
      const Duration(seconds: 6),
    );
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body);
    if (data['status'] != 'OK') return null;
    final result = data['result'];
    final location = result['geometry']?['location'];
    if (location == null) return null;
    _sessionToken = DateTime.now().microsecondsSinceEpoch.toString();
    return PlaceResult(
      // Keep the name the passenger chose, rather than replacing it with an address/code.
      displayName: place.displayName == 'Selected location'
          ? readablePlaceLabel(
              result['name'] ?? result['formatted_address'] ?? '',
            )
          : place.displayName,
      placeId: place.placeId,
      lat: (location['lat'] as num).toDouble(),
      lon: (location['lng'] as num).toDouble(),
    );
  }
}
