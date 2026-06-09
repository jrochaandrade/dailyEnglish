import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/diary_entry.dart';
import '../../providers/diary_provider.dart';
import '../../core/theme/app_theme.dart';

const _moods = ['😄', '😊', '😐', '😔', '😢', '😡', '🤔', '😴'];

class DiaryFormScreen extends ConsumerStatefulWidget {
  final int? entryId;
  const DiaryFormScreen({super.key, this.entryId});

  @override
  ConsumerState<DiaryFormScreen> createState() => _DiaryFormScreenState();
}

class _DiaryFormScreenState extends ConsumerState<DiaryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isDirty = false;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late final TextEditingController _correctedContentCtrl;
  late final TextEditingController _commentsCtrl;
  String? _selectedMood;
  DateTime? _originalCreatedAt;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.entryId != null;
    _titleCtrl = TextEditingController();
    _contentCtrl = TextEditingController();
    _correctedContentCtrl = TextEditingController();
    _commentsCtrl = TextEditingController();

    if (_isEditing) {
      _isLoading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadEntry());
    }
  }

  Future<void> _loadEntry() async {
    try {
      final entry = await ref.read(diaryDetailProvider(widget.entryId!).future);
      if (entry == null || !mounted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entrada não encontrada.')));
          context.go('/diary');
        }
        return;
      }
      setState(() {
        _isLoading = false;
        _titleCtrl.text = entry.title;
        _contentCtrl.text = entry.content;
        _correctedContentCtrl.text = entry.correctedContent ?? '';
        _commentsCtrl.text = entry.comments ?? '';
        _selectedMood = entry.mood;
        _originalCreatedAt = entry.createdAt;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao carregar a entrada.')));
      context.go('/diary');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _correctedContentCtrl.dispose();
    _commentsCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleBack() async {
    if (!_isDirty) {
      context.go('/diary');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. If you go back, all data will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.go('/diary');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final now = DateTime.now();

    final entry = DiaryEntry(
      id: widget.entryId,
      title: _titleCtrl.text.trim(),
      content: _contentCtrl.text.trim(),
      correctedContent: _correctedContentCtrl.text.trim().isEmpty ? null : _correctedContentCtrl.text.trim(),
      comments: _commentsCtrl.text.trim().isEmpty ? null : _commentsCtrl.text.trim(),
      mood: _selectedMood,
      createdAt: _originalCreatedAt ?? now,
      updatedAt: now,
    );

    try {
      if (_isEditing) {
        await ref.read(diaryListProvider.notifier).updateEntry(entry);
      } else {
        await ref.read(diaryListProvider.notifier).addEntry(entry);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEditing ? 'Entrada atualizada com sucesso!' : 'Entrada salva com sucesso!'),
        backgroundColor: AppTheme.secondary,
      ));
      context.go('/diary');
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Entry' : 'New Entry'),
        leading: BackButton(onPressed: _handleBack),
      ),
      body: Form(
        key: _formKey,
        onChanged: () {
          if (!_isDirty) setState(() => _isDirty = true);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleCtrl,
              validator: (v) => v == null || v.trim().isEmpty ? 'Campo obrigatório' : null,
              decoration: const InputDecoration(labelText: 'Title'),
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'How are you feeling?',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _moods.map((m) {
                  final selected = _selectedMood == m;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedMood = m),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.secondary.withValues(alpha: 0.2) : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? AppTheme.secondary : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: Center(child: Text(m, style: const TextStyle(fontSize: 22))),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentCtrl,
              validator: (v) => v == null || v.trim().isEmpty ? 'Campo obrigatório' : null,
              decoration: const InputDecoration(
                labelText: 'Write about your day...',
                alignLabelWithHint: true,
              ),
              maxLines: 15,
              style: GoogleFonts.nunito(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _correctedContentCtrl,
              decoration: const InputDecoration(
                labelText: 'Corrected version (Optional)',
                alignLabelWithHint: true,
              ),
              maxLines: 10,
              style: GoogleFonts.nunito(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _commentsCtrl,
              decoration: const InputDecoration(
                labelText: 'AI Comments/Feedback (Optional)',
                alignLabelWithHint: true,
              ),
              maxLines: 8,
              style: GoogleFonts.nunito(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary),
              child: _isLoading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Entry'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
    );
  }
}
