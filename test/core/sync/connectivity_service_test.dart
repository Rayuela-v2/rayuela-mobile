import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rayuela_mobile/core/sync/connectivity_service.dart';

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late _MockConnectivity connectivity;
  late StreamController<List<ConnectivityResult>> changeController;

  setUp(() {
    connectivity = _MockConnectivity();
    changeController = StreamController.broadcast();
    when(() => connectivity.onConnectivityChanged)
        .thenAnswer((_) => changeController.stream);
  });

  tearDown(() async {
    await changeController.close();
  });

  /// Helper: wait for the seed-state evaluation to land on `_last`.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('reports offline when no interface is up', () async {
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.none]);

    final svc = ConnectivityService(
      connectivity: connectivity,
      probe: () async => true, // probe is irrelevant when offline
    );
    await settle();

    expect(await svc.refresh(force: true), NetworkReachability.offline);
    expect(svc.current, NetworkReachability.offline);

    await svc.dispose();
  });

  test('promotes interfaceUp to online when the probe succeeds', () async {
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.wifi]);

    final svc = ConnectivityService(
      connectivity: connectivity,
      probe: () async => true,
    );

    expect(await svc.refresh(force: true), NetworkReachability.online);
    expect(svc.current, NetworkReachability.online);

    await svc.dispose();
  });

  test('keeps state at interfaceUp when the probe fails', () async {
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.mobile]);

    final svc = ConnectivityService(
      connectivity: connectivity,
      probe: () async => false,
    );

    expect(await svc.refresh(force: true), NetworkReachability.interfaceUp);

    await svc.dispose();
  });

  test('emits change events on the broadcast stream', () async {
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.none]);

    final svc = ConnectivityService(
      connectivity: connectivity,
      probe: () async => true,
    );
    await settle();

    final emitted = <NetworkReachability>[];
    final sub = svc.changes.listen(emitted.add);

    // Simulate the OS reporting wifi has come up.
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.wifi]);
    changeController.add([ConnectivityResult.wifi]);
    await settle();
    await settle();

    expect(emitted, contains(NetworkReachability.online));

    await sub.cancel();
    await svc.dispose();
  });

  test('throttles probes by cooldown unless force=true is passed',
      () async {
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.wifi]);

    var probeCalls = 0;
    final svc = ConnectivityService(
      connectivity: connectivity,
      probe: () async {
        probeCalls++;
        return true;
      },
    );

    await svc.refresh(force: true);
    final firstCallCount = probeCalls;
    expect(firstCallCount, greaterThanOrEqualTo(1));

    // Within cooldown, refresh() should not re-probe.
    await svc.refresh();
    expect(probeCalls, firstCallCount);

    // force=true bypasses the cooldown.
    await svc.refresh(force: true);
    expect(probeCalls, greaterThan(firstCallCount));

    await svc.dispose();
  });
}
