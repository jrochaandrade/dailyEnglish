# Mini-Games & Gamification Design

**Goal:** Add three interactive mini-games to Daily English with a Duolingo-style XP, level, and streak system.

**Architecture:** A new `/games` hub screen with source selector feeds three stateless game screens (Scramble, Fill-in-the-Blank, Multiple Choice). A singleton `PlayerStats` model persisted in SQLite tracks XP, level, streak, shields, and last-activity date. The home stats card expands to display progression.

**Tech Stack:** Flutter, Riverpod, sqflite, flutter_tts (already installed), google_fonts, go_router.

---

## Data Model

### `player_stats` table (singleton row, id = 1)

| column | type | default |
|---|---|---|
| id | INTEGER PK | 1 |
| xp | INTEGER | 0 |
| level | INTEGER | 1 |
| streak | INTEGER | 0 |
| shields | INTEGER | 0 |
| last_activity_date | TEXT | NULL |
| streak_at_risk | INTEGER (bool) | 0 |
| games_played_today | TEXT | '' |

`games_played_today` is a comma-separated list of game types played today (`scramble`, `fill_blank`, `multiple_choice`). Used to determine shield eligibility. Resets when the date changes.

### DB version bump: 12

Migration adds the `player_stats` table and inserts the singleton row.

---

## XP & Level Rules

- Correct answer: **+10 XP**
- Wrong answer: **0 XP**
- Level threshold: **100 XP per level** (Level 1 = 0–99 XP, Level 2 = 100–199 XP, …)
- Level is derived: `level = (xp ~/ 100) + 1`; stored for display convenience.
- XP progress within current level: `xp % 100` out of 100.

---

## Streak Rules

Streak logic runs once at app start (checked in `PlayerStatsNotifier.load()`) and after every game session.

1. **Same day** as `last_activity_date` → no streak change on load.
2. **Yesterday** → streak is intact, still active.
3. **Exactly 1 day missed** (2 days ago):
   - If `shields > 0`: auto-consume 1 shield (`shields--`), keep streak, set `streak_at_risk = false`.
   - If `shields == 0`: set `streak_at_risk = true` (warning shown, streak still displayed but marked at risk).
4. **2+ days missed** OR `streak_at_risk == true` and another day passes without playing: reset streak to 0, clear `streak_at_risk`.
5. Playing any game: set `last_activity_date = today`, clear `streak_at_risk`. If this is the first play of the day (date changed since last activity), increment streak by 1.
6. **Shield earned**: when all three game types appear in `games_played_today` for the current day, award 1 shield (max 2). Award fires once per day.

---

## Games

### Source selector (shared across all games)

Before every game session the hub screen shows four source chips: **Words**, **Phrasal Verbs**, **Daily Phrases**, **My Diary**. The selected source is passed to the game screen as a route parameter or constructor arg. Items with no usable content for a given game are skipped silently.

---

### Diary source

**Content requirement:** diary entries with non-null `corrected_content`.

Sentences are extracted by splitting on sentence-ending punctuation (`.`, `!`, `?`). Sentences with fewer than 3 words are skipped.

A **target word** is chosen from each sentence: a word that is ≥ 4 characters and not in a stop-word list (articles, prepositions, pronouns, common auxiliaries). If no qualifying word exists, that sentence is skipped.

Each diary `GameItem`:
- `term` = the target word (stripped of surrounding punctuation)
- `translation` = `''` (unused)
- `examples` = `[fullSentence]` — the sentence containing the target word

**Game adaptations:**
- **Scramble** — works as-is: scrambles `examples[0]`.
- **Fill in the Blank** — works as-is: blanks `term` in `examples[0]`; distractors are `term` values from other diary items.
- **Multiple Choice** — adapted: the card shows the gapped sentence (not a term); the 4 options are word choices (not translations); speaker button is hidden.

---

---

### Game 1 — Sentence Scramble

**Content requirement:** item must have at least one non-null example field (`example1`, `example2`, or `example3`).

