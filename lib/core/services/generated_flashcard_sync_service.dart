import '../../core/database/app_database.dart';
import '../../models/contest_card.dart';
import '../../models/study_content.dart';
import '../../repositories/contest_card_repository.dart';
import '../utils/markdown_text.dart';
import 'study_content_api_service.dart';

class GeneratedFlashcardSyncService {
  const GeneratedFlashcardSyncService();

  Future<List<StudyContent>> sync() async {
    final contents = await StudyContentApiService().list(includeAll: true);
    final repository = ContestCardRepository(AppDatabase().database);
    final now = DateTime.now();
    final activeKeys = <String>{};

    for (final content in contents) {
      for (final flashcard in content.flashcards) {
        final front =
            MarkdownText.plain(flashcard['question'] as String? ?? '');
        final back = MarkdownText.plain(flashcard['answer'] as String? ?? '');
        if (front.isEmpty || back.isEmpty) continue;
        final source = content.materialTitle;
        if (source != null && source.isNotEmpty) {
          activeKeys.add('$source\u0000$front');
        }
        await repository.upsertGenerated(ContestCard(
          subject: content.disciplineName ?? 'Concursos',
          deck: content.topicName,
          front: front,
          back: back,
          source: source,
          createdAt: now,
          updatedAt: now,
        ));
      }
    }
    await repository.deleteGeneratedNotIn(activeKeys);
    return contents;
  }
}
