import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/database/app_database.dart';
import '../../core/services/study_content_api_service.dart';
import '../../core/services/generated_flashcard_sync_service.dart';

class ReviewPlanScreen extends StatefulWidget {
  const ReviewPlanScreen({super.key});

  @override
  State<ReviewPlanScreen> createState() => _ReviewPlanScreenState();
}

class _ReviewPlanScreenState extends State<ReviewPlanScreen> {
  late Future<Map<String, int>> _counts;

  @override
  void initState() {
    super.initState();
    _counts = _loadCounts();
  }

  Future<Map<String, int>> _loadCounts() async {
    try {
      await const GeneratedFlashcardSyncService().sync();
    } on StudyContentApiException {
      // Mantém a contagem local quando estiver sem conexão.
    }
    final db = await AppDatabase().database;
    final now = DateTime.now().millisecondsSinceEpoch;
    Future<int> count(String table, String column) async {
      final rows = await db.rawQuery(
          'SELECT COUNT(*) AS total FROM $table WHERE $column IS NULL OR $column <= ?',
          [now]);
      return (rows.first['total'] as int?) ?? 0;
    }

    final studyContentCount = await _pendingStudyContentCount();
    return {
      'inglês': await count('words', 'next_review_at') +
          await count('phrases', 'next_review_at') +
          await count('phrasal_verbs', 'next_review_at'),
      'concursos': await count('contest_cards', 'next_review_at'),
      'estudos': studyContentCount,
    };
  }

  Future<int> _pendingStudyContentCount() async {
    try {
      final contents = await StudyContentApiService().list();
      final preferences = await SharedPreferences.getInstance();
      final completedSessionIds =
          (preferences.getStringList('study-session-all-v1-completed') ?? [])
              .map(int.tryParse)
              .whereType<int>()
              .toSet();
      return contents.where((content) {
        if (content.isDue && content.studyInterval > 0) {
          preferences.remove('study-content-progress-v1-${content.id}');
        }
        if (completedSessionIds.contains(content.id)) return false;
        final completed = (preferences
                    .getStringList('study-content-progress-v1-${content.id}') ??
                [])
            .toSet();
        final available = <String>{
          if (content.summary?.trim().isNotEmpty ?? false) 'summaries',
          if (content.flashcards.isNotEmpty) 'flashcards',
          if (content.questions.isNotEmpty) 'questions',
        };
        return available.isNotEmpty && !available.every(completed.contains);
      }).length;
    } on StudyContentApiException {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Plano de revisão de hoje')),
        body: FutureBuilder<Map<String, int>>(
          future: _counts,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final counts = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('O que está previsto para hoje',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('Cards vencidos ou ainda sem uma primeira revisão.'),
                const SizedBox(height: 20),
                _planCard(context, 'Inglês', counts['inglês']!,
                    Icons.translate_rounded, () => context.push('/flashcards')),
                _planCard(
                    context,
                    'Concursos',
                    counts['concursos']!,
                    Icons.school_rounded,
                    () => context.push('/concursos/review?mode=due')),
                _planCard(context, 'Estudar', counts['estudos']!,
                    Icons.menu_book_rounded, () => context.push('/study')),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.push('/review-settings'),
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('Configurar revisões e notificações'),
                ),
              ],
            );
          },
        ),
      );

  Widget _planCard(BuildContext context, String title, int count, IconData icon,
      VoidCallback onTap) {
    return Card(
      child: ListTile(
        onTap: count == 0 ? null : onTap,
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
            count == 0 ? 'Nada pendente hoje' : '$count item(ns) para revisar'),
        trailing: count == 0
            ? const Icon(Icons.check_circle_rounded)
            : const Icon(Icons.play_arrow_rounded),
      ),
    );
  }
}
