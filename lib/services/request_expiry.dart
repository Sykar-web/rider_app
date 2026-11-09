import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Follows the server deadline, not a timer restarted whenever a page opens.
class RequestExpiry {
  RequestExpiry({
    required this.kind,
    required this.id,
    required this.onRemoved,
    this.expire,
  });
  final String kind, id;
  final void Function() onRemoved;
  final Future<bool> Function()? expire;
  Timer? _timer;
  DateTime? _deadline;
  bool _disposed = false;
  void follow(Map<String, dynamic> row) {
    if (row['status'] != 'requested' ||
        row['driver_id'] != null ||
        row['courier_id'] != null ||
        row['accepted_at'] != null) {
      _timer?.cancel();
      _deadline = null;
      return;
    }
    final requested = DateTime.tryParse(row['requested_at']?.toString() ?? '');
    final deadline =
        DateTime.tryParse(row['request_expires_at']?.toString() ?? '') ??
        requested?.add(const Duration(minutes: 3));
    if (deadline == null || deadline == _deadline) return;
    _deadline = deadline;
    _timer?.cancel();
    final delay = deadline.difference(DateTime.now());
    _timer = Timer(delay.isNegative ? Duration.zero : delay, _check);
  }

  Future<void> _check() async {
    if (_disposed) return;
    try {
      final removed = await (expire?.call() ?? _removeExpired());
      if (!_disposed && removed) {
        onRemoved();
      }
      if (!_disposed && !removed && _deadline != null) {
        _timer = Timer(const Duration(seconds: 5), _check);
      }
    } catch (_) {
      // Retry after connectivity returns; never pretend deletion succeeded.
      if (!_disposed && _deadline != null) {
        _timer = Timer(const Duration(seconds: 5), _check);
      }
    }
  }

  Future<bool> _removeExpired() async {
    final client = Supabase.instance.client;
    await client.rpc('expire_my_requests');
    final row = await client.from(kind).select('id').eq('id', id).maybeSingle();
    return row == null;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}
