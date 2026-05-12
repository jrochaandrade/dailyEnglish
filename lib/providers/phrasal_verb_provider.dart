import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/phrasal_verb.dart';
import '../repositories/phrasal_verb_repository.dart';
import 'word_provider.dart';

final phrasalVerbRepositoryProvider = Provider<PhrasalVerbRepository>((ref) {
  final appDb = ref.watch(databaseProvider);
  return PhrasalVerbRepository(appDb.database);
});

class PhrasalVerbListNotifier extends AsyncNotifier<List<PhrasalVerb>> {
  String _searchQuery = '';
  String? _statusFilter;

  @override
  Future<List<PhrasalVerb>> build() => _fetch();

  Future<List<PhrasalVerb>> _fetch() {
    final repo = ref.read(phrasalVerbRepositoryProvider);
    if (_searchQuery.isNotEmpty) return repo.search(_searchQuery);
    if (_statusFilter != null) return repo.filterByStatus(_statusFilter!);
    return repo.getAll();
  }

  Future<void> addPhrasalVerb(PhrasalVerb pv) async {
    await ref.read(phrasalVerbRepositoryProvider).insert(pv);
    ref.invalidateSelf();
  }

  Future<void> updatePhrasalVerb(PhrasalVerb pv) async {
    await ref.read(phrasalVerbRepositoryProvider).update(pv);
    ref.invalidateSelf();
  }

  Future<void> deletePhrasalVerb(int id) async {
    await ref.read(phrasalVerbRepositoryProvider).delete(id);
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

final phrasalVerbListProvider =
    AsyncNotifierProvider<PhrasalVerbListNotifier, List<PhrasalVerb>>(PhrasalVerbListNotifier.new);

final phrasalVerbDetailProvider = FutureProvider.family<PhrasalVerb?, int>((ref, id) {
  return ref.watch(phrasalVerbRepositoryProvider).getById(id);
});

final duePhrasalVerbsCountProvider = FutureProvider<int>((ref) async {
  ref.watch(phrasalVerbListProvider);
  final due = await ref.read(phrasalVerbRepositoryProvider).getDue();
  return due.length;
});
