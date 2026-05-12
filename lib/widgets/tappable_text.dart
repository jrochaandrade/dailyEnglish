import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';
import '../core/services/audio_service.dart';
import '../models/word.dart';
import '../providers/word_provider.dart';

class TappableText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Color highlightColor;

  const TappableText({
    super.key,
    required this.text,
    required this.style,
    this.highlightColor = AppTheme.secondary,
  });

  @override
  State<TappableText> createState() => _TappableTextState();
}

class _TappableTextState extends State<TappableText> {
  List<TextSpan> _spans = [];
  final List<TapGestureRecognizer> _recognizers = [];

  static final _tokenRegex = RegExp(r"\[[^\]]+\]|[a-zA-Z]+(?:'[a-zA-Z]+)*|[^a-zA-Z\[\]]+");
  static final _startsWithLetter = RegExp(r'^[a-zA-Z]');

  @override
  void initState() {
    super.initState();
    _buildSpans();
  }

  @override
  void didUpdateWidget(covariant TappableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _disposeRecognizers();
      _buildSpans();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  void _buildSpans() {
    final spans = <TextSpan>[];
    for (final match in _tokenRegex.allMatches(widget.text)) {
      final token = match.group(0)!;
      if (token.startsWith('[') && token.endsWith(']')) {
        final word = token.substring(1, token.length - 1);
        final rec = TapGestureRecognizer()..onTap = () => _showLookup(word);
        _recognizers.add(rec);
        spans.add(TextSpan(
          text: word,
          style: widget.style.copyWith(
            color: widget.highlightColor,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
          ),
          recognizer: rec,
        ));
      } else if (_startsWithLetter.hasMatch(token)) {
        final rec = TapGestureRecognizer()..onTap = () => _showLookup(token);
        _recognizers.add(rec);
        spans.add(TextSpan(text: token, style: widget.style, recognizer: rec));
      } else {
        spans.add(TextSpan(text: token, style: widget.style));
      }
    }
    _spans = spans;
  }

  void _showLookup(String word) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => WordLookupSheet(word: word),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(style: widget.style, children: _spans),
    );
  }
}

class WordLookupSheet extends ConsumerStatefulWidget {
  final String word;
  const WordLookupSheet({super.key, required this.word});

  @override
  ConsumerState<WordLookupSheet> createState() => _WordLookupSheetState();
}

class _WordLookupSheetState extends ConsumerState<WordLookupSheet> {
  late Future<List<Word>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(wordRepositoryProvider).search(widget.word);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Dictionary Lookup',
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.word,
                    style: GoogleFonts.nunito(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up_rounded, size: 20),
                  color: AppTheme.secondary,
                  tooltip: 'Ouvir pronúncia',
                  onPressed: () => ref.read(audioServiceProvider).speak(widget.word),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  tooltip: 'Copiar palavra',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.word));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Palavra copiada!')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Word>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Text('Erro ao pesquisar a palavra.');
                }
                final words = snapshot.data!;
                if (words.isEmpty) {
                  return Column(
                    children: [
                      const Text(
                        'Palavra não encontrada no seu dicionário.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          final router = GoRouter.of(context);
                          Navigator.pop(context);
                          router.push('/words/new?word=${Uri.encodeComponent(widget.word)}');
                        },
                        label: const Text('Add to Dictionary'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  );
                }
                final w = words.first;
                // If the user searched the English word, show the Portuguese translation.
                // If they searched the Portuguese translation, show the English word.
                final searchedEnglish = w.word.toLowerCase() == widget.word.toLowerCase();
                final blueText = searchedEnglish ? w.translation : w.word;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      blueText,
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.secondary,
                      ),
                    ),
                    if (w.meaning != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        w.meaning!,
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: () {
                        final router = GoRouter.of(context);
                        Navigator.pop(context);
                        router.push('/words/${w.id}');
                      },
                      child: const Text('View Full Details'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
