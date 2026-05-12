import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/phrasal_verb_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/audio_service.dart';

class PhrasalVerbDetailScreen extends ConsumerWidget {
  final int pvId;
  const PhrasalVerbDetailScreen({super.key, required this.pvId});

  Color _statusColor(String s) =>
      s == 'learned'
          ? AppTheme.primary
          : s == 'difficult'
              ? AppTheme.error
              : AppTheme.secondary;

  String _statusLabel(String s) =>
      s == 'learning' ? 'Learning' : s == 'learned' ? 'Learned' : 'Difficult';

  Color _diffColor(int d) =>
      d == 1 ? AppTheme.primary : d == 2 ? AppTheme.warning : AppTheme.error;

  String _diffLabel(int d) => d == 1 ? 'Easy' : d == 2 ? 'Medium' : 'Hard';

  TextStyle _bodyStyle(BuildContext context) => GoogleFonts.nunito(
        fontSize: 15,
        color: Theme.of(context).colorScheme.onSurface,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pvAsync = ref.watch(phrasalVerbDetailProvider(pvId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phrasal Verb'),
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/phrasal-verbs'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => context.push('/phrasal-verbs/$pvId/edit'),
          ),
        ],
      ),
      body: pvAsync.when(
        data: (pv) {
          if (pv == null) {
            return const Center(
                child: Text('Phrasal verb não encontrado.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header card
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
                              pv.verb,
                              style: GoogleFonts.nunito(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color:
                                    Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.volume_up_rounded),
                            color: AppTheme.tertiary,
                            tooltip: 'Ouvir pronúncia',
                            onPressed: () => ref.read(audioServiceProvider).speak(pv.verb),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _statusColor(pv.status)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _statusLabel(pv.status),
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _statusColor(pv.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        pv.meaning,
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Meaning card
              if (pv.meaningEn != null || pv.meaningPt != null) ...[
                _InfoCard(
                  title: 'MEANING',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (pv.meaningEn != null)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Text(pv.meaningEn!, style: _bodyStyle(context))),
                            IconButton(
                              icon: const Icon(Icons.volume_up_rounded, size: 18),
                              color: AppTheme.tertiary,
                              padding: const EdgeInsets.only(left: 4),
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => ref.read(audioServiceProvider).speak(pv.meaningEn!),
                            ),
                          ],
                        ),
                      if (pv.meaningEn != null && pv.meaningPt != null)
                        const Divider(height: 16),
                      if (pv.meaningPt != null)
                        Text(
                          pv.meaningPt!,
                          style: _bodyStyle(context).copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Examples card
              if ([pv.example1, pv.example2, pv.example3]
                  .any((e) => e != null)) ...[
                _InfoCard(
                  title: 'EXAMPLES',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (pv.example1 != null)
                        _ExampleItem(number: 1, text: pv.example1!, translation: pv.exampleTranslation1, bodyStyle: _bodyStyle(context), onSpeak: () => ref.read(audioServiceProvider).speak(pv.example1!)),
                      if (pv.example2 != null)
                        _ExampleItem(number: 2, text: pv.example2!, translation: pv.exampleTranslation2, bodyStyle: _bodyStyle(context), onSpeak: () => ref.read(audioServiceProvider).speak(pv.example2!)),
                      if (pv.example3 != null)
                        _ExampleItem(number: 3, text: pv.example3!, translation: pv.exampleTranslation3, bodyStyle: _bodyStyle(context), onSpeak: () => ref.read(audioServiceProvider).speak(pv.example3!)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Difficulty card
              _InfoCard(
                title: 'DIFFICULTY',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _diffColor(pv.difficulty)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _diffLabel(pv.difficulty),
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _diffColor(pv.difficulty),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Status card
              _InfoCard(
                title: 'STATUS',
                child: Row(
                  children: ['learning', 'learned', 'difficult'].map((s) {
                    final color = _statusColor(s);
                    final selected = pv.status == s;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () async {
                          if (selected) return;
                          final updated = pv.copyWith(
                            status: s,
                            updatedAt: DateTime.now(),
                          );
                          try {
                            await ref
                                .read(phrasalVerbListProvider.notifier)
                                .updatePhrasalVerb(updated);
                            ref.invalidate(phrasalVerbDetailProvider(pvId));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Status atualizado!')),
                            );
                          } catch (_) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Erro ao atualizar o status.')),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? color.withValues(alpha: 0.15)
                                : Colors.grey.shade100,
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
                              color: selected
                                  ? color
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Delete button
              OutlinedButton.icon(
                onPressed: () => _confirmDelete(context, ref),
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppTheme.error),
                label: const Text('Delete',
                    style: TextStyle(color: AppTheme.error)),
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
        error: (e, _) =>
            const Center(child: Text('Erro ao carregar o phrasal verb.')),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Phrasal Verb'),
        content:
            const Text('Tem certeza que deseja remover este phrasal verb?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(phrasalVerbListProvider.notifier)
                    .deletePhrasalVerb(pvId);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Phrasal verb removido.')),
                );
                if (context.canPop()) { context.pop(); } else { context.go('/phrasal-verbs'); }
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Erro ao remover o phrasal verb.')),
                );
              }
            },
            child: const Text('Remover',
                style: TextStyle(color: AppTheme.error)),
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
              title,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _ExampleItem extends StatelessWidget {
  final int number;
  final String text;
  final String? translation;
  final TextStyle bodyStyle;
  final VoidCallback? onSpeak;

  const _ExampleItem({
    required this.number,
    required this.text,
    this.translation,
    required this.bodyStyle,
    this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(text, style: bodyStyle)),
              if (onSpeak != null)
                IconButton(
                  icon: const Icon(Icons.volume_up_rounded, size: 18),
                  color: AppTheme.tertiary,
                  padding: const EdgeInsets.only(left: 4),
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  onPressed: onSpeak,
                ),
            ],
          ),
          if (translation != null && translation!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 2),
              child: Text(
                translation!,
                style: bodyStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
