import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/study_content_api_service.dart';
import '../../models/study_content.dart';

class StudySessionScreen extends StatefulWidget {
  final String? type;
  const StudySessionScreen({super.key, this.type});

  @override
  State<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends State<StudySessionScreen> {
  final _api = StudyContentApiService();
  List<StudyContent> _contents = [];
  Set<int> _completed = {};
  Timer? _timer;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  bool _paused = false;
  bool _loading = true;
  String? _error;

  String get _key => 'study-session-${widget.type ?? 'all'}-v1';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final started = preferences.getString('${_key}-started');
      final savedIds = preferences.getStringList('${_key}-completed') ?? [];
      final savedElapsed = preferences.getInt('${_key}-elapsed') ?? 0;
      final contents = await _api.list();
      if (!mounted) return;
      setState(() {
        _contents = contents.where(_matchesType).toList();
        _completed = savedIds.map(int.tryParse).whereType<int>().toSet();
        _elapsed = Duration(seconds: savedElapsed);
        _startedAt =
            started == null ? DateTime.now() : DateTime.tryParse(started);
        _paused = preferences.getBool('${_key}-paused') ?? false;
        _loading = false;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && !_paused) setState(() {});
      });
      await _save();
    } on StudyContentApiException catch (error) {
      if (mounted)
        setState(() {
          _error = error.code;
          _loading = false;
        });
    }
  }

  bool _matchesType(StudyContent content) => switch (widget.type) {
        'summaries' => content.summary?.trim().isNotEmpty ?? false,
        'flashcards' => content.flashcards.isNotEmpty,
        'questions' => content.questions.isNotEmpty,
        _ => true,
      };

  Duration get _currentElapsed =>
      _elapsed +
      ((!_paused && _startedAt != null)
          ? DateTime.now().difference(_startedAt!)
          : Duration.zero);

  Future<void> _save() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
        '${_key}-started', (_startedAt ?? DateTime.now()).toIso8601String());
    await preferences.setInt('${_key}-elapsed', _currentElapsed.inSeconds);
    await preferences.setBool('${_key}-paused', _paused);
    await preferences.setStringList(
        '${_key}-completed', _completed.map((id) => '$id').toList());
  }

  Future<void> _togglePause() async {
    if (!_paused && _startedAt != null) _elapsed = _currentElapsed;
    _startedAt = _paused ? DateTime.now() : null;
    setState(() => _paused = !_paused);
    await _save();
  }

  Future<void> _toggleComplete(int id) async {
    setState(() =>
        _completed.contains(id) ? _completed.remove(id) : _completed.add(id));
    await _save();
  }

  Future<void> _finish() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Concluir sessão?'),
        content: const Text(
            'Os itens serão considerados estudados e você poderá revisá-los no próximo ciclo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continuar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Concluir')),
        ],
      ),
    );
    if (confirmed != true) return;
    final preferences = await SharedPreferences.getInstance();
    for (final suffix in ['started', 'elapsed', 'paused', 'completed']) {
      await preferences.remove('${_key}-$suffix');
    }
    if (mounted) context.go('/study');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _save();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _currentElapsed;
    final title = switch (widget.type) {
      'summaries' => 'Estudar resumos',
      'flashcards' => 'Estudar flashcards',
      'questions' => 'Estudar questões',
      _ => 'Sessão de estudo',
    };
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: [
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
                child: Text(_format(elapsed),
                    style: const TextStyle(fontWeight: FontWeight.w800)))),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Não foi possível carregar: $_error'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    Row(children: [
                      Expanded(
                          child: Text(
                              '${_completed.length} de ${_contents.length} concluídos',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800))),
                      TextButton.icon(
                          onPressed: _togglePause,
                          icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                          label: Text(_paused ? 'Continuar' : 'Pausar')),
                      FilledButton(
                          onPressed: _finish, child: const Text('Concluir'))
                    ]),
                    const SizedBox(height: 12),
                    ..._groupedContents(),
                  ]),
                ),
    );
  }

  List<Widget> _groupedContents() {
    final disciplines = <String, List<StudyContent>>{};
    for (final content in _contents) {
      disciplines
          .putIfAbsent(content.disciplineName ?? 'Sem disciplina', () => [])
          .add(content);
    }
    return disciplines.entries.map((discipline) {
      final topics = <String, List<StudyContent>>{};
      for (final content in discipline.value) {
        topics.putIfAbsent(content.topicName, () => []).add(content);
      }
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ExpansionTile(
          initiallyExpanded: true,
          title: Text(discipline.key,
              style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text('${discipline.value.length} material(is)'),
          children: topics.entries
              .map((topic) => ExpansionTile(
                    title: Text(topic.key,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${topic.value.length} material(is)'),
                    children: topic.value.map(_itemCard).toList(),
                  ))
              .toList(),
        ),
      );
    }).toList();
  }

  Widget _itemCard(StudyContent content) => Card(
        margin: const EdgeInsets.only(bottom: 14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(
                      content.materialTitle ?? content.title ?? 'Conteúdo',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900))),
              Checkbox(
                  value: _completed.contains(content.id),
                  onChanged: (_) => _toggleComplete(content.id))
            ]),
            Text(
                '${content.disciplineName ?? 'Sem disciplina'} · ${content.topicName}',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (content.summary?.trim().isNotEmpty ?? false)
                OutlinedButton.icon(
                    onPressed: () => _showSummary(content),
                    icon: const Icon(Icons.notes_rounded),
                    label: const Text('Ver resumo')),
              if (content.flashcards.isNotEmpty)
                OutlinedButton.icon(
                    onPressed: () => context.push(
                        '/study-content?type=flashcards&content_id=${content.id}'),
                    icon: const Icon(Icons.style_rounded),
                    label: Text(
                        'Estudar flashcards (${content.flashcards.length})')),
              if (content.questions.isNotEmpty)
                FilledButton.icon(
                    onPressed: () =>
                        context.push('/study-content?type=questions'),
                    icon: const Icon(Icons.quiz_rounded),
                    label:
                        Text('Iniciar questões (${content.questions.length})')),
            ]),
          ]),
        ),
      );

  Future<void> _showSummary(StudyContent content) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Resumo — ${content.materialTitle ?? 'Material'}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: (content.summary ?? '')
                  .split(RegExp(r'\n\s*\n'))
                  .where((paragraph) => paragraph.trim().isNotEmpty)
                  .map((paragraph) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          '    ${paragraph.trim()}',
                          textAlign: TextAlign.justify,
                          style: const TextStyle(height: 1.65),
                        ),
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'))
          ],
        ),
      );

  String _format(Duration value) =>
      '${value.inHours.toString().padLeft(2, '0')}:${(value.inMinutes % 60).toString().padLeft(2, '0')}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
}
