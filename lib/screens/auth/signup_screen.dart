import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/board_widgets.dart';
import '../../services/auth_service.dart';
import 'auth_widgets.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _hidePassword = true;
  bool _hideConfirmation = true;
  String? _errorMessage;
  String get _phone =>
      '+256${_phoneController.text.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0'), '')}';
  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _emailController,
      _phoneController,
      _passwordController,
      _confirmationController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (_isLoading || _isGoogleLoading || !_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
        phone: _phone,
      );
      if (!mounted) return;
      if (response.session == null) {
        await showDialog<void>(
          context: context,
          builder: (context) => BoardDialog(
            title: const Text('Check your email'),
            content: const Text(
              'If this email is eligible, you will receive a confirmation link. Open it to verify your account, then sign in.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to login'),
              ),
            ],
          ),
        );
      }
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Unable to create your account. Check your connection and details, then try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });
    try {
      final launched = await _authService.signInWithGoogle();
      if (!launched && mounted) {
        setState(
          () => _errorMessage =
              'Could not open Google sign-in. Please try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Google sign-in failed. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Back to login',
                    onPressed: _isLoading || _isGoogleLoading
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 23,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                const Text(
                  'Create an Account',
                  style: authTitleStyle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Join FastRide and start your journey',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Image.asset(
                    'assets/branding/illustrated_hero.png',
                    width: double.infinity,
                    height: 140,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 24),
                AuthField(
                  controller: _nameController,
                  hint: 'Full name',
                  icon: Icons.person_outline_rounded,
                  autofillHints: const [AutofillHints.name],
                  validator: (v) => (v?.trim().isEmpty ?? true)
                      ? 'Enter your full name'
                      : null,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 56,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.field,
                        border: Border.all(color: AppColors.hairline),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Center(
                        child: Text(
                          'UG  +256',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: AuthField(
                        controller: _phoneController,
                        hint: 'Phone number',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        autofillHints: const [
                          AutofillHints.telephoneNumberNational,
                        ],
                        validator: (_) =>
                            RegExp(r'^\+256\d{9}$').hasMatch(_phone)
                            ? null
                            : 'Enter 9 digits, e.g. 700123456',
                      ),
                    ),
                  ],
                ),
                AuthField(
                  controller: _emailController,
                  hint: 'Email address',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: (v) =>
                      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch(v?.trim() ?? '')
                      ? null
                      : 'Enter a valid email address',
                ),
                AuthField(
                  controller: _passwordController,
                  hint: 'Create password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _hidePassword,
                  onToggleVisibility: () =>
                      setState(() => _hidePassword = !_hidePassword),
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (v) => v == null || v.length < 6
                      ? 'Use at least 6 characters'
                      : null,
                ),
                AuthField(
                  controller: _confirmationController,
                  hint: 'Confirm password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _hideConfirmation,
                  onToggleVisibility: () =>
                      setState(() => _hideConfirmation = !_hideConfirmation),
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleSignUp(),
                  validator: (v) => v == null || v.isEmpty
                      ? 'Confirm your password'
                      : v != _passwordController.text
                      ? 'Passwords do not match'
                      : null,
                ),
                const SizedBox(height: 4),
                AuthError(_errorMessage),
                AuthSubmit(
                  label: 'Create Account',
                  busy: _isLoading,
                  onPressed: _isGoogleLoading ? null : _handleSignUp,
                ),
                AuthGoogleButton(
                  busy: _isGoogleLoading,
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Already have an account?',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    TextButton(
                      onPressed: _isLoading || _isGoogleLoading
                          ? null
                          : () =>
                                Navigator.of(context)
                                    .popUntil((route) => route.isFirst),
                      child: const Text('Login'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
