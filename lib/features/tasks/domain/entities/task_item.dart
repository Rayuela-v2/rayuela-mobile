/// Domain representation of a citizen-science task within a project.
///
/// Mirrors the wire shape from `GET /task/project/:id`, which goes through
/// the backend's explicit `Task.toJSON()` (no underscore-leak risk on this
/// endpoint). Keep this entity wire-agnostic — UI binds to it, never to the
/// raw DTO.
class TaskItem {
  const TaskItem({
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

  /// `taskType` value the user must send back when submitting a check-in.
  /// The backend matches checkins to tasks by this string, not by id.
  final String type;

  final int points;
  final bool solved;

  /// Username of the volunteer who first marked the task solved, if any.
  final String? solvedBy;

  /// Optional human description of when the task is open
  /// ("Mon–Fri 09:00–17:00"). Kept as raw text for now; we'll model it
  /// properly when the schedule UI lands.
  final TaskTimeInterval? timeInterval;

  /// Name of the project area this task belongs to. Sourced from
  /// `task.areaGeoJSON.properties.id` on the backend (the same id key the
  /// project's [ProjectArea] uses), so callers can join tasks ↔ areas
  /// without a second lookup.
  ///
  /// Null when the admin hasn't pinned the task to a specific area —
  /// older projects routinely leave this empty.
  final String? areaName;

  bool get isOpen => !solved;
}

class TaskTimeInterval {
  const TaskTimeInterval({
    required this.name,
    required this.days,
    required this.startTime,
    required this.endTime,
    this.startDate,
    this.endDate,
  });

  final String name;

  /// 1–7, ISO weekday (1 = Monday).
  final List<int> days;
  final String startTime;
  final String endTime;
  final String? startDate;
  final String? endDate;
}
