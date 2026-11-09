import 'package:supabase_flutter/supabase_flutter.dart';

class AdminAccessExpired implements Exception {}

/// The email check controls visibility only; every operation is verified by SQL.
class AdminService {
  AdminService({this.supabaseClient});
  final SupabaseClient? supabaseClient;
  SupabaseClient get client => supabaseClient ?? Supabase.instance.client;
  static const accountEmail = 'ezrasykar@gmail.com';
  bool get allowedAccount =>
      client.auth.currentUser?.email?.trim().toLowerCase() == accountEmail;
  Stream<bool> get accountChanges =>
      client.auth.onAuthStateChange.map((_) => allowedAccount);

  Future<Map<String, dynamic>> unlock(String pin) async =>
      Map<String, dynamic>.from(
        await _call('admin_unlock_dashboard', {'p_pin': pin}) as Map,
      );
  Future<Map<String, dynamic>> data(
    String section, {
    String search = '',
    int page = 0,
  }) async => Map<String, dynamic>.from(
    await _call('admin_dashboard_data', {
      'p_section': section,
      'p_search': search,
      'p_page': page,
    }) as Map,
  );
  Future<void> action(
    String action, {
    String? target,
    Map<String, dynamic> details = const {},
  }) async {
    await _call('admin_dashboard_action', {
      'p_action': action,
      'p_target': target,
      'p_details': details,
    });
  }

  Future<void> lock() async {
    await _call('admin_lock_dashboard', {});
  }

  Future<String> documentUrl(String bucket, String path) =>
      client.storage.from(bucket).createSignedUrl(path, 60);

  Future<dynamic> _call(String function, Map<String, dynamic> params) async {
    try {
      return await client.rpc(function, params: params);
    } on PostgrestException catch (e) {
      if (e.code == '42501') throw AdminAccessExpired();
      if (e.code == 'PGRST202' || e.message == 'Admin setup is incomplete') {
        throw const FormatException(
          'Run the FastRide admin setup SQL before using this dashboard.',
        );
      }
      if (e.code == 'P0001') throw FormatException(e.message);
      throw const FormatException(
        'Could not save this change. Check the information and try again.',
      );
    }
  }
}
