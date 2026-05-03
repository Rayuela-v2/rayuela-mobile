import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/language_picker.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../checkin/presentation/widgets/outbox_badge.dart';
import '../providers/projects_providers.dart';
import '../widgets/project_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final authState = ref.watch(authControllerProvider);
    final projects = ref.watch(subscribedProjectsProvider);

    final greeting = switch (authState) {
      AuthStateAuthenticated(:final user) =>
        t.dashboard_greeting(user.completeName.split(' ').first),
      _ => t.dashboard_greeting_fallback,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(greeting),
        actions: [
          // Sync badge sits before the language picker so it's the
          // first thing the user sees when something is going on with
          // the queue. Auto-hides when the system is idle.
          const SyncStatusBadge(),
          const LanguagePickerButton(),
          IconButton(
            tooltip: t.common_logout,
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(subscribedProjectsProvider);
          await ref.read(subscribedProjectsProvider.future);
        },
        child: projects.when(
          data: (list) {
            if (list.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      children: [
                        const OutboxBanner(),
                        Expanded(
                          child: EmptyState(
                            icon: Icons.explore_outlined,
                            title: t.dashboard_empty_title,
                            message: t.dashboard_empty_body,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: OutboxBanner()),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final project = list[i];
                      return ProjectCard(
                        project: project,
                        onTap: () {
                          // pushNamed (not goNamed) so the AppBar back
                          // button on the detail screen returns here.
                          context.pushNamed(
                            AppRoute.projectDetail,
                            pathParameters: {'projectId': project.id},
                            queryParameters: {'projectName': project.name},
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
          error: (error, _) => LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(subscribedProjectsProvider),
                ),
              ),
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
