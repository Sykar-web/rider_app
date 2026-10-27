import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

const authTitleStyle = TextStyle(
  fontFamily: 'Manrope',
  fontWeight: FontWeight.w800,
  fontSize: 26,
  letterSpacing: -.8,
  color: AppColors.navy,
);

class AuthHero extends StatelessWidget {
  const AuthHero({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 288,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/branding/home_hero.png', fit: BoxFit.cover),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xCC007BFF), Color(0x660066FF), Color(0x000066FF)],
            ),
          ),
        ),
        Positioned(
          top: 22,
          left: 16,
          right: 16,
          child: Column(
            children: [
              Image.asset(
                'assets/icon/app_icon_foreground.png',
                width: 70,
                height: 70,
              ),
              const SizedBox(height: 4),
              const Text(
                'FastRide',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Move Safe, Move Fast',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.onToggleVisibility,
    this.autofillHints,
    this.textInputAction,
    this.onFieldSubmitted,
  });
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final VoidCallback? onToggleVisibility;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      autofillHints: autofillHints,
      autocorrect: false,
      enableSuggestions: onToggleVisibility == null,
      textInputAction: textInputAction ?? TextInputAction.next,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
        prefixIcon: Icon(icon, size: 22, color: const Color(0xFF616889)),
        suffixIcon: onToggleVisibility == null
            ? null
            : IconButton(
                tooltip: obscureText ? 'Show password' : 'Hide password',
                onPressed: onToggleVisibility,
                icon: Icon(
                  obscureText
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 21,
                  color: const Color(0xFF616889),
                ),
              ),
      ),
    ),
  );
}

class AuthSubmit extends StatelessWidget {
  const AuthSubmit({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });
  final String label;
  final bool busy;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
    child: busy
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 17),
                ),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.arrow_forward_rounded),
            ],
          ),
  );
}

class AuthGoogleButton extends StatelessWidget {
  const AuthGoogleButton({
    super.key,
    required this.busy,
    required this.onPressed,
  });
  final bool busy;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Row(
          children: [
            Expanded(child: Divider()),
            Flexible(
              flex: 4,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Or continue with',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            ),
            Expanded(child: Divider()),
          ],
        ),
      ),
      OutlinedButton(
        onPressed: busy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: AppColors.hairline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              const SizedBox(
                width: 21,
                height: 21,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const CustomPaint(size: Size(23, 23), painter: _GoogleMark()),
            const SizedBox(width: 12),
            const Flexible(
              child: Text(
                'Continue with Google',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 15,
                  color: AppColors.navy,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _GoogleMark extends CustomPainter {
  const _GoogleMark();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(3, 3, size.width - 6, size.height - 6);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5;
    for (final segment in <(double, double, Color)>[
      (-45, -90, const Color(0xFFEA4335)),
      (-135, -60, const Color(0xFFFBBC05)),
      (-195, -90, const Color(0xFF34A853)),
      (75, -75, const Color(0xFF4285F4)),
    ]) {
      canvas.drawArc(
        rect,
        segment.$1 * math.pi / 180,
        segment.$2 * math.pi / 180,
        false,
        paint..color = segment.$3,
      );
    }
    canvas.drawLine(
      Offset(size.width / 2, size.height / 2),
      Offset(size.width - 1, size.height / 2),
      paint..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AuthError extends StatelessWidget {
  const AuthError(this.message, {super.key});
  final String? message;
  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Semantics(
            liveRegion: true,
            child: Text(
              message!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        );
}
