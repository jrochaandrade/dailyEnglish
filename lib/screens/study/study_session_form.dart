import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/study_session.dart';
import '../../providers/study_session_provider.dart';
import '../../core/theme/app_theme.dart';

class StudySessionForm extends ConsumerStatefulWidget {
  const StudySessionForm({super.key});

  @override
  ConsumerState<StudySessionForm> createState() => _StudySessionFormState();
}

class _StudySessionFormState extends ConsumerState<StudySessionForm> {
  StudyType? _selectedType;
  final _durationController = TextEditingController();
  final _activityController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _durationController.dispose();
    _activityController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    final type = _selectedType;
    final minutes = int.tryParse(_durationController.text.trim());
    if (type == null || minutes == null || minutes <= 0) return;

    setState(() => _saving = true);
    try {
      final session = StudySession(
        type: type,
        durationMinutes: minutes,
        date:
            '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
        activity: _activityController.text.trim().isEmpty
            ? null
            : _activityController.text.trim(),
        createdAt: DateTime.now(),
      );
      await ref.read(studySessionListProvider.notifier).addSession(session);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Register Study',
            style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 20),
          Text('Study type',
              style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: StudyType.values.map((t) {
              final selected = _selectedType == t;
              return ChoiceChip(
                label: Text(t.label,
                    style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface)),
                selected: selected,
                selectedColor: AppTheme.primary,
                onSelected: (_) => setState(() => _selectedType = t),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _durationController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Duration (minutes)',
              labelStyle: GoogleFonts.nunito(),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date',
                labelStyle: GoogleFonts.nunito(),
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.calendar_today_rounded),
              ),
              child: Text(_formatDate(_selectedDate),
                  style: GoogleFonts.nunito(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _activityController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'What did you do? (optional)',
              hintText: 'e.g. Netflix series, News article, Language exchange',
              labelStyle: GoogleFonts.nunito(),
              hintStyle: GoogleFonts.nunito(fontSize: 13),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('Save',
                      style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
