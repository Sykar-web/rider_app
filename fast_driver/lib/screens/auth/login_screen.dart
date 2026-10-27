import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../../widgets/onboarding_widgets.dart';
import 'signup_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) => const AccountScreen(signUp: false);
}

class AccountScreen extends StatefulWidget {
  final bool signUp;
  const AccountScreen({super.key, required this.signUp});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  StreamSubscription<AuthState>? authSubscription;
  @override
  void initState() {
    super.initState();
    authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (mounted &&
          (state.event == AuthChangeEvent.signedIn ||
              state.event == AuthChangeEvent.passwordRecovery)) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  bool busy = false;
  String? error;
  @override
  void dispose() {
    authSubscription?.cancel();
    for (final controller in [name, phone, email, password, confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (widget.signUp) {
        final response = await AuthService().signUp(
          email: email.text.trim(),
          password: password.text,
          fullName: name.text.trim(),
          phone: phone.text.trim(),
        );
        if (!mounted) return;
        if (response.session == null) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Confirm your email'),
              content: const Text(
                'Open the confirmation link in your email, then log in to upload your documents and add your vehicle.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        await AuthService().signIn(
          email: email.text.trim(),
          password: password.text,
        );
      }
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Unable to connect. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> social(String provider) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final launched = await AuthService().signInWithProvider(provider);
      if (!launched && mounted) {
        setState(() => error = 'Could not open $provider sign-in.');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              '$provider sign-in is unavailable. Please use email or try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resetPassword() async {
    final address = email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(address)) {
      setState(
        () =>
            error = 'Enter your email above to receive a password reset link.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(address);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check your email for a password reset link.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not send the reset email. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OnboardingPage(
    title: widget.signUp ? 'Create Account' : 'Welcome Back',
    subtitle: widget.signUp
        ? 'Join Fast Driver and start earning'
        : 'Sign in to your account',
    children: [
      Form(
        key: form,
        child: Column(
          children: [
            if (widget.signUp) ...[
              TextFormField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  hintText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Enter your full name'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: const InputDecoration(
                  hintText: 'Phone number (+256...)',
                  prefixIcon: Icon(Icons.phone_android),
                ),
                validator: (v) =>
                    !RegExp(r'^\+?[0-9\s]{9,16}$').hasMatch(v?.trim() ?? '')
                    ? 'Enter a valid phone number'
                    : null,
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                hintText: 'Email address',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (v) =>
                  !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                      .hasMatch(v?.trim() ?? '')
                  ? 'Enter a valid email address'
                  : null,
            ),
            const SizedBox(height: 14),
            PasswordField(
              controller: password,
              validator: (v) =>
                  (v?.length ?? 0) < 6 ? 'Use at least 6 characters' : null,
            ),
            if (widget.signUp) ...[
              const SizedBox(height: 14),
              PasswordField(
                controller: confirm,
                hint: 'Confirm password',
                validator: (v) =>
                    v != password.text ? 'Passwords do not match' : null,
              ),
            ] else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: busy ? null : resetPassword,
                  child: const Text('Forgot password?'),
                ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.red),
                  semanticsLabel: error,
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy ? null : submit,
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(widget.signUp ? 'Sign Up' : 'Login'),
            ),
            SocialButtons(onPressed: social, busy: busy),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  widget.signUp
                      ? 'Already have an account?'
                      : "Don't have an account?",
                  style: const TextStyle(fontSize: 13),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => widget.signUp
                                  ? const LoginScreen()
                                  : const SignUpScreen(),
                            ),
                          );
                        },
                  child: Text(widget.signUp ? 'Login' : 'Sign Up'),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}
