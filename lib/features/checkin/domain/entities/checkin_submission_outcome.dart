import '../../../../core/error/app_exception.dart';
import 'checkin_result.dart';

/// What [CheckinsRepository.submitCheckin] returns to the UI.
///
/// Three outcomes:
///   * [CheckinSubmissionAccepted] — backend processed the check-in
///     synchronously and returned the gamification verdict. UI navigates
///     to the reward screen.
///   * [CheckinSubmissionQueued]  — the device is offline (or the
///     outbox already had pending rows we didn't want to skip past).
///     The submission is durably persisted and will be sent later. UI
///     navigates to the reward screen in "pending" mode.
///   * [CheckinSubmissionRejected] — the backend refused the submission
///     for a reason we can't recover from automatically (validation
///     error, forbidden, …). UI surfaces the error inline.
sealed class CheckinSubmissionOutcome {
  const CheckinSubmissionOutcome();
}

class CheckinSubmissionAccepted extends CheckinSubmissionOutcome {
  const CheckinSubmissionAccepted(this.result);
  final CheckinResult result;
}

class CheckinSubmissionQueued extends CheckinSubmissionOutcome {
  const CheckinSubmissionQueued({
    required this.outboxId,
    required this.queuedAt,
  });

  /// Lets the UI re-locate the entry in the "Pending data" list.
  final String outboxId;
  final DateTime queuedAt;
}

class CheckinSubmissionRejected extends CheckinSubmissionOutcome {
  const CheckinSubmissionRejected(this.error);
  final AppException error;
}
