import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rayuela_mobile/core/storage/image_store.dart';

/// Tests for [ImageStore]. We bypass [FlutterImageCompressorImpl] (which
/// needs the Flutter engine) by injecting [PassthroughImageCompressor].
void main() {
  late Directory tempRoot;
  late Directory baseDir;
  late ImageStore store;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('rayuela_imagestore_');
    baseDir = Directory(p.join(tempRoot.path, 'outbox'))..createSync();
    store = ImageStore(
      baseDir: baseDir,
      compressor: const PassthroughImageCompressor(),
    );
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  Future<String> writeSourceFile(String name, List<int> bytes) async {
    final f = File(p.join(tempRoot.path, name));
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }

  test('persist copies each source into outbox/<id>/<position>.jpg',
      () async {
    final s1 = await writeSourceFile('a.jpg', List.filled(64, 1));
    final s2 = await writeSourceFile('b.jpg', List.filled(32, 2));

    final stored = await store.persist(
      outboxId: 'cake-001',
      sourcePaths: [s1, s2],
    );

    expect(stored, hasLength(2));
    expect(stored[0].path, endsWith('cake-001/0.jpg'));
    expect(stored[1].path, endsWith('cake-001/1.jpg'));
    expect(stored[0].mimeType, 'image/jpeg');

    final dir = Directory(p.join(baseDir.path, 'cake-001'));
    expect(await dir.exists(), isTrue);

    final f0 = File(stored[0].path);
    expect(await f0.length(), 64);
    expect(stored[0].byteSize, 64);
  });

  test('persist throws and rolls back the directory if a source is missing',
      () async {
    final ok = await writeSourceFile('ok.jpg', List.filled(8, 9));
    final bogus = p.join(tempRoot.path, 'does-not-exist.jpg');

    await expectLater(
      () => store.persist(outboxId: 'broken', sourcePaths: [ok, bogus]),
      throwsA(isA<FileSystemException>()),
    );

    expect(
      Directory(p.join(baseDir.path, 'broken')).existsSync(),
      isFalse,
      reason: 'Failed persist should leave no half-written folder behind',
    );
  });

  test('deleteForOutbox removes the directory and is idempotent', () async {
    final src = await writeSourceFile('one.jpg', [0, 1, 2, 3]);
    await store.persist(outboxId: 'id-1', sourcePaths: [src]);

    final dir = Directory(p.join(baseDir.path, 'id-1'));
    expect(await dir.exists(), isTrue);

    await store.deleteForOutbox('id-1');
    expect(await dir.exists(), isFalse);

    // Calling again on a missing folder must not throw.
    await store.deleteForOutbox('id-1');
  });

  test('sweepOrphans removes folders not in knownIds and old enough',
      () async {
    final src = await writeSourceFile('z.jpg', [0]);
    await store.persist(outboxId: 'still-pending', sourcePaths: [src]);
    await store.persist(outboxId: 'orphan', sourcePaths: [src]);

    // Backdate the orphan's mtime to satisfy the minAge cutoff.
    final orphanDir = Directory(p.join(baseDir.path, 'orphan'));
    final old = DateTime.now().subtract(const Duration(days: 2));
    for (final f in orphanDir.listSync()) {
      if (f is File) {
        await f.setLastModified(old);
      }
    }

    final removed = await store.sweepOrphans(
      knownIds: {'still-pending'},
    );

    expect(removed, 1);
    expect(orphanDir.existsSync(), isFalse);
    expect(
      Directory(p.join(baseDir.path, 'still-pending')).existsSync(),
      isTrue,
    );
  });

  test('totalBytesUsed sums every file under baseDir', () async {
    final src = await writeSourceFile(
      'b.jpg',
      Uint8List.fromList(List.filled(100, 7)),
    );
    await store.persist(outboxId: 'bag', sourcePaths: [src, src]);

    expect(await store.totalBytesUsed(), 200);
  });
}
