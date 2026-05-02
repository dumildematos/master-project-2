import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/sentio_session.dart';

class SentioDatabase {
  static final SentioDatabase _instance = SentioDatabase._();
  factory SentioDatabase() => _instance;
  SentioDatabase._();

  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final dir  = await getDatabasesPath();
    final path = p.join(dir, 'sentio.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE sessions (
            id               TEXT    PRIMARY KEY,
            title            TEXT    NOT NULL,
            start_time       INTEGER NOT NULL,
            end_time         INTEGER,
            duration_seconds INTEGER NOT NULL DEFAULT 0,
            score            INTEGER NOT NULL DEFAULT 0,
            top_emotion      TEXT    NOT NULL DEFAULT 'neutral',
            is_completed     INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE brainwave_samples (
            id             INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id     TEXT    NOT NULL,
            timestamp_ms   INTEGER NOT NULL,
            delta          REAL    NOT NULL,
            theta          REAL    NOT NULL,
            alpha          REAL    NOT NULL,
            beta           REAL    NOT NULL,
            gamma          REAL    NOT NULL,
            signal_quality REAL    NOT NULL,
            emotion        TEXT    NOT NULL,
            confidence     REAL    NOT NULL,
            FOREIGN KEY (session_id) REFERENCES sessions(id)
          )
        ''');
      },
    );
  }

  // ── Sessions ────────────────────────────────────────────────────────────────
  Future<void> insertSession(SentioSession s) async => (await db).insert(
    'sessions', s.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<void> updateSession(SentioSession s) async => (await db).update(
    'sessions', s.toMap(),
    where: 'id = ?', whereArgs: [s.id],
  );

  Future<List<SentioSession>> getAllSessions() async {
    final rows = await (await db).query('sessions', orderBy: 'start_time DESC');
    return rows.map(SentioSession.fromMap).toList();
  }

  Future<SentioSession?> getSession(String id) async {
    final rows = await (await db).query('sessions', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : SentioSession.fromMap(rows.first);
  }

  // ── Brainwave samples ───────────────────────────────────────────────────────
  Future<void> insertSample(BrainwaveSample s) async =>
      (await db).insert('brainwave_samples', s.toMap());

  Future<List<BrainwaveSample>> getSamplesForSession(String sessionId) async {
    final rows = await (await db).query(
      'brainwave_samples',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp_ms ASC',
    );
    return rows.map(BrainwaveSample.fromMap).toList();
  }
}
