import 'english_sync_api_service.dart';
import 'material_api_service.dart';
import 'offline_study_service.dart';
import 'study_content_api_service.dart';
import 'study_structure_api_service.dart';

class StartupSyncService {
  Future<void> run() async {
    await OfflineStudyService().syncPendingTimeLogs();
    await Future.wait([
      _syncEnglish(),
      _syncMaterials(),
      _syncStructure(),
      _syncStudyContent(),
      _syncOfflineResponses(),
    ]).timeout(const Duration(seconds: 8), onTimeout: () => <void>[]);
  }

  Future<void> _syncOfflineResponses() async {
    try {
      final service = OfflineStudyService();
      await service.syncPending();
      await service.syncPendingTimeLogs();
    } catch (_) {}
  }

  Future<void> _syncEnglish() async {
    try {
      final api = EnglishSyncApiService();
      await api.syncLocalDatabase();
      await api.downloadAndMerge();
    } catch (_) {}
  }

  Future<void> _syncMaterials() async {
    try {
      await MaterialApiService().list();
    } catch (_) {}
  }

  Future<void> _syncStructure() async {
    try {
      await StudyStructureApiService().list();
    } catch (_) {}
  }

  Future<void> _syncStudyContent() async {
    try {
      final contents = await StudyContentApiService().list(includeAll: true);
      await OfflineStudyService().cacheContents(contents
          .map((content) => {
                'id': content.id,
                'status': content.status,
                'study_enabled': content.studyEnabled,
                'study_interval': content.studyInterval,
                'study_repetitions': content.studyRepetitions,
                'study_next_review_at':
                    content.studyNextReviewAt?.toIso8601String(),
                'title': content.title,
                'summary': content.summary,
                'flashcards': content.flashcards,
                'questions': content.questions,
                'material': {
                  'id': content.materialId,
                  'title': content.materialTitle,
                  'topic': {'name': content.topicName},
                  'discipline': {'name': content.disciplineName},
                },
              })
          .toList());
    } catch (_) {}
  }
}
