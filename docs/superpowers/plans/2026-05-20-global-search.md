# Global Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a global search input to the home screen that searches across Words, Phrasal Verbs, and Phrases and displays grouped results inline.

**Architecture:** A new `globalSearchProvider(query)` family provider fans out to the three existing repository `search()` methods in parallel and returns a `GlobalSearchResults` value object. The home screen debounces the text input (300ms via `Timer`), drives `_searchQuery` state, and swaps the normal home body for a grouped results list when the query is non-empty.

**Tech Stack:** Flutter, Riverpod (`FutureProvider.family`), go_router, existing repo `search()` methods (no DB changes).

---

### Task 1: Create GlobalSearchResults model and globalSearchProvider

**Files:**
- Create: `lib/providers/global_search_provider.dart`

- [ ] **Step 1: Create the file**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/word.dart';
import '../models/phrasal_verb.dart';
import '../models/phrase.dart';
import 'word_provider.dart';
import 'phrasal_verb_provider.dart';
import 'phrase_provider.dart';

class GlobalSearchResults {
  final List<Word> words;
  final List<PhrasalVerb> phrasalVerbs;
  final List<Phrase> phrases;

  const GlobalSearchResults({
    required this.words,
    required this.phrasalVerbs,
    required this.phrases,
  });

  bool get isEmpty => words.isEmpty && phrasalVerbs.isEmpty && phrases.isEmpty;

  static const empty = GlobalSearchResults(words: [], phrasalVerbs: [], phrases: []);
}

final globalSearchProvider = FutureProvider.family<GlobalSearchResults, String>((ref, query) async {
  if (query.trim().isEmpty) return GlobalSearchResults.empty;

  final wordRepo = ref.read(wordRepositoryProvider);
  final pvRepo = ref.read(phrasalVerbRepositoryProvider);
  final phraseRepo = ref.read(phraseRepositoryProvider);

  final wordsFuture = wordRepo.search(query);
  final pvFuture = pvRepo.search(query);
  final phrasesFuture = phraseRepo.search(query);

  return GlobalSearchResults(
    words: await wordsFuture,
    phrasalVerbs: await pvFuture,
    phrases: await phrasesFuture,
  );
});
```

- [ ] **Step 2: Check that `phraseRepositoryProvider` exists in phrase_provider.dart**

Open `lib/providers/phrase_provider.dart` and confirm a provider named `phraseRepositoryProvider` is defined. If it is named differently, adjust the import and reference in `global_search_provider.dart` accordingly.

- [ ] **Step 3: Commit**

```bash
git add lib/providers/global_search_provider.dart
git commit -m "feat: add GlobalSearchResults model and globalSearchProvider"
```

---

### Task 2: Add search bar and debounce state to HomeScreen

**Files:**
- Modify: `lib/screens/home/home_screen.dart`

- [ ] **Step 1: Add imports at the top of home_screen.dart**

Add these two imports after the existing imports:

```dart
import 'dart:async';
import '../../providers/global_search_provider.dart';
```

- [ ] **Step 2: Add controller, debounce timer, and query state to `_HomeScreenState`**

Inside `_HomeScreenState`, add fields and override `dispose`:

```dart
final TextEditingController _searchController = TextEditingController();
Timer? _debounce;
String _searchQuery = '';

@override
void dispose() {
  _debounce?.cancel();
  _searchController.dispose();
  super.dispose();
}
```

- [ ] **Step 3: Add `_onSearchChanged` method to `_HomeScreenState`**

```dart
void _onSearchChanged(String value) {
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 300), () {
    setState(() => _searchQuery = value.trim());
  });
}
```

- [ ] **Step 4: Add the search bar widget below the header Row in `build()`**

Locate the `const SizedBox(height: 24),` that sits after the header `Row` (around line 151) and insert the search bar between it and `_StatsCard`:

```dart
const SizedBox(height: 16),
TextField(
  controller: _searchController,
  onChanged: _onSearchChanged,
  decoration: InputDecoration(
    hintText: 'Search words, phrasal verbs, phrases…',
    prefixIcon: const Icon(Icons.search_rounded),
    suffixIcon: _searchQuery.isNotEmpty
        ? IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
          )
        : null,
    filled: true,
    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
  ),
),
```

- [ ] **Step 5: Commit**

```bash
git add lib/screens/home/home_screen.dart
git commit -m "feat: add search bar with debounce to HomeScreen"
```

---

### Task 3: Add conditional body and results list to HomeScreen

**Files:**
- Modify: `lib/screens/home/home_screen.dart`

- [ ] **Step 1: Replace the static home body with a conditional**

In `build()`, the `Column` children currently render `_StatsCard`, the library `GridView`, and the study cards unconditionally. Wrap them in a conditional so that when `_searchQuery` is non-empty the results widget is shown instead.

Replace the block starting from `_StatsCard(...)` down to the final `const SizedBox(height: 24)` with:

```dart
if (_searchQuery.isNotEmpty)
  _GlobalSearchBody(query: _searchQuery)
