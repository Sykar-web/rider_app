import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles ride requests and passenger-driver matching for Smart Ride.
class RideService {
  final SupabaseClient _client = Supabase.instance.client;

  // --- Passenger side ---

  /// Creates a new ride request and returns its id.
  Future<String> requestRide({
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffAddress,
    String? vehicleType,
    Map<String, dynamic>? bookingDetails,
    String? bookingReference,
    String? reservationType,
    String? seatNumber,
    List<String>? seatNumbers,
    String? busScheduleId,
    DateTime? travelDate,
    String? travelClass,
    DateTime? scheduledAt,
    String requestType = 'private',
    double? distanceKm,
    double? durationMinutes,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not signed in.');

    final response = await _client
        .from('rides')
        .insert({
          'passenger_id': user.id,
          'pickup_lat': pickupLat,
          'pickup_lng': pickupLng,
          'pickup_address': pickupAddress,
          'dropoff_lat': dropoffLat,
          'dropoff_lng': dropoffLng,
          'dropoff_address': dropoffAddress,
          'vehicle_type': ?vehicleType,
          'booking_details': ?bookingDetails,
          'booking_reference': ?bookingReference,
          'reservation_type': ?reservationType,
          'seat_number': ?seatNumber,
          'seat_numbers': ?seatNumbers,
          'bus_schedule_id': ?busScheduleId,
          if (travelDate != null)
            'travel_date': travelDate.toIso8601String().substring(0, 10),
          'travel_class': ?travelClass,
          'scheduled_at': ?scheduledAt?.toUtc().toIso8601String(),
          'request_type': requestType,
          'distance_km': ?distanceKm,
          'estimated_duration_minutes': ?durationMinutes,
          'payment_method': 'cash',
        })
        .select()
        .single();

    return response['id'] as String;
  }

  /// Live updates for a single ride — used by the passenger to see when
  /// a driver accepts, arrives, starts, or completes the trip.
  Stream<Map<String, dynamic>?> watchRide(String rideId) {
    return _client
        .from('rides')
        .stream(primaryKey: ['id'])
        .eq('id', rideId)
        .map((rows) => rows.isNotEmpty ? rows.first : null);
  }

  Future<void> cancelRide(String rideId) async {
    await _client.rpc(
      'cancel_unaccepted_request',
      params: {'p_kind': 'rides', 'p_id': rideId},
    );
  }

  // --- Driver side ---

  /// Marks the driver online/offline and records their current location.
  Future<void> setOnline(bool online, {double? lat, double? lng}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not signed in.');

    final updates = <String, dynamic>{
      'is_online': online,
      'last_seen': DateTime.now().toIso8601String(),
    };
    if (lat != null) updates['current_lat'] = lat;
    if (lng != null) updates['current_lng'] = lng;

    await _client.from('profiles').update(updates).eq('id', user.id);
  }

  /// Live list of open (unclaimed) ride requests, for a driver to browse.
  Stream<List<Map<String, dynamic>>> watchOpenRides() {
    return _client
        .from('rides')
        .stream(primaryKey: ['id'])
        .eq('status', 'requested')
        .order('requested_at');
  }

  /// A driver claims an open ride request. RLS ensures this only succeeds
  /// if the ride is still unassigned — if two drivers try at once, only
  /// one update will actually match a still-open row.
  Future<void> acceptRide(String rideId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not signed in.');

    await _client
        .from('rides')
        .update({
          'driver_id': user.id,
          'status': 'accepted',
          'accepted_at': DateTime.now().toIso8601String(),
        })
        .eq('id', rideId)
        .eq('status', 'requested');
  }

  Future<void> updateRideStatus(String rideId, String status) async {
    final updates = <String, dynamic>{'status': status};
    if (status == 'in_progress') {
      updates['started_at'] = DateTime.now().toIso8601String();
    }
    if (status == 'completed') {
      updates['completed_at'] = DateTime.now().toIso8601String();
    }

    await _client.from('rides').update(updates).eq('id', rideId);
  }

  /// Fetches a passenger or driver's profile by id — used to show the
  /// matched counterpart's name/phone once a ride is accepted.
  Future<Map<String, dynamic>?> getProfileById(String userId) async {
    return await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
  }

  Stream<Map<String, dynamic>?> watchProfile(String userId) {
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((rows) => rows.isEmpty ? null : rows.first);
  }

  /// Straight-line distance in kilometers between two coordinates
  /// (Haversine formula) — used to sort open ride requests by how close
  /// they are to the driver.
  static double distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * (pi / 180);
}
