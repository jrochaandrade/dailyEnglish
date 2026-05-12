# Mini-Games & Gamification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add three interactive mini-games (Multiple Choice, Fill in the Blank, Sentence Scramble) with XP, levels, daily streaks, and streak shields to the Daily English Flutter app.

**Architecture:** A `PlayerStats` singleton in SQLite tracks XP/streak/shields via a Riverpod AsyncNotifier. Three `ConsumerStatefulWidget` game screens share a `GameItem` abstraction loaded from words/phrasal verbs/phrases. A `/games` hub screen picks the source and routes to each game. The home stats card expands to show progression.

**Tech Stack:** Flutter, Riverpod (AsyncNotifier), sqflite, go_router, google_fonts, flutter_tts (already installed).

---

## File Map

**Create:**
- `lib/models/player_stats.dart`
- `lib/repositories/player_stats_repository.dart`
- `lib/providers/player_stats_provider.dart`
- `lib/screens/games/game_content.dart`
- `lib/screens/games/games_screen.dart`
- `lib/screens/games/multiple_choice_screen.dart`
- `lib/screens/games/fill_blank_screen.dart`
- `lib/screens/games/sentence_scramble_screen.dart`
- `test/models/player_stats_test.dart`
- `test/repositories/player_stats_repository_test.dart`

**Modify:**
- `lib/core/database/app_database.dart` — version 12, add `player_stats` table
- `lib/core/router/app_router.dart` — add `/games` + 3 game routes
- `lib/screens/home/home_screen.dart` — expanded stats card, Mini-Games button

---

### Task 1: PlayerStats model

**Files:**
- Create: `lib/models/player_stats.dart`
- Create: `test/models/player_stats_test.dart`

- [ ] **Step 1: Write the test**

```dart
// test/models/player_stats_test.dart
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
```

- [ ] **Step 2: Run test — expect failure**

```
flutter test test/models/player_stats_test.dart
```
Expected: FAIL — `player_stats.dart` does not exist.

- [ ] **Step 3: Implement the model**

```dart
// lib/models/player_stats.dart
class PlayerStats {
  final int xp;
  final int level;
  final int streak;
  final int shields;
  final String? lastActivityDate;
  final bool streakAtRisk;
  final String gamesPlayedToday;

  const PlayerStats({
    this.xp = 0,
    this.level = 1,
    this.streak = 0,
    this.shields = 0,
    this.lastActivityDate,
    this.streakAtRisk = false,
    this.gamesPlayedToday = '',
  });

  factory PlayerStats.fromMap(Map<String, dynamic> map) => PlayerStats(
        xp: map['xp'] as int? ?? 0,
        level: map['level'] as int? ?? 1,
        streak: map['streak'] as int? ?? 0,
        shields: map['shields'] as int? ?? 0,
        lastActivityDate: map['last_activity_date'] as String?,
        streakAtRisk: (map['streak_at_risk'] as int? ?? 0) == 1,
        gamesPlayedToday: map['games_played_today'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'id': 1,
        'xp': xp,
        'level': level,
        'streak': streak,
        'shields': shields,
        'last_activity_date': lastActivityDate,
        'streak_at_risk': streakAtRisk ? 1 : 0,
        'games_played_today': gamesPlayedToday,
      };

  PlayerStats copyWith({
    int? xp,
    int? level,
    int? streak,
    int? shields,
    String? lastActivityDate,
    bool? streakAtRisk,
    String? gamesPlayedToday,
  }) =>
      PlayerStats(
        xp: xp ?? this.xp,
        level: level ?? this.level,
        streak: streak ?? this.streak,
        shields: shields ?? this.shields,
        lastActivityDate: lastActivityDate ?? this.lastActivityDate,
        streakAtRisk: streakAtRisk ?? this.streakAtRisk,
        gamesPlayedToday: gamesPlayedToday ?? this.gamesPlayedToday,
      );
}
```

- [ ] **Step 4: Run test — expect pass**

```
flutter test test/models/player_stats_test.dart
```
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```
git add lib/models/player_stats.dart test/models/player_stats_test.dart
git commit -m "feat: add PlayerStats model"
```

---

### Task 2: DB migration v12

**Files:**
- Modify: `lib/core/database/app_database.dart`

- [ ] **Step 1: Bump version to 12 and add table to `_onCreate`**

In `_open()`, change:
```dart
return openDatabase(path, version: 12, onCreate: _onCreate, onUpgrade: _onUpgrade);
```

In `_onCreate`, add after the last `db.execute` block (before the closing `}`):
```dart
    await db.execute('''
      CREATE TABLE player_stats (
        id INTEGER PRIMARY KEY,
        xp INTEGER DEFAULT 0,
        level INTEGER DEFAULT 1,
        streak INTEGER DEFAULT 0,
        shields INTEGER DEFAULT 0,
        last_activity_date TEXT,
        streak_at_risk INTEGER DEFAULT 0,
        games_played_today TEXT DEFAULT ''
      )
    ''');
    await db.insert('player_stats', {
      'id': 1, 'xp': 0, 'level': 1, 'streak': 0, 'shields': 0,
      'streak_at_risk': 0, 'games_played_today': '',
    });
```

- [ ] **Step 2: Add migration block in `_onUpgrade`**

Add at the end of `_onUpgrade`, before the closing `}`:
```dart
    if (oldVersion < 12) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS player_stats (
          id INTEGER PRIMARY KEY,
          xp INTEGER DEFAULT 0,
          level INTEGER DEFAULT 1,
          streak INTEGER DEFAULT 0,
          shields INTEGER DEFAULT 0,
          last_activity_date TEXT,
          streak_at_risk INTEGER DEFAULT 0,
          games_played_today TEXT DEFAULT ''
        )
      ''');
      try {
        await db.insert('player_stats', {
          'id': 1, 'xp': 0, 'level': 1, 'streak': 0, 'shields': 0,
          'streak_at_risk': 0, 'games_played_today': '',
        });
      } catch (_) {}
    }
```

