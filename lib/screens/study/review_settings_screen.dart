import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/review_settings_service.dart';
import '../../core/utils/sm2.dart';
import '../../models/review_settings.dart';

class ReviewSettingsScreen extends StatefulWidget {
  const ReviewSettingsScreen({super.key});

  @override
  State<ReviewSettingsScreen> createState() => _ReviewSettingsScreenState();
}

class _ReviewSettingsScreenState extends State<ReviewSettingsScreen> {
  final _service = ReviewSettingsService();
  ReviewSettings _settings = const ReviewSettings();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _service.load();
    if (mounted)
      setState(() {
        _settings = settings;
        _loading = false;
      });
  }

  Future<void> _save(ReviewSettings settings) async {
    setState(() {
      _settings = settings;
      _saving = true;
    });
    try {
      await _service.save(settings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuração de revisão salva.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: _settings.notificationHour,
          minute: _settings.notificationMinute),
    );
    if (time != null) {
      await _save(_settings.copyWith(
          notificationHour: time.hour, notificationMinute: time.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final time = TimeOfDay(
        hour: _settings.notificationHour, minute: _settings.notificationMinute);
    return Scaffold(
      appBar: AppBar(title: const Text('Configuração da revisão')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: SwitchListTile.adaptive(
              value: _settings.notificationsEnabled,
              onChanged: _saving
                  ? null
                  : (value) =>
                      _save(_settings.copyWith(notificationsEnabled: value)),
              title: const Text('Notificar revisões',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text(
                  'Receba um lembrete diário para revisar cards e questões.'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              enabled: _settings.notificationsEnabled,
              leading: const Icon(Icons.alarm_rounded),
              title: const Text('Horário do lembrete'),
              subtitle: Text(time.format(context)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _settings.notificationsEnabled ? _chooseTime : null,
            ),
          ),
          const SizedBox(height: 20),
          const Text('O que revisar no lembrete',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _modeTile('due', 'Pendentes',
                    'Cards e questões que vencem hoje.', Icons.today_rounded),
                _modeTile(
                    'difficult',
                    'Difíceis',
                    'Itens marcados como difíceis.',
                    Icons.warning_amber_rounded),
                _modeTile(
                    'all',
                    'Todos',
                    'Uma revisão completa dos itens disponíveis.',
                    Icons.style_rounded),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Revisão espaçada',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('O próximo período depende da sua resposta:'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: spacedReviewIntervals
                        .map((days) => Chip(label: Text('${days}d')))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                      'Errei reinicia em 24h; Difícil repete; Bom avança; Fácil pula um período.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => context.push('/review-plan'),
            icon: const Icon(Icons.calendar_today_rounded),
            label: const Text('Ver plano de revisão de hoje'),
          ),
        ],
      ),
    );
  }

  Widget _modeTile(String value, String title, String subtitle, IconData icon) {
    return RadioListTile<String>(
      value: value,
      groupValue: _settings.reviewMode,
      onChanged: _saving
          ? null
          : (next) {
              if (next != null) _save(_settings.copyWith(reviewMode: next));
            },
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}
