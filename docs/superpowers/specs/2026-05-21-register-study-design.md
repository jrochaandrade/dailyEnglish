# Register Study — Design Spec

**Date:** 2026-05-21

## Overview

Add a study session tracking feature to the Daily English app, adapted from the user's IELTS preparation spreadsheet (Routine Spreadsheet.xlsx). The spreadsheet tracks daily exposure in four skills (Listening, Reading, Writing, Speaking), accumulates total hours, and estimates the user's current English level (A1→C2). The app replicates this as a mobile-first experience.

**Out of scope (future feature):** Mock Tests tracking (Phase 3 of the spreadsheet).

---

## Architecture & Data

### Database

New table `study_sessions` added via migration (version 13 → 14):

```sql
CREATE TABLE study_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL,              -- 'listening' | 'reading' | 'writing' | 'speaking'
  duration_minutes INTEGER NOT NULL,
  date TEXT NOT NULL,              -- YYYY-MM-DD
  activity TEXT,                   -- "What did you do?" (nullable)
  created_at TEXT NOT NULL
)
```

### New Files

| File | Responsibility |
|------|----------------|
| `lib/models/study_session.dart` | `StudyType` enum + `StudySession` model with `fromMap`/`toMap` |
| `lib/repositories/study_session_repository.dart` | `getAll()`, `insert()`, `delete(int id)`, `getTotalMinutesByType()` → `Map<String, int>` |
| `lib/providers/study_session_provider.dart` | `StudySessionListNotifier` + `studyStatsProvider` |
| `lib/screens/study/study_log_screen.dart` | History list grouped by date + summary header |
| `lib/screens/study/study_session_form.dart` | Bottom sheet form widget |

### Modified Files

| File | Change |
|------|--------|
| `lib/core/database/app_database.dart` | Add `study_sessions` table + version 14 migration |
| `lib/core/router/app_router.dart` | Add `/study-log` route |
| `lib/screens/home/home_screen.dart` | Study summary card + "Register Study" button + Study Log menu item |

---

## StudyType Enum

```dart
enum StudyType {
  listening,
  reading,
  writing,
  speaking;

  String get label => name[0].toUpperCase() + name.substring(1);
}
```

---

## studyStatsProvider

Computed from all sessions. Returns a `StudyStats` value object:

```dart
class StudyStats {
  final int listeningMinutes;
  final int readingMinutes;
  final int writingMinutes;
  final int speakingMinutes;

  int get totalMinutes => listeningMinutes + readingMinutes + writingMinutes + speakingMinutes;
  double get totalHours => totalMinutes / 60;

  String get estimatedLevel {
    final h = totalHours;
    if (h < 90)   return 'Not started';
    if (h < 180)  return 'A1';
    if (h < 350)  return 'A2';
    if (h < 600)  return 'B1';
    if (h < 900)  return 'B2';
    if (h < 1800) return 'C1';
    return 'C2';
  }
}
```

Level thresholds match the spreadsheet exactly:
- 90h → A1, 180h → A2, 350h → B1, 600h → B2, 900h → C1, 1800h → C2

---

## UI

### Home Screen Additions

**Study summary card** (above "Register Study" button, below STUDY & PLAY section):
- Shows: total hours · estimated level
- Per-skill mini breakdown: "Listening Xh · Reading Xh · Writing Xh · Speaking Xh"

**"Register Study" button** — same `_StudyCard` style as Flashcards/Mini-Games rows.

**⋮ menu** — new "Study Log" item navigates to `/study-log`.

### Bottom Sheet Form (`StudySessionForm`)

Fields:
1. **Type** — 4 chip buttons (Listening, Reading, Writing, Speaking), one required
2. **Duration** — number input (minutes), required
3. **Date** — defaults to today, tappable to open date picker
4. **What did you do?** — optional multiline text field (activity description, e.g. "Netflix series", "News article")

Save button: inserts session, closes sheet, invalidates provider.

### Study Log Screen (`StudyLogScreen`)

- Route: `/study-log`
- Header: same `StudyStats` summary card as home
- Body: sessions grouped by date (most recent first), each row shows type icon + duration + activity preview
- Swipe-to-delete with confirmation snackbar
- Empty state: "No study sessions yet. Tap 'Register Study' on the home screen to start."
