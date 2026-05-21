# Register Study Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a study session tracking feature — a "Register Study" button on the home screen that logs Listening/Reading/Writing/Speaking sessions, with a dashboard summary and a full Study Log screen.

**Architecture:** New `study_sessions` SQLite table (DB v14), following the same model→repository→provider→screen pattern as Diary. A derived `studyStatsProvider` computes per-skill totals and an estimated English level (A1→C2) from cumulative hours. The home screen gains a stats card and a "Register Study" button that opens a bottom sheet form.

**Tech Stack:** Flutter, Riverpod (AsyncNotifierProvider, Provider), sqflite, go_router, google_fonts.

---

## File Map

| Action | File |
|--------|------|
| Create | `lib/models/study_session.dart` |
| Create | `lib/repositories/study_session_repository.dart` |
| Create | `lib/providers/study_session_provider.dart` |
| Create | `lib/screens/study/study_session_form.dart` |
| Create | `lib/screens/study/study_log_screen.dart` |
| Modify | `lib/core/database/app_database.dart` |
| Modify | `lib/core/router/app_router.dart` |
| Modify | `lib/screens/home/home_screen.dart` |

---

### Task 1: StudySession model and StudyType enum

**Files:**
- Create: `lib/models/study_session.dart`

- [ ] **Step 1: Create `lib/models/study_session.dart`**

```dart
enum StudyType {
  listening,
  reading,
  writing,
  speaking;

  String get label => name[0].toUpperCase() + name.substring(1);

  static StudyType fromString(String value) =>
      StudyType.values.firstWhere((e) => e.name == value);
}

class StudySession {
  final int? id;
  final StudyType type;
  final int durationMinutes;
  final String date; // YYYY-MM-DD
  final String? activity;
  final DateTime createdAt;

  const StudySession({
    this.id,
    required this.type,
    required this.durationMinutes,
    required this.date,
    this.activity,
    required this.createdAt,
  });

  factory StudySession.fromMap(Map<String, dynamic> map) {
    return StudySession(
      id: map['id'] as int?,
      type: StudyType.fromString(map['type'] as String),
      durationMinutes: map['duration_minutes'] as int,
      date: map['date'] as String,
      activity: map['activity'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'type': type.name,
      'duration_minutes': durationMinutes,
      'date': date,
      'activity': activity,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/models/study_session.dart
git commit -m "feat: add StudySession model and StudyType enum"
```

---

### Task 2: StudySessionRepository

**Files:**
- Create: `lib/repositories/study_session_repository.dart`

- [ ] **Step 1: Create `lib/repositories/study_session_repository.dart`**

```dart
import 'package:sqflite/sqflite.dart';
import '../models/study_session.dart';

class StudySessionRepository {
  final Future<Database> _futureDb;

  const StudySessionRepository(this._futureDb);

  Future<List<StudySession>> getAll() async {
    final db = await _futureDb;
    final maps = await db.query('study_sessions', orderBy: 'date DESC, created_at DESC');
    return maps.map(StudySession.fromMap).toList();
  }

  Future<int> insert(StudySession session) async {
    final db = await _futureDb;
    return db.insert('study_sessions', session.toMap());
  }

  Future<void> delete(int id) async {
    final db = await _futureDb;
    await db.delete('study_sessions', where: 'id = ?', whereArgs: [id]);
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/repositories/study_session_repository.dart
git commit -m "feat: add StudySessionRepository"
```

---

### Task 3: Database migration

**Files:**
- Modify: `lib/core/database/app_database.dart`

- [ ] **Step 1: Read the current file**

Open `lib/core/database/app_database.dart` and confirm the current `version` is `13`.

- [ ] **Step 2: Bump version to 14 and add table to `_onCreate`**

Change the `openDatabase` call:
```dart
return openDatabase(path, version: 14, onCreate: _onCreate, onUpgrade: _onUpgrade);
```

