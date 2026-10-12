import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/diary_entry.dart';
import '../repositories/diary_repository.dart';
import 'word_provider.dart'; // import to access databaseProvider

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  final appDb = ref.watch(databaseProvider);
  return DiaryRepository(appDb.database);
});

class DiaryListNotifier extends AsyncNotifier<List<DiaryEntry>> {
  @override
  Future<List<DiaryEntry>> build() => _fetch();

  Future<List<DiaryEntry>> _fetch() {
    return ref.read(diaryRepositoryProvider).getAll();
  }

  Future<void> addEntry(DiaryEntry entry) async {
    await ref.read(diaryRepositoryProvider).insert(entry);
    ref.invalidateSelf();
  }

  Future<void> updateEntry(DiaryEntry entry) async {
    await ref.read(diaryRepositoryProvider).update(entry);
    ref.invalidateSelf();
    if (entry.id != null) {
      ref.invalidate(diaryDetailProvider(entry.id!));
    }
  }

  Future<void> deleteEntry(int id) async {
    await ref.read(diaryRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }
}

final diaryListProvider =
    AsyncNotifierProvider<DiaryListNotifier, List<DiaryEntry>>(
        DiaryListNotifier.new);

final diaryDetailProvider = FutureProvider.family<DiaryEntry?, int>((ref, id) {
  return ref.watch(diaryRepositoryProvider).getById(id);
});
