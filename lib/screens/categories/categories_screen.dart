import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/category_provider.dart';
import '../../models/category.dart';
import '../../core/theme/app_theme.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoryListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(context, ref, null),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.label_outline_rounded,
                      size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma categoria.',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toque em + para adicionar.',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: categories.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (_, i) => _CategoryTile(
              category: categories[i],
              onEdit: () => _showEditDialog(context, ref, categories[i]),
              onDelete: () => _confirmDelete(context, ref, categories[i]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            const Center(child: Text('Erro ao carregar categorias.')),
      ),
    );
  }

  void _showEditDialog(
      BuildContext context, WidgetRef ref, Category? existing) {
    final controller = TextEditingController(text: existing?.name ?? '');
    final isNew = existing == null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isNew ? 'Nova Categoria' : 'Editar Categoria'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Nome da categoria'),
          onSubmitted: (_) => _save(ctx, ref, controller.text, existing),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => _save(ctx, ref, controller.text, existing),
            child: Text(isNew ? 'Adicionar' : 'Salvar',
                style: const TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _save(
      BuildContext ctx, WidgetRef ref, String value, Category? existing) async {
    final name = value.trim();
    if (name.isEmpty) return;
    try {
      if (existing == null) {
        await ref.read(categoryListProvider.notifier).addCategory(name);
      } else {
        await ref
            .read(categoryListProvider.notifier)
            .updateCategory(existing.id!, name);
      }
      if (ctx.mounted) Navigator.pop(ctx);
    } catch (_) {
      if (ctx.mounted) {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Essa categoria já existe.')),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Category category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover Categoria'),
        content: Text(
            'Remover "${category.name}"? As palavras nessa categoria não serão apagadas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(categoryListProvider.notifier)
                  .deleteCategory(category.id!);
            },
            child:
                const Text('Remover', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryTile({
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: const Icon(Icons.label_rounded, color: AppTheme.primary),
      title: Text(
        category.name,
        style: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 20),
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            color: AppTheme.error,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
