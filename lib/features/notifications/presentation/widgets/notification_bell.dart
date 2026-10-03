import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/notifications_providers.dart';

/// App-bar entry point to the notification centre, with an unread counter.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    // A failed count must never take the app bar down with it — worst case
    // the bell shows nothing, which is what it shows most of the time anyway.
    final unread =
        ref.watch(unreadNotificationsCountProvider).asData?.value ?? 0;

    return IconButton(
      // The count is decoration; screen readers get it as words.
      tooltip:
          unread > 0 ? t.notifications_unread(unread) : t.notifications_title,
      onPressed: () => context.pushNamed(AppRoute.notifications),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(unread > 0 ? Icons.notifications : Icons.notifications_none),
          if (unread > 0)
            Positioned(
              top: -3,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16),
                decoration: BoxDecoration(
                  color: RayuelaColors.danger,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  // Past a point the exact number stops being useful and
                  // starts breaking the layout.
                  unread > 9 ? '9+' : '$unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
