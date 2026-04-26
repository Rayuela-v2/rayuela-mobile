/// What the volunteer submits to `POST /checkin` (multipart).
///
/// We carry [imagePaths] as local file paths until the multipart layer
/// converts them into MultipartFile entries — the wire field name is
/// `imageRefs` but at request-time these are local paths.
class CheckinRequest {
  const CheckinRequest({
    required this.projectId,
    required this.taskType,
    required this.latitude,
    required this.longitude,
    required this.datetime,
    required this.imagePaths,
    this.taskId,
    this.notes,
  });

  final String projectId;
  final String taskType;

  /// Backend stores latitude/longitude as strings (max 500 chars), so we
  /// keep them as raw strings end-to-end. We still validate in the form.
  final String latitude;
  final String longitude;
  final DateTime datetime;
  final List<String> imagePaths;

  /// Not part of the wire shape today, but useful for the UI to remember
  /// which task triggered this check-in.
  final String? taskId;

  /// Optional volunteer notes. Backend ignores them today; we keep them
  /// client-side until backend §4.1 ships an extra field.
  final String? notes;
}
