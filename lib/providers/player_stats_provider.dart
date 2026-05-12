import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/player_stats.dart';
import '../repositories/player_stats_repository.dart';
import 'word_provider.dart';

final playerStatsRepositoryProvider = Provider<PlayerStatsRepository>((ref) {
  final appDb = ref.watch(databaseProvider);
  return PlayerStatsRepository(appDb.database);
});

class PlayerStatsNotifier extends AsyncNotifier<PlayerStats> {
  @override
  Future<PlayerStats> build() async {
    final stats = await ref.read(playerStatsRepositoryProvider).load();
    return _checkStreak(stats);
  }

  Future<PlayerStats> _checkStreak(PlayerStats stats) async {
    final today = _todayStr();
    final last = stats.lastActivityDate;
    if (last == null || last == today) return stats;

    final daysDiff = DateTime.parse(today).difference(DateTime.parse(last)).inDays;
    if (daysDiff == 1) return stats;

    final PlayerStats updated;
    if (daysDiff == 2) {
      // Missed exactly 1 day
      if (stats.shields > 0) {
        updated = stats.copyWith(shields: stats.shields - 1, streakAtRisk: false, gamesPlayedToday: '');
      } else {
        updated = stats.copyWith(streakAtRisk: true, gamesPlayedToday: '');
      }
    } else {
      // 3+ days since last play — streak broken
      updated = stats.copyWith(streak: 0, streakAtRisk: false, gamesPlayedToday: '');
    }
    await ref.read(playerStatsRepositoryProvider).save(updated);
    return updated;
  }

  Future<void> recordSession(String gameType, int xpEarned) async {
    final stats = state.valueOrNull;
    if (stats == null) return;

    final today = _todayStr();
    final isFirstPlayToday = stats.lastActivityDate != today;

    final played = isFirstPlayToday
        ? <String>[]
        : (stats.gamesPlayedToday.isEmpty
            ? <String>[]
            : stats.gamesPlayedToday.split(',').toList());
    if (!played.contains(gameType)) played.add(gameType);

    final newXp = stats.xp + xpEarned;
    final newLevel = (newXp ~/ 100) + 1;
    final newStreak = isFirstPlayToday ? stats.streak + 1 : stats.streak;

    // Shield: awarded first time all 3 games played in one day, max 2
    final hadAll = !isFirstPlayToday &&
        stats.gamesPlayedToday.contains('scramble') &&
        stats.gamesPlayedToday.contains('fill_blank') &&
        stats.gamesPlayedToday.contains('multiple_choice');
    final nowHasAll = played.contains('scramble') &&
        played.contains('fill_blank') &&
        played.contains('multiple_choice');
    final newShields = (nowHasAll && !hadAll && stats.shields < 2)
        ? stats.shields + 1
        : stats.shields;

    final updated = PlayerStats(
      xp: newXp,
      level: newLevel,
      streak: newStreak,
      shields: newShields,
      lastActivityDate: today,
      streakAtRisk: false,
      gamesPlayedToday: played.join(','),
    );

    await ref.read(playerStatsRepositoryProvider).save(updated);
    state = AsyncData(updated);
  }

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

final playerStatsProvider =
    AsyncNotifierProvider<PlayerStatsNotifier, PlayerStats>(PlayerStatsNotifier.new);
