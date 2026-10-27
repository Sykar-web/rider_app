import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/onboarding_widgets.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final form = GlobalKey<FormState>();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password.text),
      );
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not update your password. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OnboardingPage(
    title: 'Reset Password',
    back: false,
    subtitle: 'Choose a new password for your account',
    children: [
      Form(
        key: form,
        child: Column(
          children: [
            PasswordField(
              controller: password,
              validator: (v) =>
                  (v?.length ?? 0) < 6 ? 'Use at least 6 characters' : null,
            ),
            const SizedBox(height: 16),
            PasswordField(
              controller: confirmation,
              hint: 'Confirm password',
              validator: (v) =>
                  v != password.text ? 'Passwords do not match' : null,
            ),
            const SizedBox(height: 24),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(busy ? 'Saving...' : 'Save Password'),
            ),
          ],
        ),
      ),
    ],
  );
}
