// lib/screens/games/sentence_scramble_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/player_stats_provider.dart';
import 'game_content.dart';
import 'game_result_widgets.dart';

const _kScrambleRounds = 10;

class _ScrambleRound {
  final String original;
  final List<String> shuffled;
  const _ScrambleRound({required this.original, required this.shuffled});
}

enum _ScramblePhase { loading, playing, results }

enum _CheckState { unchecked, correct, wrong }

class SentenceScrambleScreen extends ConsumerStatefulWidget {
  final GameSource source;
  const SentenceScrambleScreen({super.key, required this.source});

  @override
  ConsumerState<SentenceScrambleScreen> createState() =>
      _SentenceScrambleScreenState();
}

class _SentenceScrambleScreenState
    extends ConsumerState<SentenceScrambleScreen> {
  _ScramblePhase _phase = _ScramblePhase.loading;
  List<_ScrambleRound> _rounds = [];
  int _current = 0;
  int _score = 0;
  String? _errorMessage;

  List<String> _bank = [];
  List<String> _placed = [];
  _CheckState _checkState = _CheckState.unchecked;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rng = math.Random();
    final allItems = await loadGameItems(widget.source, ref);
    if (!mounted) return;

    final qualifying = allItems
        .where((item) => item.examples
            .any((ex) => ex.trim().split(RegExp(r'\s+')).length >= 3))
        .toList();

    if (qualifying.isEmpty) {
      setState(() {
        _errorMessage =
            'No ${gameSourceLabel(widget.source)} with example sentences found. Add examples first.';
        _phase = _ScramblePhase.playing;
      });
      return;
    }

    final pool = [...qualifying]..shuffle(rng);
    final selected = <_ScrambleRound>[];
    int poolIdx = 0;
    while (selected.length < _kScrambleRounds) {
      final item = pool[poolIdx % pool.length];
      poolIdx++;
      final validExamples = item.examples
          .where((ex) => ex.trim().split(RegExp(r'\s+')).length >= 3)
          .toList();
      if (validExamples.isEmpty) {
        continue;
      }
      final sentence = validExamples[rng.nextInt(validExamples.length)];
      final tokens = sentence.trim().split(' ');
      final shuffled = [...tokens]..shuffle(rng);
      final uniqueTokens = tokens.toSet();
      while (_joinNorm(shuffled) == _joinNorm(tokens) &&
          tokens.length > 1 &&
          uniqueTokens.length > 1) {
        shuffled.shuffle(rng);
      }
      selected
          .add(_ScrambleRound(original: sentence.trim(), shuffled: shuffled));
    }

    if (!mounted) return;
    setState(() {
      _rounds = selected;
      _phase = _ScramblePhase.playing;
      _initRound();
    });
  }

  void _initRound() {
    _bank = [..._rounds[_current].shuffled];
    _placed = [];
    _checkState = _CheckState.unchecked;
  }

  String _joinNorm(List<String> tokens) =>
      tokens.join(' ').toLowerCase().trim();

  void _placeToken(int bankIdx) {
    if (_checkState != _CheckState.unchecked) {
      return;
    }
    setState(() {
      _placed.add(_bank[bankIdx]);
      _bank.removeAt(bankIdx);
    });
  }

  void _returnToken(int placedIdx) {
    if (_checkState != _CheckState.unchecked) {
      return;
    }
    setState(() {
      _bank.add(_placed[placedIdx]);
      _placed.removeAt(placedIdx);
    });
  }

  void _check() {
    final answer = _placed.join(' ');
    final correct = answer.toLowerCase().trim() ==
        _rounds[_current].original.toLowerCase().trim();
    setState(() {
      _checkState = correct ? _CheckState.correct : _CheckState.wrong;
      if (correct) {
        _score++;
      }
    });
  }

  Future<void> _next() async {
    if (_current + 1 >= _rounds.length) {
      setState(() => _phase = _ScramblePhase.loading);
      await ref
          .read(playerStatsProvider.notifier)
          .recordSession('scramble', _score * 10);
      if (!mounted) {
        return;
      }
      setState(() => _phase = _ScramblePhase.results);
    } else {
      setState(() {
        _current++;
        _initRound();
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
    if (_phase == _ScramblePhase.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_phase == _ScramblePhase.results) {
      return _buildResults(context);
    }
    return _buildPlaying(context);
  }

  Widget _buildPlaying(BuildContext context) {
    final round = _rounds[_current];
    final allPlaced = _bank.isEmpty;
    Color feedbackColor = Theme.of(context).colorScheme.outlineVariant;
    if (_checkState == _CheckState.correct) {
      feedbackColor = AppTheme.primary;
    }
    if (_checkState == _CheckState.wrong) {
      feedbackColor = AppTheme.error;
    }

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
                        color: AppTheme.secondary)),
              ]),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: (_current + 1) / _rounds.length,
                color: AppTheme.secondary,
                backgroundColor: AppTheme.secondary.withValues(alpha: 0.15),
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 20),
              Container(
                constraints: const BoxConstraints(minHeight: 80),
                decoration: BoxDecoration(
                  border: Border.all(color: feedbackColor, width: 2),
                  borderRadius: BorderRadius.circular(12),
                  color: _checkState == _CheckState.correct
                      ? AppTheme.primary.withValues(alpha: 0.06)
                      : _checkState == _CheckState.wrong
                          ? AppTheme.error.withValues(alpha: 0.06)
                          : Theme.of(context).cardTheme.color,
                ),
                padding: const EdgeInsets.all(12),
                child: _placed.isEmpty
                    ? Center(
                        child: Text('Tap words below to build the sentence',
                            style: GoogleFonts.nunito(
                                fontSize: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)))
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _placed
                            .asMap()
                            .entries
                            .map((e) => GestureDetector(
                                  onTap: () => _returnToken(e.key),
                                  child: _WordChip(
                                      label: e.value,
                                      color: AppTheme.secondary),
                                ))
                            .toList(),
                      ),
              ),
              if (_checkState == _CheckState.wrong) ...[
                const SizedBox(height: 8),
                Text('Correct: ${round.original}',
                    style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: AppTheme.error,
                        fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _bank
                    .asMap()
                    .entries
                    .map((e) => GestureDetector(
                          onTap: () => _placeToken(e.key),
                          child: _WordChip(
                              label: e.value,
                              color: Theme.of(context).colorScheme.outline),
                        ))
                    .toList(),
              ),
              const Spacer(),
              if (_checkState == _CheckState.unchecked)
                ElevatedButton(
                  onPressed: allPlaced ? _check : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Check',
                      style: GoogleFonts.nunito(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                )
              else
                ElevatedButton(
                  onPressed: () => _next(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _checkState == _CheckState.correct
                        ? AppTheme.primary
                        : AppTheme.secondary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                      _current + 1 >= _rounds.length ? 'See Results' : 'Next',
                      style: GoogleFonts.nunito(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final stats = ref.watch(playerStatsProvider).valueOrNull;
    final xp = _score * 10;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(children: [
            const Text('🔀', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 8),
            Text('Sentence Scramble',
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
                    color: AppTheme.secondary)),
            if (stats != null) ...[
              const SizedBox(height: 8),
              XpBar(stats: stats),
              const SizedBox(height: 8),
              StreakRow(stats: stats)
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _current = 0;
                    _score = 0;
                    _errorMessage = null;
                    _rounds = [];
                    _bank = [];
                    _placed = [];
                    _checkState = _CheckState.unchecked;
                    _phase = _ScramblePhase.loading;
                  });
                  _load();
                },
                icon: const Icon(Icons.replay_rounded),
                label: Text('Play Again',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
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
          ]),
        ),
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  final String label;
  final Color color;
  const _WordChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface)),
    );
  }
}
