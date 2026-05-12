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

enum _QuestPhase { loading, playing, results }

class _QuestRound {
  final String question;
  final String description;
  final List<String> options;
  final int correctIndex;
  final String? audioText;
  final GameItem item;

  const _QuestRound({
    required this.question,
    required this.description,
    required this.options,
    required this.correctIndex,
    this.audioText,
    required this.item,
  });
}

class EnglishQuestScreen extends ConsumerStatefulWidget {
  const EnglishQuestScreen({super.key});

  @override
  ConsumerState<EnglishQuestScreen> createState() => _EnglishQuestScreenState();
}

class _EnglishQuestScreenState extends ConsumerState<EnglishQuestScreen> {
  _QuestPhase _phase = _QuestPhase.loading;
  List<_QuestRound> _rounds = [];
  int _currentIndex = 0;
  
  int _playerLives = 3;
  int _enemyLives = 5;
  int _xpEarned = 0;
  
  int? _selectedIndex;
  bool _answered = false;
  String? _errorMessage;
  String? _battleMessage;

  @override
  void initState() {
    super.initState();
    _loadQuest();
  }

  Future<void> _loadQuest() async {
    setState(() => _phase = _QuestPhase.loading);
    try {
      final words = await loadGameItems(GameSource.words, ref);
      if (words.length < 4) {
        setState(() {
          _errorMessage = 'Not enough words to start a Battle. Add at least 4 words.';
          _phase = _QuestPhase.playing;
        });
        return;
      }

      final rng = math.Random();
      final selectedWords = [...words]..shuffle(rng);
      final rounds = <_QuestRound>[];

      // We need at least enough rounds to win or lose. Let's make 20 just in case.
      for (int i = 0; i < 20; i++) {
        final item = selectedWords[i % selectedWords.length];
        
        // Randomly choose challenge type
        final type = rng.nextInt(2); // 0: Translation, 1: Fill in blank

        if (type == 1 && item.examples.isNotEmpty) {
          final sentence = item.examples[0];
          final pattern = RegExp(r'\b' + RegExp.escape(item.term) + r'\b', caseSensitive: false);
          final gapped = pattern.hasMatch(sentence) ? sentence.replaceFirst(pattern, '____') : sentence;
          
          final distractors = words.where((w) => w.id != item.id).toList()..shuffle(rng);
          final options = [item.term, ...distractors.take(3).map((w) => w.term)]..shuffle(rng);
          
          rounds.add(_QuestRound(
            question: gapped,
            description: 'Complete the sentence:',
            options: options,
            correctIndex: options.indexOf(item.term),
            item: item,
          ));
        } else {
          final distractors = words.where((w) => w.id != item.id).toList()..shuffle(rng);
          final options = [item.translation, ...distractors.take(3).map((w) => w.translation)]..shuffle(rng);
          
          rounds.add(_QuestRound(
            question: item.term,
            description: 'What does this mean?',
            options: options,
            correctIndex: options.indexOf(item.translation),
            audioText: item.term,
            item: item,
          ));
        }
      }

      setState(() {
        _rounds = rounds;
        _phase = _QuestPhase.playing;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading quest. Try again.';
        _phase = _QuestPhase.playing;
      });
    }
  }

  void _onAnswer(int index) {
    if (_answered) return;
    
    final correct = index == _rounds[_currentIndex].correctIndex;
    setState(() {
      _selectedIndex = index;
      _answered = true;
      if (correct) {
        _xpEarned += 10;
        _enemyLives--;
        _battleMessage = '🧑‍🎓 You attacked! Enemy loses 1 life.';
      } else {
        _playerLives--;
        _battleMessage = '👾 Monster attacked! You lose 1 life.';
      }
    });

    if (_playerLives <= 0 || _enemyLives <= 0) {
      Future.delayed(const Duration(milliseconds: 2000), () => _finishQuest());
    }
  }

  Future<void> _next() async {
    if (_playerLives <= 0 || _enemyLives <= 0) {
      _finishQuest();
    } else {
      setState(() {
        _currentIndex++;
        _selectedIndex = null;
        _answered = false;
        _battleMessage = null;
      });
    }
  }

