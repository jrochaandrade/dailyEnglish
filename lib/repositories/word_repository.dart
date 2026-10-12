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

    final q = _removeDiacritics(query.toLowerCase().trim());

    // Returns relevance score > 0 if the word matches, 0 if it doesn't.
    // Higher score = shown first.
    //
    // Reverse-contains (query contains dict entry) only applies to the English
    // word field — otherwise short Portuguese words like "urso" falsely match
    // unrelated words that happen to contain "urso" as a substring (e.g. "concurso").
    int score(Word w) {
      final nWord = _removeDiacritics(w.word.toLowerCase().trim());

      if (nWord == q) return 4;
      if (nWord.contains(q)) return 3;
      // Conjugation/plural match — English only (e.g. "studying" → finds "study")
      if (nWord.length >= 3 && q.contains(nWord)) return 2;
      // Fuzzy prefix match — English only
      if (nWord.length > 4 && q.length > 4) {
        final minLen = nWord.length < q.length ? nWord.length : q.length;
        int prefix = 0;
        for (int i = 0; i < minLen; i++) {
          if (nWord[i] == q[i]) {
            prefix++;
          } else {
            break;
          }
        }
        if (prefix >= minLen - 2 && prefix >= 4) return 1;
      }

      // Translation fields: exact match or translation contains the query only.
      // No reverse-contains here to avoid false positives.
      for (final raw in [
        w.translation,
        w.translation2 ?? '',
        w.translation3 ?? ''
      ]) {
        if (raw.isEmpty) continue;
        final nT = _removeDiacritics(raw.toLowerCase().trim());
        if (nT == q || nT.contains(q)) return 1;
      }

      return 0;
    }

    final scores = <Word, int>{for (final w in words) w: score(w)};
    return words.where((w) => scores[w]! > 0).toList()
      ..sort((a, b) => scores[b]!.compareTo(scores[a]!));
  }

  String _removeDiacritics(String str) {
    var withDia =
        'ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
    var withoutDia =
        'AAAAAAaaaaaaOOOOOOOooooooEEEEeeeeeCcDIIIIiiiiUUUUuuuuNnSsYyyZz';
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
    await db
        .update('words', word.toMap(), where: 'id = ?', whereArgs: [word.id]);
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
