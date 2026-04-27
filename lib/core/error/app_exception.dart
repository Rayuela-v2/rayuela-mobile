/// Typed exception hierarchy used across the app.
///
/// Everything the UI sees is one of these. Repositories never leak
/// Dio or platform-specific errors.
sealed class AppException implements Exception {
  const AppException({required this.message, this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType($message)';
}

class NetworkException extends AppException {
  const NetworkException({
    String message = 'No internet connection',
    super.cause,
  }) : super(message: message);
}

class TimeoutException extends AppException {
  const TimeoutException({
    String message = 'The server took too long to respond',
    super.cause,
  }) : super(message: message);
}

class UnauthorizedException extends AppException {
  const UnauthorizedException({
    String message = 'You need to log in to continue',
    super.cause,
  }) : super(message: message);
}

class ForbiddenException extends AppException {
  const ForbiddenException({
    String message = 'You do not have permission to do that',
    super.cause,
  }) : super(message: message);
}

class NotFoundException extends AppException {
  const NotFoundException({
    String message = 'Not found',
    super.cause,
  }) : super(message: message);
}

class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    this.fieldErrors = const {},
    super.cause,
  });

  /// Map of field name → error message, ready to surface under form inputs.
  final Map<String, String> fieldErrors;
}

class ServerException extends AppException {
  const ServerException({
    String message = 'Something went wrong on our side',
    this.statusCode,
    super.cause,
  }) : super(message: message);

  final int? statusCode;
}

/// Surfaced by `POST /auth/google` when the Google account has no matching
/// Rayuela user yet. The UI should collect a username from the user and
/// retry the call.
class GoogleSignupRequiresUsernameException extends AppException {
  const GoogleSignupRequiresUsernameException({
    String message = 'Username is required for new Google signup',
    this.suggestedUsername,
    super.cause,
  }) : super(message: message);

  final String? suggestedUsername;
}

/// Surfaced when the user dismisses the native Google sign-in sheet.
/// Different from a real error; UIs typically just stop loading silently.
class GoogleSignInCancelledException extends AppException {
  const GoogleSignInCancelledException()
      : super(message: 'Google sign-in was cancelled');
}

class UnknownException extends AppException {
  const UnknownException({
    String message = 'Unexpected error',
    super.cause,
  }) : super(message: message);
}
