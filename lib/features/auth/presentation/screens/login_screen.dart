import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/env.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/router/routes.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/language_picker.dart';
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
    final t = AppLocalizations.of(context)!;
    setState(() {
      _submitting = false;
      if (error != null) {
        _submitError = _describe(error, t);
        if (error is ValidationException) {
          _fieldErrors = error.fieldErrors;
        }
      }
    });
  }

  Future<void> _signInWithGoogle() async {
    final t = AppLocalizations.of(context)!;
    if (!Env.isGoogleSignInConfigured) {
      setState(() {
        _submitError = t.login_google_not_configured;
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
      final t2 = AppLocalizations.of(context)!;
      setState(() {
        _googleSubmitting = false;
        if (retryError != null && retryError is! GoogleSignInCancelledException) {
          _submitError = _describe(retryError, t2);
          if (retryError is ValidationException) {
            _fieldErrors = retryError.fieldErrors;
          }
        }
      });
      return;
    }

    setState(() {
      _googleSubmitting = false;
      _submitError = _describe(error, t);
      if (error is ValidationException) {
        _fieldErrors = error.fieldErrors;
      }
    });
  }

  Future<String?> _promptForGoogleUsername({String? suggested}) {
    final t = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: suggested ?? '');
    final formKey = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(t.login_pick_username_title),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.login_pick_username_body),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: t.login_username,
                    prefixIcon: const Icon(Icons.alternate_email),
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return t.login_pick_username_required;
                    if (v.length < 3) return t.login_pick_username_min;
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
              child: Text(t.common_cancel),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(controller.text.trim());
                }
              },
              child: Text(t.common_continue),
            ),
          ],
        );
      },
    );
  }

  String _describe(AppException e, AppLocalizations t) =>
      localizeAppException(e, t);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        actions: const [
          LanguagePickerButton(),
          SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.login_title, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  t.login_subtitle,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.username],
                  decoration: InputDecoration(
                    labelText: t.login_username,
                    prefixIcon: const Icon(Icons.person_outline),
                    errorText: _fieldErrors['username'],
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return t.login_username_required;
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
                    labelText: t.login_password,
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
                      return t.login_password_required;
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
                    child: Text(t.login_forgot),
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
                      : Text(t.login_submit),
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
                        ? t.login_google_connecting
                        : t.login_google,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      t.login_no_account,
                      style: theme.textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () => context.goNamed(AppRoute.register),
                      child: Text(t.login_sign_up),
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
