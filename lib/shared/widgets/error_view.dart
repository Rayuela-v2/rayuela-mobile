import 'package:flutter/material.dart';

import '../../core/error/app_exception.dart';
import '../../l10n/app_localizations.dart';

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
    final t = AppLocalizations.of(context)!;
    final message = error is AppException
        ? localizeAppException(error as AppException, t, longForm: true)
        : error.toString();

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
              label: Text(t.common_retry),
            ),
          ],
        ],
      ),
    );
  }
}

/// Converts an [AppException] to a user-friendly localized string.
///
/// Pass [longForm] when displaying the message in a full error view (where we
/// can afford a second sentence, like "Check your signal and retry.").
String localizeAppException(
  AppException e,
  AppLocalizations t, {
  bool longForm = false,
}) {
  return switch (e) {
    NetworkException() =>
      longForm ? t.error_no_internet_long : t.error_no_internet,
    TimeoutException() => t.error_timeout,
    UnauthorizedException() => t.error_unauthorized,
    ServerException(:final statusCode) => statusCode == null
        ? t.error_server_no_code
        : t.error_server_with_code(statusCode),
    ValidationException(:final message) => message,
    GoogleSignInCancelledException() => '',
    GoogleSignupRequiresUsernameException(:final message) => message,
    NotFoundException(:final message) => message,
    ForbiddenException(:final message) => message,
    ConflictException(:final message) => message,
    UnknownException(:final message) => message,
  };
}
