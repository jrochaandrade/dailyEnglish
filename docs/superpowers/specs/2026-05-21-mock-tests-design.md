# Mock Tests — Design Spec

**Date:** 2026-05-21

## Overview

Add IELTS mock test tracking to the Study Log. Users record per-skill scores (Listening, Reading, Writing, Speaking), set personal target bands, and see live stats: tests done, positive count, positive rate, and a "Book test?" indicator that fires when the rate exceeds 70%.

---

## Data Layer

### MockTest model

```dart
class MockTest {
  final int? id;
  final String date;          // ISO date string "YYYY-MM-DD"
  final double listeningScore;
  final double readingScore;
  final double writingScore;
  final double speakingScore;
  final bool reachedTarget;   // auto-calculated at save time
  final DateTime createdAt;
}
```

`reachedTarget` is computed on save:
```dart
bool _calcReachedTarget(MockTest t, MockTestTargets targets) {
  final overall = (t.listeningScore + t.readingScore + t.writingScore + t.speakingScore) / 4;
  final roundedOverall = (overall * 2).round() / 2; // round to nearest 0.5
  return roundedOverall >= targets.overallTarget &&
      t.listeningScore >= targets.listeningMin &&
      t.readingScore   >= targets.readingMin &&
      t.writingScore   >= targets.writingMin &&
      t.speakingScore  >= targets.speakingMin;
}
```

### MockTestTargets model

Stored in `SharedPreferences`, not the database. Defaults shown:

```dart
class MockTestTargets {
  final double overallTarget;   // default 7.0
  final double listeningMin;    // default 6.0
  final double readingMin;      // default 6.0
  final double writingMin;      // default 6.0
  final double speakingMin;     // default 6.0
}
```

SharedPreferences keys: `mock_target_overall`, `mock_target_listening`, `mock_target_reading`, `mock_target_writing`, `mock_target_speaking`.

### Database

New table `mock_tests` — added to `_onCreate` and `_onUpgrade` (`if (oldVersion < 15)`) in `app_database.dart`. DB version bumps from 14 → 15.

```sql
CREATE TABLE IF NOT EXISTS mock_tests (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date TEXT NOT NULL,
  listening_score REAL NOT NULL,
  reading_score REAL NOT NULL,
  writing_score REAL NOT NULL,
  speaking_score REAL NOT NULL,
  reached_target INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
)
```

### MockTestRepository

```dart
class MockTestRepository {
  final Future<Database> _futureDb;
  const MockTestRepository(this._futureDb);

  Future<List<MockTest>> getAll() async { ... } // ORDER BY date DESC, created_at DESC
  Future<void> insert(MockTest test) async { ... }
  Future<void> delete(int id) async { ... }
}
```

---

## Providers

### mockTestTargetsProvider

```dart
class MockTestTargetsNotifier extends AsyncNotifier<MockTestTargets> {
  @override
  Future<MockTestTargets> build() => _load();

  Future<void> updateTargets(MockTestTargets targets) async {
    await _save(targets);
    ref.invalidateSelf();
  }
}

final mockTestTargetsProvider =
    AsyncNotifierProvider<MockTestTargetsNotifier, MockTestTargets>(
        MockTestTargetsNotifier.new);
```

### mockTestRepositoryProvider

```dart
final mockTestRepositoryProvider = Provider<MockTestRepository>((ref) {
  final appDb = ref.watch(databaseProvider);
  return MockTestRepository(appDb.database);
});
```

### mockTestListProvider

```dart
class MockTestListNotifier extends AsyncNotifier<List<MockTest>> {
  @override
  Future<List<MockTest>> build() =>
      ref.read(mockTestRepositoryProvider).getAll();

  Future<void> addTest(MockTest test) async {
    await ref.read(mockTestRepositoryProvider).insert(test);
    ref.invalidateSelf();
  }

  Future<void> deleteTest(int id) async {
    await ref.read(mockTestRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }
}

final mockTestListProvider =
    AsyncNotifierProvider<MockTestListNotifier, List<MockTest>>(
        MockTestListNotifier.new);
```

### mockTestStatsProvider

```dart
class MockTestStats {
  final int done;
  final int positive;
  final double rate;      // 0.0–100.0
  final bool bookTest;    // rate > 70.0

  static const empty = MockTestStats(done: 0, positive: 0, rate: 0, bookTest: false);
}

final mockTestStatsProvider = Provider<MockTestStats>((ref) {
  final async = ref.watch(mockTestListProvider);
  return async.when(
    loading: () => MockTestStats.empty,
    error: (_, __) => MockTestStats.empty,
    data: (tests) {
      final done = tests.length;
      final positive = tests.where((t) => t.reachedTarget).length;
      final rate = done == 0 ? 0.0 : positive / done * 100;
      return MockTestStats(
        done: done,
        positive: positive,
        rate: rate,
        bookTest: rate > 70.0,
      );
    },
  );
});
```

