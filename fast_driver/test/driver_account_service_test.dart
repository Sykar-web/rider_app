import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fast_driver/services/driver_account_service.dart';

void main() {
  test('Account history reads every owned page so monthly totals are not truncated', () async {
    final offsets = <int>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final rides = request.url.path.endsWith('/rides');
        expect(
          request.url.queryParameters[rides ? 'driver_id' : 'courier_id'],
          'eq.driver-1',
        );
        final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
        if (rides) offsets.add(offset);
        final rows = rides
            ? List.generate(
                offset == 0 ? 200 : 3,
                (i) => {
                  'id': 'job-${offset + i}',
                  'accepted_at': '2026-10-22T10:00:00Z',
                  'status': 'completed',
                  'fare_ugx': 1000,
                },
              )
            : [];
        return http.Response(
          jsonEncode(rows),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    final payload = base64Url
        .encode(utf8.encode(jsonEncode({'sub': 'driver-1', 'exp': 4102444800})))
        .replaceAll('=', '');
    await client.auth.recoverSession(
      jsonEncode({
        'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.signature',
        'refresh_token': 'test',
        'token_type': 'bearer',
        'expires_at': 4102444800,
        'user': {
          'id': 'driver-1',
          'app_metadata': {},
          'user_metadata': {},
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
    final rows = await DriverAccountService(client: client).jobs();
    expect(rows, hasLength(203));
    expect(offsets, [0, 200]);
    expect(rows.last['_delivery'], false);
    await client.dispose();
  });
}
