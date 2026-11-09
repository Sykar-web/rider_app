import 'package:flutter/material.dart';

class HomeRideHero extends StatelessWidget {
  const HomeRideHero({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 300,
    child: ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: Image.asset(
        'assets/branding/illustrated_local.png',
        fit: BoxFit.cover,
        alignment: const Alignment(.65, 0),
        filterQuality: FilterQuality.high,
        semanticLabel:
            'A boda driver carrying a passenger, both wearing helmets',
      ),
    ),
  );
}
