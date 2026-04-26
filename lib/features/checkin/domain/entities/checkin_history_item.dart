/// One entry in the user's check-in history for a project.
///
/// Backed by `GET /checkin/user/:projectId`. The backend's
/// `CheckInTemplate` schema (rayuela-NodeBackend/.../checkin.schema) is the
/// authoritative shape: latitude/longitude as strings, `imageRefs` is an
/// array of storage keys (resolve via `/storage/file?key=...`).
///
/// Notes are not persisted at the moment (no field on the schema). When/if
/// the backend grows a `notes` column we'll surface it here.
class CheckinHistoryItem {
  const CheckinHistoryItem({
    required this.id,
    required this.projectId,
    required this.taskType,
    required this.datetime,
    required this.imageRefs,
    this.latitude,
    this.longitude,
    this.contributesToTaskId,
    this.contributesToTaskName,
  });

  final String id;
  final String projectId;
  final String taskType;
  final DateTime datetime;

  /// Storage keys (or full URLs — defensive). Use [resolveImageUrl] to get
  /// a full URL for rendering.
  final List<String> imageRefs;

  /// String-typed because the backend persists them as strings.
  final String? latitude;
  final String? longitude;

  /// Set when this check-in resolved a specific task. Useful for surfacing
  /// "Tarea resuelta" / "Solved" badges in the history.
  final String? contributesToTaskId;
  final String? contributesToTaskName;

  bool get hasLocation => latitude != null && longitude != null;
  bool get solvesATask =>
      (contributesToTaskId ?? contributesToTaskName)?.isNotEmpty ?? false;
}
