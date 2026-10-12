import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/phrase.dart';
import '../../providers/phrase_provider.dart';
import '../../core/theme/app_theme.dart';

class PhraseFormScreen extends ConsumerStatefulWidget {
  final int? phraseId;
  const PhraseFormScreen({super.key, this.phraseId});

  @override
  ConsumerState<PhraseFormScreen> createState() => _PhraseFormScreenState();
}

class _PhraseFormScreenState extends ConsumerState<PhraseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditing = false;

  late final TextEditingController _phraseCtrl;
  late final TextEditingController _translationCtrl;
  late final TextEditingController _meaningEnCtrl;
  late final TextEditingController _meaningPtCtrl;
  late final TextEditingController _example1Ctrl;
  late final TextEditingController _exTrans1Ctrl;
  late final TextEditingController _example2Ctrl;
  late final TextEditingController _exTrans2Ctrl;
  late final TextEditingController _example3Ctrl;
  late final TextEditingController _exTrans3Ctrl;

  int _difficulty = 1;
  DateTime? _originalCreatedAt;
  Phrase? _duplicatePhrase;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.phraseId != null;
    _phraseCtrl = TextEditingController();
    _translationCtrl = TextEditingController();
    _meaningEnCtrl = TextEditingController();
    _meaningPtCtrl = TextEditingController();
    _example1Ctrl = TextEditingController();
    _exTrans1Ctrl = TextEditingController();
    _example2Ctrl = TextEditingController();
    _exTrans2Ctrl = TextEditingController();
    _example3Ctrl = TextEditingController();
    _exTrans3Ctrl = TextEditingController();

    if (_isEditing) {
      _isLoading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPhrase());
    } else {
      _phraseCtrl.addListener(_onPhraseChanged);
    }
  }

  Future<void> _loadPhrase() async {
    try {
      final phrase =
          await ref.read(phraseDetailProvider(widget.phraseId!).future);
      if (phrase == null || !mounted) {
        if (mounted) context.go('/phrases');
        return;
      }
      setState(() {
        _isLoading = false;
        _phraseCtrl.text = phrase.phrase;
        _translationCtrl.text = phrase.translation;
        _meaningEnCtrl.text = phrase.meaningEn ?? '';
        _meaningPtCtrl.text = phrase.meaningPt ?? '';
        _example1Ctrl.text = phrase.example1 ?? '';
        _exTrans1Ctrl.text = phrase.exampleTranslation1 ?? '';
        _example2Ctrl.text = phrase.example2 ?? '';
        _exTrans2Ctrl.text = phrase.exampleTranslation2 ?? '';
        _example3Ctrl.text = phrase.example3 ?? '';
        _exTrans3Ctrl.text = phrase.exampleTranslation3 ?? '';
        _difficulty = phrase.difficulty;
        _originalCreatedAt = phrase.createdAt;
      });
    } catch (_) {
      if (!mounted) return;
      context.go('/phrases');
    }
  }

  void _onPhraseChanged() {
    _debounceTimer?.cancel();
    final value = _phraseCtrl.text.trim();
    if (value.isEmpty) {
      setState(() => _duplicatePhrase = null);
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      final results = await ref.read(phraseRepositoryProvider).search(value);
      final exact = results
          .where(
            (p) => p.phrase.toLowerCase() == value.toLowerCase(),
          )
          .toList();
      if (mounted) {
        setState(
            () => _duplicatePhrase = exact.isNotEmpty ? exact.first : null);
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _phraseCtrl.removeListener(_onPhraseChanged);
    _phraseCtrl.dispose();
    _translationCtrl.dispose();
    _meaningEnCtrl.dispose();
    _meaningPtCtrl.dispose();
    _example1Ctrl.dispose();
    _exTrans1Ctrl.dispose();
    _example2Ctrl.dispose();
    _exTrans2Ctrl.dispose();
    _example3Ctrl.dispose();
    _exTrans3Ctrl.dispose();
    super.dispose();
  }

  String? _notEmpty(String? v) =>
      v == null || v.trim().isEmpty ? 'Campo obrigatório' : null;

  String? _nullable(String v) => v.trim().isEmpty ? null : v.trim();

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text == null || data!.text!.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Área de transferência vazia.')),
        );
      }
      return;
    }
    final text = data.text!;

    const allLabels = [
      'Phrase:',
      'Word:',
      'Translation:',
      'Meaning:',
      'Meaning (EN):',
      'Meaning (PT):',
      'Examples:',
      'Example translations:',
      'Synonyms:',
      'Opposite:',
      'Category:',
      'Difficulty level:',
      'Learning status:',
    ];

    String? extractValue(String label) {
      final startIndex = text.indexOf(label);
      if (startIndex == -1) return null;
      final valueStart = startIndex + label.length;
      int endIndex = text.length;
      for (final l in allLabels) {
        if (l == label) continue;
        final idx = text.indexOf(l, valueStart);
        if (idx != -1 && idx < endIndex) endIndex = idx;
      }
      return text.substring(valueStart, endIndex).trim();
    }

    List<String> extractLines(String label) {
      final block = extractValue(label);
      if (block == null || block.isEmpty) return [];
      final byNewline = block
          .split('\n')
          .map((e) => e.trim())
          .map((e) => e.replaceFirst(RegExp(r'^\d+[.)]\s*'), ''))
          .where((e) => e.isNotEmpty)
          .toList();
      if (byNewline.length > 1) return byNewline;
      return block
          .split(RegExp(r'(?<=[.?!])\s+(?=[A-ZÀ-ÖØ-öø-ÿ])'))
          .map((e) => e.trim())
          .map((e) => e.replaceFirst(RegExp(r'^\d+[.)]\s*'), ''))
          .where((e) => e.isNotEmpty)
          .toList();
    }

    setState(() {
      final phraseVal = extractValue('Phrase:') ?? extractValue('Word:');
      if (phraseVal != null) _phraseCtrl.text = phraseVal;

      final translation = extractValue('Translation:');
      if (translation != null) _translationCtrl.text = translation;

      String? meaningEn = extractValue('Meaning (EN):');
      String? meaningPt = extractValue('Meaning (PT):');
      if (meaningEn == null && meaningPt == null) {
        final block = extractValue('Meaning:');
        if (block != null) {
          final enMatch = RegExp(r'EN:\s*(.+?)(?=PT(?:-BR)?:|$)', dotAll: true)
              .firstMatch(block);
          final ptMatch =
              RegExp(r'PT(?:-BR)?:\s*(.+?)$', dotAll: true).firstMatch(block);
          meaningEn = enMatch?.group(1)?.trim();
          meaningPt = ptMatch?.group(1)?.trim();
          if (meaningEn == null && enMatch == null && ptMatch == null)
            meaningEn = block;
        }
      }
      if (meaningEn != null) _meaningEnCtrl.text = meaningEn;
      if (meaningPt != null) _meaningPtCtrl.text = meaningPt;

      final examples = extractLines('Examples:');
      if (examples.isNotEmpty) _example1Ctrl.text = examples[0];
      if (examples.length > 1) _example2Ctrl.text = examples[1];
      if (examples.length > 2) _example3Ctrl.text = examples[2];

      final exTrans = extractLines('Example translations:');
      if (exTrans.isNotEmpty) _exTrans1Ctrl.text = exTrans[0];
      if (exTrans.length > 1) _exTrans2Ctrl.text = exTrans[1];
      if (exTrans.length > 2) _exTrans3Ctrl.text = exTrans[2];

      final diffMatch = extractValue('Difficulty level:');
      if (diffMatch != null) {
        final d = diffMatch.toLowerCase();
        if (d.contains('basic') || d.contains('easy')) {
          _difficulty = 1;
        } else if (d.contains('intermediate') || d.contains('medium')) {
          _difficulty = 2;
        } else if (d.contains('hard') || d.contains('advanced')) {
          _difficulty = 3;
        }
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Campos preenchidos com sucesso!'),
        backgroundColor: AppTheme.secondary,
      ));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final now = DateTime.now();

    final phrase = Phrase(
      id: widget.phraseId,
      phrase: _phraseCtrl.text.trim(),
      translation: _translationCtrl.text.trim(),
      meaningEn: _nullable(_meaningEnCtrl.text),
      meaningPt: _nullable(_meaningPtCtrl.text),
      example1: _nullable(_example1Ctrl.text),
      exampleTranslation1: _nullable(_exTrans1Ctrl.text),
      example2: _nullable(_example2Ctrl.text),
      exampleTranslation2: _nullable(_exTrans2Ctrl.text),
      example3: _nullable(_example3Ctrl.text),
      exampleTranslation3: _nullable(_exTrans3Ctrl.text),
      difficulty: _difficulty,
      status: 'learning',
      createdAt: _originalCreatedAt ?? now,
      updatedAt: now,
    );

    try {
      if (_isEditing) {
        await ref.read(phraseListProvider.notifier).updatePhrase(phrase);
      } else {
        await ref.read(phraseListProvider.notifier).addPhrase(phrase);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEditing ? 'Frase atualizada!' : 'Frase salva!'),
        backgroundColor: AppTheme.secondary,
      ));
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/phrases');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Erro ao salvar. Tente novamente.'),
        backgroundColor: AppTheme.error,
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _isEditing && _phraseCtrl.text.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Phrase' : 'Add Phrase'),
          leading: BackButton(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/phrases')),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Phrase' : 'Add Phrase'),
        leading: BackButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/phrases')),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_paste_rounded),
            tooltip: 'Paste from AI',
            onPressed: _pasteFromClipboard,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionLabel('REQUIRED'),
            _Field(
                controller: _phraseCtrl,
                label: 'Phrase (English)',
                validator: _notEmpty),
            if (_duplicatePhrase != null)
              _DuplicateWarning(phrase: _duplicatePhrase!),
            const SizedBox(height: 12),
            _Field(
                controller: _translationCtrl,
                label: 'Translation (Portuguese)',
                validator: _notEmpty),
            const SizedBox(height: 20),
            const _SectionLabel('DETAILS'),
            _Field(controller: _meaningEnCtrl, label: 'Meaning (English)'),
            const SizedBox(height: 12),
            _Field(controller: _meaningPtCtrl, label: 'Meaning (Portuguese)'),
            const SizedBox(height: 12),
            _Field(controller: _example1Ctrl, label: 'Example 1'),
            const SizedBox(height: 12),
            _Field(controller: _exTrans1Ctrl, label: 'Example 1 Translation'),
            const SizedBox(height: 12),
            _Field(controller: _example2Ctrl, label: 'Example 2'),
            const SizedBox(height: 12),
            _Field(controller: _exTrans2Ctrl, label: 'Example 2 Translation'),
            const SizedBox(height: 12),
            _Field(controller: _example3Ctrl, label: 'Example 3'),
            const SizedBox(height: 12),
            _Field(controller: _exTrans3Ctrl, label: 'Example 3 Translation'),
            const SizedBox(height: 20),
            const _SectionLabel('DIFFICULTY'),
            Row(
              children: [
                _DiffChip(
                    label: 'Easy',
                    value: 1,
                    selected: _difficulty == 1,
                    color: AppTheme.primary,
                    onTap: () => setState(() => _difficulty = 1)),
                const SizedBox(width: 8),
                _DiffChip(
                    label: 'Medium',
                    value: 2,
                    selected: _difficulty == 2,
                    color: AppTheme.warning,
                    onTap: () => setState(() => _difficulty = 2)),
                const SizedBox(width: 8),
                _DiffChip(
                    label: 'Hard',
                    value: 3,
                    selected: _difficulty == 3,
                    color: AppTheme.error,
                    onTap: () => setState(() => _difficulty = 3)),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;

  const _Field({required this.controller, required this.label, this.validator});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _DiffChip extends StatelessWidget {
  final String label;
  final int value;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _DiffChip(
      {required this.label,
      required this.value,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              selected ? color.withValues(alpha: 0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : Colors.transparent, width: 2),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected
                ? color
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _DuplicateWarning extends StatelessWidget {
  final Phrase phrase;
  const _DuplicateWarning({required this.phrase});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppTheme.warning, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Esta frase já está cadastrada.',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.warning,
                  ),
                ),
                Text(
                  '${phrase.phrase} → ${phrase.translation}',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/phrases/${phrase.id}'),
            child: Text(
              'Ver',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w700,
                color: AppTheme.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
