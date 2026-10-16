import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/study_content_api_service.dart';
import '../../core/services/mind_map_viewer.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/markdown_text.dart';
import '../../models/study_content.dart';
import '../../models/contest_card.dart';
import '../../repositories/contest_card_repository.dart';
import '../../core/services/offline_study_service.dart';

class StudySessionScreen extends StatefulWidget {
  final String? type;
  final int? contentId;
  final bool returnToConcursos;

  const StudySessionScreen({
    super.key,
    this.type,
    this.contentId,
    this.returnToConcursos = false,
  });

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

  String get _key =>
      'study-session-${widget.type ?? 'all'}-${widget.contentId ?? 'all'}-v2';

  String get _studyPath =>
      widget.returnToConcursos ? '/study?return=concursos' : '/study';

  @override
  void initState() {
    super.initState();
    _load(remote: false);
  }

  Future<void> _load({bool remote = false}) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedIds = preferences.getStringList('${_key}-completed') ?? [];
      final completedIds = savedIds.map(int.tryParse).whereType<int>().toSet();
      final savedElapsed = preferences.getInt('${_key}-elapsed') ?? 0;
      List<StudyContent> fetchedContents =
          remote ? await _api.list() : await _api.cachedList();
      if (!remote && fetchedContents.isEmpty) {
        fetchedContents = await _api.list();
      }
      final contents = widget.contentId == null
          ? fetchedContents
          : fetchedContents
              .where((content) => content.id == widget.contentId)
              .toList();
      final progress = <int, Set<String>>{};
      final syncFailedIds = <int>{};
      for (final content in contents) {
        if (content.isDue && content.studyInterval > 0) {
          await preferences.remove(_progressKey(content.id));
          completedIds.remove(content.id);
        }
        progress[content.id] =
            (preferences.getStringList(_progressKey(content.id)) ?? []).toSet();
        if (content.studyInterval == 0 &&
            (completedIds.contains(content.id) ||
                _isFullyCompleted(content, progress[content.id]))) {
          try {
            await _api.completeStudyContent(content.id);
          } on StudyContentApiException {
            completedIds.remove(content.id);
            syncFailedIds.add(content.id);
          }
        }
      }
      if (!mounted) return;
      final sessionContents = contents.where(_matchesType).toList();
      for (final content in sessionContents) {
        final parts = progress[content.id] ?? <String>{};
        if (!syncFailedIds.contains(content.id) &&
            _isCompletedForSession(content, parts)) {
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
        // Leaving a session stores its elapsed time and pauses it. Opening it
        // again starts counting immediately from the saved elapsed duration.
        _elapsed = Duration(seconds: savedElapsed);
        _startedAt = DateTime.now();
        _paused = false;
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

  Future<void> _save({bool? paused}) async {
    final preferences = await SharedPreferences.getInstance();
    final savePaused = paused ?? _paused;
    final elapsed = _currentElapsed;
    await preferences.setInt('${_key}-elapsed', elapsed.inSeconds);
    await preferences.setBool('${_key}-paused', savePaused);
    if (savePaused) {
      await preferences.remove('${_key}-started');
    } else {
      await preferences.setString(
          '${_key}-started', DateTime.now().toIso8601String());
    }
    await preferences.setStringList(
        '${_key}-completed', _completed.map((id) => '$id').toList());
  }

  Future<void> _togglePause() async {
    if (!_paused && _startedAt != null) _elapsed = _currentElapsed;
    _paused = !_paused;
    _startedAt = _paused ? null : DateTime.now();
    setState(() {});
    await _save();
  }

  Future<void> _toggleComplete(int id) async {
    if (!_completed.contains(id)) {
      final content = _contents.where((item) => item.id == id).firstOrNull;
      if (content == null || !await _syncCompletion(content)) return;
    }

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

  Future<bool> _syncCompletion(StudyContent content) async {
    try {
      await _api.completeStudyContent(content.id);
      return true;
    } on StudyContentApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Não foi possível sincronizar a conclusão: ${error.code}'),
        ));
      }
      return false;
    }
  }

  String _progressKey(int contentId) => 'study-content-progress-v1-$contentId';

  Set<String> _availableParts(StudyContent content) => {
        if (content.hasMindMap) 'mind_map',
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
      if (!await _syncCompletion(content)) return;
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

    final durationSeconds = _currentElapsed.inSeconds;

    final pendingContents = List<StudyContent>.from(_contents);
    for (final content in pendingContents) {
      if (!await _syncCompletion(content)) return;
      if (!mounted) return;
      setState(() {
        _completed.add(content.id);
        _completedSomething = true;
        _contents.removeWhere((item) => item.id == content.id);
        if (!_completedContents.any((item) => item.id == content.id)) {
          _completedContents.add(content);
        }
      });
      await _save();
    }

    final offlineStudy = OfflineStudyService();
    await offlineStudy.recordTimeLog(
      generatedContentId: widget.contentId,
      durationSeconds: durationSeconds,
    );
    await offlineStudy.syncPendingTimeLogs();

    final preferences = await SharedPreferences.getInstance();
    for (final suffix in ['started', 'elapsed', 'paused', 'completed']) {
      await preferences.remove('${_key}-$suffix');
    }
    if (mounted) context.go(_studyPath);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _save(paused: true);
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
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && mounted) context.go(_studyPath);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            onPressed: () => context.go(_studyPath),
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
                    onRefresh: () => _load(remote: true),
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
            onPressed: () => context.go(_studyPath),
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
            LayoutBuilder(builder: (context, constraints) {
              final buttonWidth = (constraints.maxWidth - 8) / 2;
              return Wrap(spacing: 8, runSpacing: 8, children: [
                if (content.hasMindMap)
                  SizedBox(
                    width: buttonWidth,
                    child: _partButton(
                      content: content,
                      part: 'mind_map',
                      label: 'Mapa Mental',
                      icon: Icons.account_tree_outlined,
                      onPressed: () async {
                        await MindMapViewer.open(context, content);
                        if (mounted) {
                          await _markPartCompleted(content, 'mind_map');
                        }
                      },
                    ),
                  ),
                if (content.summary?.trim().isNotEmpty ?? false)
                  SizedBox(
                    width: buttonWidth,
                    child: _partButton(
                      content: content,
                      part: 'summaries',
                      label: 'Resumo',
                      icon: Icons.notes_rounded,
                      onPressed: () async {
                        await _showSummary(content);
                        if (mounted) {
                          await _markPartCompleted(content, 'summaries');
                        }
                      },
                    ),
                  ),
                if (content.flashcards.isNotEmpty)
                  SizedBox(
                    width: buttonWidth,
                    child: _partButton(
                      content: content,
                      part: 'flashcards',
                      label: 'Flashcards (${content.flashcards.length})',
                      icon: Icons.style_rounded,
                      onPressed: () async {
                        final completed = await _openFlashcards(content);
                        if (completed && mounted) {
                          await _markPartCompleted(content, 'flashcards');
                        }
                      },
                    ),
                  ),
                if (content.questions.isNotEmpty)
                  SizedBox(
                    width: buttonWidth,
                    child: _partButton(
                      content: content,
                      part: 'questions',
                      label: 'Questões (${content.questions.length})',
                      icon: Icons.quiz_rounded,
                      onPressed: () async {
                        final completed = await context.push<bool>(
                            '/study-content?type=questions&content_id=${content.id}');
                        if (completed == true && mounted) {
                          await _markPartCompleted(content, 'questions');
                        }
                      },
                    ),
                  ),
              ]);
            }),
          ]),
        ),
      );

  Widget _partButton({
    required StudyContent content,
    required String part,
    required String label,
    required IconData icon,
    required Future<void> Function() onPressed,
  }) {
    final completed = _completedParts[content.id]?.contains(part) ?? false;
    final scheme = Theme.of(context).colorScheme;
    final buttonStyle = completed
        ? FilledButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: scheme.primary,
            side: BorderSide(color: scheme.primary.withValues(alpha: .7)),
            minimumSize: const Size.fromHeight(48),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          );

    return completed
        ? FilledButton.icon(
            onPressed: () {},
            style: buttonStyle,
            icon: const Icon(Icons.check_rounded),
            label: Text(label, overflow: TextOverflow.ellipsis),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: buttonStyle,
            icon: Icon(icon),
            label: Text(label, overflow: TextOverflow.ellipsis),
          );
  }

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

  Future<bool> _openFlashcards(StudyContent content) async {
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
    if (!mounted) return false;
    final query = Uri(queryParameters: {
      'mode': 'all',
      'subject': content.disciplineName ?? 'Concursos',
      'deck': content.topicName,
      'source': source,
    }).query;
    final completed = await context.push<bool>('/concursos/review?$query');
    return completed == true;
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
            if (content.hasMindMap)
              TextButton.icon(
                  onPressed: () => MindMapViewer.open(context, content),
                  icon: const Icon(Icons.account_tree_outlined),
                  label: const Text('Mapa mental')),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'))
          ],
        ),
      );

  String _format(Duration value) =>
      '${value.inHours.toString().padLeft(2, '0')}:${(value.inMinutes % 60).toString().padLeft(2, '0')}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
}
