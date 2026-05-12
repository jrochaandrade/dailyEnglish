import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/word_provider.dart';
import '../../providers/phrasal_verb_provider.dart';
import '../../providers/phrase_provider.dart';
import '../../providers/diary_provider.dart';

enum GameSource { words, phrasalVerbs, phrases, diary }

class GameItem {
  final int id;
  final String term;
  final String translation;
  final List<String> examples;
  final GameSource source;

  const GameItem({
    required this.id,
    required this.term,
    required this.translation,
    required this.examples,
    required this.source,
  });
}

const _kStopWords = {
  'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
  'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
  'should', 'may', 'might', 'shall', 'can', 'to', 'of', 'in', 'on', 'at',
  'by', 'for', 'with', 'from', 'and', 'but', 'or', 'so', 'yet', 'nor',
  'not', 'no', 'i', 'you', 'he', 'she', 'it', 'we', 'they', 'me', 'him',
  'her', 'us', 'them', 'my', 'your', 'his', 'its', 'our', 'their',
  'this', 'that', 'these', 'those', 'if', 'as', 'up', 'out', 'more',
  'also', 'very', 'just', 'than', 'then', 'when', 'where', 'who',
  'which', 'what', 'how', 'about', 'after', 'before', 'into', 'over',
  'under', 'some', 'such', 'each', 'both', 'even', 'much', 'too',
};

List<String> _extractSentences(String text) {
  return text
      .split(RegExp(r'(?<=[.!?])\s+|\n+'))
      .map((s) => s.trim().replaceAll(RegExp(r'[.!?]+$'), '').trim())
      .where((s) => s.split(RegExp(r'\s+')).length >= 3)
      .toList();
}

String? _pickTargetWord(String sentence, math.Random rng) {
  final candidates = sentence.split(RegExp(r'\s+')).where((token) {
    final clean = token.replaceAll(RegExp(r"[^a-zA-Z'-]"), '').toLowerCase();
    return clean.length >= 4 && !_kStopWords.contains(clean);
  }).toList();
  if (candidates.isEmpty) return null;
  final token = candidates[rng.nextInt(candidates.length)];
  final stripped = token.replaceAll(RegExp(r"^[^a-zA-Z]+|[^a-zA-Z]+$"), '');
  return stripped.isEmpty ? null : stripped;
}

Future<List<GameItem>> loadGameItems(GameSource source, Ref ref) async {
  switch (source) {
    case GameSource.words:
      final words = await ref.read(wordRepositoryProvider).getAll();
      return words
          .where((w) => w.id != null)
          .map((w) => GameItem(
                id: w.id!,
                term: w.word,
                translation: w.translation,
                examples: [w.example1, w.example2, w.example3]
                    .whereType<String>()
                    .toList(),
                source: source,
              ))
          .toList();
    case GameSource.phrasalVerbs:
      final pvs = await ref.read(phrasalVerbRepositoryProvider).getAll();
      return pvs
          .where((pv) => pv.id != null)
          .map((pv) => GameItem(
                id: pv.id!,
                term: pv.verb,
                translation: pv.meaningPt ?? pv.meaning,
                examples: [pv.example1, pv.example2, pv.example3]
                    .whereType<String>()
                    .toList(),
                source: source,
              ))
          .toList();
    case GameSource.phrases:
      final phrases = await ref.read(phraseRepositoryProvider).getAll();
      return phrases
          .where((p) => p.id != null)
          .map((p) => GameItem(
                id: p.id!,
                term: p.phrase,
                translation: p.translation,
                examples: [p.example1, p.example2, p.example3]
                    .whereType<String>()
                    .toList(),
                source: source,
              ))
          .toList();
    case GameSource.diary:
      final rng = math.Random();
      final entries = await ref.read(diaryRepositoryProvider).getAll();
      final items = <GameItem>[];
      for (final entry in entries) {
        if (entry.correctedContent == null) continue;
        final sentences = _extractSentences(entry.correctedContent!);
        for (int sentIdx = 0; sentIdx < sentences.length; sentIdx++) {
          final sentence = sentences[sentIdx];
          final targetWord = _pickTargetWord(sentence, rng);
          if (targetWord == null) continue;
          // Diary items have no Portuguese translation; games must check source == GameSource.diary
          items.add(GameItem(
            id: (entry.id ?? 0) * 10000 + sentIdx,
            term: targetWord,
            translation: '',
            examples: [sentence],
            source: GameSource.diary,
          ));
        }
      }
      return items;
  }
}

String gameSourceLabel(GameSource s) {
  switch (s) {
    case GameSource.words: return 'Words';
    case GameSource.phrasalVerbs: return 'Phrasal Verbs';
    case GameSource.phrases: return 'Daily Phrases';
    case GameSource.diary: return 'My Diary';
  }
}
