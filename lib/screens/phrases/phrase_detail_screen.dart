import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/phrase_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/audio_service.dart';
import '../../widgets/tappable_text.dart';

class PhraseDetailScreen extends ConsumerWidget {
  final int phraseId;
  const PhraseDetailScreen({super.key, required this.phraseId});

  Color _statusColor(String s) => s == 'learned'
      ? AppTheme.primary
      : s == 'difficult'
          ? AppTheme.error
          : AppTheme.secondary;

  String _statusLabel(String s) => s == 'learning'
      ? 'Learning'
      : s == 'learned'
          ? 'Learned'
          : 'Difficult';

  Color _diffColor(int d) => d == 1
      ? AppTheme.primary
      : d == 2
          ? AppTheme.warning
          : AppTheme.error;

  String _diffLabel(int d) => d == 1
      ? 'Easy'
      : d == 2
          ? 'Medium'
          : 'Hard';

  TextStyle _bodyStyle(BuildContext context) => GoogleFonts.nunito(
      fontSize: 15, color: Theme.of(context).colorScheme.onSurface);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phraseAsync = ref.watch(phraseDetailProvider(phraseId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phrase Details'),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/phrases'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => context.push('/phrases/$phraseId/edit'),
          ),
        ],
      ),
      body: phraseAsync.when(
        data: (phrase) {
          if (phrase == null) {
            return const Center(child: Text('Frase não encontrada.'));
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TappableText(
                              text: phrase.phrase,
                              style: GoogleFonts.nunito(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.volume_up_rounded),
                            color: AppTheme.secondary,
                            tooltip: 'Ouvir pronúncia',
                            onPressed: () => ref
                                .read(audioServiceProvider)
                                .speak(phrase.phrase),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _statusColor(phrase.status)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _statusLabel(phrase.status),
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _statusColor(phrase.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        phrase.translation,
                        style: GoogleFonts.nunito(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (phrase.meaningEn != null || phrase.meaningPt != null) ...[
                _InfoCard(
                  title: 'MEANING',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (phrase.meaningEn != null)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: TappableText(
                                    text: phrase.meaningEn!,
                                    style: _bodyStyle(context))),
                            IconButton(
                              icon:
                                  const Icon(Icons.volume_up_rounded, size: 18),
                              color: AppTheme.secondary,
                              padding: const EdgeInsets.only(left: 4),
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => ref
                                  .read(audioServiceProvider)
                                  .speak(phrase.meaningEn!),
                            ),
                          ],
                        ),
                      if (phrase.meaningEn != null && phrase.meaningPt != null)
                        const Divider(height: 16),
                      if (phrase.meaningPt != null)
                        Text(
                          phrase.meaningPt!,
                          style: _bodyStyle(context).copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if ([phrase.example1, phrase.example2, phrase.example3]
                  .any((e) => e != null)) ...[
                _InfoCard(
                  title: 'EXAMPLES',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (phrase.example1 != null)
                        _ExampleItem(
                            number: 1,
                            text: phrase.example1!,
                            translation: phrase.exampleTranslation1,
                            style: _bodyStyle(context),
                            onSpeak: () => ref
                                .read(audioServiceProvider)
                                .speak(phrase.example1!)),
                      if (phrase.example2 != null)
                        _ExampleItem(
                            number: 2,
                            text: phrase.example2!,
                            translation: phrase.exampleTranslation2,
                            style: _bodyStyle(context),
                            onSpeak: () => ref
                                .read(audioServiceProvider)
                                .speak(phrase.example2!)),
                      if (phrase.example3 != null)
                        _ExampleItem(
                            number: 3,
                            text: phrase.example3!,
                            translation: phrase.exampleTranslation3,
                            style: _bodyStyle(context),
                            onSpeak: () => ref
                                .read(audioServiceProvider)
                                .speak(phrase.example3!)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _InfoCard(
                title: 'DIFFICULTY',
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        _diffColor(phrase.difficulty).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _diffLabel(phrase.difficulty),
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _diffColor(phrase.difficulty),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _InfoCard(
                title: 'STATUS',
                child: Row(
                  children: ['learning', 'learned', 'difficult'].map((s) {
                    final color = _statusColor(s);
                    final selected = phrase.status == s;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () async {
                          if (selected) return;
                          try {
                            await ref
                                .read(phraseListProvider.notifier)
                                .updatePhrase(
                                  phrase.copyWith(
                                      status: s, updatedAt: DateTime.now()),
                                );
                            ref.invalidate(phraseDetailProvider(phraseId));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Status atualizado!')),
                            );
                          } catch (_) {}
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
                                width: 2),
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
        error: (e, _) => const Center(child: Text('Erro ao carregar a frase.')),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Phrase'),
        content: const Text('Tem certeza que deseja remover esta frase?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(phraseListProvider.notifier)
                    .deletePhrase(phraseId);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Frase removida.')),
                );
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/phrases');
                }
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Erro ao remover a frase.')),
                );
              }
            },
            child:
                const Text('Remover', style: TextStyle(color: AppTheme.error)),
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
  final TextStyle style;
  final VoidCallback? onSpeak;

  const _ExampleItem({
    required this.number,
    required this.text,
    this.translation,
    required this.style,
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
              Text(
                '$number. ',
                style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.secondary),
              ),
              Expanded(child: TappableText(text: text, style: style)),
              if (onSpeak != null)
                IconButton(
                  icon: const Icon(Icons.volume_up_rounded, size: 18),
                  color: AppTheme.secondary,
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
                style: style.copyWith(
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
