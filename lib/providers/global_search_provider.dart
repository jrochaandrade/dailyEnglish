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

  static const empty = GlobalSearchResults(
    words: <Word>[],
    phrasalVerbs: <PhrasalVerb>[],
    phrases: <Phrase>[],
  );
}

final globalSearchProvider = FutureProvider.autoDispose
    .family<GlobalSearchResults, String>((ref, query) async {
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
