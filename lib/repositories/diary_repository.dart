import 'package:sqflite/sqflite.dart';
import '../models/diary_entry.dart';

class DiaryRepository {
  final Future<Database> _futureDb;

  const DiaryRepository(this._futureDb);

  Future<List<DiaryEntry>> getAll() async {
    final db = await _futureDb;
    final maps = await db.query('diary_entries', orderBy: 'created_at DESC');
    return maps.map(DiaryEntry.fromMap).toList();
  }

  Future<DiaryEntry?> getById(int id) async {
    final db = await _futureDb;
    final maps = await db.query('diary_entries', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return DiaryEntry.fromMap(maps.first);
  }

  Future<int> insert(DiaryEntry entry) async {
    final db = await _futureDb;
    return db.insert('diary_entries', entry.toMap());
  }

  Future<void> update(DiaryEntry entry) async {
    final db = await _futureDb;
    await db.update('diary_entries', entry.toMap(), where: 'id = ?', whereArgs: [entry.id]);
  }

  Future<void> delete(int id) async {
    final db = await _futureDb;
    await db.delete('diary_entries', where: 'id = ?', whereArgs: [id]);
  }
}
