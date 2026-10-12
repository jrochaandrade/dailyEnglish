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
import 'game_result_widgets.dart';

const _kRounds = 10;

class _MCRound {
  final String term; // English term, or gapped sentence for diary source
  final List<String> options;
  final int correctIndex;
  final bool isDiary;
  const _MCRound(
      {required this.term,
      required this.options,
      required this.correctIndex,
      this.isDiary = false});
}

enum _Phase { loading, playing, results }

class MultipleChoiceScreen extends ConsumerStatefulWidget {
  final GameSource source;
  const MultipleChoiceScreen({super.key, required this.source});

  @override
  ConsumerState<MultipleChoiceScreen> createState() =>
      _MultipleChoiceScreenState();
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
    if (!mounted) return;
    if (items.length < 4) {
      setState(() {
        _errorMessage =
            'Not enough ${gameSourceLabel(widget.source)} to play. Add at least 4 items.';
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
        final sentence =
            item.examples.isNotEmpty ? item.examples[0] : item.term;
        final pattern = RegExp(r'\b' + RegExp.escape(item.term) + r'\b',
            caseSensitive: false);
        final gapped = pattern.hasMatch(sentence)
            ? sentence.replaceFirst(pattern, '___')
            : sentence;
        final distractors = items
            .where((i) => i.id != item.id && i.term != item.term)
            .toList()
          ..shuffle(rng);
        final opts = [item.term, ...distractors.take(3).map((i) => i.term)]
          ..shuffle(rng);
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
      final opts = [
        item.translation,
        ...distractors.take(3).map((i) => i.translation)
      ]..shuffle(rng);
      return _MCRound(
        term: item.term,
        options: opts,
        correctIndex: opts.indexOf(item.translation),
      );
    }).toList();
    if (!mounted) return;
    setState(() {
      _rounds = rounds;
      _phase = _Phase.playing;
    });
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

  Future<void> _next() async {
    if (_current + 1 >= _rounds.length) {
      final xp = _score * 10;
      setState(() => _phase = _Phase.loading);
      await ref
          .read(playerStatsProvider.notifier)
          .recordSession('multiple_choice', xp);
      if (!mounted) return;
      setState(() {
        _phase = _Phase.results;
      });
    } else {
      setState(() {
        _current++;
        _selectedIndex = null;
        _answered = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
            leading: BackButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/games'))),
        body: Center(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_errorMessage!, textAlign: TextAlign.center))),
      );
    }
    if (_phase == _Phase.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_phase == _Phase.results) return _buildResults(context);
    return _buildPlaying(context);
  }

  Widget _buildPlaying(BuildContext context) {
    final round = _rounds[_current];
    final progress = (_current + 1) / _rounds.length;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Text('${_current + 1} / ${_rounds.length}',
                    style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const Spacer(),
                Text('Score: $_score',
                    style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary)),
              ]),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progress,
                color: AppTheme.primary,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
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
                        fontWeight:
                            round.isDiary ? FontWeight.w600 : FontWeight.w900,
                        height: round.isDiary ? 1.6 : null,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (!round.isDiary) ...[
                      const SizedBox(height: 8),
                      IconButton(
                        icon: const Icon(Icons.volume_up_rounded, size: 28),
                        color: AppTheme.tertiary,
                        onPressed: () =>
                            ref.read(audioServiceProvider).speak(round.term),
                      ),
                    ],
                  ]),
                ),
              ),
              const SizedBox(height: 24),
              ...List.generate(round.options.length, (i) {
                Color? bg;
                if (_answered) {
                  if (i == round.correctIndex) {
                    bg = AppTheme.primary.withValues(alpha: 0.15);
                  } else if (i == _selectedIndex) {
                    bg = AppTheme.error.withValues(alpha: 0.15);
                  }
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OutlinedButton(
                    onPressed: _answered ? null : () => _answer(i),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: bg,
                      side: BorderSide(
                        color: _answered
                            ? (i == round.correctIndex
                                ? AppTheme.primary
                                : i == _selectedIndex
                                    ? AppTheme.error
                                    : Theme.of(context)
                                        .colorScheme
                                        .outlineVariant)
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: _answered &&
                                (i == round.correctIndex || i == _selectedIndex)
                            ? 2
                            : 1,
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(round.options[i],
                        style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface)),
                  ),
                );
              }),
              const Spacer(),
              if (_answered)
                ElevatedButton(
                  onPressed: () => _next(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _current + 1 >= _rounds.length ? 'See Results' : 'Next',
                    style: GoogleFonts.nunito(
                        fontSize: 16, fontWeight: FontWeight.w700),
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
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              const Text('🎉', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 8),
              Text('Multiple Choice',
                  style: GoogleFonts.nunito(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 4),
              Text(gameSourceLabel(widget.source),
                  style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 24),
              ResultCircle(score: _score, total: _rounds.length),
              const SizedBox(height: 16),
              Text('+$xp XP',
                  style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary)),
              if (stats != null) ...[
                const SizedBox(height: 8),
                XpBar(stats: stats),
                const SizedBox(height: 8),
                StreakRow(stats: stats),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _current = 0;
                      _score = 0;
                      _selectedIndex = null;
                      _answered = false;
                      _errorMessage = null;
                      _rounds = [];
                      _phase = _Phase.loading;
                    });
                    _load();
                  },
                  icon: const Icon(Icons.replay_rounded),
                  label: Text('Play Again',
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/games'),
                  icon: const Icon(Icons.grid_view_rounded),
                  label: Text('Change Game',
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.home_rounded),
                  label: Text('Home',
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
