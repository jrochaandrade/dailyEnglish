import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/phrasal_verb.dart';
import '../../providers/phrasal_verb_provider.dart';
import '../../core/theme/app_theme.dart';

class PhrasalVerbFormScreen extends ConsumerStatefulWidget {
  final int? pvId;
  const PhrasalVerbFormScreen({super.key, this.pvId});

  @override
  ConsumerState<PhrasalVerbFormScreen> createState() =>
      _PhrasalVerbFormScreenState();
}

class _PhrasalVerbFormScreenState
    extends ConsumerState<PhrasalVerbFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditing = false;

  late final TextEditingController _baseVerbCtrl;
  late final TextEditingController _particleCtrl;
  late final TextEditingController _meaningCtrl;
  late final TextEditingController _meaningPtCtrl;
  late final TextEditingController _meaningEnCtrl;
  late final TextEditingController _example1Ctrl;
  late final TextEditingController _exTrans1Ctrl;
  late final TextEditingController _example2Ctrl;
  late final TextEditingController _exTrans2Ctrl;
  late final TextEditingController _example3Ctrl;
  late final TextEditingController _exTrans3Ctrl;

  int _difficulty = 1;
  String _status = 'learning';
  DateTime? _originalCreatedAt;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.pvId != null;
    _baseVerbCtrl = TextEditingController();
    _particleCtrl = TextEditingController();
    _meaningCtrl = TextEditingController();
    _meaningPtCtrl = TextEditingController();
    _meaningEnCtrl = TextEditingController();
    _example1Ctrl = TextEditingController();
    _exTrans1Ctrl = TextEditingController();
    _example2Ctrl = TextEditingController();
    _exTrans2Ctrl = TextEditingController();
    _example3Ctrl = TextEditingController();
    _exTrans3Ctrl = TextEditingController();

    if (_isEditing) {
      _isLoading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPhrasalVerb());
    }
  }

  Future<void> _loadPhrasalVerb() async {
    try {
      final pv =
          await ref.read(phrasalVerbDetailProvider(widget.pvId!).future);
      if (pv == null || !mounted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Phrasal verb não encontrado.'),
          ));
          context.go('/phrasal-verbs');
        }
        return;
      }
      setState(() {
        _isLoading = false;
        _baseVerbCtrl.text = pv.baseVerb;
        _particleCtrl.text = pv.particle;
        _meaningCtrl.text = pv.meaning;
        _meaningPtCtrl.text = pv.meaningPt ?? '';
        _meaningEnCtrl.text = pv.meaningEn ?? '';
        _example1Ctrl.text = pv.example1 ?? '';
        _exTrans1Ctrl.text = pv.exampleTranslation1 ?? '';
        _example2Ctrl.text = pv.example2 ?? '';
        _exTrans2Ctrl.text = pv.exampleTranslation2 ?? '';
        _example3Ctrl.text = pv.example3 ?? '';
        _exTrans3Ctrl.text = pv.exampleTranslation3 ?? '';
        _difficulty = pv.difficulty;
        _status = pv.status;
        _originalCreatedAt = pv.createdAt;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Erro ao carregar o phrasal verb.'),
      ));
      context.go('/phrasal-verbs');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _baseVerbCtrl.dispose();
    _particleCtrl.dispose();
    _meaningCtrl.dispose();
    _meaningPtCtrl.dispose();
    _meaningEnCtrl.dispose();
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

  String? _nullable(String? v) =>
      v == null || v.trim().isEmpty ? null : v.trim();

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

    // All known section headers for boundary detection (word form format included)
    const allLabels = [
      'Phrasal Verb:',
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
      // Single line — split on sentence boundaries
      return block
          .split(RegExp(r'(?<=[.?!])\s+(?=[A-ZÀ-ÖØ-öø-ÿ])'))
          .map((e) => e.trim())
          .map((e) => e.replaceFirst(RegExp(r'^\d+[.)]\s*'), ''))
          .where((e) => e.isNotEmpty)
          .toList();
    }

    setState(() {
      // Accept both "Phrasal Verb: look up" and "Word: look up"
      final pvLine = extractValue('Phrasal Verb:') ?? extractValue('Word:');
      if (pvLine != null && pvLine.isNotEmpty) {
        final parts = pvLine.trim().split(RegExp(r'\s+'));
        if (parts.isNotEmpty) _baseVerbCtrl.text = parts[0];
        if (parts.length > 1) _particleCtrl.text = parts.sublist(1).join(' ');
      }

      final translationMatch = extractValue('Translation:');
      if (translationMatch != null) {
        final parts = translationMatch
            .split(RegExp(r'[/;]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (parts.isNotEmpty) _meaningCtrl.text = parts.join(' / ');
      }

      // Try explicit "(EN):" / "(PT):" labels first, then parse "Meaning: EN: ... PT-BR: ..."
      String? meaningEn = extractValue('Meaning (EN):');
      String? meaningPt = extractValue('Meaning (PT):');
      if (meaningEn == null && meaningPt == null) {
        final block = extractValue('Meaning:');
        if (block != null) {
          final enMatch = RegExp(r'EN:\s*(.+?)(?=PT(?:-BR)?:|$)', dotAll: true).firstMatch(block);
          final ptMatch = RegExp(r'PT(?:-BR)?:\s*(.+?)$', dotAll: true).firstMatch(block);
          meaningEn = enMatch?.group(1)?.trim();
          meaningPt = ptMatch?.group(1)?.trim();
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
        backgroundColor: AppTheme.tertiary,
      ));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final now = DateTime.now();

    final pv = PhrasalVerb(
      id: widget.pvId,
      baseVerb: _baseVerbCtrl.text.trim(),
      particle: _particleCtrl.text.trim(),
      meaning: _meaningCtrl.text.trim(),
      meaningPt: _nullable(_meaningPtCtrl.text),
      meaningEn: _nullable(_meaningEnCtrl.text),
      example1: _nullable(_example1Ctrl.text),
      exampleTranslation1: _nullable(_exTrans1Ctrl.text),
      example2: _nullable(_example2Ctrl.text),
      exampleTranslation2: _nullable(_exTrans2Ctrl.text),
      example3: _nullable(_example3Ctrl.text),
      exampleTranslation3: _nullable(_exTrans3Ctrl.text),
      difficulty: _difficulty,
      status: _status,
      createdAt: _originalCreatedAt ?? now,
      updatedAt: now,
    );

    try {
      if (_isEditing) {
        await ref.read(phrasalVerbListProvider.notifier).updatePhrasalVerb(pv);
      } else {
        await ref.read(phrasalVerbListProvider.notifier).addPhrasalVerb(pv);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEditing
            ? 'Phrasal verb atualizado com sucesso!'
            : 'Phrasal verb salvo com sucesso!'),
        backgroundColor: AppTheme.tertiary,
      ));
      if (context.canPop()) { context.pop(); } else { context.go('/phrasal-verbs'); }
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
    if (_isLoading && _isEditing && _baseVerbCtrl.text.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Phrasal Verb' : 'Add Phrasal Verb'),
          leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/phrasal-verbs')),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Phrasal Verb' : 'Add Phrasal Verb'),
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/phrasal-verbs')),
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
              controller: _baseVerbCtrl,
              label: 'Base Verb',
              validator: _notEmpty,
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _particleCtrl,
              label: 'Particle',
              validator: _notEmpty,
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _meaningCtrl,
              label: 'Translation',
              hint: 'Main Portuguese translation',
              validator: _notEmpty,
            ),
            const SizedBox(height: 20),
            const _SectionLabel('DETAILS'),
            _Field(
              controller: _meaningPtCtrl,
              label: 'Meaning (Portuguese)',
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _meaningEnCtrl,
              label: 'Meaning (English)',
            ),
            const SizedBox(height: 12),
            _Field(controller: _example1Ctrl, label: 'Example 1'),
            const SizedBox(height: 12),
            _Field(
                controller: _exTrans1Ctrl, label: 'Example 1 Translation'),
            const SizedBox(height: 12),
            _Field(controller: _example2Ctrl, label: 'Example 2'),
            const SizedBox(height: 12),
            _Field(
                controller: _exTrans2Ctrl, label: 'Example 2 Translation'),
            const SizedBox(height: 12),
            _Field(controller: _example3Ctrl, label: 'Example 3'),
            const SizedBox(height: 12),
            _Field(
                controller: _exTrans3Ctrl, label: 'Example 3 Translation'),
            const SizedBox(height: 20),
            const _SectionLabel('DIFFICULTY'),
            Row(
              children: [
                _DiffChip(
                  label: 'Easy',
                  value: 1,
                  selected: _difficulty == 1,
                  color: AppTheme.primary,
                  onTap: () => setState(() => _difficulty = 1),
                ),
                const SizedBox(width: 8),
                _DiffChip(
                  label: 'Medium',
                  value: 2,
                  selected: _difficulty == 2,
                  color: AppTheme.warning,
                  onTap: () => setState(() => _difficulty = 2),
                ),
                const SizedBox(width: 8),
                _DiffChip(
                  label: 'Hard',
                  value: 3,
                  selected: _difficulty == 3,
                  color: AppTheme.error,
                  onTap: () => setState(() => _difficulty = 3),
                ),
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
  final String? hint;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
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
