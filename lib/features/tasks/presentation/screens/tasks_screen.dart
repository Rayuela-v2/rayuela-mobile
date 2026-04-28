import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../domain/entities/task_item.dart';
import '../providers/tasks_providers.dart';
import '../widgets/task_card.dart';

/// Lists every task in a project. The user taps an open task to start a
/// check-in. Solved tasks are read-only.
///
/// Optionally narrows to a single project area when [areaName] is set —
/// the project map's tap-on-area action navigates here with that filter.
/// The user can clear the filter inline via the chip in the AppBar.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    this.areaName,
  });

  final String projectId;
  final String projectName;
  final String? areaName;

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  /// Local copy of the filter so the user can clear it via the AppBar
  /// chip without bouncing back through the router. Initialized from the
  /// route param; persisted only for the duration of the screen.
  String? _areaFilter;

  @override
  void initState() {
    super.initState();
    _areaFilter = widget.areaName;
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(projectTasksProvider(widget.projectId));
    final t = AppLocalizations.of(context)!;
    final title = widget.projectName.isEmpty
        ? t.tasks_appbar_fallback
        : widget.projectName;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: _areaFilter == null
            ? null
            : _AreaFilterBar(
                areaName: _areaFilter!,
                onClear: () => setState(() => _areaFilter = null),
              ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(projectTasksProvider(widget.projectId));
          await ref.read(projectTasksProvider(widget.projectId).future);
        },
        child: tasks.when(
          data: (list) => _TasksList(
            tasks: _applyFilter(list),
            areaFilter: _areaFilter,
            onClearFilter: _areaFilter == null
                ? null
                : () => setState(() => _areaFilter = null),
            onTaskTap: (task) => _openCheckin(context, task),
          ),
          error: (error, _) => LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight),
                child: ErrorView(
                  error: error,
                  onRetry: () =>
                      ref.invalidate(projectTasksProvider(widget.projectId)),
                ),
              ),
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  /// Applies the area filter when set. Tasks without an [areaName] (older
  /// projects) are dropped from filtered views — they don't belong to any
  /// area, so showing them under "Area X" would be misleading.
  List<TaskItem> _applyFilter(List<TaskItem> source) {
    final filter = _areaFilter;
    if (filter == null) return source;
    return source
        .where((t) => t.areaName != null && t.areaName == filter)
        .toList(growable: false);
  }

  void _openCheckin(BuildContext context, TaskItem task) {
    final t = AppLocalizations.of(context)!;
    if (task.solved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.tasks_already_solved(task.name)),
        ),
      );
      return;
    }
    context.pushNamed(
      AppRoute.checkin,
      pathParameters: {'projectId': widget.projectId},
      queryParameters: {
        'taskType': task.type,
        'taskName': task.name,
        if (task.id.isNotEmpty) 'taskId': task.id,
      },
    );
  }
}

class _AreaFilterBar extends StatelessWidget implements PreferredSizeWidget {
  const _AreaFilterBar({required this.areaName, required this.onClear});

  final String areaName;
  final VoidCallback onClear;

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InputChip(
          avatar: Icon(
            Icons.place_outlined,
            size: 18,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          label: Text(t.tasks_filter_label(areaName)),
          backgroundColor: theme.colorScheme.secondaryContainer,
          labelStyle: TextStyle(
            color: theme.colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w600,
          ),
          deleteIcon: Icon(
            Icons.close,
            size: 18,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          onDeleted: onClear,
        ),
      ),
    );
  }
}

class _TasksList extends StatelessWidget {
  const _TasksList({
    required this.tasks,
    required this.onTaskTap,
    this.areaFilter,
    this.onClearFilter,
  });

  final List<TaskItem> tasks;
  final void Function(TaskItem) onTaskTap;
  final String? areaFilter;
  final VoidCallback? onClearFilter;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    if (tasks.isEmpty) {
      // When the empty state is *because* of the area filter, give the
      // user a one-tap escape so they don't have to go back to the map.
      final filterEmpty = areaFilter != null;
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: filterEmpty
                ? _EmptyForFilter(
                    areaName: areaFilter!,
                    onClearFilter: onClearFilter,
                  )
                : EmptyState(
                    icon: Icons.task_alt_outlined,
                    title: t.tasks_empty_title,
                    message: t.tasks_empty_body,
                  ),
          ),
        ),
      );
    }

    final open = tasks.where((tt) => !tt.solved).toList(growable: false);
    final solved = tasks.where((tt) => tt.solved).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (open.isNotEmpty) ...[
          _SectionHeader(label: t.tasks_section_open(open.length)),
          const SizedBox(height: 8),
          for (final tt in open) ...[
            TaskCard(task: tt, onTap: () => onTaskTap(tt)),
            const SizedBox(height: 12),
          ],
        ],
        if (solved.isNotEmpty) ...[
          const SizedBox(height: 8),
          _SectionHeader(label: t.tasks_section_solved(solved.length)),
          const SizedBox(height: 8),
          for (final tt in solved) ...[
            TaskCard(task: tt, onTap: () => onTaskTap(tt)),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

class _EmptyForFilter extends StatelessWidget {
  const _EmptyForFilter({required this.areaName, this.onClearFilter});

  final String areaName;
  final VoidCallback? onClearFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.filter_alt_off_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            t.tasks_empty_for_area_title(areaName),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            t.tasks_empty_for_area_body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (onClearFilter != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onClearFilter,
              icon: const Icon(Icons.clear),
              label: Text(t.tasks_clear_filter),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
