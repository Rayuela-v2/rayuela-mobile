import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rayuela_mobile/core/sync/app_database.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Tests for [AppDatabase] using the FFI-backed factory so the suite can
/// run on the host VM (no Android/iOS plugin required).
void main() {
  setUpAll(sqfliteFfiInit);

  group('AppDatabase.open', () {
    late AppDatabase db;

    tearDown(() async {
      await db.close();
    });

    test('creates the v1 schema on a fresh database', () async {
      db = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );

      final tables = await db.db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      );
      final names = tables.map((r) => r['name'] as String).toSet();

      expect(names, contains('outbox_checkins'));
      expect(names, contains('outbox_checkin_images'));
      expect(names, contains('cached_projects'));
      expect(names, contains('cached_tasks'));
      expect(names, contains('cached_leaderboards'));
      expect(names, contains('cached_checkin_history'));
    });

    test('outbox_checkins exposes the documented columns', () async {
      db = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );

      final cols = await db.db.rawQuery('PRAGMA table_info(outbox_checkins)');
      final names = cols.map((r) => r['name'] as String).toSet();

      // A representative subset — the full list is enforced by the
      // migration script itself; we just want to catch accidental drops.
      expect(names, containsAll(<String>{
        'id',
        'user_id',
        'project_id',
        'task_type',
        'latitude',
        'longitude',
        'datetime_iso',
        'status',
        'attempt_count',
        'next_attempt_at',
        'created_at',
        'updated_at',
      }),);
    });

    test('foreign keys cascade-delete attached images', () async {
      db = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );

      await db.db.insert('outbox_checkins', {
        'id': 'abc',
        'user_id': 'u1',
        'project_id': 'p1',
        'task_type': 'observation',
        'latitude': '0',
        'longitude': '0',
        'datetime_iso': '2026-05-01T00:00:00Z',
        'client_captured_at': '2026-05-01T00:00:00Z',
        'status': 'pending',
        'attempt_count': 0,
        'created_at': '2026-05-01T00:00:00Z',
        'updated_at': '2026-05-01T00:00:00Z',
      });
      await db.db.insert('outbox_checkin_images', {
        'outbox_id': 'abc',
        'position': 0,
        'file_path': '/tmp/0.jpg',
        'byte_size': 1234,
        'mime_type': 'image/jpeg',
      });

      final before = await db.db.query('outbox_checkin_images');
      expect(before, hasLength(1));

      await db.db.delete('outbox_checkins', where: 'id = ?', whereArgs: ['abc']);

      final after = await db.db.query('outbox_checkin_images');
      expect(after, isEmpty,
          reason: 'ON DELETE CASCADE should have removed the image row',);
    });

    test('reopening preserves the schema (migration is idempotent)',
        () async {
      // Use a temp file path so the second open hits the existing DB.
      final tempDir = await Directory.systemTemp
          .createTemp('rayuela_appdb_reopen_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final path = p.join(tempDir.path, 'rayuela.db');

      db = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
      await db.close();

      db = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
      final v = await db.db.rawQuery('PRAGMA user_version');
      expect(v.first.values.first, AppDatabase.schemaVersion);
    });
  });
}
