import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/mock_test_targets.dart';
import '../../providers/mock_test_provider.dart';
import '../../core/theme/app_theme.dart';

class MockTargetsSheet extends ConsumerStatefulWidget {
  const MockTargetsSheet({super.key});

  @override
  ConsumerState<MockTargetsSheet> createState() => _MockTargetsSheetState();
}

class _MockTargetsSheetState extends ConsumerState<MockTargetsSheet> {
  double? _overall;
  double? _listening;
  double? _reading;
  double? _writing;
  double? _speaking;
  bool _saving = false;

  static final List<double> _bands = [
    for (int i = 0; i <= 18; i++) i * 0.5,
  ];

  @override
  void initState() {
    super.initState();
    final current = ref.read(mockTestTargetsProvider).valueOrNull;
    if (current != null) {
      _overall = current.overallTarget;
      _listening = current.listeningMin;
      _reading = current.readingMin;
      _writing = current.writingMin;
      _speaking = current.speakingMin;
    }
  }

  Future<void> _save() async {
    final o = _overall;
    final l = _listening;
    final r = _reading;
    final w = _writing;
    final s = _speaking;
    if (o == null || l == null || r == null || w == null || s == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(mockTestTargetsProvider.notifier).updateTargets(
            MockTestTargets(
              overallTarget: o,
              listeningMin: l,
              readingMin: r,
              writingMin: w,
              speakingMin: s,
            ),
          );
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
        Text(
          label,
          style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
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
          Text('Mock Test Targets',
              style:
                  GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          _scoreDropdown(
              'Overall Target', _overall, (v) => setState(() => _overall = v)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _scoreDropdown('Listening Min', _listening,
                    (v) => setState(() => _listening = v)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _scoreDropdown('Reading Min', _reading,
                    (v) => setState(() => _reading = v)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _scoreDropdown('Writing Min', _writing,
                    (v) => setState(() => _writing = v)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _scoreDropdown('Speaking Min', _speaking,
                    (v) => setState(() => _speaking = v)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ||
                      [_overall, _listening, _reading, _writing, _speaking]
                          .any((v) => v == null)
                  ? null
                  : _save,
              style:
                  FilledButton.styleFrom(backgroundColor: AppTheme.primary),
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
