import 'dart:async';

import 'package:flutter/widgets.dart';

import '../connectivity_service.dart';
import 'outbox_service.dart';

/// Glue between the OS lifecycle / connectivity stream and
/// [OutboxService.drain].
///
/// Wired once during bootstrap. Activate it after the user logs in by
/// calling [bind] with the user id; call [unbind] on logout so we don't
/// keep firing drains for a stale user.
class OutboxLifecycle with WidgetsBindingObserver {
  OutboxLifecycle({
    required OutboxService outbox,
    required ConnectivityService connectivity,
  })  : _outbox = outbox,
        _connectivity = connectivity;

  final OutboxService _outbox;
  final ConnectivityService _connectivity;

  String? _userId;
  StreamSubscription<NetworkReachability>? _connectivitySub;
  bool _registered = false;

  /// Start listening. Safe to call multiple times — switching users
  /// just rebinds [userId].
  void bind(String userId) {
    _userId = userId;
    if (!_registered) {
      WidgetsBinding.instance.addObserver(this);
      _registered = true;
    }
    _connectivitySub ??= _connectivity.changes.listen(_onConnectivity);
    // Kick off an opportunistic drain right away so a user signing in
    // with a non-empty queue gets it flushed immediately.
    _maybeDrain();
  }

  /// Stop listening. Use on logout / forced sign-out.
  void unbind() {
    _userId = null;
    if (_registered) {
      WidgetsBinding.instance.removeObserver(this);
      _registered = false;
    }
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  Future<void> dispose() async {
    unbind();
  }

  // ---------------------------------------------------------------------------
  // Triggers
  // ---------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeDrain();
    }
  }

  void _onConnectivity(NetworkReachability r) {
    // Only `online` is interesting — `offline` and `interfaceUp` mean
    // the drainer would just bail in the early-return.
    if (r == NetworkReachability.online) {
      _maybeDrain();
    }
  }

  void _maybeDrain() {
    final uid = _userId;
    if (uid == null || uid.isEmpty) return;
    // Fire-and-forget; OutboxService serialises concurrent drains
    // internally via its mutex.
    // ignore: unawaited_futures
    _outbox.drain(userId: uid);
  }
}