Add the `study_sessions` table at the end of `_onCreate`, after the `player_stats` insert:
```dart
await db.execute('''
  CREATE TABLE study_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT NOT NULL,
    duration_minutes INTEGER NOT NULL,
    date TEXT NOT NULL,
    activity TEXT,
    created_at TEXT NOT NULL
  )
''');
```

- [ ] **Step 3: Add version 14 migration block to `_onUpgrade`**

Add at the end of `_onUpgrade`:
```dart
if (oldVersion < 14) {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS study_sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL,
      duration_minutes INTEGER NOT NULL,
      date TEXT NOT NULL,
      activity TEXT,
      created_at TEXT NOT NULL
    )
  ''');
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/core/database/app_database.dart
git commit -m "feat: add study_sessions table (DB v14)"
```

---

### Task 4: StudySessionProvider and StudyStats

**Files:**
- Create: `lib/providers/study_session_provider.dart`

- [ ] **Step 1: Create `lib/providers/study_session_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/study_session.dart';
import '../repositories/study_session_repository.dart';
import 'word_provider.dart';

final studySessionRepositoryProvider = Provider<StudySessionRepository>((ref) {
  final appDb = ref.watch(databaseProvider);
  return StudySessionRepository(appDb.database);
});

class StudySessionListNotifier extends AsyncNotifier<List<StudySession>> {
  @override
  Future<List<StudySession>> build() =>
      ref.read(studySessionRepositoryProvider).getAll();

  Future<void> addSession(StudySession session) async {
    await ref.read(studySessionRepositoryProvider).insert(session);
    ref.invalidateSelf();
  }

  Future<void> deleteSession(int id) async {
    await ref.read(studySessionRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }
}

final studySessionListProvider =
    AsyncNotifierProvider<StudySessionListNotifier, List<StudySession>>(
        StudySessionListNotifier.new);

class StudyStats {
  final int listeningMinutes;
  final int readingMinutes;
  final int writingMinutes;
  final int speakingMinutes;

  const StudyStats({
    required this.listeningMinutes,
    required this.readingMinutes,
    required this.writingMinutes,
    required this.speakingMinutes,
  });

  int get totalMinutes =>
      listeningMinutes + readingMinutes + writingMinutes + speakingMinutes;

  double get totalHours => totalMinutes / 60;

  String get estimatedLevel {
    final h = totalHours;
    if (h < 90) return 'Not started';
    if (h < 180) return 'A1';
    if (h < 350) return 'A2';
    if (h < 600) return 'B1';
    if (h < 900) return 'B2';
    if (h < 1800) return 'C1';
    return 'C2';
  }

  static const empty = StudyStats(
    listeningMinutes: 0,
    readingMinutes: 0,
    writingMinutes: 0,
    speakingMinutes: 0,
  );
}

// Derived from studySessionListProvider so it auto-updates on insert/delete.
final studyStatsProvider = Provider<StudyStats>((ref) {
  final sessionsAsync = ref.watch(studySessionListProvider);
  return sessionsAsync.when(
    loading: () => StudyStats.empty,
    error: (_, __) => StudyStats.empty,
    data: (sessions) {
      final minutes = <String, int>{};
      for (final s in sessions) {
        minutes[s.type.name] = (minutes[s.type.name] ?? 0) + s.durationMinutes;
      }
      return StudyStats(
        listeningMinutes: minutes[StudyType.listening.name] ?? 0,
        readingMinutes: minutes[StudyType.reading.name] ?? 0,
        writingMinutes: minutes[StudyType.writing.name] ?? 0,
        speakingMinutes: minutes[StudyType.speaking.name] ?? 0,
      );
    },
  );
});
```

- [ ] **Step 2: Commit**

```bash
git add lib/providers/study_session_provider.dart
git commit -m "feat: add StudySessionProvider and StudyStats"
```

---

### Task 5: StudySessionForm bottom sheet

**Files:**
- Create: `lib/screens/study/study_session_form.dart`

