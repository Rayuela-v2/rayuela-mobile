import '../../../../core/error/result.dart';
import '../../domain/entities/checkin_history_item.dart';
import '../../domain/entities/checkin_request.dart';
import '../../domain/entities/checkin_result.dart';
import '../../domain/repositories/checkins_repository.dart';
import '../sources/checkins_remote_source.dart';

class CheckinsRepositoryImpl implements CheckinsRepository {
  const CheckinsRepositoryImpl(this._remote);

  final CheckinsRemoteSource _remote;

  @override
  Future<Result<CheckinResult>> submitCheckin(CheckinRequest request) async {
    final res = await _remote.submit(request);
    return res.fold(
      onSuccess: (dto) => Success(dto.toEntity()),
      onFailure: Failure<CheckinResult>.new,
    );
  }

  @override
  Future<Result<List<CheckinHistoryItem>>> getUserCheckins(
    String projectId,
  ) async {
    final res = await _remote.fetchUserCheckins(projectId);
    return res.fold(
      onSuccess: (dtos) {
        final items = dtos
            .map((d) => d.toEntity())
            .toList(growable: false)
          // Newest first so the screen lands on the user's most recent
          // contribution. Backend ordering is not guaranteed.
          ..sort((a, b) => b.datetime.compareTo(a.datetime));
        return Success(items);
      },
      onFailure: Failure<List<CheckinHistoryItem>>.new,
    );
  }
}
