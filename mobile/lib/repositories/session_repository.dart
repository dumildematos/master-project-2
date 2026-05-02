import '../db/sentio_database.dart';
import '../models/sentio_session.dart';

abstract class SessionRepository {
  Future<void> saveSession(SentioSession session);
  Future<void> updateSession(SentioSession session);
  Future<List<SentioSession>> getAllSessions();
  Future<SentioSession?> getSession(String id);
  Future<void> addSample(BrainwaveSample sample);
  Future<List<BrainwaveSample>> getSamplesForSession(String sessionId);
}

class LocalSessionRepository implements SessionRepository {
  final SentioDatabase _db;
  LocalSessionRepository(this._db);

  @override Future<void> saveSession(SentioSession s)   => _db.insertSession(s);
  @override Future<void> updateSession(SentioSession s) => _db.updateSession(s);
  @override Future<List<SentioSession>> getAllSessions() => _db.getAllSessions();
  @override Future<SentioSession?> getSession(String id) => _db.getSession(id);
  @override Future<void> addSample(BrainwaveSample s)   => _db.insertSample(s);
  @override Future<List<BrainwaveSample>> getSamplesForSession(String sid) =>
      _db.getSamplesForSession(sid);
}
