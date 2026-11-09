import 'package:supabase_flutter/supabase_flutter.dart';

import 'ride_service.dart' show RideService; // reuse distanceKm helper

/// Handles delivery requests and sender-courier matching for Smart Ride.
/// Structurally mirrors RideService — couriers are just drivers acting in
/// a delivery capacity, sharing the same online/location fields on
/// profiles as ride matching does.
class DeliveryService {
  final SupabaseClient _client = Supabase.instance.client;

  // --- Sender side ---

  Future<String> requestDelivery({
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffAddress,
    String? vehicleType,
    String? packageType,
    String? packageNotes,
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
          'package_type': ?packageType,
          'package_notes': ?packageNotes,
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
    await _client.rpc(
      'cancel_unaccepted_request',
      params: {'p_kind': 'deliveries', 'p_id': deliveryId},
    );
  }

  // --- Courier (driver) side ---

  /// Live list of open (unclaimed) delivery requests, for a courier to browse.
  Stream<List<Map<String, dynamic>>> watchOpenDeliveries() {
    return _client
        .from('deliveries')
        .stream(primaryKey: ['id'])
        .eq('status', 'requested')
        .order('requested_at');
  }

  Future<void> acceptDelivery(String deliveryId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not signed in.');

    await _client
        .from('deliveries')
        .update({
          'courier_id': user.id,
          'status': 'accepted',
          'accepted_at': DateTime.now().toIso8601String(),
        })
        .eq('id', deliveryId)
        .eq('status', 'requested');
  }

  Future<void> updateDeliveryStatus(String deliveryId, String status) async {
    final updates = <String, dynamic>{'status': status};
    if (status == 'picked_up') {
      updates['picked_up_at'] = DateTime.now().toIso8601String();
    }
    if (status == 'completed') {
      updates['completed_at'] = DateTime.now().toIso8601String();
    }

    await _client.from('deliveries').update(updates).eq('id', deliveryId);
  }

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

  static double distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) => RideService.distanceKm(lat1, lon1, lat2, lon2);
}
