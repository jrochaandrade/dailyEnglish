import 'package:go_router/go_router.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/words/words_screen.dart';
import '../../screens/words/word_form_screen.dart';
import '../../screens/words/word_detail_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
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
      builder: (context, state) => const WordFormScreen(),
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
  ],
);
