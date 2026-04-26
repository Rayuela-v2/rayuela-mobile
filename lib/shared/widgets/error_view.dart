import 'package:flutter/material.dart';

import '../../core/error/app_exception.dart';

/// Generic inline error UI. Use anywhere an AsyncValue.error resolves.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.error,
    this.onRetry,
  });

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = switch (error) {
      NetworkException() => 'No internet connection.\nCheck your signal and retry.',
      TimeoutException() => 'The server is slow to respond. Try again in a moment.',
      UnauthorizedException() => 'Your session expired. Please log in again.',
      ServerException(:final statusCode) =>
        'Server error${statusCode == null ? '' : ' ($statusCode)'}. Please try again.',
      ValidationException(:final message) => message,
      AppException(:final message) => message,
      _ => error.toString(),
    };

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: theme.colorScheme.error,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}
