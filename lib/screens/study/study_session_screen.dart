import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/study_content_api_service.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/markdown_text.dart';
import '../../models/study_content.dart';
import '../../models/contest_card.dart';
import '../../repositories/contest_card_repository.dart';

class StudySessionScreen extends StatefulWidget {
  final String? type;
  const StudySessionScreen({super.key, this.type});

  @override
  State<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends State<StudySessionScreen> {
  final _api = StudyContentApiService();
  List<StudyContent> _contents = [];
  List<StudyContent> _completedContents = [];
  Set<int> _completed = {};
  final Map<int, Set<String>> _completedParts = {};
  bool _completedSomething = false;
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
      final progress = <int, Set<String>>{};
      for (final content in contents) {
        final due = content.studyNextReviewAt == null ||
            !content.studyNextReviewAt!.isAfter(DateTime.now());
        if (due && content.studyInterval > 0) {
          await preferences.remove(_progressKey(content.id));
        }
        progress[content.id] =
            (preferences.getStringList(_progressKey(content.id)) ?? []).toSet();
        if (content.studyInterval == 0 &&
            _isFullyCompleted(content, progress[content.id])) {
          try {
            await _api.completeStudyContent(content.id);
          } on StudyContentApiException {
            // Retry on the next refresh if the server is temporarily offline.
          }
        }
      }
      if (!mounted) return;
      final sessionContents = contents.where(_matchesType).toList();
      final completedIds = savedIds.map(int.tryParse).whereType<int>().toSet();
      for (final content in sessionContents) {
        final parts = progress[content.id] ?? <String>{};
        if (_isCompletedForSession(content, parts)) {
          completedIds.add(content.id);
        }
      }
      final completedContents = sessionContents
          .where((content) => completedIds.contains(content.id))
          .toList();
      sessionContents
          .removeWhere((content) => completedIds.contains(content.id));
      setState(() {
        _contents = sessionContents;
        _completedContents = completedContents;
        _completed = completedIds;
        _completedSomething = completedIds.isNotEmpty;
        _completedParts
          ..clear()
          ..addAll(progress);
        for (final content in _contents) {
          if (_isFullyCompleted(content)) _completed.add(content.id);
        }
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
    setState(() {
      if (_completed.contains(id)) {
        _completed.remove(id);
        final completedContent =
            _completedContents.where((content) => content.id == id).firstOrNull;
        if (completedContent != null) {
          _completedContents.remove(completedContent);
          _contents.add(completedContent);
        }
      } else {
        _completed.add(id);
        _completedSomething = true;
        final content = _contents.where((item) => item.id == id).firstOrNull;
        if (content != null) {
          _contents.remove(content);
          _completedContents.add(content);
        }
      }
    });
    await _save();
  }

  String _progressKey(int contentId) => 'study-content-progress-v1-$contentId';

  Set<String> _availableParts(StudyContent content) => {
        if (content.summary?.trim().isNotEmpty ?? false) 'summaries',
        if (content.flashcards.isNotEmpty) 'flashcards',
        if (content.questions.isNotEmpty) 'questions',
      };

  bool _isFullyCompleted(StudyContent content, [Set<String>? parts]) {
    final available = _availableParts(content);
    if (available.isEmpty) return false;
    final completedParts = parts ?? _completedParts[content.id] ?? <String>{};
    return available.every(completedParts.contains);
  }

  bool _isCompletedForSession(StudyContent content, [Set<String>? parts]) {
    final completedParts = parts ?? _completedParts[content.id] ?? <String>{};
    if (widget.type != null) return completedParts.contains(widget.type);
    return _isFullyCompleted(content, completedParts);
  }

  Future<void> _markPartCompleted(StudyContent content, String part) async {
    final parts = _completedParts.putIfAbsent(content.id, () => <String>{});
    parts.add(part);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_progressKey(content.id), parts.toList());
    if (_isFullyCompleted(content, parts)) {
      try {
        await _api.completeStudyContent(content.id);
      } on StudyContentApiException {
        // Keep the local progress; the next refresh can retry the server sync.
      }
    }
    if (!mounted) return;
    setState(() {
      if (_isCompletedForSession(content)) {
        _completed.add(content.id);
        _completedSomething = true;
        _contents.removeWhere((item) => item.id == content.id);
        if (!_completedContents.any((item) => item.id == content.id)) {
          _completedContents.add(content);
        }
      }
    });
    await _save();
  }

  Future<void> _resetTimer() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Reiniciar cronômetro?'),
            content: const Text(
                'O tempo acumulado desta sessão será zerado. Os itens concluídos serão mantidos.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Reiniciar')),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() {
      _elapsed = Duration.zero;
      _startedAt = _paused ? null : DateTime.now();
    });
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
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && mounted) context.go('/study');
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/study'),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Voltar para Estudar',
          ),
          actions: [
            IconButton(
              onPressed: _resetTimer,
              icon: const Icon(Icons.restart_alt_rounded),
              tooltip: 'Reiniciar cronômetro',
            ),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                    child: Text(_format(elapsed),
                        style: const TextStyle(fontWeight: FontWeight.w800)))),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Não foi possível carregar: $_error'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _contents.isEmpty
                        ? _emptyState()
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                                Row(children: [
                                  Expanded(
                                      child: Text(
                                          '${_completedContents.length} de ${_contents.length + _completedContents.length} concluídos',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800))),
                                  TextButton.icon(
                                      onPressed: _togglePause,
                                      icon: Icon(_paused
                                          ? Icons.play_arrow
                                          : Icons.pause),
                                      label: Text(
                                          _paused ? 'Continuar' : 'Pausar')),
                                  FilledButton(
                                      onPressed: _finish,
                                      child: const Text('Concluir'))
                                ]),
                                const SizedBox(height: 12),
                                ..._groupedContents(),
                              ]),
                  ),
      ),
    );
  }

  Widget _emptyState() => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          Icon(
            _completedSomething
                ? Icons.task_alt_rounded
                : Icons.menu_book_outlined,
            size: 72,
          ),
          const SizedBox(height: 18),
          Text(
            _completedSomething
                ? 'Estudo do dia concluído!'
                : 'Nenhum conteúdo para estudar.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            _completedSomething
                ? 'Você concluiu todos os conteúdos planejados para esta sessão.'
                : 'Adicione conteúdos ao ciclo de estudos para começar.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.go('/study'),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Voltar para Estudar'),
          ),
        ],
      );

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
      final scheme = Theme.of(context).colorScheme;
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: .06),
          border: Border.all(color: scheme.primary.withValues(alpha: .48)),
          borderRadius: BorderRadius.circular(22),
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          backgroundColor: scheme.primary.withValues(alpha: .12),
          collapsedBackgroundColor: scheme.primary.withValues(alpha: .08),
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          title: Row(children: [
            Icon(Icons.school_outlined, size: 24, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DISCIPLINA',
                      style: TextStyle(
                          color: scheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1)),
                  Text(discipline.key,
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ]),
          subtitle: Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text('${discipline.value.length} material(is)'),
          ),
          children: topics.entries
              .map((topic) => Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: .35),
                        border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant
                                .withValues(alpha: .7)),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 2),
                        title: Row(children: [
                          Icon(Icons.folder_outlined,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('TÓPICO',
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: .9)),
                                Text(topic.key,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ]),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(left: 30),
                          child: Text('${topic.value.length} material(is)'),
                        ),
                        children: topic.value
                            .map((content) => Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(8, 0, 8, 10),
                                  child: _itemCard(content),
                                ))
                            .toList(),
                      ),
                    ),
                  ))
              .toList(),
        ),
      );
    }).toList();
  }

  Widget _itemCard(StudyContent content) => Card(
        margin: EdgeInsets.zero,
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.description_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                      content.materialTitle ?? content.title ?? 'Conteúdo',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900))),
              PopupMenuButton<String>(
                tooltip: 'Opções do conteúdo',
                onSelected: (value) =>
                    value == 'remove' ? _removeFromCycle(content) : null,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'remove',
                    child: Text('Remover do ciclo de estudos'),
                  ),
                ],
              ),
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
                    onPressed: () async {
                      await _showSummary(content);
                      if (mounted) {
                        await _markPartCompleted(content, 'summaries');
                      }
                    },
                    icon: const Icon(Icons.notes_rounded),
                    label: const Text('Ver resumo')),
              if (content.flashcards.isNotEmpty)
                OutlinedButton.icon(
                    onPressed: () async {
                      await _openFlashcards(content);
                      if (mounted) {
                        await _markPartCompleted(content, 'flashcards');
                      }
                    },
                    icon: const Icon(Icons.style_rounded),
                    label: Text(
                        'Estudar flashcards (${content.flashcards.length})')),
              if (content.questions.isNotEmpty)
                FilledButton.icon(
                    onPressed: () async {
                      final completed = await context.push<bool>(
                          '/study-content?type=questions&content_id=${content.id}');
                      if (completed == true && mounted) {
                        await _markPartCompleted(content, 'questions');
                      }
                    },
                    icon: const Icon(Icons.quiz_rounded),
                    label:
                        Text('Iniciar questões (${content.questions.length})')),
            ]),
          ]),
        ),
      );

  Future<void> _removeFromCycle(StudyContent content) async {
    try {
      await _api.setStudyEnabled(content.id, false);
      if (!mounted) return;
      setState(() {
        _contents.removeWhere((item) => item.id == content.id);
        _completed.remove(content.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Conteúdo removido do ciclo de estudos.')));
    } on StudyContentApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Não foi possível alterar: ${error.code}')));
      }
    }
  }

  Future<void> _openFlashcards(StudyContent content) async {
    final source = content.materialTitle ?? 'Material';
    final repository = ContestCardRepository(AppDatabase().database);
    final now = DateTime.now();
    for (final flashcard in content.flashcards) {
      final front = MarkdownText.plain(flashcard['question'] as String? ?? '');
      final back = MarkdownText.plain(flashcard['answer'] as String? ?? '');
      if (front.isEmpty || back.isEmpty) continue;
      await repository.upsertGenerated(ContestCard(
        subject: content.disciplineName ?? 'Concursos',
        deck: content.topicName,
        front: front,
        back: back,
        source: source,
        createdAt: now,
        updatedAt: now,
      ));
    }
    if (!mounted) return;
    final query = Uri(queryParameters: {
      'mode': 'all',
      'subject': content.disciplineName ?? 'Concursos',
      'deck': content.topicName,
      'source': source,
    }).query;
    await context.push('/concursos/review?$query');
  }

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
