import 'package:sqflite/sqflite.dart';

import '../../../../core/cache/cached_value.dart';
import '../../../../core/cache/json_cache_table.dart';
import '../../domain/entities/task_item.dart';

/// Caches the per-project task list returned by `GET /task/project/:id`.
///
/// One row per (userId, projectId) in `cached_tasks`. The full list is
/// serialised into `payload_json` — projects rarely have more than a few
/// dozen tasks and the dashboard always renders the whole list.
class TasksLocalSource {
  TasksLocalSource(Database db)
      : _table = JsonCacheTable<List<TaskItem>>(
          db: db,
          table: 'cached_tasks',
          encode: _encode,
          decode: _decode,
        );

  final JsonCacheTable<List<TaskItem>> _table;

  Future<Cached<List<TaskItem>>?> read({
    required String userId,
    required String projectId,
  }) {
    return _table.read(userId: userId, projectId: projectId);
  }

  Future<void> write({
    required String userId,
    required String projectId,
    required List<TaskItem> tasks,
    required DateTime fetchedAt,
  }) {
    return _table.write(
      userId: userId,
      projectId: projectId,
      value: tasks,
      fetchedAt: fetchedAt,
    );
  }

  Future<void> clearForUser(String userId) => _table.clearForUser(userId);
}

Object _encode(List<TaskItem> list) => [
      for (final t in list) _encodeOne(t),
    ];

Map<String, Object?> _encodeOne(TaskItem t) => {
      'id': t.id,
      'projectId': t.projectId,
      'name': t.name,
      'description': t.description,
      'type': t.type,
      'points': t.points,
      'solved': t.solved,
      'solvedBy': t.solvedBy,
      'areaName': t.areaName,
      'timeInterval': t.timeInterval == null
          ? null
          : {
              'name': t.timeInterval!.name,
              'days': t.timeInterval!.days,
              'startTime': t.timeInterval!.startTime,
              'endTime': t.timeInterval!.endTime,
              'startDate': t.timeInterval!.startDate,
              'endDate': t.timeInterval!.endDate,
            },
    };

List<TaskItem> _decode(Object? raw) {
  if (raw is! List) return const [];
  return raw.whereType<Map<Object?, Object?>>().map((m) {
    return TaskItem(
      id: (m['id'] ?? '').toString(),
      projectId: (m['projectId'] ?? '').toString(),
      name: (m['name'] ?? '').toString(),
      description: (m['description'] ?? '').toString(),
      type: (m['type'] ?? '').toString(),
      points: _asInt(m['points']),
      solved: m['solved'] == true,
      solvedBy: m['solvedBy']?.toString(),
      areaName: m['areaName']?.toString(),
      timeInterval: _decodeInterval(m['timeInterval']),
    );
  }).toList(growable: false);
}

TaskTimeInterval? _decodeInterval(Object? raw) {
  if (raw is! Map) return null;
  final daysRaw = raw['days'];
  final days = <int>[];
  if (daysRaw is List) {
    for (final d in daysRaw) {
      if (d is int) {
        days.add(d);
      } else if (d is num) {
        days.add(d.toInt());
      } else {
        final parsed = int.tryParse(d.toString());
        if (parsed != null) days.add(parsed);
      }
    }
  }
  return TaskTimeInterval(
    name: (raw['name'] ?? '').toString(),
    days: days,
    startTime: (raw['startTime'] ?? '').toString(),
    endTime: (raw['endTime'] ?? '').toString(),
    startDate: raw['startDate']?.toString(),
    endDate: raw['endDate']?.toString(),
  );
}

int _asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}