- [ ] **Step 3: Analyze**

```
flutter analyze lib/core/database/app_database.dart
```
Expected: No errors.

- [ ] **Step 4: Commit**

```
git add lib/core/database/app_database.dart
git commit -m "feat: add player_stats table (db v12)"
```

---

### Task 3: PlayerStatsRepository

**Files:**
- Create: `lib/repositories/player_stats_repository.dart`
- Create: `test/repositories/player_stats_repository_test.dart`

- [ ] **Step 1: Write the test**

```dart
// test/repositories/player_stats_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daily_english/models/player_stats.dart';
import 'package:daily_english/repositories/player_stats_repository.dart';

void main() {
  late Database db;
  late PlayerStatsRepository repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE player_stats (
              id INTEGER PRIMARY KEY,
              xp INTEGER DEFAULT 0,
              level INTEGER DEFAULT 1,
              streak INTEGER DEFAULT 0,
              shields INTEGER DEFAULT 0,
              last_activity_date TEXT,
              streak_at_risk INTEGER DEFAULT 0,
              games_played_today TEXT DEFAULT ''
            )
          ''');
        },
      ),
    );
    repo = PlayerStatsRepository(Future.value(db));
  });

  tearDown(() => db.close());

  test('load returns default stats when table is empty', () async {
    final stats = await repo.load();
    expect(stats.xp, 0);
    expect(stats.streak, 0);
    expect(stats.shields, 0);
    expect(stats.streakAtRisk, false);
  });

  test('load returns inserted singleton after save', () async {
    await repo.save(const PlayerStats(xp: 200, streak: 7, shields: 2));
    final stats = await repo.load();
    expect(stats.xp, 200);
    expect(stats.streak, 7);
    expect(stats.shields, 2);
  });

  test('save upserts — second save overwrites first', () async {
    await repo.save(const PlayerStats(xp: 50, streak: 1));
    await repo.save(const PlayerStats(xp: 100, streak: 3));
    final stats = await repo.load();
    expect(stats.xp, 100);
    expect(stats.streak, 3);
  });

  test('save persists lastActivityDate', () async {
    await repo.save(const PlayerStats(lastActivityDate: '2026-05-10'));
    final stats = await repo.load();
    expect(stats.lastActivityDate, '2026-05-10');
  });
}
```

- [ ] **Step 2: Run test — expect failure**

```
flutter test test/repositories/player_stats_repository_test.dart
```
Expected: FAIL — repository does not exist.

- [ ] **Step 3: Implement the repository**

```dart
// lib/repositories/player_stats_repository.dart
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
```

- [ ] **Step 4: Run test — expect pass**

```
flutter test test/repositories/player_stats_repository_test.dart
```
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```
git add lib/repositories/player_stats_repository.dart test/repositories/player_stats_repository_test.dart
git commit -m "feat: add PlayerStatsRepository"
```

---

### Task 4: PlayerStatsProvider

**Files:**
- Create: `lib/providers/player_stats_provider.dart`

- [ ] **Step 1: Implement the provider**

```dart
// lib/providers/player_stats_provider.dart
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
        updated = stats.copyWith(shields: stats.shields - 1, streakAtRisk: false);
      } else {
        updated = stats.copyWith(streakAtRisk: true);
      }
    } else {
      // 2+ days missed — reset
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
```

- [ ] **Step 2: Analyze**

```
flutter analyze lib/providers/player_stats_provider.dart
```
Expected: No errors.

- [ ] **Step 3: Commit**

```
git add lib/providers/player_stats_provider.dart
git commit -m "feat: add PlayerStatsProvider with streak/XP/shield logic"
```

---

### Task 5: GameContent helper

**Files:**
- Create: `lib/screens/games/game_content.dart`

- [ ] **Step 1: Implement**

