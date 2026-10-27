import 'package:flutter/services.dart';
import 'package:fast_driver/app/theme.dart';
import 'package:fast_driver/screens/onboarding/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async => call.method == 'getAll' ? <String, Object>{} : true,
        );
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
      ),
    );
  });
  tearDownAll(() async {
    await Supabase.instance.dispose();
  });
  testWidgets('Welcome leads to signup and validates account details', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.theme, home: const WelcomeScreen()),
    );
    await tester.scrollUntilVisible(
      find.text('Get Started'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('Create Account'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign Up'));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign Up'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your full name'), findsOneWidget);
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login is reachable from welcome', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.theme, home: const WelcomeScreen()),
    );
    await tester.scrollUntilVisible(
      find.text('Login'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
