import 'package:sqflite/sqflite.dart';
import '../models/mock_test.dart';

class MockTestRepository {
  final Future<Database> _futureDb;

  const MockTestRepository(this._futureDb);

  Future<List<MockTest>> getAll() async {
    final db = await _futureDb;
    final maps = await db.query(
      'mock_tests',
      orderBy: 'date DESC, created_at DESC',
    );
    return maps.map(MockTest.fromMap).toList();
  }

  Future<void> insert(MockTest test) async {
    final db = await _futureDb;
    await db.insert('mock_tests', test.toMap());
  }

  Future<void> delete(int id) async {
    final db = await _futureDb;
    await db.delete('mock_tests', where: 'id = ?', whereArgs: [id]);
  }
}
