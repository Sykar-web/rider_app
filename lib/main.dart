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
  try {
    await dotenv.load(fileName: '.env');
    final url = dotenv.env['SUPABASE_URL'];
    final key = dotenv.env['SUPABASE_ANON_KEY'];
    if (url == null ||
        Uri.tryParse(url)?.scheme != 'https' ||
        key == null ||
        key.isEmpty) {
      throw StateError('FastRide connection settings are missing.');
    }
    await Supabase.initialize(url: url, publishableKey: key);
    runApp(const AppRoot());
  } catch (_) {
    runApp(const _StartupProblemApp());
  }
}

final supabase = Supabase.instance.client;

class _StartupProblemApp extends StatelessWidget {
  const _StartupProblemApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.theme,
    home: const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 54,
                  color: AppColors.blueDeep,
                ),
                SizedBox(height: 16),
                Text(
                  'FastRide could not start',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 8),
                Text(
                  'Check that your connection settings are available, then close and reopen the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

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
