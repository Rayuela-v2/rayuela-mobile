import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/router/routes.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../data/badge_reminder_scheduler.dart';
import 'providers/notifications_providers.dart';

/// Turns a tapped reminder into a route.
///
/// Lives outside the widget tree because the tap can arrive before any
/// widget exists — the plugin reports a cold-start tap milliseconds after
/// `main`, long before the user is signed back in.
class NotificationTapRouter {
  NotificationTapRouter(this._container);

  final ProviderContainer _container;

  /// A tap that arrived before the session was ready, waiting for it.
  BadgeReminderTarget? _pending;

  /// Wires both arrival paths and replays a cold-start tap if there was one.
  ///
  /// Call once, after `runApp`: navigation needs the router's delegate
  /// attached, which only happens once the first frame has built.
  Future<void> bind() async {
    // Sign-in is asynchronous — the splash restores the session — so a
    // cold-start tap always lands on an unauthenticated container. Hold it
    // and let this listener release it, or the single most important case
    // (tapping a reminder while the app is closed) silently does nothing.
    _container.listen<AuthState>(
      authControllerProvider,
      (_, next) {
        if (next is AuthStateAuthenticated) _flush();
      },
      fireImmediately: true,
    );

    final scheduler = _container.read(badgeReminderSchedulerProvider)
      ..onTap = _handle;
    final launched = await scheduler.launchTarget();
    if (launched != null) _handle(launched);
  }

  void _handle(BadgeReminderTarget target) {
    _pending = target;
    _flush();
  }

  void _flush() {
    final target = _pending;
    if (target == null) return;
    // A reminder can outlive the session that booked it. Keep holding rather
    // than navigating: the badge belongs to an account that isn't active yet,
    // and the router would bounce us to login anyway.
    if (_container.read(authControllerProvider) is! AuthStateAuthenticated) {
      return;
    }
    _pending = null;

    // Next frame, so the auth-driven redirect has settled first — pushing
    // into a tree that is about to be replaced loses the route.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _container.read(goRouterProvider).pushNamed(
        AppRoute.projectDetail,
        pathParameters: {'projectId': target.projectId},
        queryParameters: {
          if (target.badgeName.isNotEmpty) 'badge': target.badgeName,
        },
      );
    });
  }
}
