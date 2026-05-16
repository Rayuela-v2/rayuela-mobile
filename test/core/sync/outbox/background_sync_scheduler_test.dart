import 'package:flutter_test/flutter_test.dart';
import 'package:rayuela_mobile/core/sync/outbox/background_sync_scheduler.dart';
import 'package:workmanager/workmanager.dart';

/// In-memory fake that records every call instead of touching the
/// platform plugin. Lets us exercise the scheduler facade in plain
/// `flutter test`.
class _FakeRegistrar implements BackgroundTaskRegistrar {
  final calls = <String>[];
  final periodic = <Map<String, Object?>>[];
  final oneOff = <Map<String, Object?>>[];

  @override
  Future<void> initialize({
    required Function callbackDispatcher,
    bool isInDebugMode = false,
  }) async {
    calls.add('initialize');
  }

  @override
  Future<void> registerPeriodic({
    required String uniqueName,
    required String taskName,
    required Duration frequency,
    required NetworkType networkType,
    required ExistingWorkPolicy existingWorkPolicy,
  }) async {
    calls.add('periodic');
    periodic.add({
      'uniqueName': uniqueName,
      'taskName': taskName,
      'frequency': frequency,
      'networkType': networkType,
      'existingWorkPolicy': existingWorkPolicy,
    });
  }

  @override
  Future<void> registerOneOff({
    required String uniqueName,
    required String taskName,
    required NetworkType networkType,
    required ExistingWorkPolicy existingWorkPolicy,
  }) async {
    calls.add('oneOff');
    oneOff.add({
      'uniqueName': uniqueName,
      'taskName': taskName,
      'networkType': networkType,
      'existingWorkPolicy': existingWorkPolicy,
    });
  }

  @override
  Future<void> cancelByUniqueName(String uniqueName) async {
    calls.add('cancel:$uniqueName');
  }

  @override
  Future<void> cancelAll() async {
    calls.add('cancelAll');
  }
}

void main() {
  late _FakeRegistrar registrar;
  late BackgroundSyncScheduler scheduler;

  setUp(() {
    registrar = _FakeRegistrar();
    scheduler = BackgroundSyncScheduler(registrar: registrar);
  });

  test('initialize is idempotent across calls', () async {
    await scheduler.initialize(() {});
    await scheduler.initialize(() {});
    expect(
      registrar.calls.where((c) => c == 'initialize').length,
      1,
      reason: 'second initialize should short-circuit',
    );
  });

  test('schedulePeriodic forwards with `keep` policy and connected gate',
      () async {
    await scheduler.schedulePeriodic();

    expect(registrar.periodic, hasLength(1));
    final p = registrar.periodic.single;
    expect(p['uniqueName'], BackgroundSyncTaskId.periodic);
    expect(p['existingWorkPolicy'], ExistingWorkPolicy.keep);
    expect(p['networkType'], NetworkType.connected);
    expect(p['frequency'], const Duration(hours: 1));
  });

  test('kickOneOff replaces an existing one-off rather than queueing',
      () async {
    await scheduler.kickOneOff();
    await scheduler.kickOneOff();

    expect(registrar.oneOff, hasLength(2));
    for (final r in registrar.oneOff) {
      expect(r['existingWorkPolicy'], ExistingWorkPolicy.replace);
      expect(r['uniqueName'], BackgroundSyncTaskId.oneOff);
    }
  });

  test('cancelAll forwards to the registrar', () async {
    await scheduler.cancelAll();
    expect(registrar.calls, contains('cancelAll'));
  });

  test('a custom periodicFrequency is honored', () async {
    final s = BackgroundSyncScheduler(
      registrar: registrar,
      periodicFrequency: const Duration(minutes: 30),
    );
    await s.schedulePeriodic();
    expect(
      registrar.periodic.single['frequency'],
      const Duration(minutes: 30),
    );
  });
}
