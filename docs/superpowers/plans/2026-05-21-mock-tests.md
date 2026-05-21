# Mock Tests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add IELTS mock test tracking to the Study Log — record per-skill scores, auto-calculate whether the target was reached, and show live stats (Done / Positive / Rate / Book test?) on the dashboard.

**Architecture:** 5 new files (2 models, 1 repository, 1 provider file, 2 form screens) + 3 modified files (app_database, study_log_screen, home_screen). Providers follow the existing `AsyncNotifierProvider` pattern from `study_session_provider.dart`. Targets are persisted in SharedPreferences; test records go in a new `mock_tests` SQLite table (DB v15).

**Tech Stack:** Flutter, Riverpod (AsyncNotifier + Provider), sqflite (v15 migration), shared_preferences, google_fonts (Nunito), go_router, AppTheme colors.

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `lib/models/mock_test.dart` | Create | `MockTest` model — fromMap/toMap |
| `lib/models/mock_test_targets.dart` | Create | `MockTestTargets` model — SharedPreferences load/save |
| `lib/repositories/mock_test_repository.dart` | Create | getAll / insert / delete |
| `lib/providers/mock_test_provider.dart` | Create | All providers + `MockTestStats` |
| `lib/screens/study/mock_test_form.dart` | Create | Add-test bottom sheet |
| `lib/screens/study/mock_targets_sheet.dart` | Create | Edit-targets bottom sheet |
| `lib/core/database/app_database.dart` | Modify | v15 migration, add mock_tests table |
| `lib/screens/study/study_log_screen.dart` | Modify | Tabs, _MockTestsTab, _MockTestTile, live stats |
| `lib/screens/home/home_screen.dart` | Modify | Replace "Mock tests: —" with live stat |
| `test/repositories/mock_test_repository_test.dart` | Create | Repository unit tests |
| `pubspec.yaml` | Modify | Add shared_preferences dependency |

---

## Task 1: Models — MockTest and MockTestTargets

**Files:**
- Create: `lib/models/mock_test.dart`
- Create: `lib/models/mock_test_targets.dart`

- [ ] **Step 1: Create `lib/models/mock_test.dart`**

```dart
class MockTest {
  final int? id;
  final String date; // YYYY-MM-DD
  final double listeningScore;
  final double readingScore;
  final double writingScore;
  final double speakingScore;
  final bool reachedTarget;
  final DateTime createdAt;

  const MockTest({
    this.id,
    required this.date,
    required this.listeningScore,
    required this.readingScore,
    required this.writingScore,
    required this.speakingScore,
    required this.reachedTarget,
    required this.createdAt,
  });

  factory MockTest.fromMap(Map<String, dynamic> map) {
    return MockTest(
      id: map['id'] as int?,
      date: map['date'] as String,
      listeningScore: (map['listening_score'] as num).toDouble(),
      readingScore: (map['reading_score'] as num).toDouble(),
      writingScore: (map['writing_score'] as num).toDouble(),
      speakingScore: (map['speaking_score'] as num).toDouble(),
      reachedTarget: (map['reached_target'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'listening_score': listeningScore,
      'reading_score': readingScore,
      'writing_score': writingScore,
      'speaking_score': speakingScore,
      'reached_target': reachedTarget ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
```

- [ ] **Step 2: Create `lib/models/mock_test_targets.dart`**