- [ ] **Step 1: Create `lib/screens/study/study_session_form.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/study_session.dart';
import '../../providers/study_session_provider.dart';
import '../../core/theme/app_theme.dart';

class StudySessionForm extends ConsumerStatefulWidget {
  const StudySessionForm({super.key});

  @override
  ConsumerState<StudySessionForm> createState() => _StudySessionFormState();
}

class _StudySessionFormState extends ConsumerState<StudySessionForm> {
  StudyType? _selectedType;
  final _durationController = TextEditingController();
  final _activityController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _durationController.dispose();
    _activityController.dispose();
    super.dispose();
  }

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
    final type = _selectedType;
    final minutes = int.tryParse(_durationController.text.trim());
    if (type == null || minutes == null || minutes <= 0) return;

    setState(() => _saving = true);
    final session = StudySession(
      type: type,
      durationMinutes: minutes,
      date:
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
      activity: _activityController.text.trim().isEmpty
          ? null
          : _activityController.text.trim(),
      createdAt: DateTime.now(),
    );
    await ref.read(studySessionListProvider.notifier).addSession(session);
    if (mounted) Navigator.of(context).pop();
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
          Text(
            'Register Study',
            style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 20),
          Text('Study type',
              style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: StudyType.values.map((t) {
              final selected = _selectedType == t;
              return ChoiceChip(
                label: Text(t.label,
                    style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface)),
                selected: selected,
                selectedColor: AppTheme.primary,
                onSelected: (_) => setState(() => _selectedType = t),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _durationController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Duration (minutes)',
              labelStyle: GoogleFonts.nunito(),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
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
          TextField(
            controller: _activityController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'What did you do? (optional)',
              hintText: 'e.g. Netflix series, News article, Language exchange',
              labelStyle: GoogleFonts.nunito(),
              hintStyle: GoogleFonts.nunito(fontSize: 13),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
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

- [ ] **Step 2: Commit**

```bash
git add lib/screens/study/study_session_form.dart
git commit -m "feat: add StudySessionForm bottom sheet"
```

---

### Task 6: StudyLogScreen

**Files:**
- Create: `lib/screens/study/study_log_screen.dart`

- [ ] **Step 1: Create `lib/screens/study/study_log_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/study_session.dart';
import '../../providers/study_session_provider.dart';
import '../../core/theme/app_theme.dart';
import 'study_session_form.dart';

