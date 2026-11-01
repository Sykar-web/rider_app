import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/theme.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/onboarding/verification_screen.dart';
import 'screens/driver/driver_home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/reset_password_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FastRideDriverApp());
}

Future<void>? _initialization;

Future<void> initializeDriverApp() {
  try {
    Supabase.instance.client;
    return Future.value();
  } catch (_) {
    // Supabase not yet initialized
  }
  // Reuse in-flight work when retrying after a timeout. Future.timeout does
  // not cancel Supabase initialization, so starting a second copy is unsafe.
  return _initialization ??= _initializeServices().catchError((
    Object error,
    StackTrace stack,
  ) {
    _initialization = null;
    Error.throwWithStackTrace(error, stack);
  });
}

Future<void> _initializeServices() async {
  await dotenv.load(fileName: '.env');
  final url = dotenv.env['SUPABASE_URL']?.trim();
  final key = dotenv.env['SUPABASE_ANON_KEY']?.trim();
  final uri = url == null ? null : Uri.tryParse(url);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      key == null ||
      key.isEmpty) {
    throw const FormatException('Missing or invalid app configuration.');
  }
  await Supabase.initialize(url: url!, publishableKey: key);
}

class AppStartup extends StatefulWidget {
  const AppStartup({
    super.key,
    this.initialize,
    this.readyScreen,
    this.minimumDisplay = const Duration(milliseconds: 800),
    this.timeout = const Duration(seconds: 8),
  });

  final Future<void> Function()? initialize;
  final Widget? readyScreen;
  final Duration minimumDisplay;
  final Duration timeout;

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  Timer? _minimumTimer;
  Timer? _timeoutTimer;
  bool _minimumElapsed = false;
  bool _initialized = false;
  Object? _error;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _minimumTimer = Timer(widget.minimumDisplay, () {
      if (mounted) setState(() => _minimumElapsed = true);
    });
    _start();
  }

  void _start() {
    final attempt = ++_attempt;
    _timeoutTimer?.cancel();
    _error = null;
    _timeoutTimer = Timer(widget.timeout, () {
      if (mounted && attempt == _attempt && !_initialized) {
        setState(() => _error = TimeoutException('Startup took too long.'));
      }
    });
    // Setup runs during the animation. Keep observing after a timeout so a
    // slow startup can recover automatically, without another reload.
    Future<void>.sync(widget.initialize ?? initializeDriverApp).then(
      (_) {
        if (!mounted || attempt != _attempt) return;
        _timeoutTimer?.cancel();
        setState(() {
          _initialized = true;
          _error = null;
        });
      },
      onError: (Object error, StackTrace stack) {
        if (!mounted || attempt != _attempt) return;
        _timeoutTimer?.cancel();
        setState(() => _error = error);
      },
    );
  }

  @override
  void dispose() {
    _minimumTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initialized && _minimumElapsed) {
      return widget.readyScreen ?? const DriverAuthGate();
    }
    return SplashScreen(
      message: _error == null
          ? null
          : _error is FormatException
          ? 'FastDriver could not read its setup. Please reload the app or contact support.'
          : 'Loading is taking longer than expected. Check your internet connection and try again.',
      onRetry: _error == null ? null : () => setState(_start),
    );
  }
}

final supabase = Supabase.instance.client;

class FastRideDriverApp extends StatelessWidget {
  const FastRideDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FastDriver',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const AppStartup(),
    );
  }
}

class DriverAuthGate extends StatelessWidget {
  const DriverAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final user = supabase.auth.currentUser;
        if (user == null) return const WelcomeScreen();
        if (snapshot.data?.event == AuthChangeEvent.passwordRecovery) {
          return const ResetPasswordScreen();
        }
        // Only an administrator/server may grant driver approval.
        // Passenger logins and editable user metadata must never grant dispatch access.
        if (user.appMetadata['driver_approved'] != true) {
          return VerificationScreen(key: ValueKey(user.id));
        }
        return const DriverHomeScreen();
      },
    );
  }
}
