import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/mock_test.dart';
import '../../providers/mock_test_provider.dart';
import '../../core/theme/app_theme.dart';

class MockTestForm extends ConsumerStatefulWidget {
  const MockTestForm({super.key});

  @override
  ConsumerState<MockTestForm> createState() => _MockTestFormState();
}

class _MockTestFormState extends ConsumerState<MockTestForm> {
  DateTime _selectedDate = DateTime.now();
  double? _listening;
  double? _reading;
  double? _writing;
  double? _speaking;
  bool _saving = false;

  static final List<double> _bands = [
    for (int i = 0; i <= 18; i++) i * 0.5,
  ];

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
    final l = _listening;
    final r = _reading;
    final w = _writing;
    final s = _speaking;
    if (l == null || r == null || w == null || s == null) return;

    setState(() => _saving = true);
    try {
      final targets = await ref.read(mockTestTargetsProvider.future);
      final reachedTarget = targets.isReached(l, r, w, s);

      final test = MockTest(
        date: '${_selectedDate.year}-'
            '${_selectedDate.month.toString().padLeft(2, '0')}-'
            '${_selectedDate.day.toString().padLeft(2, '0')}',
        listeningScore: l,
        readingScore: r,
        writingScore: w,
        speakingScore: s,
        reachedTarget: reachedTarget,
        createdAt: DateTime.now(),
      );
      await ref.read(mockTestListProvider.notifier).addTest(test);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _scoreDropdown(
      String label, double? value, ValueChanged<double?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        DropdownButtonFormField<double>(
          initialValue: value,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
          ),
          hint: Text('Select', style: GoogleFonts.nunito(fontSize: 14)),
          items: _bands
              .map((b) => DropdownMenuItem(
                    value: b,
                    child: Text(b.toStringAsFixed(1),
                        style: GoogleFonts.nunito(fontSize: 14)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
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
          Text('Add Mock Test',
              style: GoogleFonts.nunito(
                  fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
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
          Row(
            children: [
              Expanded(
                child: _scoreDropdown('Listening', _listening,
                    (v) => setState(() => _listening = v)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _scoreDropdown(
                    'Reading', _reading, (v) => setState(() => _reading = v)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _scoreDropdown(
                    'Writing', _writing, (v) => setState(() => _writing = v)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _scoreDropdown('Speaking', _speaking,
                    (v) => setState(() => _speaking = v)),
              ),
            ],
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