```dart
// lib/screens/games/game_content.dart
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/word_provider.dart';
import '../../providers/phrasal_verb_provider.dart';
import '../../providers/phrase_provider.dart';
import '../../providers/diary_provider.dart';

enum GameSource { words, phrasalVerbs, phrases, diary }

class GameItem {
  final int id;
  final String term;
  final String translation;
  final List<String> examples;
  final GameSource source;

  const GameItem({
    required this.id,
    required this.term,
    required this.translation,
    required this.examples,
    required this.source,
  });
}

const _kStopWords = {
  'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
  'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
  'should', 'may', 'might', 'shall', 'can', 'to', 'of', 'in', 'on', 'at',
  'by', 'for', 'with', 'from', 'and', 'but', 'or', 'so', 'yet', 'nor',
  'not', 'no', 'i', 'you', 'he', 'she', 'it', 'we', 'they', 'me', 'him',
  'her', 'us', 'them', 'my', 'your', 'his', 'its', 'our', 'their',
  'this', 'that', 'these', 'those', 'if', 'as', 'up', 'out', 'more',
  'also', 'very', 'just', 'than', 'then', 'when', 'where', 'who',
  'which', 'what', 'how', 'about', 'after', 'before', 'into', 'over',
  'under', 'some', 'such', 'each', 'both', 'even', 'much', 'too',
};

List<String> _extractSentences(String text) {
  return text
      .split(RegExp(r'(?<=[.!?])\s+'))
      .map((s) => s.trim().replaceAll(RegExp(r'[.!?]+$'), '').trim())
      .where((s) => s.split(RegExp(r'\s+')).length >= 3)
      .toList();
}

String? _pickTargetWord(String sentence, math.Random rng) {
  final candidates = sentence.split(RegExp(r'\s+')).where((token) {
    final clean = token.replaceAll(RegExp(r"[^a-zA-Z'-]"), '').toLowerCase();
    return clean.length >= 4 && !_kStopWords.contains(clean);
  }).toList();
  if (candidates.isEmpty) return null;
  final token = candidates[rng.nextInt(candidates.length)];
  return token.replaceAll(RegExp(r"^[^a-zA-Z]+|[^a-zA-Z]+$"), '');
}

Future<List<GameItem>> loadGameItems(GameSource source, Ref ref) async {
  switch (source) {
    case GameSource.words:
      final words = await ref.read(wordRepositoryProvider).getAll();
      return words
          .where((w) => w.id != null)
          .map((w) => GameItem(
                id: w.id!,
                term: w.word,
                translation: w.translation,
                examples: [w.example1, w.example2, w.example3]
                    .whereType<String>()
                    .toList(),
                source: source,
              ))
          .toList();
    case GameSource.phrasalVerbs:
      final pvs = await ref.read(phrasalVerbRepositoryProvider).getAll();
      return pvs
          .where((pv) => pv.id != null)
          .map((pv) => GameItem(
                id: pv.id!,
                term: pv.verb,
                translation: pv.meaningPt ?? pv.meaning,
                examples: [pv.example1, pv.example2, pv.example3]
                    .whereType<String>()
                    .toList(),
                source: source,
              ))
          .toList();
    case GameSource.phrases:
      final phrases = await ref.read(phraseRepositoryProvider).getAll();
      return phrases
          .where((p) => p.id != null)
          .map((p) => GameItem(
                id: p.id!,
                term: p.phrase,
                translation: p.translation,
                examples: [p.example1, p.example2, p.example3]
                    .whereType<String>()
                    .toList(),
                source: source,
              ))
          .toList();
    case GameSource.diary:
      final rng = math.Random();
      final entries = await ref.read(diaryRepositoryProvider).getAll();
      final items = <GameItem>[];
      int autoId = 0;
      for (final entry in entries) {
        if (entry.correctedContent == null) continue;
        final sentences = _extractSentences(entry.correctedContent!);
        for (final sentence in sentences) {
          final targetWord = _pickTargetWord(sentence, rng);
          if (targetWord == null) continue;
          items.add(GameItem(
            id: autoId++,
            term: targetWord,
            translation: '',
            examples: [sentence],
            source: GameSource.diary,
          ));
        }
      }
      return items;
  }
}

String gameSourceLabel(GameSource s) {
  switch (s) {
    case GameSource.words: return 'Words';
    case GameSource.phrasalVerbs: return 'Phrasal Verbs';
    case GameSource.phrases: return 'Daily Phrases';
    case GameSource.diary: return 'My Diary';
  }
}
```

- [ ] **Step 2: Analyze**

```
flutter analyze lib/screens/games/game_content.dart
```
Expected: No errors.

- [ ] **Step 3: Commit**

```
git add lib/screens/games/game_content.dart
git commit -m "feat: add GameContent helper (GameSource, GameItem, loadGameItems)"
```

---

### Task 6: Games Hub screen + router

**Files:**
- Create: `lib/screens/games/games_screen.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/screens/home/home_screen.dart` (Mini-Games button only — stats card in Task 10)

- [ ] **Step 1: Implement the hub screen**

```dart
// lib/screens/games/games_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import 'game_content.dart';

class GamesScreen extends ConsumerStatefulWidget {
  const GamesScreen({super.key});

  @override
  ConsumerState<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends ConsumerState<GamesScreen> {
  GameSource _source = GameSource.words;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mini-Games', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose a source',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: GameSource.values.map((s) {
                  final selected = _source == s;
                  return FilterChip(
                    label: Text(
                      gameSourceLabel(s),
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() => _source = s),
                    selectedColor: AppTheme.primary,
                    backgroundColor: Theme.of(context).cardTheme.color,
                    showCheckmark: false,
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Text(
                'Games',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              _GameCard(
                icon: '🎯',
                title: 'Multiple Choice',
                description: 'See a term — pick the correct translation.',
                accentColor: AppTheme.primary,
                onPlay: () => context.push('/games/multiple-choice?source=${_source.name}'),
              ),
              const SizedBox(height: 12),
              _GameCard(
                icon: '✏️',
                title: 'Fill in the Blank',
                description: 'Complete a sentence with the missing word or verb.',
                accentColor: AppTheme.tertiary,
                onPlay: () => context.push('/games/fill-blank?source=${_source.name}'),
              ),
              const SizedBox(height: 12),
              _GameCard(
                icon: '🔀',
                title: 'Sentence Scramble',
                description: 'Arrange shuffled words into the correct sentence.',
                accentColor: AppTheme.secondary,
                onPlay: () => context.push('/games/scramble?source=${_source.name}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String icon;
  final String title;
  final String description;
  final Color accentColor;
  final VoidCallback onPlay;

  const _GameCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: onPlay,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text('Play', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Add router entries**

In `lib/core/router/app_router.dart`, add these imports at the top:
```dart
import '../../screens/games/games_screen.dart';
import '../../screens/games/multiple_choice_screen.dart';
import '../../screens/games/fill_blank_screen.dart';
import '../../screens/games/sentence_scramble_screen.dart';
import '../../screens/games/game_content.dart';
```

Add these routes inside the `routes: [` list (after the existing routes, before the closing `]`):
```dart
    GoRoute(
      path: '/games',
      builder: (context, state) => const GamesScreen(),
    ),
    GoRoute(
      path: '/games/multiple-choice',
      builder: (context, state) {
        final src = state.uri.queryParameters['source'] ?? 'words';
        final source = GameSource.values.firstWhere(
          (e) => e.name == src,
          orElse: () => GameSource.words,
        );
        return MultipleChoiceScreen(source: source);
      },
    ),
    GoRoute(
      path: '/games/fill-blank',
      builder: (context, state) {
        final src = state.uri.queryParameters['source'] ?? 'words';
        final source = GameSource.values.firstWhere(
          (e) => e.name == src,
          orElse: () => GameSource.words,
        );
        return FillBlankScreen(source: source);
      },
    ),
    GoRoute(
      path: '/games/scramble',
      builder: (context, state) {
        final src = state.uri.queryParameters['source'] ?? 'words';
        final source = GameSource.values.firstWhere(
          (e) => e.name == src,
          orElse: () => GameSource.words,
        );
        return SentenceScrambleScreen(source: source);
      },
    ),
