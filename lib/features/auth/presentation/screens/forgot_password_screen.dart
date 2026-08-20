import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/language_picker.dart';
import '../providers/auth_controller.dart';

/// Requests a reset link by email. The link itself lands on the web app
/// (`/reset-password?token=…`), so there is no reset step in mobile.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _submitting = false;
  bool _sent = false;
  String? _submitError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    final error = await ref
        .read(authControllerProvider.notifier)
        .forgotPassword(_emailController.text.trim());
    if (!mounted) return;
    final t = AppLocalizations.of(context)!;
    setState(() {
      _submitting = false;
      _sent = error == null;
      if (error != null) _submitError = localizeAppException(error, t);
    });
  }

  String? _emailValidator(String? value, AppLocalizations t) {
    if (value == null || value.trim().isEmpty) return t.register_email_required;
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
    return ok ? null : t.register_email_invalid;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.forgot_title),
        actions: const [
          LanguagePickerButton(),
          SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: _sent
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Icon(
                      Icons.mark_email_read_outlined,
                      size: 56,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      t.forgot_sent_title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.forgot_sent_body(_emailController.text.trim()),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => context.goNamed(AppRoute.login),
                      child: Text(t.forgot_back_to_login),
                    ),
                  ],
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(t.forgot_subtitle, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        autofocus: true,
                        autocorrect: false,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(
                          labelText: t.register_email,
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                        validator: (v) => _emailValidator(v, t),
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (_submitError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _submitError!,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 24),
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
                            : Text(t.forgot_submit),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
