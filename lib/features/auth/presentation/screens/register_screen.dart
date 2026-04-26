import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/router/routes.dart';
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
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      setState(() => _submitError = 'Please accept the terms to continue.');
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
        const SnackBar(
          content: Text(
            'Account created. Check your email to verify, then log in.',
          ),
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

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
    return ok ? null : 'Enter a valid email';
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Create your account')),
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
                    labelText: 'Full name',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    errorText: _fieldErrors['complete_name'],
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixIcon: const Icon(Icons.person_outline),
                    errorText: _fieldErrors['username'],
                  ),
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'Username must be at least 3 characters'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    errorText: _fieldErrors['email'],
                  ),
                  validator: _emailValidator,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    errorText: _fieldErrors['password'],
                  ),
                  validator: _passwordValidator,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
                    prefixIcon: Icon(Icons.lock_reset_outlined),
                  ),
                  validator: (v) =>
                      v != _passwordController.text ? 'Passwords do not match' : null,
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
                        'I accept the terms and privacy policy.',
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
                      : const Text('Create account'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.goNamed(AppRoute.login),
                  child: const Text('I already have an account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