```dart
import 'package:shared_preferences/shared_preferences.dart';

class MockTestTargets {
  final double overallTarget;
  final double listeningMin;
  final double readingMin;
  final double writingMin;
  final double speakingMin;

  const MockTestTargets({
    this.overallTarget = 7.0,
    this.listeningMin = 6.0,
    this.readingMin = 6.0,
    this.writingMin = 6.0,
    this.speakingMin = 6.0,
  });

  static const _keyOverall   = 'mock_target_overall';
  static const _keyListening = 'mock_target_listening';
  static const _keyReading   = 'mock_target_reading';
  static const _keyWriting   = 'mock_target_writing';
  static const _keySpeaking  = 'mock_target_speaking';

  static Future<MockTestTargets> load() async {
    final prefs = await SharedPreferences.getInstance();
    return MockTestTargets(
      overallTarget: prefs.getDouble(_keyOverall)   ?? 7.0,
      listeningMin:  prefs.getDouble(_keyListening) ?? 6.0,
      readingMin:    prefs.getDouble(_keyReading)   ?? 6.0,
      writingMin:    prefs.getDouble(_keyWriting)   ?? 6.0,
      speakingMin:   prefs.getDouble(_keySpeaking)  ?? 6.0,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyOverall,   overallTarget);
    await prefs.setDouble(_keyListening, listeningMin);
    await prefs.setDouble(_keyReading,   readingMin);
    await prefs.setDouble(_keyWriting,   writingMin);
    await prefs.setDouble(_keySpeaking,  speakingMin);
  }

  bool isReached(double listening, double reading, double writing, double speaking) {
    final avg = (listening + reading + writing + speaking) / 4;
    final rounded = (avg * 2).round() / 2;
    return rounded >= overallTarget &&
        listening >= listeningMin &&
        reading   >= readingMin &&
        writing   >= writingMin &&
        speaking  >= speakingMin;
  }
}
```

- [ ] **Step 3: Add shared_preferences to pubspec.yaml**

Open `pubspec.yaml` and add under `dependencies:`:
```yaml
  shared_preferences: ^2.3.0
```

Then run:
```
flutter pub get
```

Expected: resolves without errors.

- [ ] **Step 4: Commit**

```
git add lib/models/mock_test.dart lib/models/mock_test_targets.dart pubspec.yaml pubspec.lock
git commit -m "feat: add MockTest and MockTestTargets models"
```

---

## Task 2: Database migration — v14 → v15

**Files:**
- Modify: `lib/core/database/app_database.dart:22` (version number)
- Modify: `lib/core/database/app_database.dart:151-161` (_onCreate)
- Modify: `lib/core/database/app_database.dart:291-302` (_onUpgrade)

- [ ] **Step 1: Bump DB version and add table to `_onCreate`**

In `_open()`, change:
```dart
return openDatabase(path, version: 14, onCreate: _onCreate, onUpgrade: _onUpgrade);
```
to:
```dart
return openDatabase(path, version: 15, onCreate: _onCreate, onUpgrade: _onUpgrade);
```

Then, inside `_onCreate`, add after the `study_sessions` block (after the closing `''');` on line 160):

```dart
    await db.execute('''
      CREATE TABLE mock_tests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        listening_score REAL NOT NULL,
        reading_score REAL NOT NULL,
        writing_score REAL NOT NULL,
        speaking_score REAL NOT NULL,
        reached_target INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
```

- [ ] **Step 2: Add upgrade block for v15**

In `_onUpgrade`, add after the `if (oldVersion < 14)` block:

```dart
    if (oldVersion < 15) {
      await db.execute('''
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
      ''');
    }
```

- [ ] **Step 3: Commit**

```
git add lib/core/database/app_database.dart
git commit -m "feat: add mock_tests table (DB v15)"
```

---

## Task 3: MockTestRepository + tests

