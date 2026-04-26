import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../providers/projects_providers.dart';
import '../widgets/project_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final projects = ref.watch(subscribedProjectsProvider);

    final greeting = switch (authState) {
      AuthStateAuthenticated(:final user) =>
        'Hi, ${user.completeName.split(' ').first}',
      _ => 'Hi',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(greeting),
        actions: [
          IconButton(
            tooltip: 'Log out',
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
                    child: const EmptyState(
                      icon: Icons.explore_outlined,
                      title: 'No projects yet',
                      message:
                          'Discover citizen-science projects near you and '
                          'subscribe to start participating.',
                    ),
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final project = list[i];
                return ProjectCard(
                  project: project,
                  onTap: () {
                    // pushNamed (not goNamed) so the AppBar back button on
                    // the detail screen returns here.
                    context.pushNamed(
                      AppRoute.projectDetail,
                      pathParameters: {'projectId': project.id},
                      queryParameters: {'projectName': project.name},
                    );
                  },
                );
              },
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
