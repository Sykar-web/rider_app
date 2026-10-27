import 'package:fast_driver/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FastDriver uses the shared brand theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: const Scaffold(body: Text('FastDriver')),
      ),
    );

    expect(find.text('FastDriver'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('FastDriver'))).colorScheme.primary,
      AppColors.blueDeep,
    );
  });
}