**Files:**
- Create: `lib/repositories/mock_test_repository.dart`
- Create: `test/repositories/mock_test_repository_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/repositories/mock_test_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daily_english/models/mock_test.dart';
import 'package:daily_english/repositories/mock_test_repository.dart';

void main() {
  late Database db;
  late MockTestRepository repo;

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
            CREATE TABLE mock_tests (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL,
              listening_score REAL NOT NULL,
              reading_score REAL NOT NULL,
              writing_score REAL NOT NULL,
              speaking_score REAL NOT NULL,
              reached_target INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    repo = MockTestRepository(Future.value(db));
  });

  tearDown(() => db.close());

  MockTest _makeTest({bool reachedTarget = false, String date = '2026-05-21'}) {
    return MockTest(
      date: date,
      listeningScore: 6.5,
      readingScore: 7.0,
      writingScore: 6.0,
      speakingScore: 6.5,
      reachedTarget: reachedTarget,
      createdAt: DateTime(2026, 5, 21),
    );
  }

  test('getAll returns empty list when table is empty', () async {
    final result = await repo.getAll();
    expect(result, isEmpty);
  });

  test('insert then getAll returns the test', () async {
    await repo.insert(_makeTest());
    final result = await repo.getAll();
    expect(result.length, 1);
    expect(result.first.listeningScore, 6.5);
    expect(result.first.readingScore, 7.0);
    expect(result.first.reachedTarget, false);
  });

  test('getAll orders by date DESC', () async {
    await repo.insert(_makeTest(date: '2026-05-01'));
    await repo.insert(_makeTest(date: '2026-05-21'));
    final result = await repo.getAll();
    expect(result.first.date, '2026-05-21');
    expect(result.last.date, '2026-05-01');
  });

  test('delete removes the test', () async {
    await repo.insert(_makeTest());
    final all = await repo.getAll();
    await repo.delete(all.first.id!);
    expect(await repo.getAll(), isEmpty);
  });

  test('insert assigns id', () async {
    await repo.insert(_makeTest());
    final result = await repo.getAll();
    expect(result.first.id, isNotNull);
  });

  test('reachedTarget=true round-trips correctly', () async {
    await repo.insert(_makeTest(reachedTarget: true));
    final result = await repo.getAll();
    expect(result.first.reachedTarget, true);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```
flutter test test/repositories/mock_test_repository_test.dart -v
```

Expected: FAIL — `MockTestRepository` not defined.

- [ ] **Step 3: Implement `lib/repositories/mock_test_repository.dart`**

```dart
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
```

- [ ] **Step 4: Run tests to verify they pass**

```
flutter test test/repositories/mock_test_repository_test.dart -v
```

Expected: 6 tests PASS.

- [ ] **Step 5: Commit**

```
git add lib/repositories/mock_test_repository.dart test/repositories/mock_test_repository_test.dart
git commit -m "feat: add MockTestRepository with tests"
```

---

## Task 4: Mock test providers

**Files:**
- Create: `lib/providers/mock_test_provider.dart`

- [ ] **Step 1: Create `lib/providers/mock_test_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/mock_test.dart';
import '../models/mock_test_targets.dart';
import '../repositories/mock_test_repository.dart';
import 'word_provider.dart';

final mockTestRepositoryProvider = Provider<MockTestRepository>((ref) {
  final appDb = ref.watch(databaseProvider);
  return MockTestRepository(appDb.database);
});

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

class MockTestTargetsNotifier extends AsyncNotifier<MockTestTargets> {
  @override
  Future<MockTestTargets> build() => MockTestTargets.load();

  Future<void> updateTargets(MockTestTargets targets) async {
    await targets.save();
    ref.invalidateSelf();
  }
}

final mockTestTargetsProvider =
    AsyncNotifierProvider<MockTestTargetsNotifier, MockTestTargets>(
        MockTestTargetsNotifier.new);

class MockTestStats {
  final int done;
  final int positive;
  final double rate;
  final bool bookTest;

  const MockTestStats({
    required this.done,
    required this.positive,
    required this.rate,
    required this.bookTest,
  });

  static const empty = MockTestStats(
    done: 0,
    positive: 0,
    rate: 0,
    bookTest: false,
  );
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

- [ ] **Step 2: Verify it compiles**

```
flutter analyze lib/providers/mock_test_provider.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```
git add lib/providers/mock_test_provider.dart
git commit -m "feat: add mock test providers and MockTestStats"
```

---

## Task 5: MockTestForm — add test bottom sheet

**Files:**
- Create: `lib/screens/study/mock_test_form.dart`

- [ ] **Step 1: Create `lib/screens/study/mock_test_form.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/mock_test.dart';
import '../../providers/mock_test_provider.dart';
import '../../core/theme/app_theme.dart';

class MockTestForm extends ConsumerStatefulWidget {
  const MockTestForm({super.key});

  @override
  ConsumerState<MockTestForm> createState() => _MockTestFormState();
}

class _MockTestFormState extends ConsumerState<MockTestForm> {
  DateTime _selectedDate = DateTime.now();
  double? _listening;
  double? _reading;
  double? _writing;
  double? _speaking;
  bool _saving = false;

