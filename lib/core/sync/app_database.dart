import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Schema/migration owner for the app's local SQLite database.
///
/// Hosts the offline outbox (queued check-ins + attached image rows) and
/// the read-side caches (projects, tasks, leaderboards, check-in history)
/// described in `docs/OFFLINE_SYNC_PLAN.md` §4.
///
/// Design notes:
///   * Migrations are forward-only and idempotent; each script runs once,
///     gated by `onUpgrade`. We never DROP user data implicitly — adding
///     a migration that loses content requires an explicit data move.
///   * The database is opened with WAL journal mode and
///     `synchronous=NORMAL` so a crash mid-write doesn't lose
///     transactions while keeping write latency reasonable.
///   * The class is intentionally testable: callers can inject a
///     [DatabaseFactory] (the `sqflite_common_ffi` factory in `flutter
///     test`) and a custom on-disk path. Production code uses the
///     defaults.
class AppDatabase {
  AppDatabase._(this._db);

  /// Underlying database. Repositories should depend on [Database] (passed
  /// from a Riverpod provider) rather than this wrapper to keep the
  /// public surface small.
  final Database _db;

  Database get db => _db;

  static const String defaultFileName = 'rayuela.db';

  /// Current schema version. Bump this whenever a new migration is added
  /// in [_migrations]. The DB engine guarantees `onUpgrade` runs exactly
  /// once per version step on existing installs.
  static const int schemaVersion = 2;

  /// Open (or create) the local database.
  ///
  /// [factory] lets tests substitute the FFI-backed factory exposed by
  /// `sqflite_common_ffi`. When omitted we fall back to the default
  /// platform plugin.
  ///
  /// [path] overrides the default file location. When null we resolve
  /// the platform's database directory and place [defaultFileName] there.
  /// Pass [inMemoryDatabasePath] for ephemeral test databases.
  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final fac = factory ?? databaseFactory;
    final resolvedPath = path ?? p.join(await fac.getDatabasesPath(), defaultFileName);

    final db = await fac.openDatabase(
      resolvedPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    return AppDatabase._(db);
  }

  /// Convenience for tests and for the bootstrap shutdown hook.
  Future<void> close() => _db.close();

  // ---------------------------------------------------------------------------
  // Lifecycle hooks
  // ---------------------------------------------------------------------------

