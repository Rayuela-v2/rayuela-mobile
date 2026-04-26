import '../../domain/entities/checkin_history_item.dart';

/// Wire shape of `GET /checkin/user/:projectId` (rayuela-NodeBackend).
///
/// The endpoint returns a JSON array; each element looks like:
///   {
///     id|_id, projectId, taskType, datetime|date,
///     latitude, longitude,                    // both strings
///     imageRefs: [string, ...],               // possibly missing
///     contributesTo: { id, name } | string?,  // task ref, may be a plain id
///   }
///
/// Some fields can show up under leading-underscore aliases when the
/// backend serializer exposes the raw Mongoose document (we have seen this
/// in other endpoints — same defense everywhere).
class CheckinHistoryItemDto {
  const CheckinHistoryItemDto({
    required this.id,
    required this.projectId,
    required this.taskType,
    required this.datetime,
    required this.imageRefs,
    this.latitude,
    this.longitude,
    this.contributesToId,
    this.contributesToName,
  });

  final String id;
  final String projectId;
  final String taskType;
  final DateTime datetime;
  final List<String> imageRefs;
  final String? latitude;
  final String? longitude;
  final String? contributesToId;
  final String? contributesToName;

  static CheckinHistoryItemDto? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final m = raw.map((k, v) => MapEntry(k.toString(), v));

    final id = _firstString(m, const ['id', '_id']);
    if (id == null || id.isEmpty) return null;

    final imageRefsRaw = m['imageRefs'] ?? m['_imageRefs'] ?? m['images'];
    final imageRefs = imageRefsRaw is List
        ? imageRefsRaw
            .map((e) => e?.toString())
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    final dt = _parseDate(m['datetime']) ??
        _parseDate(m['date']) ??
        _parseDate(m['_datetime']) ??
        _parseDate(m['createdAt']);

    String? contribId;
    String? contribName;
    final contrib = m['contributesTo'];
    if (contrib is Map) {
      final cm = contrib.map((k, v) => MapEntry(k.toString(), v));
      contribId = _firstString(cm, const ['id', '_id']);
      contribName = _firstString(cm, const ['name']);
    } else if (contrib is String && contrib.isNotEmpty) {
      // Sometimes the API stores just the task id.
      contribId = contrib;
    }

    return CheckinHistoryItemDto(
      id: id,
      projectId: _firstString(m, const ['projectId', '_projectId']) ?? '',
      taskType: _firstString(m, const ['taskType', '_taskType']) ?? '',
      datetime: dt ?? DateTime.now(),
      imageRefs: imageRefs,
      latitude: _firstString(m, const ['latitude', '_latitude']),
      longitude: _firstString(m, const ['longitude', '_longitude']),
      contributesToId: contribId,
      contributesToName: contribName,
    );
  }

  CheckinHistoryItem toEntity() => CheckinHistoryItem(
        id: id,
        projectId: projectId,
        taskType: taskType,
        datetime: datetime,
        imageRefs: imageRefs,
        latitude: latitude,
        longitude: longitude,
        contributesToTaskId: contributesToId,
        contributesToTaskName: contributesToName,
      );
}

// ---------------------------------------------------------------------------
// Defensive parsing helpers — kept private to avoid coupling.
// ---------------------------------------------------------------------------

String? _firstString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final v = json[key];
    if (v == null) continue;
    if (v is String) {
      if (v.isEmpty) continue;
      return v;
    }
    if (v is num || v is bool) return v.toString();
  }
  return null;
}

DateTime? _parseDate(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  if (v is num) {
    return DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true);
  }
  return null;
}
