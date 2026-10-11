import 'package:sqflite/sqflite.dart';
import '../models/contest_card.dart';

class ContestCardRepository {
  final Future<Database> _futureDb;
  const ContestCardRepository(this._futureDb);

  Future<List<ContestCard>> getAll({String? subject, String? deck}) async {
    final db = await _futureDb;
    final where = <String>[];
    final args = <Object?>[];
    if (subject != null) {
      where.add('subject = ?');
      args.add(subject);
    }
    if (deck != null) {
      where.add('deck = ?');
      args.add(deck);
    }
    final maps = await db.query(
      'contest_cards',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
    );
    return maps.map(ContestCard.fromMap).toList();
  }

  Future<List<String>> getSubjects() async {
    final db = await _futureDb;
    final rows = await db.rawQuery(
        'SELECT DISTINCT subject FROM contest_cards ORDER BY subject');
    return rows.map((r) => r['subject'] as String).toList();
  }

  Future<List<String>> getDecks({String? subject}) async {
    final db = await _futureDb;
    final rows = await db.query('contest_cards',
        columns: ['deck'],
        distinct: true,
        where: subject == null ? null : 'subject = ?',
        whereArgs: subject == null ? null : [subject],
        orderBy: 'deck');
    return rows.map((r) => r['deck'] as String).toList();
  }

  Future<List<ContestCard>> getDue({String? subject, String? deck}) async {
    final db = await _futureDb;
    final now = DateTime.now().millisecondsSinceEpoch;
    final filters = <String>['(next_review_at IS NULL OR next_review_at <= ?)'];
    final args = <Object?>[now];
    if (subject != null) {
      filters.add('subject = ?');
      args.add(subject);
    }
    if (deck != null) {
      filters.add('deck = ?');
      args.add(deck);
    }
    final rows = await db.query('contest_cards',
        where: filters.join(' AND '),
        whereArgs: args,
        orderBy: 'next_review_at ASC, created_at ASC');
    return rows.map(ContestCard.fromMap).toList();
  }

  Future<int> insert(ContestCard card) async =>
      (await _futureDb).insert('contest_cards', card.toMap());

  Future<void> delete(int id) async => (await _futureDb)
      .delete('contest_cards', where: 'id = ?', whereArgs: [id]);

  Future<void> updateReview(ContestCard card) async {
    await (await _futureDb).update(
        'contest_cards',
        {
          'next_review_at': card.nextReviewAt?.millisecondsSinceEpoch,
          'ease_factor': card.easeFactor,
          'repetitions': card.repetitions,
          'review_interval': card.interval,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [card.id]);
  }
}
