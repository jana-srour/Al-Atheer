import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_strings.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSignUp = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.red.shade700
            : const Color(0xFF0F172A),
      ),
    );
  }

  void _finishSignIn() {
    if (!mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final error = _isSignUp
        ? await auth.signUp(
            email,
            password,
            displayName: _displayNameController.text.trim(),
          )
        : await auth.signIn(email, password);

    if (!mounted) return;
    if (error != null) {
      _showMessage(error, isError: true);
      return;
    }

    if (_isSignUp && !auth.isAuthenticated) {
      _showMessage(
        AppStrings.of(context).text('check_email'),
      );
      setState(() => _isSignUp = false);
      return;
    }

    final welcome = AppStrings.of(context).text('signed_in');
    _finishSignIn();
    _showMessage(welcome);
  }

  Future<void> _showForgotPasswordDialog() async {
    final initialEmail = _emailController.text.trim();
    final emailController = TextEditingController(text: initialEmail);
    final formKey = GlobalKey<FormState>();

    if (!mounted) return;

    final strings = AppStrings.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.text('reset_password')),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: strings.text('account_email'),
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) => value == null || !value.contains('@')
                ? strings.text('valid_email')
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(strings.text('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final emailToSend = emailController.text.trim();
              final auth = context.read<AuthProvider>();

              final error = await auth.sendPasswordReset(
                emailToSend,
                redirectTo: kIsWeb
                    ? Uri.base.origin
                    : 'al-atheer://reset-password',
              );

              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);

              if (!mounted) return;
              _showMessage(
                error ??
                    strings.text('reset_sent'),
                isError: error != null,
              );
            },
            child: Text(strings.text('send_reset')),
          ),
        ],
      ),
    );
    // Removed manual emailController.dispose() to fix the race condition crash during dialog unmount/rebuilds.
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    const radiantGold = Color(0xFFF59E0B);
    const deepNavy = Color(0xFF0F172A);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.text('account_title'))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: radiantGold.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF1E293B), deepNavy]
                        : [Colors.white, const Color(0xFFF8FAFC)],
                  ),
                ),
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: deepNavy,
                          border: Border.all(color: radiantGold, width: 2),
                        ),
                        child: Icon(
                          _isSignUp
                              ? Icons.person_add_alt_1_rounded
                              : Icons.account_circle_outlined,
                          size: 44,
                          color: radiantGold,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _isSignUp
                            ? strings.text('create_account')
                            : strings.text('sign_in'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isSignUp
                            ? strings.text('sign_up_desc')
                            : strings.text('sign_in_desc'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_isSignUp) ...[
                        TextFormField(
                          controller: _displayNameController,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.name],
                          decoration: InputDecoration(
                            labelText: strings.text('your_name'),
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            final name = value?.trim() ?? '';
                            if (_isSignUp && name.isEmpty) {
                              return strings.text('name_required');
                            }
                            if (name.length > 80) {
                              return 'Use 80 characters or fewer';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(
                          labelText: strings.text('account_email'),
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) =>
                            value == null || !value.trim().contains('@')
                            ? strings.text('valid_email')
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autofillHints: [
                          _isSignUp
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        decoration: InputDecoration(
                          labelText: strings.text('password'),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return strings.text('enter_password');
                          }
                          if (_isSignUp && value.length < 8) {
                            return strings.text('password_min');
                          }
                          return null;
                        },
                      ),
                      if (_isSignUp) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: strings.text('confirm_password'),
                            prefixIcon: Icon(Icons.lock_reset_outlined),
                          ),
                          validator: (value) =>
                              value != _passwordController.text
                              ? strings.text('passwords_match')
                              : null,
                        ),
                      ],
                      if (!_isSignUp)
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton(
                            onPressed: auth.isLoading
                                ? null
                                : _showForgotPasswordDialog,
                            child: Text(strings.text('forgot_password')),
                          ),
                        )
                      else
                        const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: auth.isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: deepNavy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(
                                color: radiantGold,
                                width: 1,
                              ),
                            ),
                          ),
                          child: auth.isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: radiantGold,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _isSignUp
                                      ? strings.text('create_account')
                                      : strings.text('sign_in'),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: auth.isLoading
                            ? null
                            : () => setState(() {
                                _isSignUp = !_isSignUp;
                                _formKey.currentState?.reset();
                                _confirmPasswordController.clear();
                              }),
                        child: Text(
                          _isSignUp
                              ? strings.text('already_account')
                              : strings.text('new_account'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
