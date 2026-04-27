import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/env.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/router/routes.dart';
import '../providers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  bool _googleSubmitting = false;
  bool _obscure = true;
  String? _submitError;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _submitError = null;
      _fieldErrors = const {};
    });
    final error = await ref.read(authControllerProvider.notifier).login(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (error != null) {
        _submitError = _describe(error);
        if (error is ValidationException) {
          _fieldErrors = error.fieldErrors;
        }
      }
    });
  }

  Future<void> _signInWithGoogle() async {
    if (!Env.isGoogleSignInConfigured) {
      setState(() {
        _submitError =
            'Google sign-in is not configured for this build. Pass GOOGLE_CLIENT_ID_WEB (and GOOGLE_CLIENT_ID_IOS on iOS) via --dart-define-from-file=.env.development.';
      });
      return;
    }

    setState(() {
      _googleSubmitting = true;
      _submitError = null;
      _fieldErrors = const {};
    });

    final controller = ref.read(authControllerProvider.notifier);
    final error = await controller.loginWithGoogle();
    if (!mounted) return;

    if (error == null) {
      // Authenticated. The router listens to authControllerProvider and
      // will redirect away from /login on its own.
      setState(() => _googleSubmitting = false);
      return;
    }

    if (error is GoogleSignInCancelledException) {
      // User dismissed the sheet — don't show a noisy banner.
      setState(() => _googleSubmitting = false);
      return;
    }

    if (error is GoogleSignupRequiresUsernameException) {
      final username = await _promptForGoogleUsername(
        suggested: error.suggestedUsername,
      );
      if (!mounted) return;
      if (username == null || username.isEmpty) {
        setState(() => _googleSubmitting = false);
        return;
      }
      final retryError =
          await controller.completeGoogleSignup(username: username);
      if (!mounted) return;
      setState(() {
        _googleSubmitting = false;
        if (retryError != null && retryError is! GoogleSignInCancelledException) {
          _submitError = _describe(retryError);
          if (retryError is ValidationException) {
            _fieldErrors = retryError.fieldErrors;
          }
        }
      });
      return;
    }

    setState(() {
      _googleSubmitting = false;
      _submitError = _describe(error);
      if (error is ValidationException) {
        _fieldErrors = error.fieldErrors;
      }
    });
  }

  Future<String?> _promptForGoogleUsername({String? suggested}) {
    final controller = TextEditingController(text: suggested ?? '');
    final formKey = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Pick a username'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "We didn't find a Rayuela account for this Google "
                  'profile yet. Choose a username to finish signing up.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Pick a username to continue';
                    if (v.length < 3) return 'At least 3 characters';
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (formKey.currentState!.validate()) {
                      Navigator.of(ctx).pop(controller.text.trim());
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(controller.text.trim());
                }
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  String _describe(AppException e) => switch (e) {
        UnauthorizedException() => 'Invalid username or password.',
        NetworkException() => 'No internet connection.',
        TimeoutException() => 'Server is slow to respond. Try again.',
        AppException(:final message) => message,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Welcome back', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Log in to keep contributing to citizen science.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.username],
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixIcon: const Icon(Icons.person_outline),
                    errorText: _fieldErrors['username'],
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter your username';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                    errorText: _fieldErrors['password'],
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter your password';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _submitting
                        ? null
                        : () {
                            // TODO(phase1): push ForgotPasswordScreen.
                          },
                    child: const Text('Forgot password?'),
                  ),
                ),
                if (_submitError != null) ...[
                  const SizedBox(height: 4),
                  _ErrorBanner(message: _submitError!),
                  const SizedBox(height: 16),
                ] else
                  const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Log in'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: (_submitting || _googleSubmitting)
                      ? null
                      : _signInWithGoogle,
                  icon: _googleSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.g_mobiledata),
                  label: Text(
                    _googleSubmitting
                        ? 'Connecting to Google\u2026'
                        : 'Continue with Google',
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?",
                      style: theme.textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () => context.goNamed(AppRoute.register),
                      child: const Text('Sign up'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
