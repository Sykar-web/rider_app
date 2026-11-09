import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles FastRide Driver authentication using the shared Supabase project.
class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  /// The currently signed-in user, or null if not signed in.
  User? get currentUser => _client.auth.currentUser;

  /// Stream of auth state changes (sign in / sign out / token refresh).
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Sign up a new user with email, password, full name, and phone number.
  /// Accounts created in this companion app start with the driver role.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'phone': phone,
        'role': 'passenger',
        'driver_onboarding_required': true,
      },
    );
  }

  /// Sign in an existing user with email and password.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Starts the Google sign-in flow. On web this redirects in-browser;
  /// on mobile it opens a browser tab/sheet and returns via a deep link
  /// (requires the redirect URL to be configured in Supabase + the app).
  Future<bool> signInWithGoogle() async {
    return await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : 'io.supabase.smartride://login-callback',
    );
  }

  Future<bool> signInWithProvider(String provider) async {
    return _client.auth.signInWithOAuth(
      provider == 'Apple' ? OAuthProvider.apple : OAuthProvider.google,
      redirectTo: kIsWeb ? null : 'io.supabase.smartride://login-callback',
    );
  }

  /// Sign the current user out.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Fetch the signed-in user's profile row (includes their role).
  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final response = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    return response;
  }

  /// Update the signed-in user's name and/or phone number.
  Future<void> updateProfile({String? fullName, String? phone}) async {
    final user = currentUser;
    if (user == null) throw Exception('Not signed in.');

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (fullName != null) updates['full_name'] = fullName;
    if (phone != null) updates['phone'] = phone;

    await _client
        .from('profiles')
        .update(updates)
        .eq('id', user.id)
        .select('id')
        .single();
    await _client.auth.updateUser(
      UserAttributes(data: {'full_name': ?fullName, 'phone': ?phone}),
    );
  }

  /// Upgrade (or switch) the signed-in user's role — e.g. from passenger to
  /// driver, business, or sender. 'admin' is intentionally never offered
  /// here since that shouldn't be self-service.
  Future<void> updateRole(String role) async {
    final user = currentUser;
    if (user == null) throw Exception('Not signed in.');

    await _client
        .from('profiles')
        .update({'role': role, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', user.id);
  }
}
