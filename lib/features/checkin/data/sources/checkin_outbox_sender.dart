import '../../../../core/error/result.dart';
import '../../../../core/sync/outbox/outbox_entry.dart';
import '../../../../core/sync/outbox/outbox_sender.dart';
import 'checkins_remote_source.dart';

/// Translates an [OutboxEntry] into a `POST /checkin` call via the
/// existing [CheckinsRemoteSource]. The outbox row's id doubles as the
/// `Idempotency-Key` so a retry after a transport hiccup can never
/// produce a duplicate server-side resource.
///
/// All mapping from `AppException` → [OutboxSendOutcome] is delegated to
/// [classifyAppException] so the policy stays in one place.
class CheckinOutboxSender implements OutboxSender {
  const CheckinOutboxSender(this._remote);

  final CheckinsRemoteSource _remote;

  @override
  Future<OutboxSendOutcome> send(OutboxEntry entry) async {
    final paths = entry.images
        .map((i) => i.filePath)
        .toList(growable: false);
    final res = await _remote.submitFromDisk(
      idempotencyKey: entry.idempotencyKey,
      projectId: entry.projectId,
      taskType: entry.taskType,
      latitude: entry.latitude,
      longitude: entry.longitude,
      datetime: entry.datetime,
      imagePaths: paths,
    );
    return switch (res) {
      Success() => const OutboxSendSucceeded(),
      Failure(:final error) => classifyAppException(error),
    };
  }
}
