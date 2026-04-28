import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/router/routes.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/language_picker.dart';
import '../providers/auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _submitting = false;
  bool _acceptedTerms = false;
  String? _submitError;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      setState(() => _submitError = t.register_must_accept_terms);
      return;
    }
    setState(() {
      _submitting = true;
      _submitError = null;
      _fieldErrors = const {};
    });
    final error = await ref.read(authControllerProvider.notifier).register(
          completeName: _nameController.text.trim(),
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    if (!mounted) return;
    if (error == null) {
      // Registration succeeded; fall back to login. Email verification
      // happens out-of-band.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.register_success_snackbar),
        ),
      );
      context.goNamed(AppRoute.login);
      return;
    }
    setState(() {
      _submitting = false;
      _submitError = error.message;
      if (error is ValidationException) {
        _fieldErrors = error.fieldErrors;
      }
    });
  }

  String? _emailValidator(String? value, AppLocalizations t) {
    if (value == null || value.trim().isEmpty) return t.register_email_required;
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
    return ok ? null : t.register_email_invalid;
  }

  String? _passwordValidator(String? value, AppLocalizations t) {
    if (value == null || value.length < 8) {
      return t.register_password_min;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.register_title),
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
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: t.register_full_name,
                    prefixIcon: const Icon(Icons.badge_outlined),
                    errorText: _fieldErrors['complete_name'],
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? t.register_full_name_required
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: t.login_username,
                    prefixIcon: const Icon(Icons.person_outline),
                    errorText: _fieldErrors['username'],
                  ),
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? t.register_username_min
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: t.register_email,
                    prefixIcon: const Icon(Icons.email_outlined),
                    errorText: _fieldErrors['email'],
                  ),
                  validator: (v) => _emailValidator(v, t),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: t.login_password,
                    prefixIcon: const Icon(Icons.lock_outline),
                    errorText: _fieldErrors['password'],
                  ),
                  validator: (v) => _passwordValidator(v, t),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: t.register_confirm_password,
                    prefixIcon: const Icon(Icons.lock_reset_outlined),
                  ),
                  validator: (v) => v != _passwordController.text
                      ? t.register_passwords_no_match
                      : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: _acceptedTerms,
                      onChanged: (v) =>
                          setState(() => _acceptedTerms = v ?? false),
                    ),
                    Expanded(
                      child: Text(
                        t.register_accept_terms,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                if (_submitError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _submitError!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
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
                      : Text(t.register_submit),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.goNamed(AppRoute.login),
                  child: Text(t.register_have_account),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
