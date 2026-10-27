import 'package:flutter/material.dart';

const onboardingBlue = Color(0xFF0085FF);
const onboardingNavy = Color(0xFF14254B);

class BrandTitle extends StatelessWidget {
  final double size;
  const BrandTitle({super.key, this.size = 32});
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        const TextSpan(
          text: 'Fast ',
          style: TextStyle(color: onboardingNavy),
        ),
        TextSpan(
          text: 'Driver',
          style: TextStyle(color: onboardingBlue),
        ),
      ],
    ),
    style: TextStyle(
      fontFamily: 'Manrope',
      fontSize: size,
      fontWeight: FontWeight.w800,
      fontStyle: FontStyle.italic,
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
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
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

/// Vector artwork scales cleanly without relying on remote image loading.
class DriverIllustration extends StatelessWidget {
  const DriverIllustration({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 245,
    child: CustomPaint(size: const Size(360, 245), painter: _DriverPainter()),
  );
}

class _DriverPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 360, size.height / 245);
    final paint = Paint();
    paint.color = const Color(0xFFEAF7FF);
    canvas.drawCircle(const Offset(180, 126), 110, paint);
    for (var i = 0; i < 7; i++) {
      paint.color = i.isEven
          ? const Color(0xFFB7E6FF)
          : const Color(0xFFD5F0FF);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(42 + i * 40, 125 - (i % 3) * 24, 29, 95 + (i % 3) * 24),
          const Radius.circular(3),
        ),
        paint,
      );
    }
    paint.color = const Color(0xFFDCEBF4);
    canvas.drawOval(const Rect.fromLTWH(28, 215, 306, 15), paint);
    paint.color = onboardingBlue;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(45, 155, 249, 57),
        const Radius.circular(19),
      ),
      paint,
    );
    final roof = Path()
      ..moveTo(89, 157)
      ..lineTo(116, 117)
      ..quadraticBezierTo(122, 110, 141, 110)
      ..lineTo(207, 110)
      ..quadraticBezierTo(225, 110, 234, 128)
      ..lineTo(253, 159)
      ..close();
    canvas.drawPath(roof, paint);
    paint.color = const Color(0xFFD9F3FF);
    canvas.drawPath(
      Path()
        ..moveTo(106, 153)
        ..lineTo(128, 121)
        ..lineTo(165, 121)
        ..lineTo(165, 153)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(175, 121)
        ..lineTo(207, 121)
        ..lineTo(232, 153)
        ..lineTo(175, 153)
        ..close(),
      paint,
    );
    for (final x in [96.0, 247.0]) {
      paint.color = onboardingNavy;
      canvas.drawCircle(Offset(x, 210), 21, paint);
      paint.color = const Color(0xFFD7E2EF);
      canvas.drawCircle(Offset(x, 210), 11, paint);
    }
    paint.color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(51, 172, 27, 11),
        const Radius.circular(5),
      ),
      paint,
    );
    paint.color = onboardingNavy;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(264, 174, 14, 45),
        const Radius.circular(6),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(286, 174, 14, 45),
        const Radius.circular(6),
      ),
      paint,
    );
    paint.color = const Color(0xFF42A8FF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(256, 125, 49, 59),
        const Radius.circular(12),
      ),
      paint,
    );
    paint.color = const Color(0xFFC78D65);
    canvas.drawCircle(const Offset(281, 110), 15, paint);
    paint.color = onboardingNavy;
    canvas.drawArc(
      const Rect.fromLTWH(266, 94, 30, 28),
      3.14,
      3.14,
      true,
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
