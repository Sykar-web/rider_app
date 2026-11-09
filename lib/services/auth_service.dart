import 'package:flutter/foundation.dart' show kIsWeb, ValueNotifier, Uint8List;
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles all authentication logic for Smart Ride using Supabase Auth.
class AuthService {
  static final avatarChanges = ValueNotifier<int>(0);
  final SupabaseClient _client = Supabase.instance.client;

  /// The currently signed-in user, or null if not signed in.
  User? get currentUser => _client.auth.currentUser;

  /// Stream of auth state changes (sign in / sign out / token refresh).
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Sign up a new user with email, password, full name, and phone number.
  /// Every new account starts as a 'passenger' — other roles (driver,
  /// business, sender, admin) are granted later via a profile upgrade,
  /// not chosen at signup.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'phone': phone, 'role': 'passenger'},
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

    final path = response?['avatar_path'] as String?;
    if (path != null && path.isNotEmpty) {
      try {
        response!['avatar_url'] = await _client.storage
            .from('profile-photos')
            .createSignedUrl(path, 3600);
      } catch (_) {
        /* Preserve the profile if storage is temporarily unavailable. */
      }
    }
    final merged = <String, dynamic>{...?user.userMetadata};
    for (final entry in (response ?? <String, dynamic>{}).entries) {
      if (entry.value != null &&
          (entry.value is! String ||
              (entry.value as String).trim().isNotEmpty)) {
        merged[entry.key] = entry.value;
      }
    }
    merged['phone'] ??= user.phone;
    merged['avatar_url'] ??= user.userMetadata?['picture'];
    if (merged['avatar_url'] == null) {
      final application = user.userMetadata?['driver_application'] as Map?;
      final legacy =
          user.userMetadata?['driver_profile_photo'] ??
          (application?['documents'] as Map?)?['Profile Photo'];
      if (legacy is String && legacy.startsWith('${user.id}/')) {
        try {
          merged['avatar_url'] = await _client.storage
              .from('driver-documents')
              .createSignedUrl(legacy, 3600);
        } catch (_) {
          /* Keep the account usable if storage is offline. */
        }
      }
    }
    return merged;
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

    await _client.from('profiles').update(updates).eq('id', user.id);
    await _client.auth.updateUser(
      UserAttributes(data: {'full_name': ?fullName, 'phone': ?phone}),
    );
    avatarChanges.value++;
  }

  Future<void> uploadAvatar(Uint8List bytes) async {
    final user = currentUser;
    if (user == null) throw StateError('Not signed in');
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const FormatException('Please choose a picture smaller than 5 MB.');
    }
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw const FormatException('Please choose a JPG, PNG or WebP picture.');
    }
    final square = img.copyResizeCropSquare(image, size: 512);
    final data = Uint8List.fromList(img.encodeJpg(square, quality: 85));
    final path =
        '${user.id}/avatar-${DateTime.now().microsecondsSinceEpoch}.jpg';
    final profile = await _client
        .from('profiles')
        .select('avatar_path')
        .eq('id', user.id)
        .single();
    final previous = profile['avatar_path'] as String?;
    await _client.storage
        .from('profile-photos')
        .uploadBinary(
          path,
          data,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );
    try {
      await _client
          .from('profiles')
          .update({
            'avatar_path': path,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', user.id)
          .select('id')
          .single();
    } catch (_) {
      try {
        await _client.storage.from('profile-photos').remove([path]);
      } catch (_) {
        /* Preserve the original save error. */
      }
      rethrow;
    }
    avatarChanges.value++;
    if (previous != null && previous.startsWith('${user.id}/')) {
      try {
        await _client.storage.from('profile-photos').remove([previous]);
      } catch (_) {
        /* The new photo is already saved. */
      }
    }
  }

  Future<void> removeAvatar() async {
    final user = currentUser;
    if (user == null) throw StateError('Not signed in');
    final profile = await _client
        .from('profiles')
        .select('avatar_path')
        .eq('id', user.id)
        .single();
    await _client
        .from('profiles')
        .update({'avatar_path': null})
        .eq('id', user.id)
        .select('id')
        .single();
    avatarChanges.value++;
    final path = profile['avatar_path'] as String?;
    if (path != null && path.startsWith('${user.id}/')) {
      try {
        await _client.storage.from('profile-photos').remove([path]);
      } catch (_) {
        /* The profile no longer references this file. */
      }
    }
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
