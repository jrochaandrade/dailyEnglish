import 'package:sqflite/sqflite.dart';
import '../models/category.dart';

class CategoryRepository {
  final Future<Database> _futureDb;
  const CategoryRepository(this._futureDb);

  Future<List<Category>> getAll() async {
    final db = await _futureDb;
    final maps = await db.query('categories', orderBy: 'name ASC');
    return maps.map(Category.fromMap).toList();
  }

  Future<Category> add(String name) async {
    final db = await _futureDb;
    final now = DateTime.now();
    final id = await db.insert('categories', {
      'name': name.trim(),
      'created_at': now.toIso8601String(),
    });
    return Category(id: id, name: name.trim(), createdAt: now);
  }

  Future<void> update(int id, String name) async {
    final db = await _futureDb;
    await db.update('categories', {'name': name.trim()}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(int id) async {
    final db = await _futureDb;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }
}
