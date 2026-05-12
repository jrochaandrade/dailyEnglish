import 'package:sqflite/sqflite.dart';
import '../models/phrasal_verb.dart';

class PhrasalVerbRepository {
  final Future<Database> _futureDb;

  const PhrasalVerbRepository(this._futureDb);

  Future<List<PhrasalVerb>> getAll() async {
    final db = await _futureDb;
    final maps = await db.query('phrasal_verbs', orderBy: 'created_at DESC');
    return maps.map(PhrasalVerb.fromMap).toList();
  }

  Future<PhrasalVerb?> getById(int id) async {
    final db = await _futureDb;
    final maps = await db.query('phrasal_verbs', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return PhrasalVerb.fromMap(maps.first);
  }

  Future<List<PhrasalVerb>> search(String query) async {
    final db = await _futureDb;
    final maps = await db.query(
      'phrasal_verbs',
      where: 'base_verb LIKE ? OR particle LIKE ? OR meaning LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'created_at DESC',
    );
    return maps.map(PhrasalVerb.fromMap).toList();
  }

  Future<List<PhrasalVerb>> filterByStatus(String status) async {
    final db = await _futureDb;
    final maps = await db.query(
      'phrasal_verbs',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'created_at DESC',
    );
    return maps.map(PhrasalVerb.fromMap).toList();
  }

  Future<int> insert(PhrasalVerb pv) async {
    final db = await _futureDb;
    return db.insert('phrasal_verbs', pv.toMap());
  }

  Future<void> update(PhrasalVerb pv) async {
    final db = await _futureDb;
    await db.update('phrasal_verbs', pv.toMap(), where: 'id = ?', whereArgs: [pv.id]);
  }

  Future<void> delete(int id) async {
    final db = await _futureDb;
    await db.delete('phrasal_verbs', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<PhrasalVerb>> getDue() async {
    final db = await _futureDb;
    final now = DateTime.now().millisecondsSinceEpoch;
    final maps = await db.rawQuery(
      'SELECT * FROM phrasal_verbs WHERE next_review_at IS NULL OR next_review_at <= ? ORDER BY next_review_at ASC, created_at ASC',
      [now],
    );
    return maps.map(PhrasalVerb.fromMap).toList();
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
      'phrasal_verbs',
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
