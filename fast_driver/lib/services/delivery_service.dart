import 'package:supabase_flutter/supabase_flutter.dart';

import 'ride_service.dart' show RideService; // reuse distanceKm helper

/// Handles delivery requests and sender-courier matching for Smart Ride.
/// Structurally mirrors RideService — couriers are just drivers acting in
/// a delivery capacity, sharing the same online/location fields on
/// profiles as ride matching does.
class DeliveryService {
  final SupabaseClient _client;

  DeliveryService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  // --- Sender side ---

  Future<String> requestDelivery({
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffAddress,
    String? vehicleType,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not signed in.');

    final response = await _client
        .from('deliveries')
        .insert({
          'sender_id': user.id,
          'pickup_lat': pickupLat,
          'pickup_lng': pickupLng,
          'pickup_address': pickupAddress,
          'dropoff_lat': dropoffLat,
          'dropoff_lng': dropoffLng,
          'dropoff_address': dropoffAddress,
          'vehicle_type': ?vehicleType,
        })
        .select()
        .single();

    return response['id'] as String;
  }

  Stream<Map<String, dynamic>?> watchDelivery(String deliveryId) {
    return _client
        .from('deliveries')
        .stream(primaryKey: ['id'])
        .eq('id', deliveryId)
        .map((rows) => rows.isNotEmpty ? rows.first : null);
  }

  Future<void> cancelDelivery(String deliveryId) async {
    await _client
        .from('deliveries')
        .update({
          'status': 'cancelled',
          'cancelled_at': DateTime.now().toIso8601String(),
        })
        .eq('id', deliveryId);
  }

  // --- Courier (driver) side ---

  /// Live list of open (unclaimed) delivery requests, for a courier to browse.
  Stream<List<Map<String, dynamic>>> watchOpenDeliveries() {
    return _client
        .from('deliveries')
        .stream(primaryKey: ['id'])
        .eq('status', 'requested')
        .order('requested_at', ascending: true);
  }

  Stream<List<Map<String, dynamic>>> watchMyDeliveries() {
    final user = _client.auth.currentUser;
    if (user == null) return const Stream.empty();
    return _client
        .from('deliveries')
        .stream(primaryKey: ['id'])
        .eq('courier_id', user.id)
        .order('accepted_at', ascending: false);
  }

  Future<Map<String, dynamic>?> getActiveDelivery() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not signed in.');
    final rows = await _client
        .from('deliveries')
        .select()
        .eq('courier_id', user.id)
        .inFilter('status', ['accepted', 'picked_up', 'in_progress'])
        .order('accepted_at', ascending: true)
        .limit(1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<bool> acceptDelivery(String deliveryId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not signed in.');

    final claimed = await _client
        .from('deliveries')
        .update({
          'courier_id': user.id,
          'status': 'accepted',
          'accepted_at': DateTime.now().toIso8601String(),
        })
        .eq('id', deliveryId)
        .eq('status', 'requested')
        .select('id');
    return claimed.isNotEmpty;
  }

  Future<void> updateDeliveryStatus(String deliveryId, String status) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Sign in first.');
    final previous = switch (status) {
      'picked_up' => 'accepted',
      'in_progress' => 'picked_up',
      'completed' => 'in_progress',
      _ => null,
    };
    if (previous == null) {
      throw ArgumentError('Unsupported delivery transition.');
    }
    final updates = <String, dynamic>{'status': status};
    if (status == 'picked_up') {
      updates['picked_up_at'] = DateTime.now().toUtc().toIso8601String();
    }
    if (status == 'in_progress') {
      updates['started_at'] = DateTime.now().toUtc().toIso8601String();
    }
    if (status == 'completed') {
      updates['completed_at'] = DateTime.now().toUtc().toIso8601String();
    }
    await _client
        .from('deliveries')
        .update(updates)
        .eq('id', deliveryId)
        .eq('courier_id', user.id)
        .eq('status', previous)
        .select('id')
        .single();
  }

  Future<Map<String, dynamic>?> getProfileById(String userId) async {
    return await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
  }

  static double distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) => RideService.distanceKm(lat1, lon1, lat2, lon2);
}
