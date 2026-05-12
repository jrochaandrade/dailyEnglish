import 'package:flutter_test/flutter_test.dart';
import 'package:daily_english/models/player_stats.dart';

void main() {
  group('PlayerStats.fromMap', () {
    test('parses all fields correctly', () {
      final map = {
        'id': 1,
        'xp': 150,
        'level': 2,
        'streak': 5,
        'shields': 1,
        'last_activity_date': '2026-05-10',
        'streak_at_risk': 0,
        'games_played_today': 'scramble,fill_blank',
      };
      final s = PlayerStats.fromMap(map);
      expect(s.xp, 150);
      expect(s.level, 2);
      expect(s.streak, 5);
      expect(s.shields, 1);
      expect(s.lastActivityDate, '2026-05-10');
      expect(s.streakAtRisk, false);
      expect(s.gamesPlayedToday, 'scramble,fill_blank');
    });

    test('uses defaults for missing fields', () {
      final map = {'id': 1};
      final s = PlayerStats.fromMap(map);
      expect(s.xp, 0);
      expect(s.streak, 0);
      expect(s.shields, 0);
      expect(s.streakAtRisk, false);
      expect(s.gamesPlayedToday, '');
    });

    test('streak_at_risk = 1 maps to true', () {
      final s = PlayerStats.fromMap({'id': 1, 'streak_at_risk': 1});
      expect(s.streakAtRisk, true);
    });
  });

  group('PlayerStats.toMap', () {
    test('includes id = 1 always', () {
      final s = const PlayerStats(xp: 50, streak: 3);
      final map = s.toMap();
      expect(map['id'], 1);
      expect(map['xp'], 50);
      expect(map['streak'], 3);
      expect(map['streak_at_risk'], 0);
    });
  });

  group('PlayerStats.copyWith', () {
    test('updates only specified fields', () {
      const s = PlayerStats(xp: 10, streak: 2, shields: 1);
      final s2 = s.copyWith(xp: 20);
      expect(s2.xp, 20);
      expect(s2.streak, 2);
      expect(s2.shields, 1);
    });
  });
}
