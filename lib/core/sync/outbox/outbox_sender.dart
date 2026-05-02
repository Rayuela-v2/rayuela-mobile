import '../../error/app_exception.dart';
import 'outbox_entry.dart';

/// Outcome the [OutboxService] needs from one delivery attempt.
sealed class OutboxSendOutcome {
  const OutboxSendOutcome();
}

/// The backend accepted the row. The drainer deletes the local copy.
class OutboxSendSucceeded extends OutboxSendOutcome {
  const OutboxSendSucceeded();
}

/// The backend already has this row (HTTP 409 with the row's
/// idempotency key). Equivalent to success from the user's POV.
class OutboxSendAlreadyExists extends OutboxSendOutcome {
  const OutboxSendAlreadyExists();
}

/// The attempt failed but should be retried later. The drainer applies
/// the configured backoff and bumps `attempt_count`.
class OutboxSendRetryable extends OutboxSendOutcome {
  const OutboxSendRetryable({required this.code, required this.message});
  final String code;
  final String message;
}

/// The attempt failed in a way no retry can fix (validation, unknown
/// resource, …). The drainer marks the row `dead`.
class OutboxSendPermanent extends OutboxSendOutcome {
  const OutboxSendPermanent({required this.code, required this.message});
  final String code;
  final String message;
}

/// Bridge between [OutboxService] (in `core/`) and the feature-level
/// remote source that knows how to translate an [OutboxEntry] into an
/// HTTP call (`POST /checkin` for the check-in outbox).
///
/// Defining the interface in `core/` keeps the sync subsystem free of
/// feature dependencies; the concrete implementation lives in
/// `features/checkin/` and is wired in `bootstrap.dart`.
abstract class OutboxSender {
  Future<OutboxSendOutcome> send(OutboxEntry entry);
}

/// Default classifier from [AppException] → [OutboxSendOutcome]. Each
/// sender can reuse this so the policy stays in one place.
OutboxSendOutcome classifyAppException(AppException e) {
  if (e is ConflictException) return const OutboxSendAlreadyExists();
  if (e is NetworkException || e is TimeoutException) {
    return OutboxSendRetryable(
      code: e.runtimeType.toString(),
      message: e.message,
    );
  }
  if (e is ServerException) {
    final status = e.statusCode ?? 0;
    if (status >= 500 || status == 429 || status == 0) {
      return OutboxSendRetryable(code: 'http_$status', message: e.message);
    }
    return OutboxSendPermanent(code: 'http_$status', message: e.message);
  }
  if (e is UnauthorizedException) {
    // The refresh interceptor already tried to recover. Marking the row
    // `dead` avoids retry storms while logged out; the user can
    // discard or re-attempt manually after re-authenticating.
    return OutboxSendPermanent(code: 'unauthorized', message: e.message);
  }
  if (e is ForbiddenException || e is NotFoundException) {
    return OutboxSendPermanent(
      code: e.runtimeType.toString(),
      message: e.message,
    );
  }
  if (e is ValidationException) {
    return OutboxSendPermanent(code: 'validation', message: e.message);
  }
  // Unknown / unmapped: be conservative and retry. The configured
  // backoff caps the number of attempts before sending it to `dead`.
  return OutboxSendRetryable(code: 'unknown', message: e.message);
}
