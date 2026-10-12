import 'package:sqflite/sqflite.dart';
import '../models/phrase.dart';

class PhraseRepository {
  final Future<Database> _futureDb;
  const PhraseRepository(this._futureDb);

  Future<List<Phrase>> getAll() async {
    final db = await _futureDb;
    final maps = await db.query('phrases', orderBy: 'created_at DESC');
    return maps.map(Phrase.fromMap).toList();
  }

  Future<Phrase?> getById(int id) async {
    final db = await _futureDb;
    final maps = await db.query('phrases', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Phrase.fromMap(maps.first);
  }

  Future<List<Phrase>> search(String query) async {
    final db = await _futureDb;
    final maps = await db.query(
      'phrases',
      where: 'phrase LIKE ? OR translation LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'created_at DESC',
    );
    return maps.map(Phrase.fromMap).toList();
  }

  Future<List<Phrase>> filterByStatus(String status) async {
    final db = await _futureDb;
    final maps = await db.query(
      'phrases',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'created_at DESC',
    );
    return maps.map(Phrase.fromMap).toList();
  }

  Future<void> insert(Phrase phrase) async {
    final db = await _futureDb;
    await db.insert('phrases', phrase.toMap());
  }

  Future<void> update(Phrase phrase) async {
    final db = await _futureDb;
    await db.update('phrases', phrase.toMap(),
        where: 'id = ?', whereArgs: [phrase.id]);
  }

  Future<void> delete(int id) async {
    final db = await _futureDb;
    await db.delete('phrases', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Phrase>> getDue() async {
    final db = await _futureDb;
    final now = DateTime.now().millisecondsSinceEpoch;
    final maps = await db.rawQuery(
      'SELECT * FROM phrases WHERE next_review_at IS NULL OR next_review_at <= ? ORDER BY next_review_at ASC, created_at ASC',
      [now],
    );
    return maps.map(Phrase.fromMap).toList();
  }

  Future<void> updateSM2(
    int id, {
    required DateTime nextReviewAt,
    required double easeFactor,
    required int srRepetitions,
    required int srInterval,
  }) async {
    final db = await _futureDb;
    await db.update(
      'phrases',
      {
        'next_review_at': nextReviewAt.millisecondsSinceEpoch,
        'ease_factor': easeFactor,
        'sr_repetitions': srRepetitions,
        'sr_interval': srInterval,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
