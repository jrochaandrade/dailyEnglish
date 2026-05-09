import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/app_database.dart';
import '../models/word.dart';
import '../repositories/word_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final wordRepositoryProvider = Provider<WordRepository>((ref) {
  final appDb = ref.watch(databaseProvider);
  return WordRepository(appDb.database);
});

class WordListNotifier extends AsyncNotifier<List<Word>> {
  String _searchQuery = '';
  String? _categoryFilter;
  String? _statusFilter;

  @override
  Future<List<Word>> build() => _fetch();

  Future<List<Word>> _fetch() {
    final repo = ref.read(wordRepositoryProvider);
    if (_searchQuery.isNotEmpty) return repo.search(_searchQuery);
    if (_categoryFilter != null) return repo.filterByCategory(_categoryFilter!);
    if (_statusFilter != null) return repo.filterByStatus(_statusFilter!);
    return repo.getAll();
  }

  Future<void> addWord(Word word) async {
    await ref.read(wordRepositoryProvider).insert(word);
    ref.invalidateSelf();
  }

  Future<void> updateWord(Word word) async {
    await ref.read(wordRepositoryProvider).update(word);
    ref.invalidateSelf();
  }

  Future<void> deleteWord(int id) async {
    await ref.read(wordRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }

  void setSearch(String query) {
    _searchQuery = query;
    _categoryFilter = null;
    _statusFilter = null;
    ref.invalidateSelf();
  }

  void setFilter({String? category, String? status}) {
    _searchQuery = '';
    _categoryFilter = category;
    _statusFilter = status;
    ref.invalidateSelf();
  }
}

final wordListProvider =
    AsyncNotifierProvider<WordListNotifier, List<Word>>(WordListNotifier.new);

final wordDetailProvider = FutureProvider.family<Word?, int>((ref, id) {
  return ref.watch(wordRepositoryProvider).getById(id);
});
