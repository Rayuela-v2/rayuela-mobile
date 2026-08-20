import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/bootstrap.dart';
import 'app/rayuela_app.dart';
import 'features/notifications/presentation/notification_tap_router.dart';

Future<void> main() async {
  final container = await bootstrapContainer();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const RayuelaApp(),
    ),
  );

  // After `runApp`, and after the first frame: a cold-start tap navigates
  // immediately, and the router's delegate isn't attached until something
  // has been built. Binding earlier drops the very tap that opened the app.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // ignore: unawaited_futures
    NotificationTapRouter(container).bind();
  });
}
