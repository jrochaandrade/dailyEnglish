import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/word.dart';
import '../../providers/word_provider.dart';
import '../../providers/category_provider.dart';
import '../../core/theme/app_theme.dart';

class WordFormScreen extends ConsumerStatefulWidget {
  final int? wordId;
  final String? initialWord;
  const WordFormScreen({super.key, this.wordId, this.initialWord});

  @override
  ConsumerState<WordFormScreen> createState() => _WordFormScreenState();
}

class _WordFormScreenState extends ConsumerState<WordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditing = false;

  late final TextEditingController _wordCtrl;
  late final TextEditingController _translationCtrl;
  late final TextEditingController _translation2Ctrl;
  late final TextEditingController _translation3Ctrl;
  late final TextEditingController _meaningCtrl;
  late final TextEditingController _meaningPtCtrl;
  late final TextEditingController _example1Ctrl;
  late final TextEditingController _exampleTranslation1Ctrl;
  late final TextEditingController _example2Ctrl;
  late final TextEditingController _exampleTranslation2Ctrl;
  late final TextEditingController _example3Ctrl;
  late final TextEditingController _exampleTranslation3Ctrl;
  late final TextEditingController _synonym1Ctrl;
  late final TextEditingController _synonym2Ctrl;
  late final TextEditingController _synonym3Ctrl;
  late final TextEditingController _synonym4Ctrl;
  late final TextEditingController _synonym5Ctrl;
  late final TextEditingController _oppositeCtrl;

  String? _selectedCategory;
  int _difficulty = 1;
  String _status = 'learning';
  DateTime? _originalCreatedAt;
  Word? _duplicateWord;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.wordId != null;
    _wordCtrl = TextEditingController(text: widget.initialWord);
    _translationCtrl = TextEditingController();
    _translation2Ctrl = TextEditingController();
    _translation3Ctrl = TextEditingController();
    _meaningCtrl = TextEditingController();
    _meaningPtCtrl = TextEditingController();
    _example1Ctrl = TextEditingController();
    _exampleTranslation1Ctrl = TextEditingController();
    _example2Ctrl = TextEditingController();
    _exampleTranslation2Ctrl = TextEditingController();
    _example3Ctrl = TextEditingController();
    _exampleTranslation3Ctrl = TextEditingController();
    _synonym1Ctrl = TextEditingController();
    _synonym2Ctrl = TextEditingController();
    _synonym3Ctrl = TextEditingController();
    _synonym4Ctrl = TextEditingController();
    _synonym5Ctrl = TextEditingController();
    _oppositeCtrl = TextEditingController();

    if (_isEditing) {
      _isLoading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadWord());
    } else {
      _wordCtrl.addListener(_onWordChanged);
    }
  }

  void _onWordChanged() {
    _debounceTimer?.cancel();
    final value = _wordCtrl.text.trim();
    if (value.isEmpty) {
      setState(() => _duplicateWord = null);
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      final results = await ref.read(wordRepositoryProvider).search(value);
      final exact = results
          .where(
            (w) => w.word.toLowerCase() == value.toLowerCase(),
          )
          .toList();
      if (mounted) {
        setState(() => _duplicateWord = exact.isNotEmpty ? exact.first : null);
      }
    });
  }

  Future<void> _loadWord() async {
    try {
      final word = await ref.read(wordDetailProvider(widget.wordId!).future);
      if (word == null || !mounted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Palavra não encontrada.'),
          ));
          context.go('/words');
        }
        return;
      }
      setState(() {
        _isLoading = false;
        _wordCtrl.text = word.word;
        _translationCtrl.text = word.translation;
        _translation2Ctrl.text = word.translation2 ?? '';
        _translation3Ctrl.text = word.translation3 ?? '';
        _meaningCtrl.text = word.meaning ?? '';
        _meaningPtCtrl.text = word.meaningPt ?? '';
        _example1Ctrl.text = word.example1 ?? '';
        _exampleTranslation1Ctrl.text = word.exampleTranslation1 ?? '';
        _example2Ctrl.text = word.example2 ?? '';
        _exampleTranslation2Ctrl.text = word.exampleTranslation2 ?? '';
        _example3Ctrl.text = word.example3 ?? '';
        _exampleTranslation3Ctrl.text = word.exampleTranslation3 ?? '';
        _synonym1Ctrl.text = word.synonym1 ?? '';
        _synonym2Ctrl.text = word.synonym2 ?? '';
        _synonym3Ctrl.text = word.synonym3 ?? '';
        _synonym4Ctrl.text = word.synonym4 ?? '';
        _synonym5Ctrl.text = word.synonym5 ?? '';
        _oppositeCtrl.text = word.opposite ?? '';
        _selectedCategory = word.category;
        _difficulty = word.difficulty;
        _status = word.status;
        _originalCreatedAt = word.createdAt;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Erro ao carregar a palavra.'),
      ));
      context.go('/words');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _wordCtrl.removeListener(_onWordChanged);
    _wordCtrl.dispose();
    _translationCtrl.dispose();
    _translation2Ctrl.dispose();
    _translation3Ctrl.dispose();
    _meaningCtrl.dispose();
    _meaningPtCtrl.dispose();
    _example1Ctrl.dispose();
    _exampleTranslation1Ctrl.dispose();
    _example2Ctrl.dispose();
    _exampleTranslation2Ctrl.dispose();
    _example3Ctrl.dispose();
    _exampleTranslation3Ctrl.dispose();
    _synonym1Ctrl.dispose();
    _synonym2Ctrl.dispose();
    _synonym3Ctrl.dispose();
    _synonym4Ctrl.dispose();
    _synonym5Ctrl.dispose();
    _oppositeCtrl.dispose();
    super.dispose();
  }

  String? _notEmpty(String? v) =>
      v == null || v.trim().isEmpty ? 'Campo obrigatório' : null;

  String? _nullable(String? v) =>
      v == null || v.trim().isEmpty ? null : v.trim();

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text == null) return;
    final text = data!.text!;

    String? extractValue(List<String> labels) {
      int startIndex = -1;
      String matchedLabel = '';
      for (final l in labels) {
        startIndex = text.indexOf(l);
        if (startIndex != -1) {
          matchedLabel = l;
          break;
        }
      }
      if (startIndex == -1) return null;

      int endIndex = text.length;
      final allLabels = [
        'Word:',
        'Translation:',
        'Meaning:',
        'EN:',
        'In simple English:',
        'PT-BR:',
        'PT:',
        'Em português:',
        'Examples:',
        'Example translations:',
        'Synonyms:',
        'Opposite:',
        'Category:',
        'Difficulty level:',
        'Learning status:'
      ];

      final valueStart = startIndex + matchedLabel.length;

      for (final l in allLabels) {
        final idx = text.indexOf(l, valueStart);
        if (idx != -1 && idx < endIndex) {
          endIndex = idx;
        }
      }
      return text.substring(valueStart, endIndex).trim();
    }

    List<String> splitList(String? block) {
      if (block == null || block.isEmpty) return [];
      if (block.contains('\n')) {
        return block
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      final matches = RegExp(r'[^.!?]+[.!?]+').allMatches(block);
      if (matches.isNotEmpty) {
        return matches.map((m) => m.group(0)!.trim()).toList();
      }
      return [block.trim()];
    }

    setState(() {
      final wordMatch = extractValue(['Word:']);
      if (wordMatch != null) _wordCtrl.text = wordMatch;

      final translationMatch = extractValue(['Translation:']);
      if (translationMatch != null) {
        final parts = translationMatch
            .split(RegExp(r'[/;]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (parts.isNotEmpty) _translationCtrl.text = parts[0];
        if (parts.length > 1) _translation2Ctrl.text = parts[1];
        if (parts.length > 2)
          _translation3Ctrl.text = parts.sublist(2).join(' / ');
      }

      final meaningEn = extractValue(['EN:', 'In simple English:']);
      if (meaningEn != null) _meaningCtrl.text = meaningEn;

      final meaningPt = extractValue(['PT-BR:', 'PT:', 'Em português:']);
      if (meaningPt != null) _meaningPtCtrl.text = meaningPt;

      final examples = splitList(extractValue(['Examples:']));
      if (examples.isNotEmpty) _example1Ctrl.text = examples[0];
      if (examples.length > 1) _example2Ctrl.text = examples[1];
      if (examples.length > 2) _example3Ctrl.text = examples[2];

      final exTrans = splitList(extractValue(['Example translations:']));
      if (exTrans.isNotEmpty) _exampleTranslation1Ctrl.text = exTrans[0];
      if (exTrans.length > 1) _exampleTranslation2Ctrl.text = exTrans[1];
      if (exTrans.length > 2) _exampleTranslation3Ctrl.text = exTrans[2];

      final synonymsMatch = extractValue(['Synonyms:']);
      if (synonymsMatch != null) {
        final parts = synonymsMatch
            .split(RegExp(r'[,;/]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        final synCtrls = [
          _synonym1Ctrl,
          _synonym2Ctrl,
          _synonym3Ctrl,
          _synonym4Ctrl,
          _synonym5Ctrl
        ];
        for (int i = 0; i < parts.length && i < synCtrls.length; i++) {
          synCtrls[i].text = parts[i];
        }
      }

      final oppositeMatch = extractValue(['Opposite:']);
      if (oppositeMatch != null) _oppositeCtrl.text = oppositeMatch;

      final categoryMatch = extractValue(['Category:']);
      if (categoryMatch != null) {
        final cats = ref
                .read(categoryListProvider)
                .valueOrNull
                ?.map((c) => c.name)
                .toList() ??
            [];
        final cat = cats.firstWhere(
            (c) => c.toLowerCase() == categoryMatch.toLowerCase(),
            orElse: () => '');
        if (cat.isNotEmpty) _selectedCategory = cat;
      }

      final diffMatch = extractValue(['Difficulty level:']);
      if (diffMatch != null) {
        final d = diffMatch.toLowerCase();
        if (d.contains('basic') || d.contains('easy')) {
          _difficulty = 1;
        } else if (d.contains('medium') || d.contains('intermediate')) {
          _difficulty = 2;
        } else if (d.contains('hard') || d.contains('advanced')) {
          _difficulty = 3;
        }
      }

      final statusMatch = extractValue(['Learning status:']);
      if (statusMatch != null) {
        final s = statusMatch.toLowerCase();
        if (s.contains('learned') || s.contains('known')) {
          _status = 'learned';
        } else if (s.contains('difficult') || s.contains('hard')) {
          _status = 'difficult';
        } else {
          _status = 'learning';
        }
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Dados colados com sucesso!'),
        backgroundColor: AppTheme.primary,
      ));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final now = DateTime.now();

    final word = Word(
      id: widget.wordId,
      word: _wordCtrl.text.trim(),
      translation: _translationCtrl.text.trim(),
      translation2: _nullable(_translation2Ctrl.text),
      translation3: _nullable(_translation3Ctrl.text),
      meaning: _nullable(_meaningCtrl.text),
      meaningPt: _nullable(_meaningPtCtrl.text),
      example1: _nullable(_example1Ctrl.text),
      exampleTranslation1: _nullable(_exampleTranslation1Ctrl.text),
      example2: _nullable(_example2Ctrl.text),
      exampleTranslation2: _nullable(_exampleTranslation2Ctrl.text),
      example3: _nullable(_example3Ctrl.text),
      exampleTranslation3: _nullable(_exampleTranslation3Ctrl.text),
      synonym1: _nullable(_synonym1Ctrl.text),
      synonym2: _nullable(_synonym2Ctrl.text),
      synonym3: _nullable(_synonym3Ctrl.text),
      synonym4: _nullable(_synonym4Ctrl.text),
      synonym5: _nullable(_synonym5Ctrl.text),
      opposite: _nullable(_oppositeCtrl.text),
      category: _selectedCategory,
      difficulty: _difficulty,
      status: _status,
      createdAt: _originalCreatedAt ?? now,
      updatedAt: now,
    );

    try {
      if (_isEditing) {
        await ref.read(wordListProvider.notifier).updateWord(word);
      } else {
        await ref.read(wordListProvider.notifier).addWord(word);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEditing
            ? 'Palavra atualizada com sucesso!'
            : 'Palavra salva com sucesso!'),
        backgroundColor: AppTheme.primary,
      ));
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/words');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Erro ao salvar a palavra. Tente novamente.'),
        backgroundColor: AppTheme.error,
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Word' : 'Add Word'),
        leading: BackButton(onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/words');
          }
        }),
        actions: [
          IconButton(
            icon: const Icon(Icons.paste_rounded),
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
            _Field(controller: _wordCtrl, label: 'Word', validator: _notEmpty),
            if (_duplicateWord != null)
              _DuplicateWarning(word: _duplicateWord!),
            const SizedBox(height: 12),
            _Field(
                controller: _translationCtrl,
                label: 'Translation',
                validator: _notEmpty),
            const SizedBox(height: 12),
            _Field(
                controller: _translation2Ctrl,
                label: 'Translation 2 (optional)'),
            const SizedBox(height: 12),
            _Field(
                controller: _translation3Ctrl,
                label: 'Translation 3 (optional)'),
            const SizedBox(height: 20),
            const _SectionLabel('DETAILS'),
            _Field(
                controller: _meaningCtrl, label: 'Meaning (In simple English)'),
            const SizedBox(height: 12),
            _Field(controller: _meaningPtCtrl, label: 'Meaning (Em português)'),
            const SizedBox(height: 12),
            _Field(controller: _example1Ctrl, label: 'Example 1'),
            const SizedBox(height: 12),
            _Field(
                controller: _exampleTranslation1Ctrl,
                label: 'Example 1 Translation'),
            const SizedBox(height: 12),
            _Field(controller: _example2Ctrl, label: 'Example 2'),
            const SizedBox(height: 12),
            _Field(
                controller: _exampleTranslation2Ctrl,
                label: 'Example 2 Translation'),
            const SizedBox(height: 12),
            _Field(controller: _example3Ctrl, label: 'Example 3'),
            const SizedBox(height: 12),
            _Field(
                controller: _exampleTranslation3Ctrl,
                label: 'Example 3 Translation'),
            const SizedBox(height: 12),
            const SizedBox(height: 8),
            const _SectionLabel('SYNONYMS'),
            _Field(controller: _synonym1Ctrl, label: 'Synonym 1'),
            const SizedBox(height: 12),
            _Field(controller: _synonym2Ctrl, label: 'Synonym 2'),
            const SizedBox(height: 12),
            _Field(controller: _synonym3Ctrl, label: 'Synonym 3'),
            const SizedBox(height: 12),
            _Field(controller: _synonym4Ctrl, label: 'Synonym 4'),
            const SizedBox(height: 12),
            _Field(controller: _synonym5Ctrl, label: 'Synonym 5'),
            const SizedBox(height: 12),
            _Field(controller: _oppositeCtrl, label: 'Opposite'),
            const SizedBox(height: 20),
            const _SectionLabel('CATEGORY'),
            DropdownButtonFormField<String>(
              key: ValueKey(_selectedCategory),
              initialValue: _selectedCategory,
              decoration: const InputDecoration(hintText: 'Select a category'),
              items: (ref.watch(categoryListProvider).valueOrNull ?? [])
                  .map((c) =>
                      DropdownMenuItem(value: c.name, child: Text(c.name)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v),
            ),
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
                          strokeWidth: 2, color: Colors.white),
                    )
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

class _DuplicateWarning extends StatelessWidget {
  final Word word;
  const _DuplicateWarning({required this.word});

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
                  'Esta palavra já está no dicionário.',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.warning,
                  ),
                ),
                Text(
                  '${word.word} → ${word.translation}',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/words/${word.id}'),
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

class _DiffChip extends StatelessWidget {
  final String label;
  final int value;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _DiffChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.color,
    required this.onTap,
  });

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