  Future<void> _finishQuest() async {
    setState(() => _phase = _QuestPhase.loading);
    if (_enemyLives <= 0) {
      // Bonus XP for winning
      _xpEarned += 50;
    }
    await ref.read(playerStatsProvider.notifier).recordSession('quest', _xpEarned);
    if (!mounted) return;
    setState(() => _phase = _QuestPhase.results);
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _QuestPhase.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_phase == _QuestPhase.results) return _buildResults();
    
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Word Battle')),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_errorMessage!))),
      );
    }

    return _buildPlaying();
  }

  Widget _buildPlaying() {
    final round = _rounds[_currentIndex];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: Theme.of(context).brightness == Brightness.dark
                ? [const Color(0xFF1E1E2E), const Color(0xFF11111B)]
                : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // HEADER WITH EXIT BUTTON
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => context.pop(),
                ),
              ),
              
              // BATTLE ARENA STATUS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Player
                    Column(
                      children: [
                        const Text('🧑‍🎓', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 4),
                        Text('You', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(height: 4),
                        Row(
                          children: List.generate(3, (i) => Icon(
                            i < _playerLives ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: Colors.redAccent,
                            size: 20,
                          )),
                        ),
                      ],
                    ),
                    
                    // VS
                    Column(
                      children: [
                        Text('VS', style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.warning)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('XP: $_xpEarned', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: AppTheme.warning)),
                        ),
                      ],
                    ),

                    // Enemy
                    Column(
                      children: [
                        const Text('👾', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 4),
                        Text('Monster', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(height: 4),
                        Row(
                          children: List.generate(5, (i) => Icon(
                            i < _enemyLives ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: Colors.purpleAccent,
                            size: 20,
                          )),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              
              // BATTLE MESSAGE
              AnimatedOpacity(
                opacity: _answered ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _selectedIndex == round.correctIndex 
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedIndex == round.correctIndex ? Colors.green : Colors.red,
                    ),
                  ),
                  child: Text(
                    _battleMessage ?? '',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: _selectedIndex == round.correctIndex ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    children: [
                      Text(
                        round.description,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                          child: Column(
                            children: [
                              Text(
                                round.question,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.nunito(
                                  fontSize: round.question.length > 30 ? 20 : 28,
                                  fontWeight: FontWeight.w900,
                                  height: 1.4,
                                ),
                              ),
                              if (round.audioText != null) ...[
                                const SizedBox(height: 16),
                                IconButton(
                                  icon: const Icon(Icons.volume_up_rounded, size: 32),
                                  color: AppTheme.primary,
                                  onPressed: () => ref.read(audioServiceProvider).speak(round.audioText!),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Options
                      ...List.generate(round.options.length, (i) {
                        final isCorrect = i == round.correctIndex;
                        final isSelected = i == _selectedIndex;
                        
                        Color? borderColor;
                        Color? bgColor;
                        if (_answered) {
                          if (isCorrect) {
                            borderColor = AppTheme.primary;
                            bgColor = AppTheme.primary.withValues(alpha: 0.1);
                          } else if (isSelected) {
                            borderColor = AppTheme.error;
                            bgColor = AppTheme.error.withValues(alpha: 0.1);
                          }
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () => _onAnswer(i),
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                              decoration: BoxDecoration(
                                color: bgColor ?? Theme.of(context).cardTheme.color,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: borderColor ?? Colors.grey.withValues(alpha: 0.2),
                                  width: (isSelected || (_answered && isCorrect)) ? 2.5 : 1,
                                ),
                                boxShadow: isSelected ? [] : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      round.options[i],
                                      style: GoogleFonts.nunito(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (_answered && isCorrect)
                                    const Icon(Icons.check_circle_rounded, color: AppTheme.primary),
                                  if (_answered && isSelected && !isCorrect)
                                    const Icon(Icons.cancel_rounded, color: AppTheme.error),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      
                      if (_answered && _playerLives > 0 && _enemyLives > 0) ...[
                        const SizedBox(height: 16),
                        if (round.item.translation.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardTheme.color,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text('Learning Note:', style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('${round.item.term} = ${round.item.translation}', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _next,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                          ),
                          child: Text(
                            'NEXT ROUND',
                            style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    final success = _enemyLives <= 0;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Text(
                success ? '🏆 MONSTER DEFEATED!' : '💀 YOU DIED',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: success ? AppTheme.primary : AppTheme.error,
                ),
              ),
              const SizedBox(height: 24),
              Icon(
                success ? Icons.emoji_events_rounded : Icons.sentiment_very_dissatisfied_rounded,
                size: 100,
                color: success ? AppTheme.warning : AppTheme.error,
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _resultRow('Total XP', '+$_xpEarned XP', color: AppTheme.primary),
                      if (success) ...[
                         const Divider(height: 32),
                        _resultRow('Victory Bonus', '+50 XP', color: AppTheme.warning),
                      ],
                      const Divider(height: 32),
                      _resultRow('Player Health', '$_playerLives / 3', color: Colors.redAccent),
                      const Divider(height: 32),
                      _resultRow('Monster Health', '$_enemyLives / 5', color: Colors.purpleAccent),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () => context.go('/'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('BACK TO HOME', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentIndex = 0;
                    _playerLives = 3;
                    _enemyLives = 5;
                    _xpEarned = 0;
                    _selectedIndex = null;
                    _answered = false;
                    _battleMessage = null;
                    _phase = _QuestPhase.loading;
                  });
                  _loadQuest();
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('BATTLE AGAIN', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey)),
        Text(value, style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }
}

