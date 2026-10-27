import 'package:flutter/material.dart';

import 'home/booking_shell.dart';

/// FastRide is the passenger and sender app. Driver operations live only in
/// the separate FastDriver application.
class HomeRouter extends StatelessWidget {
  const HomeRouter({super.key});

  @override
  Widget build(BuildContext context) => const BookingShell();
}
