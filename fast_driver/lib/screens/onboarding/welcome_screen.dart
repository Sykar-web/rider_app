import 'package:flutter/material.dart';

import '../../widgets/onboarding_widgets.dart';
import '../auth/login_screen.dart';
import '../auth/signup_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) => OnboardingPage(
    title: '',
    back: false,
    children: [
      const Center(child: BrandTitle()),
      const SizedBox(height: 6),
      const Text('Drive. Earn. Move.', textAlign: TextAlign.center),
      const SizedBox(height: 24),
      const DriverIllustration(),
      const SizedBox(height: 28),
      for (final benefit in [
        'Flexible working hours',
        'Earn on your own schedule',
        'Be part of a safer community',
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: onboardingBlue, size: 23),
              const SizedBox(width: 12),
              Expanded(child: Text(benefit)),
            ],
          ),
        ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SignUpScreen())),
        child: const Text('Get Started'),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Already have an account?',
            style: TextStyle(fontSize: 13),
          ),
          TextButton(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const LoginScreen())),
            child: const Text('Login'),
          ),
        ],
      ),
    ],
  );
}