```

- [ ] **Step 3: Add Mini-Games button to home screen**

In `lib/screens/home/home_screen.dart`, add this button after the Flashcards button block:
```dart
              const SizedBox(height: 12),
              _MenuButton(
                label: 'Mini-Games',
                icon: Icons.games_rounded,
                color: AppTheme.primary,
                onTap: () => context.push('/games'),
              ),
```

- [ ] **Step 4: Create stub screens so router compiles**

Create these three stubs (will be replaced in Tasks 7–9):

```dart
// lib/screens/games/multiple_choice_screen.dart
import 'package:flutter/material.dart';
import 'game_content.dart';
class MultipleChoiceScreen extends StatelessWidget {
  final GameSource source;
  const MultipleChoiceScreen({super.key, required this.source});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Coming soon')));
}
```

```dart
// lib/screens/games/fill_blank_screen.dart
import 'package:flutter/material.dart';
import 'game_content.dart';
class FillBlankScreen extends StatelessWidget {
  final GameSource source;
  const FillBlankScreen({super.key, required this.source});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Coming soon')));
}
```

```dart
// lib/screens/games/sentence_scramble_screen.dart
import 'package:flutter/material.dart';
import 'game_content.dart';
class SentenceScrambleScreen extends StatelessWidget {
  final GameSource source;
  const SentenceScrambleScreen({super.key, required this.source});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Coming soon')));
}
```

- [ ] **Step 5: Analyze**

```
flutter analyze lib/
```
Expected: No errors.

- [ ] **Step 6: Commit**

```
git add lib/screens/games/ lib/core/router/app_router.dart lib/screens/home/home_screen.dart
git commit -m "feat: add games hub screen, stub game screens, router entries"
```

---

### Task 7: Multiple Choice game screen

**Files:**
- Modify: `lib/screens/games/multiple_choice_screen.dart` (replace stub)

- [ ] **Step 1: Implement**

```dart
// lib/screens/games/multiple_choice_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/audio_service.dart';
import '../../providers/player_stats_provider.dart';
import 'game_content.dart';

const _kRounds = 10;

class _MCRound {
  final String term; // English term, or gapped sentence for diary source
  final List<String> options;
  final int correctIndex;
  final bool isDiary;
  const _MCRound({required this.term, required this.options, required this.correctIndex, this.isDiary = false});
}

enum _Phase { loading, playing, results }

class MultipleChoiceScreen extends ConsumerStatefulWidget {
  final GameSource source;
  const MultipleChoiceScreen({super.key, required this.source});

  @override
  ConsumerState<MultipleChoiceScreen> createState() => _MultipleChoiceScreenState();
}

