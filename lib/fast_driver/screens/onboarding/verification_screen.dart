import 'package:flutter/material.dart';

import 'driver_application_form.dart';

/// Compatibility route for older navigation links.
class VerificationScreen extends StatelessWidget {
  const VerificationScreen({super.key});
  @override
  Widget build(BuildContext context) => const DriverApplicationForm();
}
