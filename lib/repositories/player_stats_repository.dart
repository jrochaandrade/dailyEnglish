import 'package:sqflite/sqflite.dart';
import '../models/player_stats.dart';

class PlayerStatsRepository {
  final Future<Database> _futureDb;
  const PlayerStatsRepository(this._futureDb);

  Future<PlayerStats> load() async {
    final db = await _futureDb;
    final maps = await db.query('player_stats', where: 'id = ?', whereArgs: [1]);
    if (maps.isEmpty) {
      const stats = PlayerStats();
      await db.insert('player_stats', stats.toMap());
      return stats;
    }
    return PlayerStats.fromMap(maps.first);
  }

  Future<void> save(PlayerStats stats) async {
    final db = await _futureDb;
    await db.insert(
      'player_stats',
      stats.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