---

## Study Log UI

### Tab structure

`StudyLogScreen` gains a `DefaultTabController(length: 2)`. The app bar gets a `TabBar` at the bottom:

```
[ Sessions ]  [ Mock Tests ]
```

Body layout:

```
Column
  _StatsHeader(stats: studyStats, mockStats: mockStats)   ← always visible
  TabBar
  Expanded → TabBarView
    Sessions tab
    Mock Tests tab
```

`_StatsHeader` receives both `StudyStats` and `MockTestStats` as constructor parameters (passed down from `StudyLogScreen`, which watches both providers).

The FAB is tab-aware using `TabController`:
```dart
floatingActionButton: AnimatedBuilder(
  animation: _tabController,
  builder: (_, __) => FloatingActionButton(
    onPressed: _tabController.index == 0 ? _addSession : _addMockTest,
    child: const Icon(Icons.add),
  ),
),
```

### Sessions tab

Unchanged from current implementation (4 `_SkillGroup` `ExpansionTile` cards).

### Mock Tests tab — `_MockTestsTab`

```
[  Date  ]  [ L ]  [ R ]  [ W ]  [ S ]  [ ✓/✗ ]  [ ⋮ ]
```

- Ordered by date descending
- Empty state: `ListTile` with "No mock tests yet."
- Each `_MockTestTile`:
  - Title: date string
  - Subtitle: `L 6.5 · R 7.0 · W 6.0 · S 6.5`
  - Trailing: reached-target badge (green ✓ or red ✗) + `PopupMenuButton` with **Delete** only
  - Delete shows `AlertDialog("Delete this test?")`, on confirm calls `deleteTest(id)`
  - `ValueKey(test.id)` on each tile

### Settings bottom sheet — `_MockTargetsSheet`

Opened from a settings `IconButton` in the app bar. Contains 5 `DropdownButtonFormField` fields (Overall, Listening, Reading, Writing, Speaking), each with options 0.0–9.0 in 0.5 steps. A **Save** button calls `updateTargets()` and pops the sheet.

---

## Mock Test Form — `MockTestForm`

`ConsumerStatefulWidget`, opened via `showModalBottomSheet(isScrollControlled: true)`.

Fields:
- **Date** — `InkWell` + `InputDecorator` + `showDatePicker`, defaults to today
- **Listening Score** — `DropdownButtonFormField`, values 0.0–9.0 in 0.5 steps
- **Reading Score** — same
- **Writing Score** — same
- **Speaking Score** — same

On save:
1. Validate all 4 scores are selected
2. Load current targets via `ref.read(mockTestTargetsProvider.future)`
3. Compute `reachedTarget`
4. Call `addTest(MockTest(...))`
5. `Navigator.pop(context)`

No "reached target" field shown — computed silently.

---

## Stats Integration

`_StatsHeader` and `_StudySummaryCard` already render `_MockStat` widgets with hardcoded `"—"`. Replace with live values from `mockTestStatsProvider`:

### _StatsHeader (study_log_screen.dart)

`_StatsHeader` gains a second constructor parameter `MockTestStats mockStats`. Replace hardcoded `_MockStat` values:

```dart
_MockStat(label: 'Done',      value: '${mockStats.done}')
_MockStat(label: 'Positive',  value: '${mockStats.positive}')
_MockStat(label: 'Rate',      value: mockStats.done == 0 ? '—' : '${mockStats.rate.toStringAsFixed(0)}%')
_MockStat(label: 'Book test?', value: mockStats.done == 0 ? '—' : (mockStats.bookTest ? 'Yes' : 'No'))
```

### _StudySummaryCard (home_screen.dart)

```dart
final mockStats = ref.watch(mockTestStatsProvider);
// Replace hardcoded "Mock tests: —":
'Mock tests: ${mockStats.done == 0 ? "—" : "${mockStats.positive}/${mockStats.done} (${mockStats.rate.toStringAsFixed(0)}%)"}'
```

---

## Modified / Created Files

| File | Change |
|------|--------|
| `lib/models/mock_test.dart` | New — `MockTest` model + `fromMap`/`toMap` |
| `lib/models/mock_test_targets.dart` | New — `MockTestTargets` model |
| `lib/repositories/mock_test_repository.dart` | New — `getAll`, `insert`, `delete` |
| `lib/providers/mock_test_provider.dart` | New — all 4 providers + `MockTestStats` |
| `lib/screens/study/mock_test_form.dart` | New — add mock test bottom sheet form |
| `lib/screens/study/study_log_screen.dart` | Add tabs, `_MockTestsTab`, `_MockTestTile`, `_MockTargetsSheet`, live stats |
| `lib/screens/home/home_screen.dart` | Replace "Mock tests: —" with live stat |
| `lib/core/database/app_database.dart` | DB v15, add `mock_tests` table |