class _MultipleChoiceScreenState extends ConsumerState<MultipleChoiceScreen> {
  _Phase _phase = _Phase.loading;
  List<_MCRound> _rounds = [];
  int _current = 0;
  int _score = 0;
  int? _selectedIndex;
  bool _answered = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await loadGameItems(widget.source, ref);
    if (items.length < 4) {
      setState(() {
        _errorMessage = 'Not enough ${gameSourceLabel(widget.source)} to play. Add at least 4 items.';
        _phase = _Phase.playing;
      });
      return;
    }
    final rng = math.Random();
    final pool = [...items]..shuffle(rng);
    final selected = pool.take(_kRounds).toList();
    final rounds = selected.map((item) {
      if (widget.source == GameSource.diary) {
        // Diary mode: gapped sentence as question, word choices as options
        final sentence = item.examples.isNotEmpty ? item.examples[0] : item.term;
        final idx = sentence.toLowerCase().indexOf(item.term.toLowerCase());
        final gapped = idx >= 0
            ? sentence.substring(0, idx) + '___' + sentence.substring(idx + item.term.length)
            : sentence;
        final distractors = items
            .where((i) => i.id != item.id && i.term != item.term)
            .toList()
          ..shuffle(rng);
        final opts = [item.term, ...distractors.take(3).map((i) => i.term)]..shuffle(rng);
        return _MCRound(
          term: gapped,
          options: opts,
          correctIndex: opts.indexOf(item.term),
          isDiary: true,
        );
      }
      final distractors = items
          .where((i) => i.id != item.id && i.translation != item.translation)
          .toList()
        ..shuffle(rng);
      final opts = [item.translation, ...distractors.take(3).map((i) => i.translation)]
        ..shuffle(rng);
      return _MCRound(
        term: item.term,
        options: opts,
        correctIndex: opts.indexOf(item.translation),
      );
    }).toList();
    setState(() { _rounds = rounds; _phase = _Phase.playing; });
  }

  void _answer(int idx) {
    if (_answered) return;
    final correct = idx == _rounds[_current].correctIndex;
    setState(() {
      _selectedIndex = idx;
      _answered = true;
      if (correct) _score++;
    });
  }

  void _next() {
    if (_current + 1 >= _rounds.length) {
      final xp = _score * 10;
      ref.read(playerStatsProvider.notifier).recordSession('multiple_choice', xp);
      setState(() { _phase = _Phase.results; });
    } else {
      setState(() { _current++; _selectedIndex = null; _answered = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_phase == _Phase.results) return _buildResults(context);
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/games'))),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_errorMessage!, textAlign: TextAlign.center))),
      );
    }
    return _buildPlaying(context);
  }

  Widget _buildPlaying(BuildContext context) {
    final round = _rounds[_current];
    final progress = _current / _rounds.length;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Text('${_current + 1} / ${_rounds.length}',
                    style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const Spacer(),
                Text('Score: $_score',
                    style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary)),
              ]),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progress, color: AppTheme.primary,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                minHeight: 6, borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    Text(
                      round.term,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: round.isDiary ? 16 : 28,
                        fontWeight: round.isDiary ? FontWeight.w600 : FontWeight.w900,
                        height: round.isDiary ? 1.6 : null,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (!round.isDiary) ...[
                      const SizedBox(height: 8),
                      IconButton(
                        icon: const Icon(Icons.volume_up_rounded, size: 28),
                        color: AppTheme.tertiary,
                        onPressed: () => ref.read(audioServiceProvider).speak(round.term),
                      ),
                    ],
                  ]),
                ),
              ),
              const SizedBox(height: 24),
              ...List.generate(round.options.length, (i) {
                Color? bg;
                if (_answered) {
                  if (i == round.correctIndex) bg = AppTheme.primary.withValues(alpha: 0.15);
                  else if (i == _selectedIndex) bg = AppTheme.error.withValues(alpha: 0.15);
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OutlinedButton(
                    onPressed: _answered ? null : () => _answer(i),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: bg,
                      side: BorderSide(
                        color: _answered
                            ? (i == round.correctIndex ? AppTheme.primary
                                : i == _selectedIndex ? AppTheme.error
                                : Theme.of(context).colorScheme.outlineVariant)
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: _answered && (i == round.correctIndex || i == _selectedIndex) ? 2 : 1,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(round.options[i],
                        style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface)),
                  ),
                );
              }),
              const Spacer(),
              if (_answered)
                ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _current + 1 >= _rounds.length ? 'See Results' : 'Next',
                    style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final statsAsync = ref.watch(playerStatsProvider);
    final stats = statsAsync.valueOrNull;
    final xp = _score * 10;
    final percent = _score / _rounds.length;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              Text('🎉', style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 8),
              Text('Multiple Choice', style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 4),
              Text('${gameSourceLabel(widget.source)}',
                  style: GoogleFonts.nunito(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 24),
              _ResultCircle(score: _score, total: _rounds.length),
              const SizedBox(height: 16),
              Text('+$xp XP', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800,
                  color: AppTheme.primary)),
              if (stats != null) ...[
                const SizedBox(height: 8),
                _XpBar(stats: stats),
                const SizedBox(height: 8),
                _StreakRow(stats: stats),
              ],
              const SizedBox(height: 32),
              SizedBox(width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => setState(() { _current = 0; _score = 0; _selectedIndex = null; _answered = false; _phase = _Phase.loading; _load(); }),
                  icon: const Icon(Icons.replay_rounded),
                  label: Text('Play Again', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.canPop() ? context.pop() : context.go('/games'),
                  icon: const Icon(Icons.grid_view_rounded),
                  label: Text('Change Game', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.home_rounded),
                  label: Text('Home', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Shared result widgets — defined once here, imported by other game screens
class _ResultCircle extends StatelessWidget {
  final int score;
  final int total;
  const _ResultCircle({required this.score, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : score / total;
    return SizedBox(
      width: 110, height: 110,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox(width: 110, height: 110,
          child: CircularProgressIndicator(value: pct, strokeWidth: 10,
              color: AppTheme.primary, backgroundColor: AppTheme.primary.withValues(alpha: 0.15))),
        Text('$score/$total', style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primary)),
      ]),
    );
  }
}

class _XpBar extends StatelessWidget {
  final dynamic stats; // PlayerStats
  const _XpBar({required this.stats});

  @override
  Widget build(BuildContext context) {
    final xpInLevel = stats.xp % 100;
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Level ${stats.level}', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text('${stats.xp} XP total', style: GoogleFonts.nunito(fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
      const SizedBox(height: 4),
      LinearProgressIndicator(value: xpInLevel / 100, color: AppTheme.primary,
          backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
          minHeight: 8, borderRadius: BorderRadius.circular(4)),
    ]);
  }
}

class _StreakRow extends StatelessWidget {
  final dynamic stats; // PlayerStats
  const _StreakRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🔥', style: TextStyle(fontSize: 20)),
      const SizedBox(width: 4),
      Text('${stats.streak} day streak', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700)),
      if (stats.shields > 0) ...[
        const SizedBox(width: 12),
        const Text('🛡', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 4),
        Text('×${stats.shields}', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700)),
      ],
      if (stats.streakAtRisk) ...[
        const SizedBox(width: 8),
        Text('at risk!', style: GoogleFonts.nunito(fontSize: 13, color: AppTheme.error, fontWeight: FontWeight.w700)),
      ],
    ]);
  }
}
```

- [ ] **Step 2: Analyze**

```
flutter analyze lib/screens/games/multiple_choice_screen.dart
```
Expected: No errors.

- [ ] **Step 3: Commit**

```
git add lib/screens/games/multiple_choice_screen.dart
git commit -m "feat: implement Multiple Choice game"
```

---

### Task 8: Fill in the Blank game screen

**Files:**
- Modify: `lib/screens/games/fill_blank_screen.dart` (replace stub)

- [ ] **Step 1: Implement**

```dart
// lib/screens/games/fill_blank_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/player_stats_provider.dart';
import 'game_content.dart';
import 'multiple_choice_screen.dart' show _ResultCircle, _XpBar, _StreakRow;

const _kFIBRounds = 10;

class _FIBRound {
  final String gapped;
  final List<String> options;
  final int correctIndex;
  const _FIBRound({required this.gapped, required this.options, required this.correctIndex});
}

enum _FIBPhase { loading, playing, results }

class FillBlankScreen extends ConsumerStatefulWidget {
  final GameSource source;
  const FillBlankScreen({super.key, required this.source});

  @override
  ConsumerState<FillBlankScreen> createState() => _FillBlankScreenState();
}

class _FillBlankScreenState extends ConsumerState<FillBlankScreen> {
  _FIBPhase _phase = _FIBPhase.loading;
  List<_FIBRound> _rounds = [];
  int _current = 0;
  int _score = 0;
  int? _selectedIndex;
  bool _answered = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rng = math.Random();
    final allItems = await loadGameItems(widget.source, ref);

