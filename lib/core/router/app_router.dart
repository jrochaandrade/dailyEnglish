import 'package:go_router/go_router.dart';
import '../services/audio_service.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/words/words_screen.dart';
import '../../screens/words/word_form_screen.dart';
import '../../screens/words/word_detail_screen.dart';
import '../../screens/diary/diary_list_screen.dart';
import '../../screens/diary/diary_form_screen.dart';
import '../../screens/diary/diary_detail_screen.dart';
import '../../screens/phrasal_verbs/phrasal_verbs_screen.dart';
import '../../screens/phrasal_verbs/phrasal_verb_form_screen.dart';
import '../../screens/phrasal_verbs/phrasal_verb_detail_screen.dart';
import '../../screens/flashcards/flashcards_screen.dart';
import '../../screens/categories/categories_screen.dart';
import '../../screens/phrases/phrases_screen.dart';
import '../../screens/phrases/phrase_detail_screen.dart';
import '../../screens/phrases/phrase_form_screen.dart';
import '../../screens/games/games_screen.dart';
import '../../screens/games/multiple_choice_screen.dart';
import '../../screens/games/fill_blank_screen.dart';
import '../../screens/games/sentence_scramble_screen.dart';
import '../../screens/games/english_quest_screen.dart';
import '../../screens/games/game_content.dart';
import '../../screens/study/study_log_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  observers: [AudioStopObserver()],
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/words',
      builder: (context, state) => const WordsScreen(),
    ),
    GoRoute(
      path: '/words/new',
      builder: (context, state) => WordFormScreen(initialWord: state.uri.queryParameters['word']),
    ),
    GoRoute(
      path: '/words/:id/edit',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return WordFormScreen(wordId: id);
      },
    ),
    GoRoute(
      path: '/words/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return WordDetailScreen(wordId: id);
      },
    ),
    GoRoute(
      path: '/diary',
      builder: (context, state) => const DiaryListScreen(),
    ),
    GoRoute(
      path: '/diary/new',
      builder: (context, state) => const DiaryFormScreen(),
    ),
    GoRoute(
      path: '/diary/:id/edit',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return DiaryFormScreen(entryId: id);
      },
    ),
    GoRoute(
      path: '/diary/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return DiaryDetailScreen(entryId: id);
      },
    ),
    GoRoute(
      path: '/phrasal-verbs',
      builder: (context, state) => const PhrasalVerbsScreen(),
    ),
    GoRoute(
      path: '/phrasal-verbs/new',
      builder: (context, state) => const PhrasalVerbFormScreen(),
    ),
    GoRoute(
      path: '/phrasal-verbs/:id/edit',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return PhrasalVerbFormScreen(pvId: id);
      },
    ),
    GoRoute(
      path: '/phrasal-verbs/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return PhrasalVerbDetailScreen(pvId: id);
      },
    ),
    GoRoute(
      path: '/flashcards',
      builder: (context, state) => const FlashcardsScreen(),
    ),
    GoRoute(
      path: '/categories',
      builder: (context, state) => const CategoriesScreen(),
    ),
    GoRoute(
      path: '/phrases',
      builder: (context, state) => const PhrasesScreen(),
    ),
    GoRoute(
      path: '/phrases/new',
      builder: (context, state) => const PhraseFormScreen(),
    ),
    GoRoute(
      path: '/phrases/:id/edit',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return PhraseFormScreen(phraseId: id);
      },
    ),
    GoRoute(
      path: '/phrases/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return PhraseDetailScreen(phraseId: id);
      },
    ),
    GoRoute(
      path: '/games',
      builder: (context, state) => const GamesScreen(),
    ),
    GoRoute(
      path: '/games/multiple-choice',
      builder: (context, state) {
        final src = state.uri.queryParameters['source'] ?? 'words';
        final source = GameSource.values.firstWhere(
          (e) => e.name == src,
          orElse: () => GameSource.words,
        );
        return MultipleChoiceScreen(source: source);
      },
    ),
    GoRoute(
      path: '/games/fill-blank',
      builder: (context, state) {
        final src = state.uri.queryParameters['source'] ?? 'words';
        final source = GameSource.values.firstWhere(
          (e) => e.name == src,
          orElse: () => GameSource.words,
        );
        return FillBlankScreen(source: source);
      },
    ),
    GoRoute(
      path: '/games/scramble',
      builder: (context, state) {
        final src = state.uri.queryParameters['source'] ?? 'words';
        final source = GameSource.values.firstWhere(
          (e) => e.name == src,
          orElse: () => GameSource.words,
        );
        return SentenceScrambleScreen(source: source);
      },
    ),
    GoRoute(
      path: '/games/quest',
      builder: (context, state) => const EnglishQuestScreen(),
    ),
    GoRoute(
      path: '/study-log',
      builder: (context, state) => const StudyLogScreen(),
    ),
  ],
);
