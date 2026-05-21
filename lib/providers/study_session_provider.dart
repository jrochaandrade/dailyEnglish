import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/study_session.dart';
import '../repositories/study_session_repository.dart';
import 'word_provider.dart';

final studySessionRepositoryProvider = Provider<StudySessionRepository>((ref) {
  final appDb = ref.watch(databaseProvider);
  return StudySessionRepository(appDb.database);
});

class StudySessionListNotifier extends AsyncNotifier<List<StudySession>> {
  @override
  Future<List<StudySession>> build() =>
      ref.read(studySessionRepositoryProvider).getAll();

  Future<void> addSession(StudySession session) async {
    await ref.read(studySessionRepositoryProvider).insert(session);
    ref.invalidateSelf();
  }

  Future<void> deleteSession(int id) async {
    await ref.read(studySessionRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }
}

final studySessionListProvider =
    AsyncNotifierProvider<StudySessionListNotifier, List<StudySession>>(
        StudySessionListNotifier.new);

class StudyStats {
  final int listeningMinutes;
  final int readingMinutes;
  final int writingMinutes;
  final int speakingMinutes;

  const StudyStats({
    required this.listeningMinutes,
    required this.readingMinutes,
    required this.writingMinutes,
    required this.speakingMinutes,
  });

  int get totalMinutes =>
      listeningMinutes + readingMinutes + writingMinutes + speakingMinutes;

  double get totalHours => totalMinutes / 60;

  String get estimatedLevel {
    final h = totalHours;
    if (h < 90) return 'Not started';
    if (h < 180) return 'A1';
    if (h < 350) return 'A2';
    if (h < 600) return 'B1';
    if (h < 900) return 'B2';
    if (h < 1800) return 'C1';
    return 'C2';
  }

  static const empty = StudyStats(
    listeningMinutes: 0,
    readingMinutes: 0,
    writingMinutes: 0,
    speakingMinutes: 0,
  );
}

final studyStatsProvider = Provider<StudyStats>((ref) {
  final sessionsAsync = ref.watch(studySessionListProvider);
  return sessionsAsync.when(
    loading: () => StudyStats.empty,
    error: (_, __) => StudyStats.empty,
    data: (sessions) {
      final minutes = <String, int>{};
      for (final s in sessions) {
        minutes[s.type.name] = (minutes[s.type.name] ?? 0) + s.durationMinutes;
      }
      return StudyStats(
        listeningMinutes: minutes[StudyType.listening.name] ?? 0,
        readingMinutes: minutes[StudyType.reading.name] ?? 0,
        writingMinutes: minutes[StudyType.writing.name] ?? 0,
        speakingMinutes: minutes[StudyType.speaking.name] ?? 0,
      );
    },
  );
});
