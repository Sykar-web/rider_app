import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Checks that the device can actually reach the internet, rather than only
/// checking whether Wi-Fi or mobile data is switched on.
class ConnectionService {
  Future<bool> hasInternet() async {
    try {
      // Supabase allows cross-origin requests. An auth rejection still proves
      // reachability; a transport timeout or server outage does not.
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
}
