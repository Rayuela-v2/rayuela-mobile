import '../../../../core/error/result.dart';
import '../entities/checkin_history_item.dart';
import '../entities/checkin_request.dart';
import '../entities/checkin_result.dart';

abstract class CheckinsRepository {
  Future<Result<CheckinResult>> submitCheckin(CheckinRequest request);

  /// Returns the requesting user's check-in history for a single project,
  /// most recent first.
  Future<Result<List<CheckinHistoryItem>>> getUserCheckins(String projectId);
}