  /// Runs on every open BEFORE [onCreate]/[onUpgrade]. Used to enable
  /// foreign-key enforcement (sqflite disables it by default) and the
  /// WAL journal mode that we rely on for crash safety.
  static Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    // WAL gives us atomic commits without fsync per write. `journal_mode`
    // is a query: we issue a `rawQuery` to satisfy the `PRAGMA = ...`
    // contract on Android/iOS where `execute` doesn't return rows.
    await db.rawQuery('PRAGMA journal_mode = WAL');
    await db.execute('PRAGMA synchronous = NORMAL');
  }

  static Future<void> _onCreate(Database db, int version) async {
    // First install: run every migration in sequence so a fresh DB ends
    // up at the latest schema. `version` here is whatever we passed in
    // [open] (i.e. [schemaVersion]); we still iterate to keep one source
    // of truth for table definitions.
    for (var v = 1; v <= version; v++) {
      final script = _migrations[v];
      if (script != null) {
        await script(db);
      }
    }
  }

  static Future<void> _onUpgrade(Database db, int from, int to) async {
    for (var v = from + 1; v <= to; v++) {
      final script = _migrations[v];
      if (script != null) {
        await script(db);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Migrations
  // ---------------------------------------------------------------------------

  /// Versioned migration scripts, keyed by the schema version they
  /// produce. Add a new entry whenever [schemaVersion] is bumped — never
  /// edit existing entries (released installs already ran them).
  static final Map<int, Future<void> Function(Database db)> _migrations = {
    1: _migrateToV1,
    2: _migrateToV2,
  };

  static Future<void> _migrateToV1(Database db) async {
    // ---- Outbox: queued check-in submissions ----------------------------
    await db.execute('''
      CREATE TABLE outbox_checkins (
        id                 TEXT    PRIMARY KEY,
        user_id            TEXT    NOT NULL,
        project_id         TEXT    NOT NULL,
        task_id            TEXT,
        task_type          TEXT    NOT NULL,
        latitude           TEXT    NOT NULL,
        longitude          TEXT    NOT NULL,
        datetime_iso       TEXT    NOT NULL,
        client_captured_at TEXT    NOT NULL,
        notes              TEXT,
        status             TEXT    NOT NULL,
        attempt_count      INTEGER NOT NULL DEFAULT 0,
        next_attempt_at    TEXT,
        last_error_code    TEXT,
        last_error_message TEXT,
        created_at         TEXT    NOT NULL,
        updated_at         TEXT    NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_outbox_user_status '
      'ON outbox_checkins(user_id, status, next_attempt_at)',
    );
    await db.execute(
      'CREATE INDEX idx_outbox_project '
      'ON outbox_checkins(project_id, created_at)',
    );

    // ---- Outbox image attachments (1:N, ordered by `position`) ----------
    await db.execute('''
      CREATE TABLE outbox_checkin_images (
        outbox_id  TEXT    NOT NULL,
        position   INTEGER NOT NULL,
        file_path  TEXT    NOT NULL,
        byte_size  INTEGER NOT NULL,
        mime_type  TEXT    NOT NULL,
        PRIMARY KEY (outbox_id, position),
        FOREIGN KEY (outbox_id) REFERENCES outbox_checkins(id) ON DELETE CASCADE
      )
    ''');

    // ---- Read-side caches: keyed by (user_id, project_id) ---------------
    // We store the entity as opaque JSON to avoid coupling the schema to
    // the wire DTOs (which evolve with the backend).
    //
    // `cached_projects` carries an extra `is_subscribed` flag so the
    // dashboard query can filter without parsing the JSON; the rest of
    // the project payload sits in `payload_json`.
    await db.execute('''
      CREATE TABLE cached_projects (
        user_id       TEXT    NOT NULL,
        project_id    TEXT    NOT NULL,
        payload_json  TEXT    NOT NULL,
        is_subscribed INTEGER NOT NULL DEFAULT 1,
        fetched_at    TEXT    NOT NULL,
        PRIMARY KEY (user_id, project_id)
      )
    ''');
    for (final table in const [
      'cached_tasks',
      'cached_leaderboards',
      'cached_checkin_history',
    ]) {
      await db.execute('''
        CREATE TABLE $table (
          user_id      TEXT NOT NULL,
          project_id   TEXT NOT NULL,
          payload_json TEXT NOT NULL,
          fetched_at   TEXT NOT NULL,
          PRIMARY KEY (user_id, project_id)
        )
      ''');
    }
  }

  /// The in-app notification centre.
  ///
  /// Deliberately NOT a cache: rows are derived locally from what sync sees
  /// (a badge that started fading, one whose window closed) and they are the
  /// only record that the user was ever told. Two consequences:
  ///
  ///   * `id` is a deterministic fingerprint of the event, so re-syncing the
  ///     same project ten times inserts one row. `INSERT OR IGNORE` does the
  ///     whole dedupe — no read-modify-write, no races.
  ///   * this table must survive a cache wipe. Clearing it re-announces
  ///     everything the user already read.
  ///
  /// Type-specific fields live in `data_json` rather than as columns, so a
  /// new notification kind is a new `type` string and nothing else.
  static Future<void> _migrateToV2(Database db) async {
    await db.execute('''
      CREATE TABLE app_notifications (
        id           TEXT PRIMARY KEY,
        user_id      TEXT NOT NULL,
        type         TEXT NOT NULL,
        project_id   TEXT NOT NULL,
        subject      TEXT NOT NULL,
        data_json    TEXT NOT NULL,
        created_at   TEXT NOT NULL,
        read_at      TEXT,
        seen_at      TEXT
      )
    ''');
    // The centre lists newest-first per user; the bell counts unread.
    await db.execute(
      'CREATE INDEX idx_notifications_user_created '
      'ON app_notifications(user_id, created_at DESC)',
    );
  }
}
