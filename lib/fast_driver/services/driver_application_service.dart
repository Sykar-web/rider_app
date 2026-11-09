import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart' as shared;

/// One account owns both the passenger profile and its driver application.
class DriverApplicationService {
  DriverApplicationService({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;
  final SupabaseClient client;

  Future<Map<String, dynamic>> load() async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Sign in to apply.');
    final profile = await shared.AuthService().getCurrentProfile();
    final row = await client
        .from('driver_applications')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    final legacy = Map<String, dynamic>.from(
      user.userMetadata?['driver_application'] as Map? ?? {},
    );
    return {
      'profile': {...?user.userMetadata, ...?profile, 'email': user.email},
      'data': row?['details'] ?? legacy,
      'status':
          row?['status'] ??
          user.userMetadata?['driver_application_status'] ??
          'draft',
    };
  }

  Future<String> upload(String label, PlatformFile file) async {
    final id = client.auth.currentUser!.id;
    if (file.bytes == null || file.size > 5 * 1024 * 1024) {
      throw const FormatException('Choose a file smaller than 5 MB.');
    }
    final ext = file.extension?.toLowerCase() ?? 'jpg';
    if (!['jpg', 'jpeg', 'png', 'pdf'].contains(ext)) {
      throw const FormatException('Choose JPG, PNG or PDF.');
    }
    final path =
        '$id/${DateTime.now().microsecondsSinceEpoch}_${label.replaceAll(' ', '_')}.$ext';
    await client.storage
        .from('driver-documents')
        .uploadBinary(
          path,
          file.bytes!,
          fileOptions: FileOptions(
            contentType: ext == 'pdf'
                ? 'application/pdf'
                : ext == 'png'
                ? 'image/png'
                : 'image/jpeg',
          ),
        );
    return path;
  }

  Future<void> save(Map<String, dynamic> details, {bool submit = false}) async {
    await client.rpc(
      'save_driver_application',
      params: {'application_details': details, 'submit_application': submit},
    );
  }
}
