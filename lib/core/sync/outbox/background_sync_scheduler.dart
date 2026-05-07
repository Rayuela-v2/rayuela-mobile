import 'package:workmanager/workmanager.dart';

/// Stable identifiers used by both the platform and our own
/// scheduling logic. They MUST match the iOS `Info.plist`
/// `BGTaskSchedulerPermittedIdentifiers` entries.
abstract class BackgroundSyncTaskId {
  /// One-off drain triggered by connectivity coming back. Replaces any
  /// previously-scheduled one-off so we never queue several at once.
  static const String oneOff = 'com.rayuela.sync.oneoff';

  /// Periodic drain. Acts as a long-period safety net (default 1 h) for
  /// the cases where the connectivity stream missed a transition.
  static const String periodic = 'com.rayuela.sync.periodic';
}

/// Thin abstraction in front of `Workmanager()` so the rest of the app
/// can talk to "schedule a sync" without knowing about the plugin. Tests
/// can pass a stub registrar; production code uses
/// [WorkmanagerTaskRegistrar].
abstract class BackgroundTaskRegistrar {
  Future<void> initialize({
    required Function callbackDispatcher,
    bool isInDebugMode = false,
  });

  Future<void> registerPeriodic({
    required String uniqueName,
    required String taskName,
    required Duration frequency,
    required NetworkType networkType,
    required ExistingWorkPolicy existingWorkPolicy,
  });

  Future<void> registerOneOff({
    required String uniqueName,
    required String taskName,
    required NetworkType networkType,
    required ExistingWorkPolicy existingWorkPolicy,
  });

  Future<void> cancelByUniqueName(String uniqueName);
  Future<void> cancelAll();
}

/// Default implementation that forwards to the real `Workmanager`
/// singleton. Lives in production code; replaced in tests.
class WorkmanagerTaskRegistrar implements BackgroundTaskRegistrar {
  const WorkmanagerTaskRegistrar();

  @override
  Future<void> initialize({
    required Function callbackDispatcher,
    bool isInDebugMode = false,
  }) {
    return Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: isInDebugMode,
    );
  }

  @override
  Future<void> registerPeriodic({
    required String uniqueName,
    required String taskName,
    required Duration frequency,
    required NetworkType networkType,
    required ExistingWorkPolicy existingWorkPolicy,
  }) {
    return Workmanager().registerPeriodicTask(
      uniqueName,
      taskName,
      frequency: frequency,
      constraints: Constraints(networkType: networkType),
      existingWorkPolicy: existingWorkPolicy,
    );
  }

  @override
  Future<void> registerOneOff({
    required String uniqueName,
    required String taskName,
    required NetworkType networkType,
    required ExistingWorkPolicy existingWorkPolicy,
  }) {
    return Workmanager().registerOneOffTask(
      uniqueName,
      taskName,
      constraints: Constraints(networkType: networkType),
      existingWorkPolicy: existingWorkPolicy,
    );
  }

  @override
  Future<void> cancelByUniqueName(String uniqueName) {
    return Workmanager().cancelByUniqueName(uniqueName);
  }

  @override
  Future<void> cancelAll() => Workmanager().cancelAll();
}

/// User-facing facade for "make sure the outbox drains in the
/// background eventually." The bootstrap sequence calls
/// [initialize] once, [schedulePeriodic] after auth lands, and
/// [kickOneOff] whenever connectivity flips to online.
///
/// Cancellation on logout is critical so we don't keep waking up the
/// device for a user that has signed out.
class BackgroundSyncScheduler {
  BackgroundSyncScheduler({
    required BackgroundTaskRegistrar registrar,
    Duration periodicFrequency = const Duration(hours: 1),
  })  : _registrar = registrar,
        _frequency = periodicFrequency;

  final BackgroundTaskRegistrar _registrar;
  final Duration _frequency;

  bool _initialized = false;

  /// Hook the dispatcher entry-point. Called once during bootstrap.
  /// Subsequent calls are no-ops so it's safe to invoke from multiple
  /// hot-restart paths during development.
  Future<void> initialize(
    Function callbackDispatcher, {
    bool isInDebugMode = false,
  }) async {
    if (_initialized) return;
    await _registrar.initialize(
      callbackDispatcher: callbackDispatcher,
      isInDebugMode: isInDebugMode,
    );
    _initialized = true;
  }

  /// Long-period safety net. Uses `keep` so re-running this on every
  /// auth state change doesn't churn the schedule.
  Future<void> schedulePeriodic() {
    return _registrar.registerPeriodic(
      uniqueName: BackgroundSyncTaskId.periodic,
      taskName: BackgroundSyncTaskId.periodic,
      frequency: _frequency,
      networkType: NetworkType.connected,
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }

  /// "Connectivity just came back, please drain". Replace policy means
  /// flapping connections collapse into a single scheduled task instead
  /// of building up a backlog.
  Future<void> kickOneOff() {
    return _registrar.registerOneOff(
      uniqueName: BackgroundSyncTaskId.oneOff,
      taskName: BackgroundSyncTaskId.oneOff,
      networkType: NetworkType.connected,
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  /// Drop all scheduled tasks. Called on logout so a signed-out user
  /// doesn't keep waking the device.
  Future<void> cancelAll() => _registrar.cancelAll();
}
