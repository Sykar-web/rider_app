import 'dart:async';

import 'package:fast_driver/app/theme.dart';
import 'package:fast_driver/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _ready = Scaffold(body: Text('Startup ready'));

Widget _app({
  required Future<void> Function() initialize,
  Duration minimumDisplay = const Duration(milliseconds: 800),
  Duration timeout = const Duration(seconds: 8),
}) => MaterialApp(
  theme: AppTheme.theme,
  home: AppStartup(
    initialize: initialize,
    readyScreen: _ready,
    minimumDisplay: minimumDisplay,
    timeout: timeout,
  ),
);

void main() {
  testWidgets('Initialization begins while the splash is visible', (
    tester,
  ) async {
    final setup = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      _app(
        initialize: () {
          calls++;
          return setup.future;
        },
      ),
    );
    expect(calls, 1);
    expect(find.text('Drive. Earn. Move.'), findsOneWidget);
    expect(find.text('Startup ready'), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    setup.complete();
    await tester.pump();
    expect(find.text('Startup ready'), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Startup ready'), findsOneWidget);
    expect(calls, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Fast startup has only one short splash delay', (tester) async {
    await tester.pumpWidget(_app(initialize: () async {}));
    await tester.pump();
    expect(find.text('Startup ready'), findsNothing);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Startup ready'), findsOneWidget);
    expect(find.text('Drive. Earn. Move.'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Timed-out startup automatically recovers when setup finishes', (
    tester,
  ) async {
    final setup = Completer<void>();
    await tester.pumpWidget(_app(initialize: () => setup.future));
    await tester.pump(const Duration(seconds: 8));
    await tester.pump();
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.text('Startup ready'), findsNothing);
    setup.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Startup ready'), findsOneWidget);
    expect(find.text('Try Again'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Failed initialization can be retried successfully', (
    tester,
  ) async {
    final first = Completer<void>();
    final second = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      _app(initialize: () => ++calls == 1 ? first.future : second.future),
    );
    first.completeError(StateError('Test startup failure'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Try Again'), findsOneWidget);
    await tester.tap(find.text('Try Again'));
    await tester.pump();
    expect(calls, 2);
    second.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Startup ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Completion from an earlier attempt cannot finish a newer retry',
    (tester) async {
      final first = Completer<void>();
      final second = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        _app(initialize: () => ++calls == 1 ? first.future : second.future),
      );
      await tester.pump(const Duration(seconds: 8));
      await tester.pump();
      await tester.tap(find.text('Try Again'));
      await tester.pump();
      expect(calls, 2);
      first.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('Startup ready'), findsNothing);
      second.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Startup ready'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('A synchronous setup error shows recovery instead of crashing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(initialize: () => throw StateError('Test failure')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Try Again'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Completing setup after disposal does not update the removed screen',
    (tester) async {
      final setup = Completer<void>();
      await tester.pumpWidget(_app(initialize: () => setup.future));
      await tester.pumpWidget(const SizedBox());
      setup.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 9));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('A setup error after disposal is handled', (tester) async {
    final setup = Completer<void>();
    await tester.pumpWidget(_app(initialize: () => setup.future));
    await tester.pumpWidget(const SizedBox());
    setup.completeError(StateError('Late test failure'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 9));
    expect(tester.takeException(), isNull);
  });
}
