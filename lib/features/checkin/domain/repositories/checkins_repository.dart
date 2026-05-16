import '../../../../core/error/result.dart';
import '../entities/checkin_history_item.dart';
import '../entities/checkin_request.dart';
import '../entities/checkin_submission_outcome.dart';

abstract class CheckinsRepository {
  /// Submit a check-in.
  ///
  /// Phase 2 contract: returns one of three [CheckinSubmissionOutcome]
  /// variants instead of just a [CheckinResult]. The repository decides
  /// whether to attempt online (returning [CheckinSubmissionAccepted])
  /// or queue locally (returning [CheckinSubmissionQueued]).
  ///
  /// [CheckinSubmissionRejected] is reserved for errors the user can
  /// act on right away (validation, forbidden) — anything network-flavoured
  /// is queued automatically.
  ///
  /// Wrapped in [Result] only for callers that want a uniform error
  /// channel; the queueing path always returns `Success(...Queued)`.
  Future<Result<CheckinSubmissionOutcome>> submitCheckin(CheckinRequest request);

  /// Returns the requesting user's check-in history for a single project,
  /// most recent first.
  Future<Result<List<CheckinHistoryItem>>> getUserCheckins(String projectId);
}
