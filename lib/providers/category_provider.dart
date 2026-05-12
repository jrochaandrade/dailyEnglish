import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../repositories/category_repository.dart';
import 'word_provider.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final appDb = ref.watch(databaseProvider);
  return CategoryRepository(appDb.database);
});

class CategoryListNotifier extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() =>
      ref.read(categoryRepositoryProvider).getAll();

  Future<void> addCategory(String name) async {
    await ref.read(categoryRepositoryProvider).add(name);
    ref.invalidateSelf();
  }

  Future<void> updateCategory(int id, String name) async {
    await ref.read(categoryRepositoryProvider).update(id, name);
    ref.invalidateSelf();
  }

  Future<void> deleteCategory(int id) async {
    await ref.read(categoryRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }
}

final categoryListProvider =
    AsyncNotifierProvider<CategoryListNotifier, List<Category>>(
        CategoryListNotifier.new);
