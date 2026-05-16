import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rayuela_mobile/core/sync/connectivity_service.dart';
import 'package:rayuela_mobile/core/sync/outbox/outbox_lifecycle.dart';
import 'package:rayuela_mobile/core/sync/outbox/outbox_service.dart';

class _MockOutbox extends Mock implements OutboxService {}
class _MockConnectivity extends Mock implements ConnectivityService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockOutbox outbox;
  late _MockConnectivity connectivity;
  late StreamController<NetworkReachability> changes;

  setUp(() {
    outbox = _MockOutbox();
    connectivity = _MockConnectivity();
    changes = StreamController<NetworkReachability>.broadcast();
    when(() => connectivity.changes).thenAnswer((_) => changes.stream);
    when(() => outbox.drain(userId: any(named: 'userId')))
        .thenAnswer((_) async {});
  });

  tearDown(() async {
    await changes.close();
  });

  test('bind triggers an opportunistic drain', () async {
    final lc = OutboxLifecycle(outbox: outbox, connectivity: connectivity);
    lc.bind('u1');
    await Future<void>.delayed(Duration.zero);
    verify(() => outbox.drain(userId: 'u1')).called(1);
  });

  test('connectivity online while bound triggers a drain', () async {
    final lc = OutboxLifecycle(outbox: outbox, connectivity: connectivity);
    lc.bind('u1');
    await Future<void>.delayed(Duration.zero);
    clearInteractions(outbox);

    changes.add(NetworkReachability.online);
    await Future<void>.delayed(Duration.zero);
    verify(() => outbox.drain(userId: 'u1')).called(1);
  });

  test('connectivity online while unbound does not drain', () async {
    final lc = OutboxLifecycle(outbox: outbox, connectivity: connectivity);
    lc.bind('u1');
    await Future<void>.delayed(Duration.zero);
    lc.unbind();
    clearInteractions(outbox);

    changes.add(NetworkReachability.online);
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => outbox.drain(userId: any(named: 'userId')));
  });

  test('connectivity offline/interfaceUp does not trigger a drain', () async {
    final lc = OutboxLifecycle(outbox: outbox, connectivity: connectivity);
    lc.bind('u1');
    await Future<void>.delayed(Duration.zero);
    clearInteractions(outbox);

    changes.add(NetworkReachability.offline);
    changes.add(NetworkReachability.interfaceUp);
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => outbox.drain(userId: any(named: 'userId')));
  });

  test('app resume while bound triggers a drain', () async {
    final lc = OutboxLifecycle(outbox: outbox, connectivity: connectivity);
    lc.bind('u1');
    await Future<void>.delayed(Duration.zero);
    clearInteractions(outbox);

    lc.didChangeAppLifecycleState(AppLifecycleState.resumed);
    verify(() => outbox.drain(userId: 'u1')).called(1);
  });
}
