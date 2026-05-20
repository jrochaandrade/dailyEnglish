import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/word_provider.dart';
import '../../providers/phrasal_verb_provider.dart';
import '../../providers/phrase_provider.dart';
import '../../providers/player_stats_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/sm2.dart';
import '../../core/services/audio_service.dart';

enum _DeckType { wordsDue, wordsDifficult, wordsAll, phrasalVerbsDue, phrasalVerbsDifficult, phrasalVerbsAll, phrasesDue, phrasesDifficult, phrasesAll }

class _FlashCard {
  final int id;
  final String front;
  final String back;
  final String? meaningEn;
  final String? example1;
  final String? example2;
  final String? example3;
  final int difficulty;
  final _DeckType deckType;
  final int srInterval;
  final double easeFactor;
  final int srRepetitions;

  const _FlashCard({
    required this.id,
    required this.front,
    required this.back,
    this.meaningEn,
    this.example1,
    this.example2,
    this.example3,
    required this.difficulty,
    required this.deckType,
    this.srInterval = 0,
    this.easeFactor = 2.5,
    this.srRepetitions = 0,
  });
}

enum _Phase { setup, studying, results }

class FlashcardsScreen extends ConsumerStatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  ConsumerState<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends ConsumerState<FlashcardsScreen> {
  _Phase _phase = _Phase.setup;
  _DeckType _deckType = _DeckType.wordsDue;
  List<_FlashCard> _session = [];
  int _currentIndex = 0;
  final Map<int, int> _answers = {};
  bool _isFlipped = false;
  bool _isLoading = false;

