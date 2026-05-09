import 'package:sqflite/sqflite.dart';
import '../models/word.dart';

class WordRepository {
  final Future<Database> _futureDb;

  const WordRepository(this._futureDb);

  Future<List<Word>> getAll() async {
    final db = await _futureDb;
    final maps = await db.query('words', orderBy: 'created_at DESC');
    return maps.map(Word.fromMap).toList();
  }

  Future<Word?> getById(int id) async {
    final db = await _futureDb;
    final maps = await db.query('words', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Word.fromMap(maps.first);
  }

  Future<List<Word>> search(String query) async {
    final db = await _futureDb;
    final pattern = '%$query%';
    final maps = await db.query(
      'words',
      where: 'word LIKE ? OR translation LIKE ?',
      whereArgs: [pattern, pattern],
      orderBy: 'created_at DESC',
    );
    return maps.map(Word.fromMap).toList();
  }

  Future<List<Word>> filterByCategory(String category) async {
    final db = await _futureDb;
    final maps = await db.query(
      'words',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'created_at DESC',
    );
    return maps.map(Word.fromMap).toList();
  }

  Future<List<Word>> filterByStatus(String status) async {
    final db = await _futureDb;
    final maps = await db.query(
      'words',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'created_at DESC',
    );
    return maps.map(Word.fromMap).toList();
  }

  Future<int> insert(Word word) async {
    final db = await _futureDb;
    return db.insert('words', word.toMap());
  }

  Future<void> update(Word word) async {
    final db = await _futureDb;
    await db.update('words', word.toMap(), where: 'id = ?', whereArgs: [word.id]);
  }

  Future<void> delete(int id) async {
    final db = await _futureDb;
    await db.delete('words', where: 'id = ?', whereArgs: [id]);
  }
}