  static final List<double> _bands = [
    for (int i = 0; i <= 18; i++) i * 0.5,
  ];

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    final l = _listening;
    final r = _reading;
    final w = _writing;
    final s = _speaking;
    if (l == null || r == null || w == null || s == null) return;

    setState(() => _saving = true);
    try {
      final targetsAsync = ref.read(mockTestTargetsProvider);
      final targets = targetsAsync.valueOrNull;
      final reachedTarget = targets?.isReached(l, r, w, s) ?? false;

      final test = MockTest(
        date:
            '${_selectedDate.year}-'
            '${_selectedDate.month.toString().padLeft(2, '0')}-'
            '${_selectedDate.day.toString().padLeft(2, '0')}',
        listeningScore: l,
        readingScore: r,
        writingScore: w,
        speakingScore: s,
        reachedTarget: reachedTarget,
        createdAt: DateTime.now(),
      );
      await ref.read(mockTestListProvider.notifier).addTest(test);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _scoreDropdown(
      String label, double? value, ValueChanged<double?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        DropdownButtonFormField<double>(
          value: value,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
          ),
          hint: Text('Select', style: GoogleFonts.nunito(fontSize: 14)),
          items: _bands
              .map((b) => DropdownMenuItem(
                    value: b,
                    child: Text(b.toStringAsFixed(1),
                        style: GoogleFonts.nunito(fontSize: 14)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add Mock Test',
              style:
                  GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date',
                labelStyle: GoogleFonts.nunito(),
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.calendar_today_rounded),
              ),
              child: Text(_formatDate(_selectedDate),
                  style: GoogleFonts.nunito(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _scoreDropdown('Listening', _listening,
                    (v) => setState(() => _listening = v)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _scoreDropdown('Reading', _reading,
                    (v) => setState(() => _reading = v)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _scoreDropdown('Writing', _writing,
                    (v) => setState(() => _writing = v)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _scoreDropdown('Speaking', _speaking,
                    (v) => setState(() => _speaking = v)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style:
                  FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('Save',
                      style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

```
flutter analyze lib/screens/study/mock_test_form.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```
git add lib/screens/study/mock_test_form.dart
git commit -m "feat: add MockTestForm bottom sheet"
```

---

## Task 6: MockTargetsSheet — configure target bands

**Files:**
- Create: `lib/screens/study/mock_targets_sheet.dart`

- [ ] **Step 1: Create `lib/screens/study/mock_targets_sheet.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/mock_test_targets.dart';
import '../../providers/mock_test_provider.dart';
import '../../core/theme/app_theme.dart';

class MockTargetsSheet extends ConsumerStatefulWidget {
  const MockTargetsSheet({super.key});

  @override
  ConsumerState<MockTargetsSheet> createState() => _MockTargetsSheetState();
}

class _MockTargetsSheetState extends ConsumerState<MockTargetsSheet> {
  double _overall = 7.0;
  double _listening = 6.0;
  double _reading = 6.0;
  double _writing = 6.0;
  double _speaking = 6.0;
  bool _saving = false;

  static final List<double> _bands = [
    for (int i = 0; i <= 18; i++) i * 0.5,
  ];

  @override
  void initState() {
    super.initState();
    final current = ref.read(mockTestTargetsProvider).valueOrNull;
    if (current != null) {
      _overall   = current.overallTarget;
      _listening = current.listeningMin;
      _reading   = current.readingMin;
      _writing   = current.writingMin;
      _speaking  = current.speakingMin;
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(mockTestTargetsProvider.notifier).updateTargets(
            MockTestTargets(
              overallTarget: _overall,
              listeningMin: _listening,
              readingMin: _reading,
              writingMin: _writing,
              speakingMin: _speaking,
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _targetDropdown(
      String label, double value, ValueChanged<double?> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: GoogleFonts.nunito(
                  fontSize: 14, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: DropdownButtonFormField<double>(
            value: value,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            items: _bands
                .map((b) => DropdownMenuItem(
                      value: b,
                      child: Text(b.toStringAsFixed(1),
                          style: GoogleFonts.nunito(fontSize: 14)),
                    ))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Target Scores',
              style: GoogleFonts.nunito(
                  fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Test is positive when ALL conditions are met.',
              style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          _targetDropdown(
              'Overall ≥', _overall, (v) => setState(() => _overall = v!)),
          const SizedBox(height: 10),
          _targetDropdown('Listening ≥', _listening,
              (v) => setState(() => _listening = v!)),
          const SizedBox(height: 10),
          _targetDropdown(
              'Reading ≥', _reading, (v) => setState(() => _reading = v!)),
          const SizedBox(height: 10),
          _targetDropdown(
              'Writing ≥', _writing, (v) => setState(() => _writing = v!)),
          const SizedBox(height: 10),
          _targetDropdown('Speaking ≥', _speaking,
              (v) => setState(() => _speaking = v!)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style:
                  FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('Save',
                      style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

```
flutter analyze lib/screens/study/mock_targets_sheet.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```
git add lib/screens/study/mock_targets_sheet.dart
git commit -m "feat: add MockTargetsSheet for configuring IELTS target bands"
```

---

## Task 7: StudyLogScreen — tabs, mock test list, live stats

**Files:**
- Modify: `lib/screens/study/study_log_screen.dart`

This task rewrites `StudyLogScreen` substantially. The full replacement is below.

- [ ] **Step 1: Replace `lib/screens/study/study_log_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/mock_test.dart';
import '../../models/study_session.dart';
import '../../providers/mock_test_provider.dart';
import '../../providers/study_session_provider.dart';
import '../../core/theme/app_theme.dart';
import 'mock_targets_sheet.dart';
import 'mock_test_form.dart';
import 'study_session_form.dart';

enum _SessionAction { edit, delete }

class StudyLogScreen extends ConsumerStatefulWidget {
  const StudyLogScreen({super.key});

  @override
  ConsumerState<StudyLogScreen> createState() => _StudyLogScreenState();
}

class _StudyLogScreenState extends ConsumerState<StudyLogScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _addSession(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const StudySessionForm(),
    );
  }

  void _addMockTest(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const MockTestForm(),
    );
  }

  void _openTargets(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const MockTargetsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(studySessionListProvider);
    final studyStats = ref.watch(studyStatsProvider);
    final mockStats = ref.watch(mockTestStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Log'),
        leading: BackButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Target scores',
            onPressed: () => _openTargets(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _tabController.index == 0
            ? _addSession(context)
            : _addMockTest(context),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          _StatsHeader(stats: studyStats, mockStats: mockStats),
          TabBar(
            controller: _tabController,
            labelStyle:
                GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800),
            unselectedLabelStyle:
                GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Sessions'),
              Tab(text: 'Mock Tests'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Sessions tab
                sessionsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      const Center(child: Text('Error loading sessions.')),
                  data: (sessions) {
                    final grouped = <StudyType, List<StudySession>>{
                      for (final t in StudyType.values)
                        t: sessions.where((s) => s.type == t).toList(),
                    };
                    return ListView(
                      children: [
                        for (final type in StudyType.values)
                          _SkillGroup(type: type, sessions: grouped[type]!),
                        const SizedBox(height: 80),
                      ],
                    );
                  },
                ),
                // Mock Tests tab
                const _MockTestsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats header ────────────────────────────────────────────────────────────

class _StatsHeader extends StatelessWidget {
  final StudyStats stats;
  final MockTestStats mockStats;
  const _StatsHeader({required this.stats, required this.mockStats});

  String _fmt(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Study Time',
                          style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      Text(_fmt(stats.totalMinutes),
                          style: GoogleFonts.nunito(
                              fontSize: 28, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    stats.estimatedLevel,
                    style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _SkillStat(
                    label: 'Listening',
                    minutes: stats.listeningMinutes,
                    color: AppTheme.primary),
                const SizedBox(width: 12),
                _SkillStat(
                    label: 'Reading',
                    minutes: stats.readingMinutes,
                    color: AppTheme.secondary),
                const SizedBox(width: 12),
                _SkillStat(
                    label: 'Writing',
                    minutes: stats.writingMinutes,
                    color: AppTheme.tertiary),
                const SizedBox(width: 12),
                _SkillStat(
                    label: 'Speaking',
                    minutes: stats.speakingMinutes,
                    color: Colors.orange),
              ],
            ),
            const Divider(height: 28),
            Text('MOCK TESTS',
                style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Row(
              children: [
                _MockStat(label: 'Done', value: '${mockStats.done}'),
                _MockStat(label: 'Positive', value: '${mockStats.positive}'),
                _MockStat(
                    label: 'Rate',
                    value: mockStats.done == 0
                        ? '—'
                        : '${mockStats.rate.toStringAsFixed(0)}%'),
                _MockStat(
                    label: 'Book test?',
                    value: mockStats.done == 0
                        ? '—'
                        : (mockStats.bookTest ? 'Yes' : 'No')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillStat extends StatelessWidget {
  final String label;
  final int minutes;
  final Color color;
  const _SkillStat(
      {required this.label, required this.minutes, required this.color});

  String _fmt(int m) {
    final h = m ~/ 60;
    final min = m % 60;
    if (h == 0) return '${min}m';
    if (min == 0) return '${h}h';
    return '${h}h${min}m';
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(_fmt(minutes),
              style: GoogleFonts.nunito(
                  fontSize: 14, fontWeight: FontWeight.w900, color: color)),
          Text(label,
              style: GoogleFonts.nunito(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _MockStat extends StatelessWidget {
  final String label;
  final String value;
  const _MockStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: GoogleFonts.nunito(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
          Text(value,
              style:
                  GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

// ─── Sessions tab widgets ────────────────────────────────────────────────────

class _SkillGroup extends StatelessWidget {
  final StudyType type;
  final List<StudySession> sessions;

  static const _typeIcons = {
    StudyType.listening: Icons.headphones_rounded,
    StudyType.reading: Icons.menu_book_rounded,
    StudyType.writing: Icons.edit_rounded,
    StudyType.speaking: Icons.record_voice_over_rounded,
  };

  static const _typeColors = {
    StudyType.listening: AppTheme.primary,
    StudyType.reading: AppTheme.secondary,
    StudyType.writing: AppTheme.tertiary,
    StudyType.speaking: Colors.orange,
  };

  const _SkillGroup({required this.type, required this.sessions});

  String _fmt(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColors[type]!;
    final icon = _typeIcons[type]!;
    final totalMinutes = sessions.fold(0, (sum, s) => sum + s.durationMinutes);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Icon(icon, color: color),
        title: Text(
          '${type.label}  ·  ${_fmt(totalMinutes)}',
          style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        children: sessions.isEmpty
            ? [
                ListTile(
                  title: Text('No sessions yet.',
                      style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant)),
                ),
              ]
            : sessions
                .map((s) => _SessionTile(key: ValueKey(s.id), session: s))
                .toList(),
      ),
    );
  }
}

class _SessionTile extends ConsumerWidget {
  final StudySession session;
  const _SessionTile({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = session.durationMinutes ~/ 60;
    final m = session.durationMinutes % 60;
    final durationStr = h > 0 ? '${h}h ${m}m' : '${m}m';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(durationStr,
          style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (session.activity != null)
            Text(session.activity!,
                style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          Text(session.date,
              style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
      trailing: PopupMenuButton<_SessionAction>(
        icon: const Icon(Icons.more_vert_rounded),
        onSelected: (action) async {
          switch (action) {
            case _SessionAction.edit:
              if (!context.mounted) return;
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24))),
                builder: (_) => StudySessionForm(initialSession: session),
              );
            case _SessionAction.delete:
              final id = session.id;
              if (id == null) return;
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete this session?'),
                  content: const Text('This cannot be undone.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete',
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await ref
                    .read(studySessionListProvider.notifier)
                    .deleteSession(id);
              }
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: _SessionAction.edit,
            child: ListTile(
                leading: Icon(Icons.edit_rounded),
                title: Text('Edit'),
                contentPadding: EdgeInsets.zero),
          ),
          PopupMenuItem(
            value: _SessionAction.delete,
            child: ListTile(
                leading: Icon(Icons.delete_rounded, color: Colors.red),
                title:
                    Text('Delete', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero),
          ),
        ],
      ),
    );
  }
}

// ─── Mock Tests tab ──────────────────────────────────────────────────────────

class _MockTestsTab extends ConsumerWidget {
  const _MockTestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testsAsync = ref.watch(mockTestListProvider);
    return testsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('Error loading mock tests.')),
      data: (tests) {
        if (tests.isEmpty) {
          return const Center(
            child: ListTile(
              title: Text('No mock tests yet.'),
            ),
          );
        }
        return ListView(
          children: [
            ...tests.map(
                (t) => _MockTestTile(key: ValueKey(t.id), test: t)),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }
}

class _MockTestTile extends ConsumerWidget {
  final MockTest test;
  const _MockTestTile({super.key, required this.test});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(test.date,
          style:
              GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800)),
      subtitle: Text(
        'L ${test.listeningScore.toStringAsFixed(1)}  ·  '
        'R ${test.readingScore.toStringAsFixed(1)}  ·  '
        'W ${test.writingScore.toStringAsFixed(1)}  ·  '
        'S ${test.speakingScore.toStringAsFixed(1)}',
        style: GoogleFonts.nunito(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            test.reachedTarget ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: test.reachedTarget ? Colors.green : Colors.red,
            size: 20,
          ),
          PopupMenuButton<void>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (_) async {
              final id = test.id;
              if (id == null) return;
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete this test?'),
                  content: const Text('This cannot be undone.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete',
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await ref
                    .read(mockTestListProvider.notifier)
                    .deleteTest(id);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                child: ListTile(
                    leading: Icon(Icons.delete_rounded, color: Colors.red),
                    title: Text('Delete',
                        style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run analyzer**

```
flutter analyze lib/screens/study/study_log_screen.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```
git add lib/screens/study/study_log_screen.dart
git commit -m "feat: add mock tests tab to StudyLogScreen with live stats"
```

---

## Task 8: HomeScreen — live mock test stats

**Files:**
- Modify: `lib/screens/home/home_screen.dart`

The `_StudySummaryCard` already has a hardcoded `Text('Mock tests: —', ...)`. Replace it with a live value from `mockTestStatsProvider`.

- [ ] **Step 1: Add import and update `_StudySummaryCard`**

At the top of `home_screen.dart`, add:
```dart
import '../providers/mock_test_provider.dart';
```

Find `_StudySummaryCard` (it is a `ConsumerWidget` that watches `studyStatsProvider`). Replace the hardcoded line:
```dart
            Text(
              'Mock tests: —',
              style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700),
            ),
```

with:
```dart
            Consumer(
              builder: (context, ref, _) {
                final mockStats = ref.watch(mockTestStatsProvider);
                final mockText = mockStats.done == 0
                    ? '—'
                    : '${mockStats.positive}/${mockStats.done} '
                      '(${mockStats.rate.toStringAsFixed(0)}%)';
                return Text(
                  'Mock tests: $mockText',
                  style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700),
                );
              },
            ),
```

- [ ] **Step 2: Run analyzer**

```
flutter analyze lib/screens/home/home_screen.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```
git add lib/screens/home/home_screen.dart
git commit -m "feat: show live mock test stats in home screen summary card"
```

---

## Self-Review Checklist

- [x] MockTest model — fromMap/toMap, reachedTarget as int 0/1 in DB
- [x] MockTestTargets — SharedPreferences load/save, isReached() helper
- [x] DB v15 — table in _onCreate AND _onUpgrade
- [x] Repository — getAll/insert/delete, ordered by date DESC
- [x] Tests — 6 cases covering empty, insert, order, delete, id assignment, bool round-trip
- [x] All 4 providers — repository, list notifier, targets notifier, stats
- [x] MockTestStats — done/positive/rate/bookTest (rate > 70%)
- [x] MockTestForm — date + 4 IELTS score dropdowns, reachedTarget computed on save
- [x] MockTargetsSheet — 5 dropdowns, saves via updateTargets()
- [x] StudyLogScreen — ConsumerStatefulWidget + TabController, FAB tab-aware, _StatsHeader takes mockStats
- [x] _MockTestsTab — live list, empty state, ValueKey, delete with confirmation
- [x] HomeScreen — Consumer inline for mock stats, same text style
- [x] shared_preferences added to pubspec.yaml
