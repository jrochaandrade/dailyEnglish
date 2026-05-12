// lib/screens/games/fill_blank_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/player_stats_provider.dart';
import 'game_content.dart';
import 'game_result_widgets.dart';

const _kFIBRounds = 10;

class _FIBRound {
  final String gapped;
  final List<String> options;
  final int correctIndex;
  const _FIBRound({required this.gapped, required this.options, required this.correctIndex});
}

enum _FIBPhase { loading, playing, results }

class FillBlankScreen extends ConsumerStatefulWidget {
  final GameSource source;
  const FillBlankScreen({super.key, required this.source});

  @override
  ConsumerState<FillBlankScreen> createState() => _FillBlankScreenState();
}

class _FillBlankScreenState extends ConsumerState<FillBlankScreen> {
  _FIBPhase _phase = _FIBPhase.loading;
  List<_FIBRound> _rounds = [];
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
    final rng = math.Random();
    final allItems = await loadGameItems(widget.source, ref);
    if (!mounted) return;

    final qualifying = allItems.where((item) =>
        item.examples.any((ex) => ex.toLowerCase().contains(item.term.toLowerCase()))).toList();

    if (qualifying.length < 4) {
      setState(() {
        _errorMessage = 'Not enough ${gameSourceLabel(widget.source)} with matching examples. Add more content.';
        _phase = _FIBPhase.playing;
      });
      return;
    }

    final pool = [...qualifying]..shuffle(rng);
    final selected = pool.take(_kFIBRounds).toList();

    final rounds = selected.map((item) {
      final validExamples = item.examples.where((ex) =>
          ex.toLowerCase().contains(item.term.toLowerCase())).toList();
      final example = validExamples[rng.nextInt(validExamples.length)];

      final idx = example.toLowerCase().indexOf(item.term.toLowerCase());
      final gapped = '${example.substring(0, idx)}___${example.substring(idx + item.term.length)}';

      final distractors = allItems
          .where((i) => i.id != item.id && i.term != item.term)
          .toList()
        ..shuffle(rng);
      final opts = [item.term, ...distractors.take(3).map((i) => i.term)]..shuffle(rng);

      return _FIBRound(
        gapped: gapped,
        options: opts,
        correctIndex: opts.indexOf(item.term),
      );
    }).toList();

    if (!mounted) return;
    setState(() { _rounds = rounds; _phase = _FIBPhase.playing; });
  }

  void _answer(int idx) {
    if (_answered) return;
    final correct = idx == _rounds[_current].correctIndex;
    setState(() {
      _selectedIndex = idx;
      _answered = true;
      if (correct) { _score++; }
    });
  }

  Future<void> _next() async {
    if (_current + 1 >= _rounds.length) {
      await ref.read(playerStatsProvider.notifier).recordSession('fill_blank', _score * 10);
      if (!mounted) return;
      setState(() => _phase = _FIBPhase.results);
    } else {
      setState(() { _current++; _selectedIndex = null; _answered = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/games'))),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_errorMessage!, textAlign: TextAlign.center))),
      );
    }
    if (_phase == _FIBPhase.loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_phase == _FIBPhase.results) return _buildResults(context);
    return _buildPlaying(context);
  }

  Widget _buildPlaying(BuildContext context) {
    final round = _rounds[_current];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Text('${_current + 1} / ${_rounds.length}',
                    style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const Spacer(),
                Text('Score: $_score',
                    style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.tertiary)),
              ]),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: (_current + 1) / _rounds.length, color: AppTheme.tertiary,
                backgroundColor: AppTheme.tertiary.withValues(alpha: 0.15),
                minHeight: 6, borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    round.gapped,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(fontSize: 18, height: 1.6,
                        color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ...List.generate(round.options.length, (i) {
                Color? bg;
                if (_answered) {
                  if (i == round.correctIndex) { bg = AppTheme.primary.withValues(alpha: 0.15); }
                  else if (i == _selectedIndex) { bg = AppTheme.error.withValues(alpha: 0.15); }
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OutlinedButton(
                    onPressed: _answered ? null : () => _answer(i),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: bg,
                      side: BorderSide(
                        color: _answered
                            ? (i == round.correctIndex ? AppTheme.primary
                                : i == _selectedIndex ? AppTheme.error
                                : Theme.of(context).colorScheme.outlineVariant)
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: _answered && (i == round.correctIndex || i == _selectedIndex) ? 2 : 1,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(round.options[i],
                        style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface)),
                  ),
                );
              }),
              const Spacer(),
              if (_answered)
                ElevatedButton(
                  onPressed: () => _next(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.tertiary, foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(_current + 1 >= _rounds.length ? 'See Results' : 'Next',
                      style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700)),
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
            const Text('✏️', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 8),
            Text('Fill in the Blank', style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 4),
            Text(gameSourceLabel(widget.source),
                style: GoogleFonts.nunito(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            ResultCircle(score: _score, total: _rounds.length),
            const SizedBox(height: 16),
            Text('+$xp XP', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.tertiary)),
            if (stats != null) ...[const SizedBox(height: 8), XpBar(stats: stats), const SizedBox(height: 8), StreakRow(stats: stats)],
            const SizedBox(height: 32),
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _current = 0; _score = 0; _selectedIndex = null; _answered = false;
                    _errorMessage = null; _rounds = []; _phase = _FIBPhase.loading;
                  });
                  _load();
                },
                icon: const Icon(Icons.replay_rounded),
                label: Text('Play Again', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.tertiary, foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.canPop() ? context.pop() : context.go('/games'),
                icon: const Icon(Icons.grid_view_rounded),
                label: Text('Change Game', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_rounded),
                label: Text('Home', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