    // Qualify: has at least one example containing the term
    final qualifying = allItems.where((item) =>
        item.examples.any((ex) => ex.toLowerCase().contains(item.term.toLowerCase()))).toList();

    if (qualifying.length < 4) {
      setState(() {
        _errorMessage = 'Not enough ${gameSourceLabel(widget.source)} with matching examples. Add more content.';
        _phase = _FIBPhase.playing;
      });
      return;
    }

    final pool = [...qualifying]..shuffle(rng);
    final selected = pool.take(_kFIBRounds).toList();

    final rounds = selected.map((item) {
      final validExamples = item.examples.where((ex) =>
          ex.toLowerCase().contains(item.term.toLowerCase())).toList();
      final example = validExamples[rng.nextInt(validExamples.length)];

      // Case-insensitive replace first occurrence of term
      final idx = example.toLowerCase().indexOf(item.term.toLowerCase());
      final gapped = example.substring(0, idx) + '___' + example.substring(idx + item.term.length);

      final distractors = allItems
          .where((i) => i.id != item.id && i.term != item.term)
          .toList()
        ..shuffle(rng);
      final opts = [item.term, ...distractors.take(3).map((i) => i.term)]..shuffle(rng);

      return _FIBRound(
        gapped: gapped,
        options: opts,
        correctIndex: opts.indexOf(item.term),
      );
    }).toList();

