import 'package:flutter/material.dart';

import '../widgets/onboarding_widgets.dart';

/// Branding stays visible while AppStartup handles initialization and recovery.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFBEEBFF), Color(0xFFF5FCFF), Color(0xFFB8E7FC)],
        ),
      ),
      child: SizedBox.expand(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'assets/icon/app_icon_foreground.png',
                        width: 132,
                        height: 132,
                        cacheWidth: 396,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.local_taxi_rounded,
                          size: 132,
                          color: onboardingBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const BrandTitle(size: 38),
                    const SizedBox(height: 8),
                    const Text(
                      'Drive. Earn. Move.',
                      style: TextStyle(fontSize: 18, color: onboardingNavy),
                    ),
                    const SizedBox(height: 32),
                    if (message == null)
                      const SizedBox(
                        width: 110,
                        child: LinearProgressIndicator(
                          minHeight: 4,
                          color: onboardingBlue,
                          backgroundColor: Color(0xFFB9E4FA),
                        ),
                      )
                    else ...[
                      Text(
                        message!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: onboardingNavy),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: onRetry,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
