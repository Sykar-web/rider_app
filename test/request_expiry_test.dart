import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ride/services/request_expiry.dart';

void main() {
  testWidgets(
    'expiry follows server deadline and removes only after server confirmation',
    (tester) async {
      var calls = 0, removed = 0;
      final expiry = RequestExpiry(
        kind: 'rides',
        id: 'request',
        expire: () async {
          calls++;
          return true;
        },
        onRemoved: () => removed++,
      );
      expiry.follow({
        'status': 'requested',
        'request_expires_at': DateTime.now()
            .add(const Duration(seconds: 30))
            .toIso8601String(),
      });
      await tester.pump(const Duration(seconds: 29));
      expect(calls, 0);
      await tester.pump(const Duration(seconds: 2));
      expect(calls, 1);
      expect(removed, 1);
      expiry.dispose();
    },
  );
  testWidgets('acceptance before deadline cancels removal', (tester) async {
    var calls = 0;
    final expiry = RequestExpiry(
      kind: 'rides',
      id: 'request',
      expire: () async {
        calls++;
        return false;
      },
      onRemoved: () => fail('Accepted request removed'),
    );
    expiry.follow({
      'status': 'requested',
      'request_expires_at': DateTime.now()
          .add(const Duration(seconds: 3))
          .toIso8601String(),
    });
    expiry.follow({'status': 'accepted', 'driver_id': 'driver'});
    await tester.pump(const Duration(seconds: 5));
    expect(calls, 0);
    expiry.dispose();
  });
  testWidgets('failed cleanup retries and never reports successful deletion', (
    tester,
  ) async {
    var calls = 0, removed = 0;
    final expiry = RequestExpiry(
      kind: 'rides',
      id: 'request',
      expire: () async {
        calls++;
        if (calls == 1) throw StateError('Offline');
        return false;
      },
      onRemoved: () => removed++,
    );
    expiry.follow({
      'status': 'requested',
      'request_expires_at': DateTime.now()
          .subtract(const Duration(seconds: 1))
          .toIso8601String(),
    });
    await tester.pump(const Duration(milliseconds: 1));
    expect(calls, 1);
    expect(removed, 0);
    await tester.pump(const Duration(seconds: 5));
    expect(calls, 2);
    expect(removed, 0);
    expiry.dispose();
  });
}
