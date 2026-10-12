import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/phrase.dart';
import '../repositories/phrase_repository.dart';
import 'word_provider.dart';

final phraseRepositoryProvider = Provider<PhraseRepository>((ref) {
  final appDb = ref.watch(databaseProvider);
  return PhraseRepository(appDb.database);
});

class PhraseListNotifier extends AsyncNotifier<List<Phrase>> {
  String _searchQuery = '';
  String? _statusFilter;

  @override
  Future<List<Phrase>> build() => _fetch();

  Future<List<Phrase>> _fetch() {
    final repo = ref.read(phraseRepositoryProvider);
    if (_searchQuery.isNotEmpty) return repo.search(_searchQuery);
    if (_statusFilter != null) return repo.filterByStatus(_statusFilter!);
    return repo.getAll();
  }

  Future<void> addPhrase(Phrase phrase) async {
    await ref.read(phraseRepositoryProvider).insert(phrase);
    ref.invalidateSelf();
  }

  Future<void> updatePhrase(Phrase phrase) async {
    await ref.read(phraseRepositoryProvider).update(phrase);
    ref.invalidateSelf();
    if (phrase.id != null) ref.invalidate(phraseDetailProvider(phrase.id!));
  }

  Future<void> deletePhrase(int id) async {
    await ref.read(phraseRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }

  void setSearch(String query) {
    _searchQuery = query;
    _statusFilter = null;
    ref.invalidateSelf();
  }

  void setFilter({String? status}) {
    _searchQuery = '';
    _statusFilter = status;
    ref.invalidateSelf();
  }
}

final phraseListProvider =
    AsyncNotifierProvider<PhraseListNotifier, List<Phrase>>(
        PhraseListNotifier.new);

final phraseDetailProvider = FutureProvider.family<Phrase?, int>((ref, id) {
  return ref.watch(phraseRepositoryProvider).getById(id);
});

final duePhrasesCountProvider = FutureProvider<int>((ref) async {
  ref.watch(phraseListProvider);
  final due = await ref.read(phraseRepositoryProvider).getDue();
  return due.length;
});
