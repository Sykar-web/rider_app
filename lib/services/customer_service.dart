import 'package:supabase_flutter/supabase_flutter.dart';

import 'location_service.dart';

class CustomerService {
  final SupabaseClient _client = Supabase.instance.client;
  String get _userId => _client.auth.currentUser!.id;

  Future<List<Map<String, dynamic>>> places({bool recent = false}) async =>
      await _client
          .from('customer_places')
          .select()
          .eq('user_id', _userId)
          .inFilter('kind', recent ? ['recent'] : ['home', 'work', 'favourite'])
          .order('created_at', ascending: false)
          .limit(20);

  Future<void> savePlace(String name, String kind, PlaceResult place) async {
    if (place.lat == null || place.lon == null) return;
    await _client.from('customer_places').upsert({
      'user_id': _userId,
      'label': name,
      'kind': kind,
      'address': place.displayName,
      'place_id': place.placeId,
      'latitude': place.lat,
      'longitude': place.lon,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,label,kind');
  }

  Future<void> deletePlace(String id) async => await _client
      .from('customer_places')
      .delete()
      .eq('id', id)
      .eq('user_id', _userId);

  Future<Map<String, dynamic>> wallet() async {
    final account = await _client
        .from('wallet_accounts')
        .select('balance_ugx,is_active')
        .eq('user_id', _userId)
        .maybeSingle();
    final transactions = await _client
        .from('wallet_transactions')
        .select('id,description,amount_ugx,created_at')
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(50);
    return {'account': account, 'transactions': transactions};
  }

  Future<void> review(String rideId, int rating, String comment) async {
    await _client.rpc(
      'submit_ride_review',
      params: {'p_ride_id': rideId, 'p_rating': rating, 'p_comment': comment},
    );
  }

  Future<Map<String, dynamic>?> rideReview(String rideId) async => await _client
      .from('ride_reviews')
      .select('rating,comment')
      .eq('ride_id', rideId)
      .eq('passenger_id', _userId)
      .maybeSingle();

  Future<void> support(String category, String message) async {
    await _client.from('support_requests').insert({
      'user_id': _userId,
      'category': category,
      'message': message,
    });
  }

  Future<List<Map<String, dynamic>>> supportRequests() async => await _client
      .from('support_requests')
      .select('id,category,message,status,response,created_at')
      .eq('user_id', _userId)
      .order('created_at', ascending: false)
      .limit(30);

  Future<Map<String, dynamic>> preferences() async =>
      await _client
          .from('customer_preferences')
          .select()
          .eq('user_id', _userId)
          .maybeSingle() ??
      {};

  Future<void> savePreferences(bool updates, bool offers) async =>
      await _client.from('customer_preferences').upsert({
        'user_id': _userId,
        'trip_updates': updates,
        'offers': offers,
      }, onConflict: 'user_id');
}
