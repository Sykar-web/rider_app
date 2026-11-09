import 'package:flutter/material.dart';

const onboardingBlue = Color(0xFF00617F);
const onboardingNavy = Color(0xFF123542);

class BrandTitle extends StatelessWidget {
  final double size;
  const BrandTitle({super.key, this.size = 32});
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        const TextSpan(
          text: 'Fast',
          style: TextStyle(color: onboardingNavy),
        ),
        TextSpan(
          text: 'Driver',
          style: TextStyle(color: onboardingBlue),
        ),
      ],
    ),
    style: TextStyle(
      fontFamily: 'Asap',
      fontSize: size,
      fontWeight: FontWeight.w800,
      fontStyle: FontStyle.normal,
      letterSpacing: -1,
    ),
  );
}

class OnboardingPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? bottom;
  final bool back;
  const OnboardingPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.bottom,
    this.back = true,
  });
  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      scaffoldBackgroundColor: Colors.white,
      colorScheme: Theme.of(context).colorScheme
          .copyWith(primary: onboardingBlue),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: onboardingBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ),
    child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: back,
        foregroundColor: onboardingNavy,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                if (title == 'Create Account' || title == 'Welcome Back') ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      'assets/branding/illustrated_hero.png',
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      cacheWidth: 900,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Asap',
                    color: onboardingNavy,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF748094),
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                ...children,
                if (bottom != null) ...[const SizedBox(height: 24), bottom!],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  const PasswordField({
    super.key,
    required this.controller,
    this.hint = 'Password',
    this.validator,
  });
  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool hidden = true;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    obscureText: hidden,
    validator: widget.validator,
    autofillHints: [
      widget.hint == 'Password'
          ? AutofillHints.password
          : AutofillHints.newPassword,
    ],
    decoration: InputDecoration(
      hintText: widget.hint,
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        tooltip: hidden ? 'Show password' : 'Hide password',
        onPressed: () => setState(() => hidden = !hidden),
        icon: Icon(
          hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
      ),
    ),
  );
}

class SocialButtons extends StatelessWidget {
  final void Function(String) onPressed;
  final bool busy;
  const SocialButtons({super.key, required this.onPressed, this.busy = false});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 20),
      const Text(
        'or continue with',
        style: TextStyle(color: Color(0xFF748094), fontSize: 13),
      ),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final provider in ['Google', 'Apple'])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: OutlinedButton(
                onPressed: busy ? null : () => onPressed(provider),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(96, 52),
                  side: const BorderSide(color: Color(0xFFE8ECF2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: provider == 'Apple'
                    ? const Icon(Icons.apple, color: Colors.black, size: 28)
                    : const Text(
                        'G',
                        semanticsLabel: 'Continue with Google',
                        style: TextStyle(
                          color: Color(0xFF4285F4),
                          fontSize: 27,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
        ],
      ),
    ],
  );
}

/// Bundled cartoon artwork stays crisp without a remote image dependency.
class DriverIllustration extends StatelessWidget {
  const DriverIllustration({super.key});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: Image.asset(
      'assets/branding/illustrated_hero.png',
      height: 230,
      width: double.infinity,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      cacheWidth: (480 * MediaQuery.devicePixelRatioOf(context)).round().clamp(
        720,
        2048,
      ),
    ),
  );
}