else ...[
  const SizedBox(height: 24),
  _StatsCard(wordCount: wordCount, stats: stats),
  const SizedBox(height: 24),
  Text(
    'MY LIBRARY',
    style: GoogleFonts.nunito(
      fontSize: 13,
      fontWeight: FontWeight.w900,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      letterSpacing: 1.2,
    ),
  ),
  const SizedBox(height: 12),
  GridView.count(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisCount: 2,
    crossAxisSpacing: 16,
    mainAxisSpacing: 16,
    childAspectRatio: 0.9,
    children: [
      _GridMenuButton(
        label: 'Words',
        description: 'Your dictionary',
        icon: Icons.menu_book_rounded,
        color: AppTheme.secondary,
        onTap: () => context.push('/words'),
      ),
      _GridMenuButton(
        label: 'Phrasal Verbs',
        description: 'Idioms & verbs',
        icon: Icons.auto_stories_rounded,
        color: AppTheme.tertiary,
        onTap: () => context.push('/phrasal-verbs'),
      ),
      _GridMenuButton(
        label: 'Phrases',
        description: 'Daily expressions',
        icon: Icons.format_quote_rounded,
        color: AppTheme.secondary,
        onTap: () => context.push('/phrases'),
      ),
      _GridMenuButton(
        label: 'Diary',
        description: 'Writing practice',
        icon: Icons.edit_note_rounded,
        color: AppTheme.primary,
        onTap: () => context.push('/diary'),
      ),
    ],
  ),
  const SizedBox(height: 24),
  Text(
    'STUDY & PLAY',
    style: GoogleFonts.nunito(
      fontSize: 13,
      fontWeight: FontWeight.w900,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      letterSpacing: 1.2,
    ),
  ),
  const SizedBox(height: 12),
  _StudyCard(
    label: 'Flashcards',
    subtitle: 'Spaced repetition study',
    icon: Icons.style_rounded,
    color: AppTheme.secondary,
    onTap: () => context.push('/flashcards'),
  ),
  const SizedBox(height: 12),
  _StudyCard(
    label: 'Mini-Games',
    subtitle: 'Quick practice sessions',
    icon: Icons.games_rounded,
    color: AppTheme.primary,
    onTap: () => context.push('/games'),
  ),
  const SizedBox(height: 24),
],
```

- [ ] **Step 2: Add `_GlobalSearchBody` widget at the bottom of home_screen.dart (after `_StudyCard`)**

```dart
class _GlobalSearchBody extends ConsumerWidget {
  final String query;
  const _GlobalSearchBody({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(globalSearchProvider(query));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(child: Text('Error: $e')),
      ),
      data: (results) {
        if (results.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text(
                'No results found',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            if (results.words.isNotEmpty) ...[
              _SearchSectionHeader(label: 'Words'),
              ...results.words.map((w) => _SearchResultTile(
                    title: w.word,
                    subtitle: w.translation,
                    typeLabel: 'Word',
                    typeColor: AppTheme.secondary,
                    onTap: () => context.push('/words/${w.id}'),
                  )),
              const SizedBox(height: 16),
            ],
            if (results.phrasalVerbs.isNotEmpty) ...[
              _SearchSectionHeader(label: 'Phrasal Verbs'),
              ...results.phrasalVerbs.map((pv) => _SearchResultTile(
                    title: pv.verb,
                    subtitle: pv.meaningPt ?? pv.meaning,
                    typeLabel: 'Phrasal Verb',
                    typeColor: AppTheme.tertiary,
                    onTap: () => context.push('/phrasal-verbs/${pv.id}'),
                  )),
              const SizedBox(height: 16),
            ],
            if (results.phrases.isNotEmpty) ...[
              _SearchSectionHeader(label: 'Phrases'),
              ...results.phrases.map((p) => _SearchResultTile(
                    title: p.phrase,
                    subtitle: p.translation,
                    typeLabel: 'Phrase',
                    typeColor: AppTheme.primary,
                    onTap: () => context.push('/phrases/${p.id}'),
                  )),
              const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }
}

class _SearchSectionHeader extends StatelessWidget {
  final String label;
  const _SearchSectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String typeLabel;
  final Color typeColor;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.title,
    required this.subtitle,
    required this.typeLabel,
    required this.typeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          title,
          style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.nunito(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: typeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            typeLabel,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: typeColor,
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Run the app and verify**

```bash
flutter run
```

Expected:
- Home screen shows search bar below the header
- Typing a query replaces the home content with grouped results
- Tapping a result navigates to its detail screen
- Clearing the field restores the normal home

- [ ] **Step 4: Commit**

```bash
git add lib/screens/home/home_screen.dart
git commit -m "feat: global search results list on home screen"
```
