import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:rayuela_mobile/core/storage/image_store.dart';
import 'package:rayuela_mobile/core/sync/app_database.dart';
import 'package:rayuela_mobile/core/sync/connectivity_service.dart';
import 'package:rayuela_mobile/core/sync/outbox/backoff_strategy.dart';
import 'package:rayuela_mobile/core/sync/outbox/outbox_dao.dart';
import 'package:rayuela_mobile/core/sync/outbox/outbox_entry.dart';
import 'package:rayuela_mobile/core/sync/outbox/outbox_sender.dart';
import 'package:rayuela_mobile/core/sync/outbox/outbox_service.dart';
import 'package:rayuela_mobile/core/sync/outbox/sync_status.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

class _MockConnectivity extends Mock implements Connectivity {}

class _MockUuid extends Mock implements Uuid {}

/// In-memory sender programmed with a sequence of outcomes.
class _ScriptedSender implements OutboxSender {
  _ScriptedSender(this._script);

  final List<OutboxSendOutcome> _script;
  final List<String> sent = [];

  @override
  Future<OutboxSendOutcome> send(OutboxEntry entry) async {
    sent.add(entry.id);
    if (_script.isEmpty) return const OutboxSendSucceeded();
    return _script.removeAt(0);
  }
}

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory tempRoot;
  late ImageStore imageStore;
  late AppDatabase db;
  late OutboxDao dao;
  late ConnectivityService connectivity;
  late _MockConnectivity rawConnectivity;
  late StreamController<List<ConnectivityResult>> connectivityChanges;

  Future<String> writeFakeJpeg(String name) async {
    final f = File(p.join(tempRoot.path, name));
    await f.writeAsBytes(List.filled(8, 1));
    return f.path;
  }

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('rayuela_outbox_svc_');
    imageStore = ImageStore(
      baseDir: Directory(p.join(tempRoot.path, 'outbox'))..createSync(),
      compressor: const PassthroughImageCompressor(),
    );
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    dao = OutboxDao(db.db);

    rawConnectivity = _MockConnectivity();
    connectivityChanges = StreamController.broadcast();
    when(() => rawConnectivity.onConnectivityChanged)
        .thenAnswer((_) => connectivityChanges.stream);
    when(() => rawConnectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.wifi]);
    connectivity = ConnectivityService(
      connectivity: rawConnectivity,
      probe: () async => true,
    );
    // Settle the seed-state evaluation before any test starts probing.
    await connectivity.refresh(force: true);
  });

  tearDown(() async {
    await connectivity.dispose();
    await connectivityChanges.close();
    await db.close();
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  group('enqueue', () {
    test('persists an outbox row with stored image copies', () async {
      final svc = OutboxService(
        dao: dao,
        imageStore: imageStore,
        connectivity: connectivity,
        sender: _ScriptedSender([]),
        uuid: const Uuid(),
      );
      addTearDown(svc.dispose);

      final src = await writeFakeJpeg('a.jpg');
      final entry = await svc.enqueue(
        userId: 'u1',
        projectId: 'p1',
        taskType: 'observation',
        latitude: '0',
        longitude: '0',
        datetime: DateTime.utc(2026, 5, 1, 12),
        sourceImagePaths: [src],
      );

      expect(entry.status, OutboxStatus.pending);
      expect(entry.images, hasLength(1));
      expect(File(entry.images.first.filePath).existsSync(), isTrue);

      final fromDb = await dao.findById(entry.id);
      expect(fromDb, isNotNull);
      expect(fromDb!.images.first.filePath, entry.images.first.filePath);
    });

    test('rolls back the on-disk folder if the SQLite insert fails',
        () async {
      // Pre-insert a row with the same id so the second insert blows up.
      final fixedId = const Uuid().v4();
      await dao.insert(
        OutboxEntry(
          id: fixedId,
          userId: 'u1',
          projectId: 'p1',
          taskType: 'observation',
          latitude: '0',
          longitude: '0',
          datetime: DateTime.utc(2026, 5),
          clientCapturedAt: DateTime.utc(2026, 5),
          images: const [],
          status: OutboxStatus.pending,
          attemptCount: 0,
          createdAt: DateTime.utc(2026, 5),
          updatedAt: DateTime.utc(2026, 5),
        ),
      );

      final stubUuid = _MockUuid();
      when(stubUuid.v4).thenReturn(fixedId);

      final svc = OutboxService(
        dao: dao,
        imageStore: imageStore,
        connectivity: connectivity,
        sender: _ScriptedSender([]),
        uuid: stubUuid,
      );
      addTearDown(svc.dispose);

      final src = await writeFakeJpeg('b.jpg');
      await expectLater(
        () => svc.enqueue(
          userId: 'u1',
          projectId: 'p1',
          taskType: 'observation',
          latitude: '0',
          longitude: '0',
          datetime: DateTime.utc(2026, 5, 1, 12),
          sourceImagePaths: [src],
        ),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        Directory(p.join(imageStore.baseDir.path, fixedId)).existsSync(),
        isFalse,
        reason: 'Failed insert must clean up the orphan image folder',
      );
    });
  });

  group('drain', () {
    test('processes rows in FIFO order and clears successful ones',
        () async {
      final sender = _ScriptedSender([
        const OutboxSendSucceeded(),
        const OutboxSendSucceeded(),
      ]);
      final svc = OutboxService(
        dao: dao,
        imageStore: imageStore,
        connectivity: connectivity,
        sender: sender,
      );
      addTearDown(svc.dispose);

      final src = await writeFakeJpeg('c.jpg');
      final first = await svc.enqueue(
        userId: 'u1',
        projectId: 'p1',
        taskType: 'observation',
        latitude: '0',
        longitude: '0',
        datetime: DateTime.utc(2026, 5, 1, 8),
        sourceImagePaths: [src],
      );
      final second = await svc.enqueue(
        userId: 'u1',
        projectId: 'p1',
        taskType: 'observation',
        latitude: '0',
        longitude: '0',
        datetime: DateTime.utc(2026, 5, 1, 9),
        sourceImagePaths: [src],
      );

      await svc.drain(userId: 'u1');

      expect(sender.sent, [first.id, second.id]);
      expect(await dao.pendingCount('u1'), 0);
      expect(svc.status, SyncStatus.idle);
    });

    test('treats AlreadyExists as success and removes the row', () async {
      final sender = _ScriptedSender([const OutboxSendAlreadyExists()]);
      final svc = OutboxService(
        dao: dao,
        imageStore: imageStore,
        connectivity: connectivity,
        sender: sender,
      );
      addTearDown(svc.dispose);

      final src = await writeFakeJpeg('d.jpg');
      final entry = await svc.enqueue(
        userId: 'u1',
        projectId: 'p1',
        taskType: 'observation',
        latitude: '0',
        longitude: '0',
        datetime: DateTime.utc(2026, 5),
        sourceImagePaths: [src],
      );

      await svc.drain(userId: 'u1');
      expect(await dao.findById(entry.id), isNull);
    });

    test('schedules a retry on retryable failure and stops the cycle',
        () async {
      // Two rows: first is retryable, second should NOT be touched in the
      // same cycle (we bail to give the server breathing room).
      final sender = _ScriptedSender([
        const OutboxSendRetryable(code: 'http_503', message: 'busy'),
      ]);
      final svc = OutboxService(
        dao: dao,
        imageStore: imageStore,
        connectivity: connectivity,
        sender: sender,
        backoff: JitteredExponentialBackoff(
          scheduleSeconds: const [60, 120],
          jitterRatio: 0,
        ),
      );
      addTearDown(svc.dispose);

      final src = await writeFakeJpeg('e.jpg');
      final first = await svc.enqueue(
        userId: 'u1',
        projectId: 'p1',
        taskType: 'observation',
        latitude: '0',
        longitude: '0',
        datetime: DateTime.utc(2026, 5, 1, 8),
        sourceImagePaths: [src],
      );
      await svc.enqueue(
        userId: 'u1',
        projectId: 'p1',
        taskType: 'observation',
        latitude: '0',
        longitude: '0',
        datetime: DateTime.utc(2026, 5, 1, 9),
        sourceImagePaths: [src],
      );

      await svc.drain(userId: 'u1');

      expect(sender.sent, [first.id]);
      final firstRow = await dao.findById(first.id);
      expect(firstRow!.status, OutboxStatus.failed);
      expect(firstRow.attemptCount, 1);
      expect(firstRow.nextAttemptAt, isNotNull);
    });

    test('marks rows dead on permanent failure', () async {
      final sender = _ScriptedSender([
        const OutboxSendPermanent(code: 'validation', message: 'bad'),
      ]);
      final svc = OutboxService(
        dao: dao,
        imageStore: imageStore,
        connectivity: connectivity,
        sender: sender,
      );
      addTearDown(svc.dispose);

      final src = await writeFakeJpeg('f.jpg');
      final entry = await svc.enqueue(
        userId: 'u1',
        projectId: 'p1',
        taskType: 'observation',
        latitude: '0',
        longitude: '0',
        datetime: DateTime.utc(2026, 5),
        sourceImagePaths: [src],
      );

      await svc.drain(userId: 'u1');
      final row = await dao.findById(entry.id);
      expect(row!.status, OutboxStatus.dead);
      expect(svc.status, SyncStatus.error);
    });

    test('skips processing entirely when offline', () async {
      // Switch to offline by re-stubbing both the immediate check and
      // promoting the cached state via a forced refresh.
      when(() => rawConnectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.none]);
      await connectivity.refresh(force: true);

      final sender = _ScriptedSender([const OutboxSendSucceeded()]);
      final svc = OutboxService(
        dao: dao,
        imageStore: imageStore,
        connectivity: connectivity,
        sender: sender,
      );
      addTearDown(svc.dispose);

      final src = await writeFakeJpeg('g.jpg');
      await svc.enqueue(
        userId: 'u1',
        projectId: 'p1',
        taskType: 'observation',
        latitude: '0',
        longitude: '0',
        datetime: DateTime.utc(2026, 5),
        sourceImagePaths: [src],
      );

      await svc.drain(userId: 'u1');
      expect(sender.sent, isEmpty);
      expect(svc.status, SyncStatus.offline);
      expect(await dao.pendingCount('u1'), 1);
    });
  });
}

