import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/word_provider.dart';
import '../../core/theme/app_theme.dart';

class WordDetailScreen extends ConsumerWidget {
  final int wordId;
  const WordDetailScreen({super.key, required this.wordId});

  Color _statusColor(String s) =>
      s == 'learned' ? AppTheme.primary : s == 'difficult' ? AppTheme.error : AppTheme.secondary;

  String _statusLabel(String s) =>
      s == 'learning' ? 'Learning' : s == 'learned' ? 'Learned' : 'Difficult';

  Color _diffColor(int d) =>
      d == 1 ? AppTheme.primary : d == 2 ? AppTheme.warning : AppTheme.error;

  String _diffLabel(int d) => d == 1 ? 'Easy' : d == 2 ? 'Medium' : 'Hard';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordAsync = ref.watch(wordDetailProvider(wordId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Word Details'),
        leading: BackButton(onPressed: () => context.go('/words')),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => context.go('/words/$wordId/edit'),
          ),
        ],
      ),
      body: wordAsync.when(
        data: (word) {
          if (word == null) {
            return const Center(child: Text('Palavra não encontrada.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              word.word,
                              style: GoogleFonts.nunito(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _statusColor(word.status).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _statusLabel(word.status),
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _statusColor(word.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        word.translation,
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (word.meaning != null) ...[
                _InfoCard(title: 'Meaning', child: Text(word.meaning!, style: _bodyStyle)),
                const SizedBox(height: 12),
              ],
              if ([word.example1, word.example2, word.example3].any((e) => e != null)) ...[
                _InfoCard(
                  title: 'Examples',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [word.example1, word.example2, word.example3]
                        .whereType<String>()
                        .toList()
                        .asMap()
                        .entries
                        .map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${e.key + 1}. ',
                                      style: GoogleFonts.nunito(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.secondary)),
                                  Expanded(child: Text(e.value, style: _bodyStyle)),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (word.synonyms != null) ...[
                _InfoCard(title: 'Synonyms', child: Text(word.synonyms!, style: _bodyStyle)),
                const SizedBox(height: 12),
              ],
              if (word.opposite != null) ...[
                _InfoCard(title: 'Opposite', child: Text(word.opposite!, style: _bodyStyle)),
                const SizedBox(height: 12),
              ],
              if (word.category != null) ...[
                _InfoCard(title: 'Category', child: Text(word.category!, style: _bodyStyle)),
                const SizedBox(height: 12),
              ],
              _InfoCard(
                title: 'Difficulty',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _diffColor(word.difficulty).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _diffLabel(word.difficulty),
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _diffColor(word.difficulty),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _InfoCard(
                title: 'Status',
                child: Row(
                  children: ['learning', 'learned', 'difficult'].map((s) {
                    final color = _statusColor(s);
                    final selected = word.status == s;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () async {
                          if (selected) return;
                          final updated = word.copyWith(
                            status: s,
                            updatedAt: DateTime.now(),
                          );
                          try {
                            await ref.read(wordListProvider.notifier).updateWord(updated);
                            ref.invalidate(wordDetailProvider(wordId));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Status atualizado!')),
                            );
                          } catch (_) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Erro ao atualizar o status.')),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? color.withValues(alpha: 0.15) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected ? color : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            _statusLabel(s),
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: selected ? color : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _confirmDelete(context, ref),
                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
                label: const Text('Delete', style: TextStyle(color: AppTheme.error)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.error),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Erro ao carregar a palavra.')),
      ),
    );
  }

  TextStyle get _bodyStyle =>
      GoogleFonts.nunito(fontSize: 15, color: AppTheme.textPrimary);

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Word'),
        content: const Text('Tem certeza que deseja remover esta palavra?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(wordListProvider.notifier).deleteWord(wordId);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Palavra removida.')),
                );
                context.go('/words');
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Erro ao remover a palavra.')),
                );
              }
            },
            child: const Text('Remover', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _InfoCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppTheme.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
