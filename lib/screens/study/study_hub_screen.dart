import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/study_content_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/study_content.dart';

class StudyHubScreen extends StatefulWidget {
  const StudyHubScreen({super.key});

  @override
  State<StudyHubScreen> createState() => _StudyHubScreenState();
}

class _StudyHubScreenState extends State<StudyHubScreen> {
  final _api = StudyContentApiService();
  List<StudyContent> _contents = [];
  final Map<int, Set<String>> _completedParts = {};
  final Map<String, Set<int>> _completedSessionItems = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final contents = await _api.list();
      final preferences = await SharedPreferences.getInstance();
      final completedParts = <int, Set<String>>{};
      for (final content in contents) {
        final due = content.studyNextReviewAt == null ||
            !content.studyNextReviewAt!.isAfter(DateTime.now());
        if (due && content.studyInterval > 0) {
          await preferences.remove(_progressKey(content.id));
        }
        completedParts[content.id] =
            (preferences.getStringList(_progressKey(content.id)) ?? []).toSet();
      }
      final completedSessionItems = <String, Set<int>>{};
      for (final type in ['all', 'summaries', 'flashcards', 'questions']) {
        completedSessionItems[type] =
            (preferences.getStringList('study-session-$type-v1-completed') ??
                    [])
                .map(int.tryParse)
                .whereType<int>()
                .toSet();
      }
      if (mounted) {
        setState(() {
          _completedParts
            ..clear()
            ..addAll(completedParts);
          _completedSessionItems
            ..clear()
            ..addAll(completedSessionItems);
          _contents = contents.where(_hasPendingContent).toList();
        });
      }
    } on StudyContentApiException catch (error) {
      if (mounted) setState(() => _error = error.code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _summaryCount =>
      _contents.where((item) => _partPending(item, 'summaries')).length;
  int get _flashcardCount => _contents.fold(
      0,
      (sum, item) =>
          sum +
          (_partPending(item, 'flashcards') ? item.flashcards.length : 0));
  int get _questionCount => _contents.fold(
      0,
      (sum, item) =>
          sum + (_partPending(item, 'questions') ? item.questions.length : 0));

  String _progressKey(int contentId) => 'study-content-progress-v1-$contentId';

  bool _partAvailable(StudyContent content, String type) => switch (type) {
        'summaries' => content.summary?.trim().isNotEmpty ?? false,
        'flashcards' => content.flashcards.isNotEmpty,
        'questions' => content.questions.isNotEmpty,
        _ => true,
      };

  bool _partPending(StudyContent content, String type) {
    if (!_partAvailable(content, type)) return false;
    if (_completedParts[content.id]?.contains(type) ?? false) return false;
    if (_completedSessionItems[type]?.contains(content.id) ?? false)
      return false;
    if (type != 'all' &&
        (_completedSessionItems['all']?.contains(content.id) ?? false)) {
      return false;
    }
    return true;
  }

  bool _hasPendingContent(StudyContent content) => [
        'summaries',
        'flashcards',
        'questions'
      ].any((type) => _partPending(content, type));

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && context.mounted) context.go('/areas');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Estudar'),
          leading: IconButton(
            tooltip: 'Voltar para áreas de estudo',
            onPressed: () => context.go('/areas'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          actions: [
            IconButton(
              tooltip: 'Cadernos de revisão',
              onPressed: () => context.push('/summary-notebooks'),
              icon: const Icon(Icons.menu_book_rounded),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? ListView(children: const [
                  SizedBox(
                      height: 280,
                      child: Center(child: CircularProgressIndicator()))
                ])
              : ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    if (_error != null) ...[
                      Text('Não foi possível carregar: $_error'),
                      const SizedBox(height: 16),
                    ],
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                  _summaryCount +
                                              _flashcardCount +
                                              _questionCount ==
                                          0
                                      ? Icons.task_alt_rounded
                                      : Icons.play_circle_fill_rounded,
                                  size: 42,
                                  color: _summaryCount +
                                              _flashcardCount +
                                              _questionCount ==
                                          0
                                      ? AppTheme.primary
                                      : Theme.of(context).colorScheme.primary),
                              const SizedBox(height: 10),
                              Text(
                                  _summaryCount +
                                              _flashcardCount +
                                              _questionCount ==
                                          0
                                      ? 'Estudo do dia concluído'
                                      : 'Revisões disponíveis',
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900)),
                              const SizedBox(height: 5),
                              Text(
                                  _summaryCount +
                                              _flashcardCount +
                                              _questionCount ==
                                          0
                                      ? 'Você concluiu todos os conteúdos planejados.'
                                      : 'Escolha o tipo de conteúdo para começar.',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                              const SizedBox(height: 16),
                              if (_summaryCount +
                                      _flashcardCount +
                                      _questionCount ==
                                  0)
                                Text('Estudo do dia concluído!',
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800))
                              else
                                Wrap(spacing: 8, runSpacing: 8, children: [
                                  if (_summaryCount > 0)
                                    _studyBadge('Resumos', _summaryCount,
                                        Icons.notes_rounded),
                                  if (_flashcardCount > 0)
                                    _studyBadge('Flashcards', _flashcardCount,
                                        Icons.style_rounded),
                                  if (_questionCount > 0)
                                    _studyBadge('Questões', _questionCount,
                                        Icons.quiz_rounded),
                                ]),
                            ]),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('Conteúdos por material',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    if (_contents.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(child: Text('Nenhum material pendente.')),
                      )
                    else
                      ..._contents
                          .map((content) => _ContentTile(content: content)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _studyBadge(String label, int count, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: .14),
          border: Border.all(color: AppTheme.primary.withValues(alpha: .65)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 7),
          Text('$label · $count',
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _ContentTile extends StatelessWidget {
  final StudyContent content;
  const _ContentTile({required this.content});

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(content.materialTitle ?? content.title ?? 'Material'),
          subtitle: Text(
              '${content.disciplineName ?? 'Sem disciplina'} · ${content.topicName}'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push('/study/session'),
        ),
      );
}
