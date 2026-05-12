import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../../providers/diary_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/tappable_text.dart';
import '../../core/services/translation_service.dart';
import '../../core/services/audio_service.dart';

class DiaryDetailScreen extends ConsumerStatefulWidget {
  final int entryId;
  const DiaryDetailScreen({super.key, required this.entryId});

  @override
  ConsumerState<DiaryDetailScreen> createState() => _DiaryDetailScreenState();
}

class _DiaryDetailScreenState extends ConsumerState<DiaryDetailScreen> {
  bool _isTranslating = false;
  String? _translatedContent;
  String? _translatedCorrected;

  Future<void> _translate(dynamic entry) async {
    if (_translatedContent != null) {
      setState(() {
        _translatedContent = null;
        _translatedCorrected = null;
      });
      return;
    }

    setState(() => _isTranslating = true);
    try {
      final translationService = ref.read(translationServiceProvider);
      final tContent = await translationService.translate(entry.content);
      String? tCorrected;
      if (entry.correctedContent != null) {
        tCorrected = await translationService.translate(entry.correctedContent!);
      }

      if (mounted) {
        setState(() {
          _translatedContent = tContent;
          _translatedCorrected = tCorrected;
          _isTranslating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTranslating = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao traduzir.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entryAsync = ref.watch(diaryDetailProvider(widget.entryId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entry Details'),
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/diary')),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up_rounded),
            tooltip: 'Ouvir o texto',
            onPressed: () {
              entryAsync.whenData((entry) {
                if (entry == null) return;
                final text = entry.correctedContent ?? entry.content;
                ref.read(audioServiceProvider).speak(text);
              });
            },
          ),
          IconButton(
            icon: _isTranslating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_translatedContent == null ? Icons.translate : Icons.g_translate, color: _translatedContent == null ? null : AppTheme.secondary),
            onPressed: _isTranslating ? null : () {
              entryAsync.whenData((entry) {
                if (entry != null) _translate(entry);
              });
            },
            tooltip: _translatedContent == null ? 'Traduzir tudo' : 'Ver original',
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => context.go('/diary/${widget.entryId}/edit'),
          ),
        ],
      ),
      body: entryAsync.when(
        data: (entry) {
          if (entry == null) return const Center(child: Text('Entrada não encontrada.'));
          final dateStr = "${entry.createdAt.day.toString().padLeft(2, '0')}/${entry.createdAt.month.toString().padLeft(2, '0')}/${entry.createdAt.year}";

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: GoogleFonts.nunito(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (entry.mood != null)
                    Text(entry.mood!, style: const TextStyle(fontSize: 40)),
                ],
              ),
              const SizedBox(height: 24),
              if (entry.correctedContent == null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Content',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: entry.content));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Texto copiado!')));
                      },
                    ),
                  ],
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _translatedContent != null
                    ? Text(
                        _translatedContent!,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          height: 1.6,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      )
                    : TappableText(
                        text: entry.content,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          height: 1.6,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        highlightColor: AppTheme.secondary,
                      ),
                  ),
                )
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Original Text',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: entry.content));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Texto original copiado!')));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _translatedContent != null
                    ? Text(
                        _translatedContent!,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          height: 1.6,
                          color: Theme.of(context).colorScheme.onSurface,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Colors.red.withValues(alpha: 0.5),
                        ),
                      )
                    : TappableText(
                        text: entry.content,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          height: 1.6,
                          color: Theme.of(context).colorScheme.onSurface,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Colors.red.withValues(alpha: 0.5),
                        ),
                        highlightColor: AppTheme.secondary,
                      ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'AI Corrected Text',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      color: AppTheme.primary,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: entry.correctedContent!));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Texto corrigido copiado!')));
                      },
                    ),
                  ],
                ),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppTheme.primary, width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _translatedCorrected != null
                    ? Text(
                        _translatedCorrected!,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          height: 1.6,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      )
                    : TappableText(
                        text: entry.correctedContent!,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          height: 1.6,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        highlightColor: AppTheme.primary,
                      ),
                  ),
                ),
              ],
              if (entry.comments != null) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.comment_outlined, size: 20, color: AppTheme.secondary),
                    const SizedBox(width: 8),
                    Text(
                      'AI Feedback & Comments',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Card(
                  color: AppTheme.secondary.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppTheme.secondary.withValues(alpha: 0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      entry.comments!,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () => _confirmDelete(context, ref),
                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
                label: const Text('Delete', style: TextStyle(color: AppTheme.error)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.error),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Erro ao carregar a entrada.')),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Tem certeza que deseja remover esta entrada do diário?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(diaryListProvider.notifier).deleteEntry(widget.entryId);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Entrada removida.')),
                );
                context.go('/diary');
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Erro ao remover a entrada.')),
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
