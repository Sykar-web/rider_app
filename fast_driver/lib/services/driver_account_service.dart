import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverAccountService {
  DriverAccountService({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;
  final SupabaseClient client;

  Future<List<Map<String, dynamic>>> jobs() async {
    final id = client.auth.currentUser?.id;
    if (id == null) return [];
    final records = await Future.wait([
      _allOwned('rides', 'driver_id', id),
      _allOwned('deliveries', 'courier_id', id),
    ]);
    final rows = [
      for (final r in records[0]) {...r, '_delivery': false},
      for (final r in records[1]) {...r, '_delivery': true},
    ];
    rows.sort(
      (a, b) => (b['accepted_at'] ?? '').toString().compareTo(
        (a['accepted_at'] ?? '').toString(),
      ),
    );
    return rows;
  }

  Future<List<Map<String, dynamic>>> _allOwned(
    String table,
    String owner,
    String id,
  ) async {
    final rows = <Map<String, dynamic>>[];
    const size = 200;
    for (var offset = 0; ; offset += size) {
      final page = await client
          .from(table)
          .select()
          .eq(owner, id)
          .order('accepted_at', ascending: false)
          .range(offset, offset + size - 1);
      rows.addAll(page);
      if (page.length < size) return rows;
    }
  }

  Future<Map<String, dynamic>> profile() async {
    final user = client.auth.currentUser;
    if (user == null) return {};
    final row = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    final data = <String, dynamic>{
      ...?(user.userMetadata),
      ...?row,
      'email': user.email,
    };
    final metadata = user.userMetadata ?? {};
    final application = metadata['driver_application'] as Map? ?? {};
    final path =
        metadata['driver_profile_photo'] ??
        (application['documents'] as Map?)?['Profile Photo'];
    if (path is String && path.startsWith('${user.id}/')) {
      try {
        data['photo_url'] = await client.storage
            .from('driver-documents')
            .createSignedUrl(path, 3600);
      } catch (_) {
        /* Account stays usable if photo is unavailable. */
      }
    }
    return data;
  }

  Future<void> changePhoto() async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Sign in first.');
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null) return;
    final photo = result.files.single;
    if (photo.bytes == null || photo.size > 5 * 1024 * 1024) {
      throw const FormatException('Choose a JPG or PNG smaller than 5 MB.');
    }
    final path =
        '${user.id}/profile-${DateTime.now().microsecondsSinceEpoch}.${photo.extension}';
    await client.storage
        .from('driver-documents')
        .uploadBinary(
          path,
          photo.bytes!,
          fileOptions: FileOptions(
            contentType: photo.extension == 'png' ? 'image/png' : 'image/jpeg',
          ),
        );
    try {
      await client.auth.updateUser(
        UserAttributes(data: {'driver_profile_photo': path}),
      );
    } catch (_) {
      await client.storage.from('driver-documents').remove([path]);
      rethrow;
    }
  }
}

class DriverTotals {
  DriverTotals(List<Map<String, dynamic>> jobs, {DateTime? now, int days = 1}) {
    final time = now ?? DateTime.now();
    final today = DateTime(time.year, time.month, time.day);
    final since = today.subtract(Duration(days: days - 1));
    for (final job in jobs) {
      if (job['status'] != 'completed') continue;
      final completed = DateTime.tryParse(
        (job['completed_at'] ?? '').toString(),
      )?.toLocal();
      if (completed == null ||
          completed.isBefore(since) ||
          completed.isAfter(time)) {
        continue;
      }
      count++;
      if (job['fare_ugx'] is num) {
        gross += (job['fare_ugx'] as num).toDouble();
        pricedCount++;
      }
      final started = DateTime.tryParse(
        (job['started_at'] ?? job['picked_up_at'] ?? '').toString(),
      )?.toLocal();
      if (started != null && !completed.isBefore(started)) {
        seconds += completed.difference(started).inSeconds;
      }
      byDay[DateTime(completed.year, completed.month, completed.day)] =
          (byDay[DateTime(completed.year, completed.month, completed.day)] ??
              0) +
          (job['fare_ugx'] is num ? (job['fare_ugx'] as num).toDouble() : 0);
    }
  }
  int count = 0, pricedCount = 0, seconds = 0;
  double gross = 0;
  final Map<DateTime, double> byDay = {};
}
