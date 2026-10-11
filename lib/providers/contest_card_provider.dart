import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contest_card.dart';
import '../repositories/contest_card_repository.dart';
import 'word_provider.dart';

final contestCardRepositoryProvider = Provider<ContestCardRepository>((ref) {
  return ContestCardRepository(ref.watch(databaseProvider).database);
});

class ContestCardListNotifier extends AsyncNotifier<List<ContestCard>> {
  String? subject;
  String? deck;

  @override
  Future<List<ContestCard>> build() => ref
      .read(contestCardRepositoryProvider)
      .getAll(subject: subject, deck: deck);

  Future<void> add(ContestCard card) async {
    await ref.read(contestCardRepositoryProvider).insert(card);
    ref.invalidateSelf();
  }

  Future<void> delete(int id) async {
    await ref.read(contestCardRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }

  void filter({String? newSubject, String? newDeck}) {
    subject = newSubject;
    deck = newDeck;
    ref.invalidateSelf();
  }
}

final contestCardListProvider =
    AsyncNotifierProvider<ContestCardListNotifier, List<ContestCard>>(
  ContestCardListNotifier.new,
);

final contestSubjectsProvider = FutureProvider<List<String>>((ref) async {
  ref.watch(contestCardListProvider);
  return ref.read(contestCardRepositoryProvider).getSubjects();
});

final contestDueCountProvider = FutureProvider<int>((ref) async {
  ref.watch(contestCardListProvider);
  return (await ref.read(contestCardRepositoryProvider).getDue()).length;
});
