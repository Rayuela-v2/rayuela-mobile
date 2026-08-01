import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/linkified_text.dart';
import '../../../dashboard/domain/entities/project_detail.dart' show TaskType;
import '../../domain/entities/task_item.dart';

// ---------------------------------------------------------------------------
// Schedule formatting
//
// The task's time interval carries a name, a set of ISO weekdays (1=Mon..7=Sun),
// an hour range, and an optional validity date window. The card only ever
// showed the name; these helpers turn the interval into the *real* schedule.
// Weekday letters and dates come from MaterialLocalizations (always available
// for the app's locales — no intl date-symbol init needed).
// ---------------------------------------------------------------------------

/// One-line schedule for the task card, e.g. "L·X·V  09:00–17:00". Null when
/// there's nothing meaningful to show.
String? taskScheduleShort(BuildContext context, TaskTimeInterval? interval) {
  if (interval == null) return null;
  final days = _daysLabel(context, interval.days);
  final hours = _hoursLabel(interval);
  if (days == null && hours == null) return null;
  return [days, hours].whereType<String>().join('  ');
}

String? _daysLabel(BuildContext context, List<int> days) {
  if (days.isEmpty) return null;
  if (days.toSet().length >= 7) {
    return AppLocalizations.of(context)!.task_schedule_everyday;
  }
  // narrowWeekdays is Sunday-first (index 0). ISO day d maps to d % 7.
  final narrow = MaterialLocalizations.of(context).narrowWeekdays;
  final sorted = [...days.toSet()]..sort();
  return sorted.map((d) => narrow[d % 7]).join('·');
}

String? _hoursLabel(TaskTimeInterval interval) {
  final s = interval.startTime.trim();
  final e = interval.endTime.trim();
  if (s.isEmpty && e.isEmpty) return null;
  if (s.isEmpty) return e;
  if (e.isEmpty) return s;
  return '$s–$e';
}

String? _dateWindowLabel(BuildContext context, TaskTimeInterval interval) {
  final fmt = MaterialLocalizations.of(context).formatMediumDate;
  final start = _tryDate(interval.startDate);
  final end = _tryDate(interval.endDate);
  if (start == null && end == null) return null;
  if (start != null && end != null) return '${fmt(start)} – ${fmt(end)}';
  return fmt((start ?? end)!);
}

DateTime? _tryDate(String? raw) =>
    (raw == null || raw.isEmpty) ? null : DateTime.tryParse(raw);

// ---------------------------------------------------------------------------
// Detail sheet
// ---------------------------------------------------------------------------

/// Opens the task detail sheet. [taskType] carries the catalog entry (so the
/// type's description — which may contain markdown links — can be shown); pass
/// null when the catalog isn't loaded. [onCheckin] drives the primary CTA and
/// should be null for solved tasks (no action to offer).
void showTaskDetails(
  BuildContext context, {
  required TaskItem task,
  TaskType? taskType,
  VoidCallback? onCheckin,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) =>
        _TaskDetailSheet(task: task, taskType: taskType, onCheckin: onCheckin),
  );
}

class _TaskDetailSheet extends StatelessWidget {
  const _TaskDetailSheet({
    required this.task,
    required this.taskType,
    required this.onCheckin,
  });

  final TaskItem task;
  final TaskType? taskType;
  final VoidCallback? onCheckin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    final solved = task.solved;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    final typeDescription = taskType?.description?.trim();

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 4, 24, 24 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _PointsPill(points: task.points, solved: solved),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatusLine(
                    solved: solved,
                    solvedBy: task.solvedBy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              task.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (task.description.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              LinkifiedText(
                text: task.description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],

            // What kind of task this is — the description often carries the
            // real instructions and a link ("read the protocol [here](...)").
            if (task.type.isNotEmpty || typeDescription != null)
              _Section(
                icon: Icons.category_outlined,
                title: t.task_detail_about_type,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (task.type.isNotEmpty)
                      _Pill(label: task.type, color: theme.colorScheme.primary),
                    if (typeDescription != null &&
                        typeDescription.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      LinkifiedText(
                        text: typeDescription,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),

            // The real interval, not just its name.
            _Section(
              icon: Icons.schedule,
              title: t.task_detail_schedule,
              child: _ScheduleBody(interval: task.timeInterval),
            ),

            if (task.areaName != null && task.areaName!.isNotEmpty)
              _Section(
                icon: Icons.place_outlined,
                title: t.task_detail_area,
                child: Text(
                  task.areaName!,
                  style: theme.textTheme.bodyMedium,
                ),
              ),

            if (!solved && onCheckin != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onCheckin!();
                  },
                  icon: const Icon(Icons.post_add),
                  label: Text(t.project_add_checkin),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The schedule rows: hours, days, and (when set) the validity date window.
/// Falls back to "any time / every day" so the block never looks empty.
class _ScheduleBody extends StatelessWidget {
  const _ScheduleBody({required this.interval});
  final TaskTimeInterval? interval;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    final iv = interval;

    final hours = iv == null ? null : _hoursLabel(iv);
    final days = iv == null ? null : _daysLabel(context, iv.days);
    final dates = iv == null ? null : _dateWindowLabel(context, iv);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (iv != null && iv.name.isNotEmpty) ...[
          Text(
            iv.name,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
        ],
        _ScheduleRow(
          icon: Icons.access_time,
          label: hours ?? t.task_schedule_anytime,
        ),
        const SizedBox(height: 6),
        _ScheduleRow(
          icon: Icons.event_repeat_outlined,
          label: days ?? t.task_schedule_everyday,
        ),
        if (dates != null) ...[
          const SizedBox(height: 6),
          _ScheduleRow(icon: Icons.date_range_outlined, label: dates),
        ],
      ],
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

/// A labeled section: a small header (icon + title) and its content, boxed
/// so the sheet reads as a set of clear, scannable blocks.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _PointsPill extends StatelessWidget {
  const _PointsPill({required this.points, required this.solved});
  final int points;
  final bool solved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    final color = solved
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.primaryContainer;
    final fg = solved
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onPrimaryContainer;
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$points',
            style: theme.textTheme.titleLarge?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            t.task_card_pts_unit,
            style: theme.textTheme.labelSmall?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.solved, required this.solvedBy});
  final bool solved;
  final String? solvedBy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    final color =
        solved ? const Color(0xFF2E7D32) : theme.colorScheme.primary;
    final label = solved
        ? (solvedBy != null && solvedBy!.isNotEmpty
            ? '${t.badge_earned} · ${t.task_card_solved_by(solvedBy!)}'
            : t.badge_earned)
        : t.task_detail_status_open;
    return Row(
      children: [
        Icon(
          solved ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
