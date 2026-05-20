# Global Search — Design Spec

**Date:** 2026-05-20

## Overview

Add a global search input to the home screen that searches across all content types (Words, Phrasal Verbs, Phrases) and displays results inline, replacing the normal home content while the query is active.

## Architecture & Data Flow

- New provider `globalSearchProvider(query)` — a Riverpod family provider that fans out to the three existing repository `search()` methods in parallel and returns a `GlobalSearchResults` value object.
- `GlobalSearchResults` holds three typed lists: `List<Word>`, `List<PhrasalVerb>`, `List<Phrase>`.
- Search is debounced ~300ms inside the provider to avoid hitting the DB on every keystroke.
- No database schema changes required — existing `repo.search()` methods cover all needed fields.

**Search fields per type:**
- Word: `word`, `translation`, `translation2`, `translation3`, `meaning`, `meaningPt`, `synonyms`
- PhrasalVerb: `baseVerb`, `particle`, `meaning`, `meaningPt`, `meaningEn`
- Phrase: `phrase`, `translation`, `meaningEn`, `meaningPt`

## UI Layout

- Search bar placed below the header row (title + menu), above the stats card.
- Styled as a rounded card with a search icon prefix and a clear (`×`) button that appears when text is present.
- When `_searchQuery` is empty: normal home body renders (stats card + library grid + study section).
- When `_searchQuery` is non-empty: normal body is replaced by a grouped results list.

**Results list:**
- Section headers: **Words**, **Phrasal Verbs**, **Phrases** (sections with zero results are omitted).
- Each row: main term (bold) + translation/meaning as subtitle + colored type chip matching existing theme colors.
- Empty state (all sections empty): "No results found" centered message.

## Navigation

Tapping a result navigates to the existing detail screen:
- Word → `/words/:id`
- PhrasalVerb → `/phrasal-verbs/:id`
- Phrase → `/phrases/:id`

## Files

**New:**
- `lib/providers/global_search_provider.dart` — `GlobalSearchResults` + `globalSearchProvider`

**Modified:**
- `lib/screens/home/home_screen.dart` — search bar, `_searchQuery` state, conditional body, results list widgets
