import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/word.dart';
import '../../providers/word_provider.dart';
import '../../core/theme/app_theme.dart';

const _wordCategories = [
  'Work', 'Travel', 'Family', 'Daily Routine', 'Technology',
  'IELTS', 'Verbs', 'Adjectives', 'Useful Phrases',
  'Environmental Police', 'Immigration', 'Conversation',
];

class WordFormScreen extends ConsumerStatefulWidget {
  final int? wordId;
  const WordFormScreen({super.key, this.wordId});

  @override
  ConsumerState<WordFormScreen> createState() => _WordFormScreenState();
}

class _WordFormScreenState extends ConsumerState<WordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditing = false;

  late final TextEditingController _wordCtrl;
  late final TextEditingController _translationCtrl;
  late final TextEditingController _meaningCtrl;
  late final TextEditingController _example1Ctrl;
  late final TextEditingController _example2Ctrl;
  late final TextEditingController _example3Ctrl;
  late final TextEditingController _synonymsCtrl;
  late final TextEditingController _oppositeCtrl;

  String? _selectedCategory;
  int _difficulty = 1;
  String _status = 'learning';
  DateTime? _originalCreatedAt;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.wordId != null;
    _wordCtrl = TextEditingController();
    _translationCtrl = TextEditingController();
    _meaningCtrl = TextEditingController();
    _example1Ctrl = TextEditingController();
    _example2Ctrl = TextEditingController();
    _example3Ctrl = TextEditingController();
    _synonymsCtrl = TextEditingController();
    _oppositeCtrl = TextEditingController();

    if (_isEditing) {
      _isLoading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadWord());
    }
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
        _meaningCtrl.text = word.meaning ?? '';
        _example1Ctrl.text = word.example1 ?? '';
        _example2Ctrl.text = word.example2 ?? '';
        _example3Ctrl.text = word.example3 ?? '';
        _synonymsCtrl.text = word.synonyms ?? '';
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
    _wordCtrl.dispose();
    _translationCtrl.dispose();
    _meaningCtrl.dispose();
    _example1Ctrl.dispose();
    _example2Ctrl.dispose();
    _example3Ctrl.dispose();
    _synonymsCtrl.dispose();
    _oppositeCtrl.dispose();
    super.dispose();
  }

  String? _notEmpty(String? v) =>
      v == null || v.trim().isEmpty ? 'Campo obrigatório' : null;

  String? _nullable(String? v) => v == null || v.trim().isEmpty ? null : v.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final now = DateTime.now();

    final word = Word(
      id: widget.wordId,
      word: _wordCtrl.text.trim(),
      translation: _translationCtrl.text.trim(),
      meaning: _nullable(_meaningCtrl.text),
      example1: _nullable(_example1Ctrl.text),
      example2: _nullable(_example2Ctrl.text),
      example3: _nullable(_example3Ctrl.text),
      synonyms: _nullable(_synonymsCtrl.text),
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
        content: Text(_isEditing ? 'Palavra atualizada com sucesso!' : 'Palavra salva com sucesso!'),
        backgroundColor: AppTheme.primary,
      ));
      context.go('/words');
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
        leading: BackButton(onPressed: () => context.go('/words')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionLabel('REQUIRED'),
            _Field(controller: _wordCtrl, label: 'Word', validator: _notEmpty),
            const SizedBox(height: 12),
            _Field(controller: _translationCtrl, label: 'Translation', validator: _notEmpty),
            const SizedBox(height: 20),
            const _SectionLabel('DETAILS'),
            _Field(controller: _meaningCtrl, label: 'Meaning'),
            const SizedBox(height: 12),
            _Field(controller: _example1Ctrl, label: 'Example 1'),
            const SizedBox(height: 12),
            _Field(controller: _example2Ctrl, label: 'Example 2'),
            const SizedBox(height: 12),
            _Field(controller: _example3Ctrl, label: 'Example 3'),
            const SizedBox(height: 12),
            _Field(controller: _synonymsCtrl, label: 'Synonyms'),
            const SizedBox(height: 12),
            _Field(controller: _oppositeCtrl, label: 'Opposite'),
            const SizedBox(height: 20),
            const _SectionLabel('CATEGORY'),
            DropdownButtonFormField<String>(
              key: ValueKey(_selectedCategory),
              initialValue: _selectedCategory,
              decoration: const InputDecoration(hintText: 'Select a category'),
              items: _wordCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v),
            ),
            const SizedBox(height: 20),
            const _SectionLabel('DIFFICULTY'),
            Row(
              children: [
                _DiffChip(label: 'Easy', value: 1, selected: _difficulty == 1,
                    color: AppTheme.primary, onTap: () => setState(() => _difficulty = 1)),
                const SizedBox(width: 8),
                _DiffChip(label: 'Medium', value: 2, selected: _difficulty == 2,
                    color: AppTheme.warning, onTap: () => setState(() => _difficulty = 2)),
                const SizedBox(width: 8),
                _DiffChip(label: 'Hard', value: 3, selected: _difficulty == 3,
                    color: AppTheme.error, onTap: () => setState(() => _difficulty = 3)),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
          color: AppTheme.textSecondary,
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
          color: selected ? color.withValues(alpha: 0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.transparent, width: 2),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected ? color : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
