import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/study_session.dart';
import '../../providers/study_session_provider.dart';
import '../../core/theme/app_theme.dart';

class StudySessionForm extends ConsumerStatefulWidget {
  final StudySession? initialSession;
  const StudySessionForm({super.key, this.initialSession});

  @override
  ConsumerState<StudySessionForm> createState() => _StudySessionFormState();
}

class _StudySessionFormState extends ConsumerState<StudySessionForm> {
  late StudyType? _selectedType;
  late TimeOfDay? _selectedDuration;
  late final TextEditingController _activityController;
  late DateTime _selectedDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.initialSession;
    _selectedType = s?.type;
    _selectedDuration = s != null
        ? TimeOfDay(
            hour: s.durationMinutes ~/ 60,
            minute: s.durationMinutes % 60,
          )
        : null;
    _selectedDate = s != null ? DateTime.parse(s.date) : DateTime.now();
    _activityController = TextEditingController(text: s?.activity ?? '');
  }

  @override
  void dispose() {
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

  String _formatDuration(TimeOfDay t) {
    if (t.hour == 0) return '${t.minute}m';
    if (t.minute == 0) return '${t.hour}h';
    return '${t.hour}h ${t.minute}m';
  }

  Future<void> _pickDuration() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedDuration ?? const TimeOfDay(hour: 0, minute: 30),
      helpText: 'Select duration',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDuration = picked);
  }

  Future<void> _save() async {
    final type = _selectedType;
    final d = _selectedDuration;
    final minutes = d != null ? d.hour * 60 + d.minute : 0;
    if (type == null || d == null || minutes <= 0) return;

    setState(() => _saving = true);
    try {
      final session = StudySession(
        id: widget.initialSession?.id,
        type: type,
        durationMinutes: minutes,
        date: '${_selectedDate.year}-'
            '${_selectedDate.month.toString().padLeft(2, '0')}-'
            '${_selectedDate.day.toString().padLeft(2, '0')}',
        activity: _activityController.text.trim().isEmpty
            ? null
            : _activityController.text.trim(),
        createdAt: widget.initialSession?.createdAt ?? DateTime.now(),
      );
      if (widget.initialSession != null) {
        await ref
            .read(studySessionListProvider.notifier)
            .updateSession(session);
      } else {
        await ref.read(studySessionListProvider.notifier).addSession(session);
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialSession != null;
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
            isEdit ? 'Edit Session' : 'Register Study',
            style:
                GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900),
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
          InkWell(
            onTap: _pickDuration,
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Duration',
                labelStyle: GoogleFonts.nunito(),
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.timer_rounded),
              ),
              child: Text(
                _selectedDuration != null
                    ? _formatDuration(_selectedDuration!)
                    : 'Tap to select',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  color: _selectedDuration != null
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
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
