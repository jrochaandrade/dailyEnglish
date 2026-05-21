import 'package:sqflite/sqflite.dart';
import '../models/study_session.dart';

class StudySessionRepository {
  final Future<Database> _futureDb;

  const StudySessionRepository(this._futureDb);

  Future<List<StudySession>> getAll() async {
    final db = await _futureDb;
    final maps = await db.query('study_sessions', orderBy: 'date DESC, created_at DESC');
    return maps.map(StudySession.fromMap).toList();
  }

  Future<int> insert(StudySession session) async {
    final db = await _futureDb;
    return db.insert('study_sessions', session.toMap());
  }

  Future<void> delete(int id) async {
    final db = await _futureDb;
    await db.delete('study_sessions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> update(StudySession session) async {
    final db = await _futureDb;
    await db.update(
      'study_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }
}