    setState(() { _rounds = rounds; _phase = _FIBPhase.playing; });
  }

  void _answer(int idx) {
    if (_answered) return;
    final correct = idx == _rounds[_current].correctIndex;
    setState(() { _selectedIndex = idx; _answered = true; if (correct) _score++; });
  }

  void _next() {
    if (_current + 1 >= _rounds.length) {
      ref.read(playerStatsProvider.notifier).recordSession('fill_blank', _score * 10);
      setState(() => _phase = _FIBPhase.results);
    } else {
      setState(() { _current++; _selectedIndex = null; _answered = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _FIBPhase.loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_phase == _FIBPhase.results) return _buildResults(context);
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/games'))),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_errorMessage!, textAlign: TextAlign.center))),
      );
    }
    return _buildPlaying(context);
  }

  Widget _buildPlaying(BuildContext context) {
    final round = _rounds[_current];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Text('${_current + 1} / ${_rounds.length}',
                    style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const Spacer(),
                Text('Score: $_score',
                    style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.tertiary)),
              ]),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: _current / _rounds.length, color: AppTheme.tertiary,
                backgroundColor: AppTheme.tertiary.withValues(alpha: 0.15),
                minHeight: 6, borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    round.gapped,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(fontSize: 18, height: 1.6,
                        color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ...List.generate(round.options.length, (i) {
                Color? bg;
                if (_answered) {
                  if (i == round.correctIndex) bg = AppTheme.primary.withValues(alpha: 0.15);
                  else if (i == _selectedIndex) bg = AppTheme.error.withValues(alpha: 0.15);
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OutlinedButton(
                    onPressed: _answered ? null : () => _answer(i),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: bg,
                      side: BorderSide(
                        color: _answered
                            ? (i == round.correctIndex ? AppTheme.primary
                                : i == _selectedIndex ? AppTheme.error
                                : Theme.of(context).colorScheme.outlineVariant)
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: _answered && (i == round.correctIndex || i == _selectedIndex) ? 2 : 1,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(round.options[i],
                        style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface)),
                  ),
                );
              }),
              const Spacer(),
              if (_answered)
                ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.tertiary, foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(_current + 1 >= _rounds.length ? 'See Results' : 'Next',
                      style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final stats = ref.watch(playerStatsProvider).valueOrNull;
    final xp = _score * 10;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(children: [
            const Text('✏️', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 8),
            Text('Fill in the Blank', style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 4),
            Text(gameSourceLabel(widget.source),
                style: GoogleFonts.nunito(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            _ResultCircle(score: _score, total: _rounds.length),
            const SizedBox(height: 16),
            Text('+$xp XP', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.tertiary)),
            if (stats != null) ...[const SizedBox(height: 8), _XpBar(stats: stats), const SizedBox(height: 8), _StreakRow(stats: stats)],
            const SizedBox(height: 32),
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() { _current = 0; _score = 0; _selectedIndex = null; _answered = false; _phase = _FIBPhase.loading; _load(); }),
                icon: const Icon(Icons.replay_rounded),
                label: Text('Play Again', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.tertiary, foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.canPop() ? context.pop() : context.go('/games'),
                icon: const Icon(Icons.grid_view_rounded),
                label: Text('Change Game', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_rounded),
                label: Text('Home', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze**

```
flutter analyze lib/screens/games/fill_blank_screen.dart
```
Expected: No errors.

- [ ] **Step 3: Commit**

```
git add lib/screens/games/fill_blank_screen.dart
git commit -m "feat: implement Fill in the Blank game"
```

---

### Task 9: Sentence Scramble game screen

**Files:**
- Modify: `lib/screens/games/sentence_scramble_screen.dart` (replace stub)

- [ ] **Step 1: Implement**

```dart
// lib/screens/games/sentence_scramble_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/player_stats_provider.dart';
import 'game_content.dart';
import 'multiple_choice_screen.dart' show _ResultCircle, _XpBar, _StreakRow;

const _kScrambleRounds = 10;

class _ScrambleRound {
  final String original;
  final List<String> shuffled;
  const _ScrambleRound({required this.original, required this.shuffled});
}

enum _ScramblePhase { loading, playing, results }
enum _CheckState { unchecked, correct, wrong }

class SentenceScrambleScreen extends ConsumerStatefulWidget {
  final GameSource source;
  const SentenceScrambleScreen({super.key, required this.source});

  @override
  ConsumerState<SentenceScrambleScreen> createState() => _SentenceScrambleScreenState();
}

class _SentenceScrambleScreenState extends ConsumerState<SentenceScrambleScreen> {
  _ScramblePhase _phase = _ScramblePhase.loading;
  List<_ScrambleRound> _rounds = [];
  int _current = 0;
  int _score = 0;
  String? _errorMessage;

  // Per-round state
  List<String> _bank = [];   // chips not yet placed
  List<String?> _placed = []; // chips placed in order (null = empty slot)
  _CheckState _checkState = _CheckState.unchecked;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rng = math.Random();
    final allItems = await loadGameItems(widget.source, ref);

    // Qualify: item has at least one example with 3+ tokens
    final qualifying = allItems.where((item) =>
        item.examples.any((ex) => ex.trim().split(' ').length >= 3)).toList();

    if (qualifying.isEmpty) {
      setState(() {
        _errorMessage = 'No ${gameSourceLabel(widget.source)} with example sentences found. Add examples first.';
        _phase = _ScramblePhase.playing;
      });
      return;
    }

    final pool = [...qualifying]..shuffle(rng);
    final selected = <_ScrambleRound>[];
    int poolIdx = 0;
    while (selected.length < _kScrambleRounds) {
      final item = pool[poolIdx % pool.length];
      poolIdx++;
      final validExamples = item.examples.where((ex) => ex.trim().split(' ').length >= 3).toList();
      if (validExamples.isEmpty) continue;
      final sentence = validExamples[rng.nextInt(validExamples.length)];
      final tokens = sentence.trim().split(' ');
      final shuffled = [...tokens]..shuffle(rng);
      // Ensure shuffle is not accidentally in original order
      while (_joinNorm(shuffled) == _joinNorm(tokens) && tokens.length > 1) {
        shuffled.shuffle(rng);
      }
      selected.add(_ScrambleRound(original: sentence.trim(), shuffled: shuffled));
    }

    setState(() {
      _rounds = selected;
      _phase = _ScramblePhase.playing;
      _initRound();
    });
  }

  void _initRound() {
    _bank = [..._rounds[_current].shuffled];
    _placed = [];
    _checkState = _CheckState.unchecked;
  }

  String _joinNorm(List<String> tokens) => tokens.join(' ').toLowerCase().trim();

  void _placeToken(int bankIdx) {
    if (_checkState != _CheckState.unchecked) return;
    setState(() {
      _placed.add(_bank[bankIdx]);
      _bank.removeAt(bankIdx);
    });
  }

  void _returnToken(int placedIdx) {
    if (_checkState != _CheckState.unchecked) return;
    setState(() {
      _bank.add(_placed[placedIdx]!);
      _placed.removeAt(placedIdx);
    });
  }

  void _check() {
    final answer = _placed.whereType<String>().join(' ');
    final correct = answer.toLowerCase().trim() == _rounds[_current].original.toLowerCase().trim();
    setState(() {
      _checkState = correct ? _CheckState.correct : _CheckState.wrong;
      if (correct) _score++;
    });
  }

  void _next() {
    if (_current + 1 >= _rounds.length) {
      ref.read(playerStatsProvider.notifier).recordSession('scramble', _score * 10);
      setState(() => _phase = _ScramblePhase.results);
    } else {
      setState(() { _current++; _initRound(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _ScramblePhase.loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_phase == _ScramblePhase.results) return _buildResults(context);
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/games'))),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_errorMessage!, textAlign: TextAlign.center))),
      );
    }
    return _buildPlaying(context);
  }

  Widget _buildPlaying(BuildContext context) {
    final round = _rounds[_current];
    final allPlaced = _bank.isEmpty;
    Color feedbackColor = Theme.of(context).colorScheme.outlineVariant;
    if (_checkState == _CheckState.correct) feedbackColor = AppTheme.primary;
    if (_checkState == _CheckState.wrong) feedbackColor = AppTheme.error;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Text('${_current + 1} / ${_rounds.length}',
                    style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const Spacer(),
                Text('Score: $_score',
                    style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.secondary)),
              ]),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: _current / _rounds.length, color: AppTheme.secondary,
                backgroundColor: AppTheme.secondary.withValues(alpha: 0.15),
                minHeight: 6, borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 20),
              // Answer area
              Container(
                constraints: const BoxConstraints(minHeight: 80),
                decoration: BoxDecoration(
                  border: Border.all(color: feedbackColor, width: 2),
                  borderRadius: BorderRadius.circular(12),
                  color: _checkState == _CheckState.correct
                      ? AppTheme.primary.withValues(alpha: 0.06)
                      : _checkState == _CheckState.wrong
                          ? AppTheme.error.withValues(alpha: 0.06)
                          : Theme.of(context).cardTheme.color,
                ),
                padding: const EdgeInsets.all(12),
                child: _placed.isEmpty
                    ? Center(child: Text('Tap words below to build the sentence',
                        style: GoogleFonts.nunito(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)))
                    : Wrap(
                        spacing: 6, runSpacing: 6,
                        children: _placed.asMap().entries.map((e) => GestureDetector(
                          onTap: () => _returnToken(e.key),
                          child: _Chip(label: e.value!, color: AppTheme.secondary),
                        )).toList(),
                      ),
              ),
              if (_checkState == _CheckState.wrong) ...[
                const SizedBox(height: 8),
                Text('Correct: ${round.original}',
                    style: GoogleFonts.nunito(fontSize: 13, color: AppTheme.error, fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 20),
              // Token bank
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _bank.asMap().entries.map((e) => GestureDetector(
                  onTap: () => _placeToken(e.key),
                  child: _Chip(label: e.value, color: Theme.of(context).colorScheme.outline),
                )).toList(),
              ),
              const Spacer(),
              if (_checkState == _CheckState.unchecked)
                ElevatedButton(
                  onPressed: allPlaced ? _check : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary, foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Check', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700)),
                )
              else
                ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _checkState == _CheckState.correct ? AppTheme.primary : AppTheme.secondary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(_current + 1 >= _rounds.length ? 'See Results' : 'Next',
                      style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final stats = ref.watch(playerStatsProvider).valueOrNull;
    final xp = _score * 10;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(children: [
            const Text('🔀', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 8),
            Text('Sentence Scramble', style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 4),
            Text(gameSourceLabel(widget.source),
                style: GoogleFonts.nunito(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            _ResultCircle(score: _score, total: _rounds.length),
            const SizedBox(height: 16),
            Text('+$xp XP', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.secondary)),
            if (stats != null) ...[const SizedBox(height: 8), _XpBar(stats: stats), const SizedBox(height: 8), _StreakRow(stats: stats)],
            const SizedBox(height: 32),
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() { _current = 0; _score = 0; _phase = _ScramblePhase.loading; _load(); }),
                icon: const Icon(Icons.replay_rounded),
                label: Text('Play Again', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary, foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.canPop() ? context.pop() : context.go('/games'),
                icon: const Icon(Icons.grid_view_rounded),
                label: Text('Change Game', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_rounded),
                label: Text('Home', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface)),
    );
  }
}
```

- [ ] **Step 2: Analyze**

```
flutter analyze lib/screens/games/sentence_scramble_screen.dart
```
Expected: No errors.

- [ ] **Step 3: Commit**

```
git add lib/screens/games/sentence_scramble_screen.dart
git commit -m "feat: implement Sentence Scramble game"
```

---

### Task 10: Expanded home stats card + final wiring

**Files:**
- Modify: `lib/screens/home/home_screen.dart`

- [ ] **Step 1: Update `HomeScreen` to watch `playerStatsProvider`**

Replace the entire `HomeScreen` build method and `_HomeScreenState` class `wordCount` line. The full updated `_HomeScreenState.build`:

```dart
  @override
  Widget build(BuildContext context) {
    final wordCount = ref.watch(totalWordCountProvider).valueOrNull ?? 0;
    final statsAsync = ref.watch(playerStatsProvider);
    final stats = statsAsync.valueOrNull;
    // ... rest of build unchanged, but pass stats to _StatsCard
```

Replace the `_StatsCard(wordCount: wordCount)` call with:
```dart
              _StatsCard(wordCount: wordCount, stats: stats),
```

- [ ] **Step 2: Replace `_StatsCard` widget**

Remove the existing `_StatsCard` class entirely and replace with:

```dart
class _StatsCard extends StatelessWidget {
  final int wordCount;
  final dynamic stats; // PlayerStats?

  const _StatsCard({required this.wordCount, this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book_rounded, size: 40, color: AppTheme.secondary),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$wordCount',
                      style: GoogleFonts.nunito(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primary,
                      ),
                    ),
                    Text(
                      'words in your dictionary',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (stats != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Level ${stats.level}',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        width: 80,
                        child: LinearProgressIndicator(
                          value: (stats.xp % 100) / 100,
                          color: AppTheme.primary,
                          backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${stats.xp % 100}/100 XP',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (stats != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 4),
                  Text(
                    '${stats.streak} day streak',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: stats.streakAtRisk
                          ? AppTheme.error
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (stats.streakAtRisk) ...[
                    const SizedBox(width: 4),
                    Text('⚠️ at risk',
                        style: GoogleFonts.nunito(fontSize: 12, color: AppTheme.error)),
                  ],
                  const Spacer(),
                  if (stats.shields > 0) ...[
                    const Text('🛡', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 4),
                    Text(
                      '×${stats.shields}',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Add `playerStatsProvider` import to home_screen.dart**

Add to imports:
```dart
import '../../providers/player_stats_provider.dart';
```

- [ ] **Step 4: Analyze entire lib**

```
flutter analyze lib/
```
Expected: No errors.

- [ ] **Step 5: Run all tests**

```
flutter test
```
Expected: All tests PASS.

- [ ] **Step 6: Commit**

```
git add lib/screens/home/home_screen.dart lib/providers/player_stats_provider.dart
git commit -m "feat: expanded stats card with XP/level/streak/shields"
```

---

## Self-Review Checklist

**Spec coverage:**
- ✅ PlayerStats model with all fields
- ✅ DB v12 migration
- ✅ Streak rules (same day, yesterday, 1 missed, 2+ missed, shield consumption)
- ✅ XP +10 per correct, 0 wrong; level = xp÷100+1
- ✅ Shield earned when all 3 games played in one day
- ✅ Multiple Choice — 4 options, speaker button, immediate feedback
- ✅ Fill in the Blank — gapped sentence, 4 options, immediate feedback
- ✅ Sentence Scramble — tap chips to place/return, Check button, correct answer shown on wrong
- ✅ All games: 10 rounds, results screen with score/XP/streak/shields
- ✅ Results: Play Again / Change Game / Home buttons
- ✅ Games hub with source selector (Words / Phrasal Verbs / Daily Phrases / My Diary) using Wrap for 4 chips
- ✅ Diary source: sentence extraction + stop-word-filtered target word; `GameSource.diary` in `loadGameItems`
- ✅ Multiple Choice diary mode: gapped sentence as question, word choices as options, no speaker button
- ✅ Fill in the Blank + Scramble: diary works as-is (term appears in examples[0] by construction)
- ✅ Home stats card: word count + level + XP bar + streak + shields

**Type consistency:** `recordSession` called with `'multiple_choice'`, `'fill_blank'`, `'scramble'` — matches shield check strings in provider. `GameSource.words/phrasalVerbs/phrases/diary` used consistently. `_ResultCircle`, `_XpBar`, `_StreakRow` defined in `multiple_choice_screen.dart` and imported in the other two game screens. `_MCRound.isDiary` flag gates diary-specific rendering in Task 7.
