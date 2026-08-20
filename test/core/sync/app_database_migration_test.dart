import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rayuela_mobile/core/sync/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// v1 → v2 is the first upgrade this app has ever shipped, so `onUpgrade`
/// has never actually run on a real install. These tests exercise both
/// entry points against a file-backed database (in-memory always looks like
/// a fresh install and would quietly skip the interesting path).
void main() {
  setUpAll(sqfliteFfiInit);

  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('rayuela_db_test');
    path = '${dir.path}/rayuela.db';
  });

  tearDown(() async => dir.delete(recursive: true));

  Future<bool> hasTable(AppDatabase db, String name) async {
    final rows = await db.db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [name],
    );
    return rows.isNotEmpty;
  }

  test('a fresh install lands on the latest schema', () async {
    final db = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    addTearDown(db.close);

    expect(await hasTable(db, 'app_notifications'), isTrue);
    expect(await hasTable(db, 'outbox_checkins'), isTrue);
    expect(await db.db.getVersion(), AppDatabase.schemaVersion);
  });

  test('an existing v1 install gains the notification centre', () async {
    // Stand in for a phone that has been running the shipped v1 schema.
    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE outbox_checkins (id TEXT PRIMARY KEY)',
          );
          await db.execute('''
            CREATE TABLE cached_projects (
              user_id      TEXT NOT NULL,
              project_id   TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              fetched_at   TEXT NOT NULL,
              PRIMARY KEY (user_id, project_id)
            )
          ''');
        },
      ),
    );
    await legacy.insert('cached_projects', {
      'user_id': 'u1',
      'project_id': 'p1',
      'payload_json': '{"keep":"me"}',
      'fetched_at': DateTime.utc(2026, 1, 1).toIso8601String(),
    });
    await legacy.close();

    final db = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    addTearDown(db.close);

    expect(await hasTable(db, 'app_notifications'), isTrue);
    expect(await db.db.getVersion(), 2);

    // The upgrade must not cost the user their offline cache.
    final rows = await db.db.query('cached_projects');
    expect(rows.single['payload_json'], '{"keep":"me"}');
  });

  test('reopening an up-to-date database changes nothing', () async {
    final first =
        await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    await first.db.insert('app_notifications', {
      'id': 'n1',
      'user_id': 'u1',
      'type': 'badge_fading',
      'project_id': 'p1',
      'subject': 'A',
      'data_json': '{}',
      'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
    });
    await first.close();

    final second =
        await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    addTearDown(second.close);

    // Notifications are a record of what the user was told, not a cache:
    // a reopen that dropped them would re-announce everything they read.
    expect(await second.db.query('app_notifications'), hasLength(1));
  });
}
