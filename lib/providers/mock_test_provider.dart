import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/mock_test.dart';
import '../models/mock_test_targets.dart';
import '../repositories/mock_test_repository.dart';
import 'word_provider.dart';

final mockTestRepositoryProvider = Provider<MockTestRepository>((ref) {
  final appDb = ref.watch(databaseProvider);
  return MockTestRepository(appDb.database);
});

class MockTestListNotifier extends AsyncNotifier<List<MockTest>> {
  @override
  Future<List<MockTest>> build() =>
      ref.read(mockTestRepositoryProvider).getAll();

  Future<void> addTest(MockTest test) async {
    await ref.read(mockTestRepositoryProvider).insert(test);
    ref.invalidateSelf();
  }

  Future<void> deleteTest(int id) async {
    await ref.read(mockTestRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }
}

final mockTestListProvider =
    AsyncNotifierProvider<MockTestListNotifier, List<MockTest>>(
        MockTestListNotifier.new);

class MockTestTargetsNotifier extends AsyncNotifier<MockTestTargets> {
  @override
  Future<MockTestTargets> build() => MockTestTargets.load();

  Future<void> updateTargets(MockTestTargets targets) async {
    await targets.save();
    ref.invalidateSelf();
  }
}

final mockTestTargetsProvider =
    AsyncNotifierProvider<MockTestTargetsNotifier, MockTestTargets>(
        MockTestTargetsNotifier.new);

class MockTestStats {
  final int done;
  final int positive;
  final double rate;
  final bool bookTest;

  const MockTestStats({
    required this.done,
    required this.positive,
    required this.rate,
    required this.bookTest,
  });

  static const empty = MockTestStats(
    done: 0,
    positive: 0,
    rate: 0,
    bookTest: false,
  );
}

final mockTestStatsProvider = Provider<MockTestStats>((ref) {
  final async = ref.watch(mockTestListProvider);
  return async.when(
    loading: () => MockTestStats.empty,
    error: (_, __) => MockTestStats.empty,
    data: (tests) {
      final done = tests.length;
      final positive = tests.where((t) => t.reachedTarget).length;
      final rate = done == 0 ? 0.0 : positive / done * 100;
      return MockTestStats(
        done: done,
        positive: positive,
        rate: rate,
        bookTest: rate > 70.0,
      );
    },
  );
});