  Future<void> _startSession() async {
    setState(() => _isLoading = true);
    try {
      final List<_FlashCard> cards;
      switch (_deckType) {
        case _DeckType.wordsDue:
          final words = await ref.read(wordRepositoryProvider).getDueWords();
          cards = words.map((w) => _FlashCard(
                id: w.id!, front: w.word,
                back: [w.translation, w.translation2, w.translation3].whereType<String>().join(' / '),
                meaningEn: w.meaning, example1: w.example1, example2: w.example2, example3: w.example3,
                difficulty: w.difficulty, deckType: _deckType,
                srInterval: w.srInterval, easeFactor: w.easeFactor, srRepetitions: w.srRepetitions,
              )).toList();
        case _DeckType.wordsDifficult:
          final all = await ref.read(wordRepositoryProvider).getAll();
          cards = (all.where((w) => w.status == 'difficult').toList()..shuffle())
              .map((w) => _FlashCard(
                id: w.id!, front: w.word,
                back: [w.translation, w.translation2, w.translation3].whereType<String>().join(' / '),
                meaningEn: w.meaning, example1: w.example1, example2: w.example2, example3: w.example3,
                difficulty: w.difficulty, deckType: _deckType,
                srInterval: w.srInterval, easeFactor: w.easeFactor, srRepetitions: w.srRepetitions,
              )).toList();
        case _DeckType.wordsAll:
          final all = await ref.read(wordRepositoryProvider).getAll();
          cards = (all..shuffle()).map((w) => _FlashCard(
                id: w.id!, front: w.word,
                back: [w.translation, w.translation2, w.translation3].whereType<String>().join(' / '),
                meaningEn: w.meaning, example1: w.example1, example2: w.example2, example3: w.example3,
                difficulty: w.difficulty, deckType: _deckType,
                srInterval: w.srInterval, easeFactor: w.easeFactor, srRepetitions: w.srRepetitions,
              )).toList();
        case _DeckType.phrasalVerbsDue:
          final pvs = await ref.read(phrasalVerbRepositoryProvider).getDue();
          cards = pvs.map((pv) => _FlashCard(
                id: pv.id!, front: pv.verb, back: pv.meaningPt ?? pv.meaning,
                meaningEn: pv.meaningEn, example1: pv.example1, example2: pv.example2, example3: pv.example3,
                difficulty: pv.difficulty, deckType: _deckType,
                srInterval: pv.srInterval, easeFactor: pv.easeFactor, srRepetitions: pv.srRepetitions,
              )).toList();
        case _DeckType.phrasalVerbsDifficult:
          final all = await ref.read(phrasalVerbRepositoryProvider).getAll();
          cards = (all.where((pv) => pv.status == 'difficult').toList()..shuffle())
              .map((pv) => _FlashCard(
                id: pv.id!, front: pv.verb, back: pv.meaningPt ?? pv.meaning,
                meaningEn: pv.meaningEn, example1: pv.example1, example2: pv.example2, example3: pv.example3,
                difficulty: pv.difficulty, deckType: _deckType,
                srInterval: pv.srInterval, easeFactor: pv.easeFactor, srRepetitions: pv.srRepetitions,
              )).toList();
        case _DeckType.phrasalVerbsAll:
          final all = await ref.read(phrasalVerbRepositoryProvider).getAll();
          cards = (all..shuffle()).map((pv) => _FlashCard(
                id: pv.id!, front: pv.verb, back: pv.meaningPt ?? pv.meaning,
                meaningEn: pv.meaningEn, example1: pv.example1, example2: pv.example2, example3: pv.example3,
                difficulty: pv.difficulty, deckType: _deckType,
                srInterval: pv.srInterval, easeFactor: pv.easeFactor, srRepetitions: pv.srRepetitions,
              )).toList();
        case _DeckType.phrasesDue:
          final phrases = await ref.read(phraseRepositoryProvider).getAll();
          cards = (phrases..shuffle()).map((p) => _FlashCard(
                id: p.id!, front: p.phrase, back: p.translation,
                meaningEn: p.meaningEn, example1: p.example1, example2: p.example2, example3: p.example3,
                difficulty: p.difficulty, deckType: _deckType,
                srInterval: p.srInterval, easeFactor: p.easeFactor, srRepetitions: p.srRepetitions,
              )).toList();
        case _DeckType.phrasesDifficult:
          final all = await ref.read(phraseRepositoryProvider).getAll();
          cards = (all.where((p) => p.status == 'difficult').toList()..shuffle())
              .map((p) => _FlashCard(
                id: p.id!, front: p.phrase, back: p.translation,
                meaningEn: p.meaningEn, example1: p.example1, example2: p.example2, example3: p.example3,
                difficulty: p.difficulty, deckType: _deckType,
                srInterval: p.srInterval, easeFactor: p.easeFactor, srRepetitions: p.srRepetitions,
              )).toList();
        case _DeckType.phrasesAll:
          final all = await ref.read(phraseRepositoryProvider).getAll();
          cards = (all..shuffle()).map((p) => _FlashCard(
                id: p.id!, front: p.phrase, back: p.translation,
                meaningEn: p.meaningEn, example1: p.example1, example2: p.example2, example3: p.example3,
                difficulty: p.difficulty, deckType: _deckType,
                srInterval: p.srInterval, easeFactor: p.easeFactor, srRepetitions: p.srRepetitions,
              )).toList();
      }

      if (cards.isEmpty) return;
      setState(() {
        _session = cards;
        _currentIndex = 0;
        _answers.clear();
        _isFlipped = false;
        _phase = _Phase.studying;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsLearned() async {
    final card = _session[_currentIndex];
    
    switch (card.deckType) {
      case _DeckType.wordsDue:
      case _DeckType.wordsDifficult:
      case _DeckType.wordsAll:
        final repo = ref.read(wordRepositoryProvider);
        final word = await repo.getById(card.id);
        if (word != null) {
          await repo.update(word.copyWith(status: 'learned'));
        }
      case _DeckType.phrasalVerbsDue:
      case _DeckType.phrasalVerbsDifficult:
      case _DeckType.phrasalVerbsAll:
        final repo = ref.read(phrasalVerbRepositoryProvider);
        final pv = await repo.getById(card.id);
        if (pv != null) {
          await repo.update(pv.copyWith(status: 'learned'));
        }
      case _DeckType.phrasesDue:
      case _DeckType.phrasesDifficult:
      case _DeckType.phrasesAll:
        final repo = ref.read(phraseRepositoryProvider);
        final p = await repo.getById(card.id);
        if (p != null) {
          await repo.update(p.copyWith(status: 'learned'));
        }
    }

    _answers[_currentIndex] = 5;

    final isLast = _currentIndex + 1 >= _session.length;
    if (isLast) {
      setState(() {
        _isFlipped = false;
        _phase = _Phase.results;
        ref.invalidate(dueWordsCountProvider);
        ref.invalidate(duePhrasalVerbsCountProvider);
        ref.invalidate(duePhrasesCountProvider);
      });
    } else {
      setState(() {
        _isFlipped = false;
        _currentIndex++;
      });
    }
  }

  Future<void> _answer(int quality) async {
    final card = _session[_currentIndex];

    final result = computeSM2(
      currentInterval: card.srInterval,
      easeFactor: card.easeFactor,
      repetitions: card.srRepetitions,
      quality: quality,
    );

    switch (card.deckType) {
      case _DeckType.wordsDue:
      case _DeckType.wordsDifficult:
      case _DeckType.wordsAll:
        await ref.read(wordRepositoryProvider).updateSM2(
              card.id,
              nextReviewAt: result.nextReviewAt,
              easeFactor: result.easeFactor,
              srRepetitions: result.repetitions,
              srInterval: result.interval,
            );
      case _DeckType.phrasalVerbsDue:
      case _DeckType.phrasalVerbsDifficult:
      case _DeckType.phrasalVerbsAll:
        await ref.read(phrasalVerbRepositoryProvider).updateSM2(
              card.id,
              nextReviewAt: result.nextReviewAt,
              easeFactor: result.easeFactor,
              srRepetitions: result.repetitions,
              srInterval: result.interval,
            );
      case _DeckType.phrasesDue:
      case _DeckType.phrasesDifficult:
      case _DeckType.phrasesAll:
        await ref.read(phraseRepositoryProvider).updateSM2(
              card.id,
              nextReviewAt: result.nextReviewAt,
              easeFactor: result.easeFactor,
              srRepetitions: result.repetitions,
              srInterval: result.interval,
            );
    }

    _answers[_currentIndex] = quality;

    final isLast = _currentIndex + 1 >= _session.length;
    if (isLast) {
      final good = _answers.values.where((q) => q >= 3).length;
      await ref.read(playerStatsProvider.notifier).recordSession('flashcard', good * 10);
      if (!mounted) return;
      setState(() {
        _isFlipped = false;
        _phase = _Phase.results;
        ref.invalidate(dueWordsCountProvider);
        ref.invalidate(duePhrasalVerbsCountProvider);
        ref.invalidate(duePhrasesCountProvider);
      });
    } else {
      setState(() {
        _isFlipped = false;
        _currentIndex++;
      });
    }
  }

  void _retryAgain() {
    final again = _session
        .asMap()
        .entries
        .where((e) => (_answers[e.key] ?? 0) < 3)
        .map((e) => e.value)
        .toList()
      ..shuffle();
    setState(() {
      _session = again;
      _currentIndex = 0;
      _answers.clear();
      _isFlipped = false;
      _phase = _Phase.studying;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.setup:
        return _buildSetup(context);
      case _Phase.studying:
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) setState(() { _isFlipped = false; _phase = _Phase.setup; });
          },
          child: _buildStudying(context),
        );
      case _Phase.results:
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) setState(() => _phase = _Phase.setup);
          },
          child: _buildResults(context),
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Setup phase
  // ---------------------------------------------------------------------------

  Widget _buildSetup(BuildContext context) {
    final allWords = ref.watch(wordListProvider).valueOrNull ?? [];
    final wordsDueCount = ref.watch(dueWordsCountProvider).valueOrNull ?? 0;
    final wordsDifficultCount = allWords.where((w) => w.status == 'difficult').length;

    final allPV = ref.watch(phrasalVerbListProvider).valueOrNull ?? [];
    final pvDueCount = ref.watch(duePhrasalVerbsCountProvider).valueOrNull ?? 0;
    final pvDifficultCount = allPV.where((pv) => pv.status == 'difficult').length;

    final allPhrases = ref.watch(phraseListProvider).valueOrNull ?? [];
    final phrasesDueCount = ref.watch(duePhrasesCountProvider).valueOrNull ?? 0;
    final phrasesDifficultCount = allPhrases.where((p) => p.status == 'difficult').length;

    final allWordsCount = allWords.length;
    final allPVCount = allPV.length;
    final allPhrasesCount = allPhrases.length;

    int selectedCount() {
      switch (_deckType) {
        case _DeckType.wordsDue: return wordsDueCount;
        case _DeckType.wordsDifficult: return wordsDifficultCount;
        case _DeckType.wordsAll: return allWordsCount;
        case _DeckType.phrasalVerbsDue: return pvDueCount;
        case _DeckType.phrasalVerbsDifficult: return pvDifficultCount;
        case _DeckType.phrasalVerbsAll: return allPVCount;
        case _DeckType.phrasesDue: return phrasesDueCount;
        case _DeckType.phrasesDifficult: return phrasesDifficultCount;
        case _DeckType.phrasesAll: return allPhrasesCount;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Flashcards', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Study Mode',
                style: GoogleFonts.nunito(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose a deck to study',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              _sectionLabel(context, 'WORDS'),
              const SizedBox(height: 8),
              _DeckCard(
                icon: '🎯',
                label: 'Due for Review',
                subtitle: 'Spaced repetition schedule',
                count: wordsDueCount,
                selected: _deckType == _DeckType.wordsDue,
                onTap: () => setState(() => _deckType = _DeckType.wordsDue),
                accentColor: AppTheme.primary,
              ),
              const SizedBox(height: 10),
              _DeckCard(
                icon: '⚡',
                label: 'Difficult Words',
                count: wordsDifficultCount,
                selected: _deckType == _DeckType.wordsDifficult,
                onTap: () => setState(() => _deckType = _DeckType.wordsDifficult),
                accentColor: AppTheme.error,
              ),
              const SizedBox(height: 10),
              _DeckCard(
                icon: '📚',
                label: 'All Words',
                subtitle: 'Review your entire dictionary',
                count: allWordsCount,
                selected: _deckType == _DeckType.wordsAll,
                onTap: () => setState(() => _deckType = _DeckType.wordsAll),
                accentColor: AppTheme.secondary,
              ),
              const SizedBox(height: 20),
              _sectionLabel(context, 'PHRASAL VERBS'),
              const SizedBox(height: 8),
              _DeckCard(
                icon: '🎯',
                label: 'Due for Review',
                subtitle: 'Spaced repetition schedule',
                count: pvDueCount,
                selected: _deckType == _DeckType.phrasalVerbsDue,
                onTap: () => setState(() => _deckType = _DeckType.phrasalVerbsDue),
                accentColor: AppTheme.tertiary,
              ),
              const SizedBox(height: 10),
              _DeckCard(
                icon: '⚡',
                label: 'Difficult Phrasal Verbs',
                count: pvDifficultCount,
                selected: _deckType == _DeckType.phrasalVerbsDifficult,
                onTap: () => setState(() => _deckType = _DeckType.phrasalVerbsDifficult),
                accentColor: AppTheme.error,
              ),
              const SizedBox(height: 10),
              _DeckCard(
                icon: '📚',
                label: 'All Phrasal Verbs',
                subtitle: 'Review all phrasal verbs',
                count: allPVCount,
                selected: _deckType == _DeckType.phrasalVerbsAll,
                onTap: () => setState(() => _deckType = _DeckType.phrasalVerbsAll),
                accentColor: AppTheme.secondary,
              ),
              const SizedBox(height: 20),
              _sectionLabel(context, 'DAILY PHRASES'),
              const SizedBox(height: 8),
              _DeckCard(
                icon: '🎯',
                label: 'Due for Review',
                subtitle: 'Spaced repetition schedule',
                count: phrasesDueCount,
                selected: _deckType == _DeckType.phrasesDue,
                onTap: () => setState(() => _deckType = _DeckType.phrasesDue),
                accentColor: AppTheme.secondary,
              ),
              const SizedBox(height: 10),
              _DeckCard(
                icon: '⚡',
                label: 'Difficult Phrases',
                count: phrasesDifficultCount,
                selected: _deckType == _DeckType.phrasesDifficult,
                onTap: () => setState(() => _deckType = _DeckType.phrasesDifficult),
                accentColor: AppTheme.error,
              ),
              const SizedBox(height: 10),
              _DeckCard(
                icon: '📚',
                label: 'All Phrases',
                subtitle: 'Review all daily expressions',
                count: allPhrasesCount,
                selected: _deckType == _DeckType.phrasesAll,
                onTap: () => setState(() => _deckType = _DeckType.phrasesAll),
                accentColor: AppTheme.secondary,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: selectedCount() == 0 || _isLoading ? null : _startSession,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppTheme.primary,
                  disabledBackgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                  disabledForegroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Start Study Session',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Studying phase
  // ---------------------------------------------------------------------------

  void _goBack() {
    if (_currentIndex == 0) return;
    setState(() {
      _answers.remove(_currentIndex - 1);
      _currentIndex--;
      _isFlipped = false;
    });
  }

  Widget _buildStudying(BuildContext context) {
    final card = _session[_currentIndex];
    final progress = (_currentIndex + 1) / _session.length;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (_currentIndex > 0)
                    GestureDetector(
                      onTap: _goBack,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_ios_rounded, size: 14,
                              color: Theme.of(context).colorScheme.onSurfaceVariant),
                          Text(
                            'Anterior',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox(width: 8),
                  const Spacer(),
                  Text(
                    'Card ${_currentIndex + 1} of ${_session.length}',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progress,
                color: AppTheme.primary,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 20),
              _FlipCard(
                isFlipped: _isFlipped,
                onTap: () => setState(() => _isFlipped = !_isFlipped),
                front: _buildCardFront(context, card),
                back: _buildCardBack(context, card),
              ),
              const SizedBox(height: 20),
              if (_isFlipped)
                _buildAnswerButtons(context, card)
              else
                Center(
                  child: Text(
                    'Toque no cartão para revelar',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: _markAsLearned,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                  label: const Text('Mark as Learned'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerButtons(BuildContext context, _FlashCard card) {
    String previewInterval(int quality) {
      final result = computeSM2(
        currentInterval: card.srInterval,
        easeFactor: card.easeFactor,
        repetitions: card.srRepetitions,
        quality: quality,
      );
      return formatInterval(result.interval);
    }

    return Row(
      children: [
        Expanded(
          child: _AnswerButton(
            label: 'Again',
            sublabel: previewInterval(0),
            color: AppTheme.error,
            onPressed: () => _answer(0),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _AnswerButton(
            label: 'Good',
            sublabel: previewInterval(3),
            color: AppTheme.primary,
            filled: true,
            onPressed: () => _answer(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _AnswerButton(
            label: 'Easy',
            sublabel: previewInterval(5),
            color: AppTheme.secondary,
            onPressed: () => _answer(5),
          ),
        ),
      ],
    );
  }

  Widget _buildCardFront(BuildContext context, _FlashCard card) {
    final difficultyColor = _difficultyColor(card.difficulty);
    final difficultyLabel = _difficultyLabel(card.difficulty);

    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 56),
              child: Text(
                card.front,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: card.front.length > 20 ? 22 : 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: difficultyColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                difficultyLabel,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: difficultyColor,
                ),
              ),
            ),
          ),
          if (card.srRepetitions > 0)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '×${card.srRepetitions}',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.secondary,
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 12,
            right: 12,
            child: IconButton(
              icon: const Icon(Icons.volume_up_rounded),
              color: AppTheme.tertiary,
              tooltip: 'Ouvir',
              onPressed: () => ref.read(audioServiceProvider).speak(card.front),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack(BuildContext context, _FlashCard card) {
    final examples = [card.example1, card.example2, card.example3]
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .toList();

    return Container(
      constraints: const BoxConstraints(minHeight: 200),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Translation
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    card.back,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up_rounded, size: 20),
                  color: AppTheme.primary,
                  tooltip: 'Ouvir frase',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => ref.read(audioServiceProvider).speak(card.front),
                ),
              ],
            ),
            if (card.meaningEn != null) ...[
              const SizedBox(height: 8),
              Text(
                card.meaningEn!,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
            if (examples.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 4),
              ...examples.map((ex) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        ex,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.volume_up_rounded, size: 18),
                      color: AppTheme.tertiary,
                      tooltip: 'Ouvir exemplo',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => ref.read(audioServiceProvider).speak(ex),
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Results phase
  // ---------------------------------------------------------------------------

  Widget _buildResults(BuildContext context) {
    final total = _session.length;
    final good = _answers.values.where((q) => q >= 3).length;
    final again = total - good;
    final percent = total == 0 ? 0.0 : good / total;

    return Scaffold(
      appBar: AppBar(
        title: Text('Flashcards', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events_rounded, size: 80, color: AppTheme.warning),
              const SizedBox(height: 16),
              Text(
                'Session Complete!',
                style: GoogleFonts.nunito(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: percent,
                        strokeWidth: 10,
                        color: AppTheme.primary,
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    Text(
                      '${(percent * 100).toInt()}%',
                      style: GoogleFonts.nunito(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ResultChip(label: 'Good / Easy', count: good, color: AppTheme.primary),
                  const SizedBox(width: 12),
                  _ResultChip(label: 'Again', count: again, color: AppTheme.error),
                ],
              ),
              const SizedBox(height: 32),
              if (again > 0) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _retryAgain,
                    icon: const Icon(Icons.replay_rounded),
                    label: Text(
                      'Retry Again cards ($again)',
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _phase = _Phase.setup),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text('New Session', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.home_rounded),
                  label: Text('Back to Home', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Widget _sectionLabel(BuildContext context, String text) => Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      );

  String _difficultyLabel(int difficulty) {
    if (difficulty == 1) return 'Easy';
    if (difficulty == 2) return 'Medium';
    return 'Hard';
  }

  Color _difficultyColor(int difficulty) {
    if (difficulty == 1) return AppTheme.primary;
    if (difficulty == 2) return AppTheme.warning;
    return AppTheme.error;
  }
}

// ---------------------------------------------------------------------------
// Answer button
// ---------------------------------------------------------------------------

class _AnswerButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final Color color;
  final bool filled;
  final VoidCallback onPressed;

  const _AnswerButton({
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onPressed,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: filled ? color.withValues(alpha: 0.1) : null,
        side: BorderSide(color: color, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (sublabel.isNotEmpty)
            Text(
              sublabel,
              style: GoogleFonts.nunito(
                fontSize: 11,
                color: color.withValues(alpha: 0.8),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Result chip
// ---------------------------------------------------------------------------

class _ResultChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _ResultChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            label,
            style: GoogleFonts.nunito(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Deck selection card
// ---------------------------------------------------------------------------

class _DeckCard extends StatelessWidget {
  final String icon;
  final String label;
  final String? subtitle;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final Color accentColor;

  const _DeckCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.accentColor = AppTheme.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? accentColor : Theme.of(context).colorScheme.outline;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? accentColor.withValues(alpha: 0.08)
              : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accentColor : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: Text(icon, style: const TextStyle(fontSize: 24)),
          title: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle!,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              : null,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: selected ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Flip card widget
// ---------------------------------------------------------------------------

class _FlipCard extends StatelessWidget {
  final bool isFlipped;
  final VoidCallback? onTap;
  final Widget front;
  final Widget back;

  const _FlipCard({
    required this.isFlipped,
    required this.onTap,
    required this.front,
    required this.back,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: isFlipped ? 0 : 1, end: isFlipped ? 1 : 0),
        duration: const Duration(milliseconds: 350),
        builder: (context, value, _) {
          final angle = value * math.pi;
          final showFront = angle <= math.pi / 2;
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            alignment: Alignment.center,
            child: showFront
                ? front
                : Transform(
                    transform: Matrix4.identity()..rotateY(math.pi),
                    alignment: Alignment.center,
                    child: back,
                  ),
          );
        },
      ),
    );
  }
}
