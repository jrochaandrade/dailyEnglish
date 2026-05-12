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
    final words = await getAll();
    if (query.trim().isEmpty) return words;
    
    final normalizedQuery = _removeDiacritics(query.toLowerCase().trim());
    
    return words.where((w) {
      final nWord = _removeDiacritics(w.word.toLowerCase().trim());
      final nTrans = _removeDiacritics(w.translation.toLowerCase().trim());
      final nTrans2 = _removeDiacritics((w.translation2 ?? '').toLowerCase().trim());
      final nTrans3 = _removeDiacritics((w.translation3 ?? '').toLowerCase().trim());
      
      bool isMatch(String dictStr) {
        if (dictStr.isEmpty) return false;
        if (dictStr.contains(normalizedQuery)) return true;
        if (dictStr.length >= 3 && normalizedQuery.contains(dictStr)) return true;
        if (dictStr == normalizedQuery) return true;
        
        // Fuzzy plural/conjugation match: e.g. "por volta de" vs "por volta das"
        if (dictStr.length > 4 && normalizedQuery.length > 4) {
          int minLen = dictStr.length < normalizedQuery.length ? dictStr.length : normalizedQuery.length;
          int prefixMatchLen = 0;
          for (int i = 0; i < minLen; i++) {
            if (dictStr[i] == normalizedQuery[i]) {
              prefixMatchLen++;
            } else {
              break;
            }
          }
          // If the prefix matches the entire shorter string except the last 1 or 2 characters
          if (prefixMatchLen >= minLen - 2 && prefixMatchLen >= 4) {
            return true;
          }
        }
        
        return false;
      }

      return isMatch(nWord) || isMatch(nTrans) || isMatch(nTrans2) || isMatch(nTrans3);
    }).toList();
  }

  String _removeDiacritics(String str) {
    var withDia = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
    var withoutDia = 'AAAAAAaaaaaaOOOOOOOooooooEEEEeeeeeCcDIIIIiiiiUUUUuuuuNnSsYyyZz';
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str;
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

  Future<List<Word>> getDueWords() async {
    final db = await _futureDb;
    final now = DateTime.now().millisecondsSinceEpoch;
    final maps = await db.rawQuery(
      'SELECT * FROM words WHERE next_review_at IS NULL OR next_review_at <= ? ORDER BY next_review_at ASC, created_at ASC',
      [now],
    );
    return maps.map(Word.fromMap).toList();
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
      'words',
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
