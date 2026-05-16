import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_controller.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/checkin/domain/entities/checkin_result.dart';
import '../../features/checkin/domain/entities/checkin_submission_outcome.dart';
import '../../features/checkin/presentation/screens/checkin_result_screen.dart';
import '../../features/checkin/presentation/screens/checkin_screen.dart';
import '../../features/checkin/presentation/screens/pending_data_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/project_detail_screen.dart';
import '../../features/tasks/presentation/screens/tasks_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/admin_not_supported_screen.dart';
import 'routes.dart';

/// App-wide router, auth-aware via [authControllerProvider].
final goRouterProvider = Provider<GoRouter>((ref) {
  final authListenable = _AuthListenable(ref);
  ref.onDispose(authListenable.dispose);

  return GoRouter(
    initialLocation: AppPath.splash,
    refreshListenable: authListenable,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      return _redirectFor(auth, state);
    },
    routes: [
      GoRoute(
        path: AppPath.splash,
        name: AppRoute.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppPath.login,
        name: AppRoute.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppPath.register,
        name: AppRoute.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppPath.dashboard,
        name: AppRoute.dashboard,
        builder: (_, __) => const DashboardScreen(),
      ),
      GoRoute(
        path: AppPath.projectDetail,
        name: AppRoute.projectDetail,
        builder: (context, state) {
          final projectId = state.pathParameters['projectId'] ?? '';
          if (projectId.isEmpty) {
            return _MissingParamsScreen(
              what: AppLocalizations.of(context)!.router_param_project_id,
            );
          }
          final projectName = state.uri.queryParameters['projectName'];
          return ProjectDetailScreen(
            projectId: projectId,
            fallbackName: projectName,
          );
        },
      ),
      GoRoute(
        path: AppPath.tasks,
        name: AppRoute.tasks,
        builder: (context, state) {
          final projectId = state.pathParameters['projectId'] ?? '';
          final projectName = state.uri.queryParameters['projectName'] ??
              AppLocalizations.of(context)!.tasks_appbar_fallback;
          // Optional area filter — set when navigating from the project
          // map's tap-on-area action. Empty string treated as "no filter"
          // so reusing the same route from a navigation pop works cleanly.
          final areaNameRaw = state.uri.queryParameters['areaName'];
          final areaName = (areaNameRaw == null || areaNameRaw.isEmpty)
              ? null
              : areaNameRaw;
          return TasksScreen(
            projectId: projectId,
            projectName: projectName,
            areaName: areaName,
          );
        },
      ),
      GoRoute(
        path: AppPath.checkin,
        name: AppRoute.checkin,
        builder: (context, state) {
          final projectId = state.pathParameters['projectId'] ?? '';
          if (projectId.isEmpty) {
            return _MissingParamsScreen(
              what: AppLocalizations.of(context)!.router_param_project_id,
            );
          }
          final qp = state.uri.queryParameters;
          // taskType is optional now: when launched from a specific Task
          // it's pre-set, when launched from "Add a check-in" on the
          // project detail the user picks from `taskTypes` (extra).
          final taskType = qp['taskType'];
          // The project's taskType catalog comes through `extra` because
          // it's a list. Falls back to an empty list — the screen renders
          // a free-text input in that case.
          final extra = state.extra;
          final taskTypes = extra is List<String>
              ? extra
              : (extra is List
                  ? extra.map((e) => e.toString()).toList(growable: false)
                  : const <String>[]);
          return CheckinScreen(
            projectId: projectId,
            taskType: (taskType != null && taskType.isNotEmpty)
                ? taskType
                : null,
            availableTaskTypes: taskTypes,
            taskId: qp['taskId'],
            taskName: qp['taskName'],
            projectName: qp['projectName'],
          );
        },
      ),
      GoRoute(
        path: AppPath.checkinResult,
        name: AppRoute.checkinResult,
        builder: (context, state) {
          final projectId = state.pathParameters['projectId'] ?? '';
          final extra = state.extra;
          // The form (Phase 2) hands us a CheckinSubmissionOutcome so the
          // screen can render either the reward (Accepted) or the
          // "Pending" state (Queued). Older callers that still hand a raw
          // CheckinResult are tolerated and treated as Accepted.
          if (extra is CheckinSubmissionOutcome) {
            return CheckinResultScreen(
              outcome: extra,
              projectId: projectId,
            );
          }
          if (extra is CheckinResult) {
            return CheckinResultScreen(
              outcome: CheckinSubmissionAccepted(extra),
              projectId: projectId,
            );
          }
          // Defensive fallback: if someone deep-links here without an
          // extra, send them home gracefully.
          return _MissingParamsScreen(
            what: AppLocalizations.of(context)!.router_param_checkin_result,
          );
        },
      ),
      GoRoute(
        path: AppPath.pendingData,
        name: AppRoute.pendingData,
        builder: (_, __) => const PendingDataScreen(),
      ),
      GoRoute(
        path: AppPath.adminNotSupported,
        name: AppRoute.adminNotSupported,
        builder: (_, __) => const AdminNotSupportedScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Text(
          AppLocalizations.of(context)!
              .router_route_not_found(state.uri.toString()),
        ),
      ),
    ),
  );
});

String? _redirectFor(AuthState auth, GoRouterState state) {
  final loc = state.matchedLocation;
  final isSplash = loc == AppPath.splash;
  final isAuthArea = loc == AppPath.login ||
      loc == AppPath.register ||
      loc == AppPath.forgotPassword;
  final isAdminWall = loc == AppPath.adminNotSupported;

  switch (auth) {
    case AuthStateInitial():
      return isSplash ? null : AppPath.splash;
    case AuthStateUnauthenticated():
      if (isSplash) return AppPath.login;
      if (isAdminWall) return AppPath.login;
      return isAuthArea ? null : AppPath.login;
    case AuthStateAuthenticated(:final user):
      if (user.isAdmin) {
        return isAdminWall ? null : AppPath.adminNotSupported;
      }
      if (isSplash || isAuthArea) return AppPath.dashboard;
      return null;
  }
}

/// Bridges Riverpod state changes to go_router's [Listenable] API.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._ref) {
    _sub = _ref.listen<AuthState>(
      authControllerProvider,
      (_, __) => notifyListeners(),
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

class _MissingParamsScreen extends StatelessWidget {
  const _MissingParamsScreen({required this.what});
  final String what;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                t.router_missing_params(what),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    GoRouter.of(context).goNamed(AppRoute.dashboard),
                child: Text(t.checkin_back_to_dashboard),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
