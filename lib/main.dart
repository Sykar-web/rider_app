import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/connection_gate.dart';
import 'screens/home_router.dart';
import 'screens/splash_screen.dart';
import 'app_root.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const AppRoot());
}

final supabase = Supabase.instance.client;

class FastRideApp extends StatelessWidget {
  const FastRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FastRide',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      builder: (context, child) {
        if (MediaQuery.sizeOf(context).width <= 600) return child!;
        return ColoredBox(
          color: AppColors.field,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: child!,
            ),
          ),
        );
      },
      home: const SplashScreen(child: ConnectionGate(child: AuthGate())),
    );
  }
}

/// Shows login until an email or OAuth session becomes available.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Read the current session on each auth event, including sign-out.
        final session = supabase.auth.currentSession;
        return session == null ? const LoginScreen() : const HomeRouter();
      },
    );
  }
}
