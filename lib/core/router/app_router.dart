import 'package:go_router/go_router.dart';
import '../services/audio_service.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/home/sync_screen.dart';
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
import '../../screens/concursos/contest_home_screen.dart';
import '../../screens/concursos/contest_cards_screen.dart';
import '../../screens/concursos/contest_performance_screen.dart';
import '../../screens/materials/summary_notebooks_screen.dart';
import '../../models/contest_card.dart';
import '../../screens/start/start_screen.dart';
import '../../screens/materials/materials_screen.dart';
import '../../screens/materials/study_content_screen.dart';
import '../../screens/study/review_settings_screen.dart';
import '../../screens/study/review_plan_screen.dart';
import '../../screens/study/study_hub_screen.dart';
import '../../screens/study/study_session_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/auth_gate.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  observers: [AudioStopObserver()],
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AuthLandingScreen(),
    ),
    GoRoute(
      path: '/ingles',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/words',
      builder: (context, state) => const WordsScreen(),
    ),
    GoRoute(
      path: '/words/new',
      builder: (context, state) =>
          WordFormScreen(initialWord: state.uri.queryParameters['word']),
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
    GoRoute(
      path: '/review-settings',
      builder: (context, state) => const ReviewSettingsScreen(),
    ),
    GoRoute(
      path: '/review-plan',
      builder: (context, state) => const ReviewPlanScreen(),
    ),
    GoRoute(
      path: '/sync',
      builder: (context, state) => AuthGate(
        child: SyncScreen(
          title: state.uri.queryParameters['area'] == 'concursos'
              ? 'Sincronização · Concursos'
              : 'Sincronização',
          contestsOnly: state.uri.queryParameters['area'] == 'concursos',
        ),
      ),
    ),
    GoRoute(
      path: '/concursos',
      builder: (context, state) => const AuthGate(child: ContestHomeScreen()),
    ),
    GoRoute(
      path: '/materials',
      builder: (context, state) => const AuthGate(child: MaterialsScreen()),
    ),
    GoRoute(
      path: '/study-content',
      builder: (context, state) => AuthGate(
        child: StudyContentScreen(
          type: state.uri.queryParameters['type'],
          contentId:
              int.tryParse(state.uri.queryParameters['content_id'] ?? ''),
        ),
      ),
    ),
    GoRoute(
      path: '/study',
      builder: (context, state) => const AuthGate(child: StudyHubScreen()),
    ),
    GoRoute(
      path: '/study/session',
      builder: (context, state) => AuthGate(
        child: StudySessionScreen(type: state.uri.queryParameters['type']),
      ),
    ),
    GoRoute(
      path: '/summary-notebooks',
      builder: (context, state) =>
          const AuthGate(child: SummaryNotebooksScreen()),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/areas',
      builder: (context, state) => const AuthGate(child: StartScreen()),
    ),
    GoRoute(
      path: '/concursos/new',
      builder: (context, state) =>
          const AuthGate(child: ContestCardFormScreen()),
    ),
    GoRoute(
      path: '/concursos/edit',
      builder: (context, state) => AuthGate(
        child: ContestCardFormScreen(card: state.extra as ContestCard?),
      ),
    ),
    GoRoute(
      path: '/concursos/review',
      builder: (context, state) => AuthGate(
        child: ContestReviewScreen(
          subject: state.uri.queryParameters['subject'],
          deck: state.uri.queryParameters['deck'],
          mode: state.uri.queryParameters['mode'] ?? 'due',
        ),
      ),
    ),
    GoRoute(
      path: '/concursos/performance',
      builder: (context, state) =>
          const AuthGate(child: ContestPerformanceScreen()),
    ),
  ],
);
