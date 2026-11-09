import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Native builds can verify that the FastRide backend is actually reachable.
Future<bool> hasInternetConnection() async {
  try {
    final base = dotenv.env['SUPABASE_URL'];
    if (base == null) return false;
    final response = await http
        .get(Uri.parse('$base/auth/v1/health'))
        .timeout(const Duration(seconds: 5));
    return response.statusCode < 500;
  } catch (_) {
    return false;
  }
}