class StudyLogScreen extends ConsumerWidget {
  const StudyLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(studySessionListProvider);
    final stats = ref.watch(studyStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Log'),
        leading: BackButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (_) => const StudySessionForm(),
        ),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Error loading sessions.')),
        data: (sessions) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _StatsHeader(stats: stats)),
            if (sessions.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.school_rounded,
                          size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('No study sessions yet.',
                          style: GoogleFonts.nunito(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      const SizedBox(height: 8),
                      Text("Tap + to register your first session.",
                          style: GoogleFonts.nunito(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final session = sessions[index];
                    return _SessionTile(session: session);
                  },
                  childCount: sessions.length,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  final StudyStats stats;
  const _StatsHeader({required this.stats});

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
                _SkillStat(label: 'Listening', minutes: stats.listeningMinutes, color: AppTheme.primary),
                const SizedBox(width: 12),
                _SkillStat(label: 'Reading', minutes: stats.readingMinutes, color: AppTheme.secondary),
                const SizedBox(width: 12),
                _SkillStat(label: 'Writing', minutes: stats.writingMinutes, color: AppTheme.tertiary),
                const SizedBox(width: 12),
                _SkillStat(label: 'Speaking', minutes: stats.speakingMinutes, color: Colors.orange),
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
  const _SkillStat({required this.label, required this.minutes, required this.color});

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
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: color)),
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

class _SessionTile extends ConsumerWidget {
  final StudySession session;
  const _SessionTile({required this.session});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _typeColors[session.type] ?? AppTheme.primary;
    final icon = _typeIcons[session.type] ?? Icons.school_rounded;
    final h = session.durationMinutes ~/ 60;
    final m = session.durationMinutes % 60;
    final durationStr = h > 0 ? '${h}h ${m}m' : '${m}m';

    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) {
        ref
            .read(studySessionListProvider.notifier)
            .deleteSession(session.id!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session deleted.')),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(
            '${session.type.label} · $durationStr',
            style: GoogleFonts.nunito(
                fontSize: 15, fontWeight: FontWeight.w800),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (session.activity != null)
                Text(session.activity!,
                    style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              Text(session.date,
                  style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/study/study_log_screen.dart
git commit -m "feat: add StudyLogScreen with stats header and session list"
```

---

### Task 7: Router — add /study-log route

**Files:**
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: Add import at the top of `app_router.dart`**

Add after the existing screen imports:
```dart
import '../../screens/study/study_log_screen.dart';
```

- [ ] **Step 2: Add the route inside the `routes` list**

Add after the `/games/quest` route:
```dart
GoRoute(
  path: '/study-log',
  builder: (context, state) => const StudyLogScreen(),
),
```

- [ ] **Step 3: Commit**

```bash
git add lib/core/router/app_router.dart
git commit -m "feat: add /study-log route"
```

---

### Task 8: Home screen — study card, button, and menu item

**Files:**
- Modify: `lib/screens/home/home_screen.dart`

- [ ] **Step 1: Add imports**

Add after the existing imports at the top of `home_screen.dart`:
```dart
import '../../providers/study_session_provider.dart';
import '../../screens/study/study_session_form.dart';
```

- [ ] **Step 2: Add `studyLog` to the `_HomeMenuItem` enum**

Change:
```dart
enum _HomeMenuItem { categories, exportBackup, importBackup, backupToDrive, restoreFromDrive }
```
To:
```dart
enum _HomeMenuItem { categories, studyLog, exportBackup, importBackup, backupToDrive, restoreFromDrive }
```

- [ ] **Step 3: Handle `studyLog` in the `onSelected` switch**

In the `PopupMenuButton.onSelected` callback, add a case:
```dart
case _HomeMenuItem.studyLog:
  context.push('/study-log');
```

- [ ] **Step 4: Add "Study Log" popup menu item**

In the `PopupMenuButton.itemBuilder` list, add after the `categories` item and before the first `PopupMenuDivider`:
```dart
const PopupMenuItem(
  value: _HomeMenuItem.studyLog,
  child: ListTile(
    leading: Icon(Icons.school_rounded),
    title: Text('Study Log'),
    contentPadding: EdgeInsets.zero,
  ),
),
```

- [ ] **Step 5: Add study summary card and "Register Study" button to the home body**

In the `else` branch of the `_searchQuery` conditional (the normal home content), add just before the final `const SizedBox(height: 24)` at the very end:

```dart
const SizedBox(height: 24),
_StudySummaryCard(),
const SizedBox(height: 12),
_StudyCard(
  label: 'Register Study',
  subtitle: 'Log a study session',
  icon: Icons.add_task_rounded,
  color: AppTheme.primary,
  onTap: () => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const StudySessionForm(),
  ),
),
```

- [ ] **Step 6: Add `_StudySummaryCard` widget at the bottom of `home_screen.dart`**

Add after the `_StudyCard` class:

```dart
class _StudySummaryCard extends ConsumerWidget {
  const _StudySummaryCard();

  String _fmt(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(studyStatsProvider);
    return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Study Progress',
                            style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                        Text(_fmt(stats.totalMinutes),
                            style: GoogleFonts.nunito(
                                fontSize: 22,
                                fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(stats.estimatedLevel,
                        style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'L ${_fmt(stats.listeningMinutes)}  ·  R ${_fmt(stats.readingMinutes)}  ·  W ${_fmt(stats.writingMinutes)}  ·  S ${_fmt(stats.speakingMinutes)}',
                style: GoogleFonts.nunito(
                    fontSize: 12,
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Note: `_StudySummaryCard` renders `StudyStats.empty` (all zeros, "Not started") until the first session is logged — no loading spinner needed since `studyStatsProvider` is a synchronous `Provider` derived from the list.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/home/home_screen.dart
git commit -m "feat: add study summary card and Register Study button to home screen"
```
