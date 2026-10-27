import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fast_driver/services/ride_service.dart';
import 'package:fast_driver/services/delivery_service.dart';

void main() {
  for (final delivery in [false, true]) {
    final table = delivery ? 'deliveries' : 'rides';
    late SupabaseClient client;
    late List<http.Request> requests;
    late String response;
    late int statusCode;
    setUp(() async {
      requests = [];
      response = '[]';
      statusCode = 200;
      client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            response,
            statusCode,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      final payload = base64Url
          .encode(
            utf8.encode(jsonEncode({'sub': 'driver-1', 'exp': 4102444800})),
          )
          .replaceAll('=', '');
      await client.auth.recoverSession(
        jsonEncode({
          'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.signature',
          'refresh_token': 'test-refresh',
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
    });
    tearDown(() async => client.dispose());

    Future<bool> accept() => delivery
        ? DeliveryService(client: client).acceptDelivery('job-1')
        : RideService(client: client).acceptRide('job-1');
    Future<Map<String, dynamic>?> recover() => delivery
        ? DeliveryService(client: client).getActiveDelivery()
        : RideService(client: client).getActiveRide();

    test('$table acceptance succeeds only with a returned job', () async {
      response = '[{"id":"job-1"}]';
      expect(await accept(), isTrue);
      final request = requests.single;
      expect(request.method, 'PATCH');
      expect(request.url.path, endsWith('/$table'));
      expect(request.url.queryParameters['status'], 'eq.requested');
      expect(request.url.queryParameters['select'], 'id');
      expect(
        jsonDecode(request.body)[delivery ? 'courier_id' : 'driver_id'],
        'driver-1',
      );
    });
    test(
      '$table server errors are not mistaken for an unavailable job',
      () async {
        statusCode = 403;
        response = '{"message":"Denied","code":"42501"}';
        await expectLater(accept(), throwsA(isA<PostgrestException>()));
      },
    );
    test('$table already claimed request returns false', () async {
      expect(await accept(), isFalse);
    });
    test('$table recovery filters by owner and unfinished statuses', () async {
      response = '[{"id":"job-1","accepted_at":"2026-01-01T00:00:00Z"}]';
      expect((await recover())?['id'], 'job-1');
      final query = requests.single.url.queryParameters;
      expect(query[delivery ? 'courier_id' : 'driver_id'], 'eq.driver-1');
      expect(
        query['status']?.replaceAll('"', ''),
        delivery
            ? 'in.(accepted,picked_up,in_progress)'
            : 'in.(accepted,arriving,in_progress)',
      );
      expect(query['limit'], '1');
      expect(query['order'], startsWith('accepted_at.asc'));
    });
    test('$table recovery returns null when no job is active', () async {
      expect(await recover(), isNull);
    });
    test(
      '$table status changes require the assigned driver and previous state',
      () async {
        response = '{"id":"job-1"}';
        if (delivery) {
          await DeliveryService(client: client)
              .updateDeliveryStatus('job-1', 'picked_up');
        } else {
          await RideService(client: client)
              .updateRideStatus('job-1', 'arriving');
        }
        final request = requests.single;
        expect(
          request.url.queryParameters[delivery ? 'courier_id' : 'driver_id'],
          'eq.driver-1',
        );
        expect(request.url.queryParameters['status'], 'eq.accepted');
        expect(
          jsonDecode(request.body)['status'],
          delivery ? 'picked_up' : 'arriving',
        );
      },
    );
    test(
      '$table rejects unsupported transitions before sending a request',
      () async {
        final future = delivery
            ? DeliveryService(client: client)
                  .updateDeliveryStatus('job-1', 'cancelled')
            : RideService(client: client)
                  .updateRideStatus('job-1', 'cancelled');
        await expectLater(future, throwsArgumentError);
        expect(requests, isEmpty);
      },
    );
  }
}