**Round flow:**
1. Pick a random qualifying item from the selected source.
2. Pick a random non-null example sentence from the item.
3. Split the sentence into word tokens (split on space, preserve punctuation attached to tokens).
4. Shuffle the tokens.
5. Display shuffled tokens as tappable chips in a "bank" area at the bottom.
6. User taps chips to move them into an answer row at the top (tap again to return a chip).
7. A "Check" button activates when all chips are placed.
8. On check: compare joined answer to original sentence (case-insensitive, punctuation-tolerant).
9. Show correct/wrong feedback with the correct sentence. Award XP.
10. 10 rounds per session → results screen.

**Edge cases:**
- Sentences shorter than 3 words are skipped.
- If fewer than 10 qualifying items exist, items are reused (shuffled pool with replacement).

---

### Game 2 — Fill in the Blank

**Content requirement:** item must have at least one non-null example AND the main term must appear in that example (case-insensitive substring match).

**Round flow:**
1. Pick a random qualifying item.
2. Pick a random example that contains the main term.
3. Replace the first occurrence of the main term in the example with `___` (case-insensitive replace, preserve original casing context).
4. Display the gapped sentence.
5. Build 4 answer options: the correct term + 3 random distractors drawn from other items of the same source. Distractors use the same field as the correct answer (word, verb, or phrase).
6. Shuffle the 4 options.
7. User taps one option. Immediate feedback (green correct / red wrong + reveal correct answer). Award XP.
8. 10 rounds → results screen.

**Main term per source:**
- Words → `word.word`
- Phrasal Verbs → `pv.verb` (`baseVerb + ' ' + particle`)
- Daily Phrases → `phrase.phrase`

---

### Game 3 — Multiple Choice

**Content requirement:** none beyond the item existing. Every item qualifies.

**Round flow:**
1. Pick a random item from the selected source.
2. Display the English term (word, phrasal verb, or phrase) in large text, with a speaker button to hear it.
3. Build 4 answer options: correct Portuguese translation + 3 random distractors from the same source (using same translation field).
4. Shuffle options.
5. User taps one. Immediate feedback. Award XP.
6. 10 rounds → results screen.

**Translation field per source:**
- Words → `word.translation`
- Phrasal Verbs → `pv.meaningPt ?? pv.meaning`
- Daily Phrases → `phrase.translation`

---

## Shared Results Screen

Displayed after every 10-round session. Shows:
- Score: X / 10
- XP earned this session
- Total XP + level progress bar
- Streak + shield icons
- Buttons: "Play Again" (same game + source), "Change Game", "Home"

---

## UI: Games Hub (`/games`)

- AppBar: "Mini-Games"
- Source selector: four chips (Words / Phrasal Verbs / Daily Phrases / My Diary), one selected at a time, in a `Wrap` to handle narrow screens
- Three game cards, each showing:
  - Icon + game name + one-line description
  - A "Play" button
- Tapping Play navigates to the game screen with the selected source

---

## UI: Home Screen Stats Card

Expands the existing stats card to show:

```
[book icon]  42 words        Level 3  ████░░  47/100 XP
[flame icon] 🔥 5  [shield icon] 🛡 2
```

All on one card, clean layout with two rows.

---

## New Files

| file | purpose |
|---|---|
| `lib/models/player_stats.dart` | PlayerStats data class |
| `lib/repositories/player_stats_repository.dart` | CRUD + singleton load/upsert |
| `lib/providers/player_stats_provider.dart` | PlayerStatsNotifier (AsyncNotifier) |
| `lib/screens/games/games_screen.dart` | Hub with source selector + 3 game cards |
| `lib/screens/games/sentence_scramble_screen.dart` | Scramble game |
| `lib/screens/games/fill_blank_screen.dart` | Fill-in-the-blank game |
| `lib/screens/games/multiple_choice_screen.dart` | Multiple choice game |
| `lib/screens/games/game_results_screen.dart` | Shared post-game results |

## Modified Files

| file | change |
|---|---|
| `lib/core/database/app_database.dart` | Version 12, add `player_stats` table |
| `lib/screens/home/home_screen.dart` | Expanded stats card, add Mini-Games button |
| `lib/core/router/app_router.dart` | Add `/games`, `/games/scramble`, `/games/fill-blank`, `/games/multiple-choice`, `/games/results` |
