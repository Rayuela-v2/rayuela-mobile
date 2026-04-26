import '../../domain/entities/task_item.dart';

/// Wire shape of `GET /task/project/:id`.
///
/// Backend's `Task.toJSON()` returns a clean object — no underscore-leak
/// hack needed here, but we still parse defensively so a malformed row
/// doesn't take the whole list down.
class TaskDto {
  const TaskDto({
    required this.id,
    required this.projectId,
    required this.name,
    required this.description,
    required this.type,
    required this.points,
    required this.solved,
    this.solvedBy,
    this.timeInterval,
    this.areaName,
  });

  final String id;
  final String projectId;
  final String name;
  final String description;
  final String type;
  final int points;
  final bool solved;
  final String? solvedBy;
  final TaskTimeIntervalDto? timeInterval;
  final String? areaName;

  factory TaskDto.fromJson(Object? raw) {
    final json = _asMap(raw);
    return TaskDto(
      id: _firstString(json, const ['id', '_id']) ?? '',
      projectId: _firstString(json, const ['projectId', 'project_id']) ?? '',
      name: _firstString(json, const ['name']) ?? '',
      description: _firstString(json, const ['description']) ?? '',
      type: _firstString(json, const ['type', 'taskType']) ?? '',
      points: _asInt(json['points']) ?? 0,
      solved: _asBool(json['solved']) ?? false,
      solvedBy: _firstString(json, const ['solvedBy', 'solved_by']),
      timeInterval: TaskTimeIntervalDto.tryParse(json['timeInterval']),
      areaName: _parseAreaName(json),
    );
  }

  TaskItem toEntity() => TaskItem(
        id: id,
        projectId: projectId,
        name: name,
        description: description,
        type: type,
        points: points,
        solved: solved,
        solvedBy: solvedBy,
        timeInterval: timeInterval?.toEntity(),
        areaName: areaName,
      );

  /// Pulls the area name out of `task.areaGeoJSON.properties.id`. That is the
  /// canonical join key the backend uses to wire a task to one of the project's
  /// `areas` (Project schema → `areas` FeatureCollection → each Feature's
  /// `properties.id`). Tolerates a flat `areaName` / `area` field for older
  /// admin tooling that bypassed the GeoJSON wrap.
  static String? _parseAreaName(Map<String, dynamic> json) {
    final inline = _firstString(json, const ['areaName', 'area']);
    if (inline != null && inline.isNotEmpty) return inline;
    final geo = json['areaGeoJSON'] ?? json['_areaGeoJSON'];
    if (geo is Map) {
      final m = geo.map((k, v) => MapEntry(k.toString(), v));
      final props = m['properties'];
      if (props is Map) {
        final pm = props.map((k, v) => MapEntry(k.toString(), v));
        return _firstString(pm, const ['id', 'name']);
      }
    }
    return null;
  }
}

class TaskTimeIntervalDto {
  const TaskTimeIntervalDto({
    required this.name,
    required this.days,
    required this.startTime,
    required this.endTime,
    this.startDate,
    this.endDate,
  });

  final String name;
  final List<int> days;
  final String startTime;
  final String endTime;
  final String? startDate;
  final String? endDate;

  static TaskTimeIntervalDto? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final json = raw.map((k, v) => MapEntry(k.toString(), v));
    final time = json['time'];
    String start = '';
    String end = '';
    if (time is Map) {
      start = (time['start'] ?? '').toString();
      end = (time['end'] ?? '').toString();
    }
    final daysRaw = json['days'];
    final days = daysRaw is List
        ? daysRaw
            .map((d) => _asInt(d) ?? -1)
            .where((d) => d >= 0)
            .toList(growable: false)
        : const <int>[];
    return TaskTimeIntervalDto(
      name: _firstString(json, const ['name']) ?? '',
      days: days,
      startTime: start,
      endTime: end,
      startDate: _firstString(json, const ['startDate']),
      endDate: _firstString(json, const ['endDate']),
    );
  }

  TaskTimeInterval toEntity() => TaskTimeInterval(
        name: name,
        days: days,
        startTime: startTime,
        endTime: endTime,
        startDate: startDate,
        endDate: endDate,
      );
}

// ---------------------------------------------------------------------------
// Defensive parsing helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _asMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return raw.map((k, v) => MapEntry(k.toString(), v));
  return const <String, dynamic>{};
}

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

int? _asInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

bool? _asBool(Object? v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
  }
  return null;
}
