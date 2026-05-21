# Study Log v2 — Design Spec

**Date:** 2026-05-21

## Overview

Improve the existing study tracking feature with three changes: edit support for saved sessions, sessions grouped by skill type in expandable cards, and a dashboard that also reserves space for future mock test stats.

---

## Data Layer

### StudySessionRepository — new method

```dart
Future<void> update(StudySession session) async {
  final db = await _futureDb;
  await db.update('study_sessions', session.toMap(),
      where: 'id = ?', whereArgs: [session.id]);
}
```

### StudySessionListNotifier — new method

```dart
Future<void> updateSession(StudySession session) async {
  await ref.read(studySessionRepositoryProvider).update(session);
  ref.invalidateSelf();
}
```

No database schema changes. No migration needed.

---

## StudySessionForm — edit mode

Add an optional parameter:

```dart
class StudySessionForm extends ConsumerStatefulWidget {
  final StudySession? initialSession;
  const StudySessionForm({super.key, this.initialSession});
}
```

Behaviour when `initialSession != null`:
- Title shows **"Edit Session"** instead of "Register Study"
- All fields pre-fill: type chip selected, duration picker set to `TimeOfDay(hour: h, minute: m)` where `h = initialSession.durationMinutes ~/ 60` and `m = initialSession.durationMinutes % 60`, date parsed from `initialSession.date` via `DateTime.parse`, activity text filled
- Save constructs a new `StudySession` directly, preserving `id` and `createdAt` from `initialSession`, and calls `updateSession(...)` instead of `addSession(...)`

No `copyWith` needed — the form already owns all field values at save time.

---

## StudyLogScreen — grouped expandable cards

Sessions are grouped into 4 `ExpansionTile` cards ordered: Listening → Reading → Writing → Speaking.

Grouping logic:
```dart
final grouped = <StudyType, List<StudySession>>{
  for (final t in StudyType.values)
    t: sessions.where((s) => s.type == t).toList(),
};
```

Each `ExpansionTile`:
- `initiallyExpanded: true`
- Leading: skill icon + color (matching `_typeIcons` / `_typeColors`)
- Title: skill label + total time for that skill (e.g. "Listening · 2h 30m")
- Children: list of `_SessionTile` for that skill, or a "No sessions yet." `ListTile` if empty

### _SessionTile — ⋮ menu replaces Dismissible

Remove `Dismissible`. Add `trailing: PopupMenuButton` with two items:

- **Edit** — opens `showModalBottomSheet` with `StudySessionForm(initialSession: session)`
- **Delete** — shows `showDialog` confirmation ("Delete this session?", Cancel / Delete buttons), on confirm calls `deleteSession(session.id!)`

---

## Dashboard — mock test placeholders

### _StatsHeader (StudyLogScreen)

Add a second section below the skill breakdown row, separated by a `Divider`:

```
MOCK TESTS
[ Done ]  [ Positive ]  [ Rate ]  [ Book test? ]
[  —   ]  [    —     ]  [  —  ]  [     —      ]
```

Rendered as a `Row` of 4 `Expanded` → `Column` widgets, each with a small label (`10px onSurfaceVariant`) above a bold value (`14px`). Values are hardcoded `"—"` until Sub-project B is built. A `Text('MOCK TESTS', ...)` heading in the same style as section labels appears above the row.

### _StudySummaryCard (HomeScreen)

Add one line below the L/R/W/S breakdown:

```
Mock tests: —
```

Same style as the existing breakdown text (12px, `onSurfaceVariant`, `FontWeight.w700`). Hardcoded `"—"` until Sub-project B.

---

## Modified Files

| File | Change |
|------|--------|
| `lib/repositories/study_session_repository.dart` | Add `update()` method |
| `lib/providers/study_session_provider.dart` | Add `updateSession()` to notifier |
| `lib/screens/study/study_session_form.dart` | Add `initialSession` param + edit mode |
| `lib/screens/study/study_log_screen.dart` | Grouped `ExpansionTile` cards + ⋮ menu + mock test placeholders |
| `lib/screens/home/home_screen.dart` | Add "Mock tests: —" line to `_StudySummaryCard` |
