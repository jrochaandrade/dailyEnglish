import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/study_content_api_service.dart';
import '../../core/database/app_database.dart';
import '../../models/study_content.dart';
import '../../models/contest_card.dart';
import '../../models/summary_notebook.dart';
import '../../repositories/contest_card_repository.dart';
import '../../core/utils/markdown_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/summary_notebook_api_service.dart';
import '../../core/services/generated_flashcard_sync_service.dart';

class StudyContentScreen extends StatefulWidget {
  final String? type;
  final int? contentId;

  const StudyContentScreen({super.key, this.type, this.contentId});

  @override
  State<StudyContentScreen> createState() => _StudyContentScreenState();
}

class _StudyContentScreenState extends State<StudyContentScreen> {
  final _api = StudyContentApiService();
  List<StudyContent> _contents = [];
  List<SummaryNotebook> _notebooks = [];
  List<ContestCard> _localReviewCards = [];
  String? _message;
  bool _loading = true;
  int _studyIndex = 0;
  String? _selectedAnswer;
  bool _questionAnswered = false;
  bool _questionAnswerRecorded = false;
  String _questionTopicFilter = '';
  String _questionDisciplineFilter = '';
  String _questionMaterialFilter = '';
  String _summaryDisciplineFilter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final includeAll = widget.type == 'flashcards' ||
          widget.type == 'questions' ||
          widget.type == 'summaries';
      final contents = widget.type == 'flashcards'
          ? await const GeneratedFlashcardSyncService().sync()
          : await _api.list(includeAll: includeAll);
      List<SummaryNotebook> notebooks = [];
      try {
        notebooks = await SummaryNotebookApiService().list();
      } on SummaryNotebookApiException {
        // A falha ao carregar os cadernos não impede a leitura dos resumos.
      }
      await _syncQuestionAnswers();
      if (widget.type != 'flashcards') {
        await _syncFlashcardsForReview(contents);
      }
      final localCards =
          await ContestCardRepository(AppDatabase().database).getAll();
      if (!mounted) return;
      setState(() {
        _contents = contents
            .where((content) => includeAll || content.studyEnabled)
            .where((content) =>
                widget.contentId == null || content.id == widget.contentId)
            .toList();
        _notebooks = notebooks;
        _localReviewCards = localCards;
        _message = null;
      });
    } on StudyContentApiException catch (error) {
      if (!mounted) return;
      setState(() => _message = error.code == 'auth_required'
          ? 'Faça login para acessar os conteúdos.'
          : 'Não foi possível carregar os conteúdos.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<QuestionAnswerResult?> _recordQuestionAnswer(
      Map<String, dynamic> question) async {
    if (_questionAnswerRecorded) return null;
    _questionAnswerRecorded = true;
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getStringList('question-performance-v1') ?? [];
    final item = <String, dynamic>{
      'generated_content_id': question['_contentId'],
      'item_index': question['_index'],
      'user_answer': question['_selectedAnswer'] ?? '',
      'answered_at': DateTime.now().toIso8601String(),
      'synced': false,
      'discipline': question['_discipline'] ?? 'Sem disciplina',
      'material': question['_material'] ?? 'Material',
    };
    QuestionAnswerResult? result;
    try {
      result = await _api.submitQuestionAnswer(
        generatedContentId: item['generated_content_id'] as int,
        itemIndex: item['item_index'] as int,
        userAnswer: item['user_answer'] as String,
        answeredAt: item['answered_at'] as String,
      );
      item['correct'] = result.isCorrect;
      item['synced'] = true;
    } on StudyContentApiException {
      _questionAnswerRecorded = false;
    } catch (_) {
      _questionAnswerRecorded = false;
    }
    saved.add(jsonEncode(item));
    if (saved.length > 1000) saved.removeRange(0, saved.length - 1000);
    await preferences.setStringList('question-performance-v1', saved);

    return result;
  }

  Future<void> _syncQuestionAnswers() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getStringList('question-performance-v1') ?? [];
    var changed = false;
    for (var index = 0; index < saved.length; index++) {
      final decoded = jsonDecode(saved[index]);
      if (decoded is! Map) continue;
      final item = Map<String, dynamic>.from(decoded);
      if (item['synced'] == true ||
          item['generated_content_id'] is! int ||
          item['item_index'] is! int) {
        continue;
      }
      try {
        final result = await _api.submitQuestionAnswer(
          generatedContentId: item['generated_content_id'] as int,
          itemIndex: item['item_index'] as int,
          userAnswer: item['user_answer'] as String? ?? '',
          answeredAt: item['answered_at'] as String?,
        );
        item['correct'] = result.isCorrect;
        item['synced'] = true;
        saved[index] = jsonEncode(item);
        changed = true;
      } on StudyContentApiException {
        // Mantém a resposta na fila para sincronizar na próxima abertura.
      } catch (_) {
        // Falhas de rede não devem impedir o estudo offline.
      }
    }
    if (changed)
      await preferences.setStringList('question-performance-v1', saved);
  }

  bool _isCorrectQuestionOption(
    Map<String, dynamic> option,
    String answer,
  ) {
    final normalizedAnswer = answer.trim().toLowerCase();
    final key = (option['key'] as String? ?? '').trim().toLowerCase();
    final label = (option['label'] as String? ?? '').trim().toLowerCase();

    return normalizedAnswer == key ||
        normalizedAnswer == label ||
        (key.isNotEmpty &&
            RegExp('^${RegExp.escape(key)}(?:\\)|\\.|\\s|\$)')
                .hasMatch(normalizedAnswer));
  }

  Future<void> _syncFlashcardsForReview(List<StudyContent> contents) async {
    final repository = ContestCardRepository(AppDatabase().database);
    final now = DateTime.now();
    for (final content in contents) {
      for (final flashcard in content.flashcards) {
        final front =
            MarkdownText.plain(flashcard['question'] as String? ?? '');
        final back = MarkdownText.plain(flashcard['answer'] as String? ?? '');
        if (front.isEmpty || back.isEmpty) continue;
        await repository.upsertGenerated(ContestCard(
          subject: content.disciplineName ?? 'Concursos',
          deck: content.topicName,
          front: front,
          back: back,
          source: content.materialTitle,
          createdAt: now,
          updatedAt: now,
        ));
      }
    }
  }

  Future<void> _addToNotebook({
    required String type,
    required String prompt,
    required String answer,
    String explanation = '',
  }) async {
    try {
      final notebooks = await SummaryNotebookApiService().list();
      if (!mounted) return;
      var selected = await showDialog<dynamic>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('Adicionar ao caderno'),
          children: [
            ...notebooks.map((notebook) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, notebook),
                  child: Text(notebook.name),
                )),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'create'),
              child: const Text('＋ Criar novo caderno'),
            ),
          ],
        ),
      );
      if (selected == 'create' && mounted) {
        final nameController = TextEditingController();
        selected = await showDialog<dynamic>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Novo caderno'),
            content: TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nome do caderno'),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar')),
              FilledButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, nameController.text.trim()),
                  child: const Text('Criar')),
            ],
          ),
        );
        if (selected is String && selected.isNotEmpty) {
          selected = await SummaryNotebookApiService().createEmpty(selected);
        }
      }
      if (selected == null || selected is! SummaryNotebook || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A IA está organizando o conteúdo...')));
      await SummaryNotebookApiService().appendEntry(selected.id,
          type: type, prompt: prompt, answer: answer, explanation: explanation);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Conteúdo adicionado ao caderno com destaque da pegadinha.')));
      }
    } on SummaryNotebookApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Não foi possível adicionar: ${error.code}')));
      }
    }
  }

  Map<String, List<StudyContent>> _groupByTopic() {
    final groups = <String, List<StudyContent>>{};
    for (final content in _contents.where(_matchesType)) {
      groups.putIfAbsent(content.topicName, () => []).add(content);
    }
    return groups;
  }

  bool _matchesType(StudyContent content) {
    return switch (widget.type) {
      'flashcards' => content.flashcards.isNotEmpty,
      'questions' => content.questions.isNotEmpty,
      'summaries' => content.summary?.trim().isNotEmpty ?? false,
      _ => true,
    };
  }

  String get _title => switch (widget.type) {
        'flashcards' => 'Flashcards',
        'questions' => 'Questões',
        'summaries' => 'Resumos',
        _ => 'Conteúdos de estudo',
      };

  @override
  Widget build(BuildContext context) {
    final groups = _groupByTopic();
    final content = widget.type == 'flashcards'
        ? _flashcardsBody(context)
        : widget.type == 'questions'
            ? _questionsBody(context)
            : _summariesBody(context, groups);
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: RefreshIndicator(onRefresh: _load, child: content),
    );
  }

  Widget _summariesBody(
      BuildContext context, Map<String, List<StudyContent>> groups) {
    final summaries = _contents
        .where(_matchesType)
        .where((content) =>
            _summaryDisciplineFilter.isEmpty ||
            content.disciplineName == _summaryDisciplineFilter)
        .toList();
    final summaryGroups = <String, List<StudyContent>>{};
    for (final content in summaries) {
      summaryGroups.putIfAbsent(content.topicName, () => []).add(content);
    }
    return _loading
        ? ListView(children: const [
            SizedBox(
                height: 280, child: Center(child: CircularProgressIndicator()))
          ])
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Conteúdos por tópico',
                  style: GoogleFonts.nunito(
                      fontSize: 23, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('Materiais gerados na Plataforma de Estudos.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              if (!_loading && _message == null) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _summaryDisciplineFilter,
                  decoration: const InputDecoration(
                      labelText: 'Filtrar por disciplina'),
                  items: [
                    const DropdownMenuItem(
                        value: '', child: Text('Todas as disciplinas')),
                    ..._summaryDisciplines.map((discipline) => DropdownMenuItem(
                        value: discipline,
                        child:
                            Text(discipline, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (value) => setState(() {
                    _summaryDisciplineFilter = value ?? '';
                  }),
                ),
              ],
              if (_message != null)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(_message!)),
              if (!_loading && _message == null && groups.isEmpty)
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('Nenhum conteúdo disponível.'))),
              ...summaryGroups.entries.map((entry) =>
                  _summarySelectionTopic(context, entry.key, entry.value)),
            ],
          );
  }

  List<String> get _summaryDisciplines => _contents
      .where(_matchesType)
      .map((content) => content.disciplineName ?? 'Sem disciplina')
      .toSet()
      .toList()
    ..sort();

  Widget _summarySelectionTopic(
      BuildContext context, String topic, List<StudyContent> contents) {
    return Card(
      margin: const EdgeInsets.only(top: 14),
      child: ExpansionTile(
        title:
            Text(topic, style: GoogleFonts.nunito(fontWeight: FontWeight.w900)),
        subtitle: Text('${contents.length} resumo(s)'),
        children: [
          for (final content in contents)
            ListTile(
              title: Text(content.materialTitle ?? 'Resumo'),
              subtitle: Text(
                '${_notebookNamesFor(content.id).isEmpty ? 'Ainda não adicionado a um caderno' : (_notebookNamesFor(content.id).contains(', ') ? 'Adicionado aos cadernos: ${_notebookNamesFor(content.id)}' : 'Adicionado ao caderno ${_notebookNamesFor(content.id)}')}\n${MarkdownText.plain(content.summary ?? '')}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.justify,
              ),
              trailing: PopupMenuButton<String>(
                tooltip: 'Opções do resumo',
                onSelected: (value) {
                  if (value == 'notebooks') _manageSummaryNotebooks(content);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'notebooks',
                    child: Text('Adicionar aos cadernos'),
                  ),
                ],
              ),
              onTap: () => _showSummary(content),
            ),
        ],
      ),
    );
  }

  Future<void> _showSummary(StudyContent content) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Resumo — ${content.materialTitle ?? 'Material'}'),
        content: SingleChildScrollView(
          child: Text(
            MarkdownText.plain(content.summary ?? ''),
            textAlign: TextAlign.justify,
            style: const TextStyle(height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _manageSummaryNotebooks(StudyContent content) async {
    if (_notebooks.isEmpty) {
      if (mounted) context.push('/summary-notebooks');
      return;
    }
    final selected = _notebooks
        .where((notebook) => notebook.sourceContentIds.contains(content.id))
        .map((notebook) => notebook.id)
        .toSet();
    final initial = {...selected};
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Cadernos do resumo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _notebooks
                  .map((notebook) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: selected.contains(notebook.id),
                        title: Text(notebook.name),
                        subtitle: Text(selected.contains(notebook.id)
                            ? 'Já inserido'
                            : 'Adicionar ao caderno'),
                        onChanged: (value) => setDialogState(() {
                          value == true
                              ? selected.add(notebook.id)
                              : selected.remove(notebook.id);
                        }),
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (result != true || !mounted) return;
    try {
      for (final notebook in _notebooks) {
        final shouldInclude = selected.contains(notebook.id);
        final included = initial.contains(notebook.id);
        if (shouldInclude == included) continue;
        final ids = {...notebook.sourceContentIds};
        if (shouldInclude) {
          ids.add(content.id);
        } else if (ids.length > 1) {
          ids.remove(content.id);
        } else {
          continue;
        }
        final updated = await SummaryNotebookApiService().update(
          notebook.id,
          sourceContentIds: ids.toList(),
          regenerate: true,
        );
        final index = _notebooks.indexWhere((item) => item.id == updated.id);
        if (index >= 0) _notebooks[index] = updated;
      }
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cadernos do resumo atualizados.')));
    } on SummaryNotebookApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Não foi possível atualizar: ${error.code}')));
      }
    }
  }

  String _notebookNamesFor(int contentId) => _notebooks
      .where((notebook) => notebook.sourceContentIds.contains(contentId))
      .map((notebook) => notebook.name)
      .join(', ');

  List<Map<String, dynamic>> get _flashcards => _contents
      .expand((content) => content.flashcards.map((card) => {
            ...card,
            '_discipline': content.disciplineName ?? 'Concursos',
            '_topic': content.topicName,
            '_material': content.materialTitle ?? 'Material',
          }))
      .toList();

  List<ContestCard> _reviewCardsFor(List<Map<String, dynamic>> cards) {
    final fronts = cards
        .map((card) => MarkdownText.plain(card['question'] as String? ?? ''))
        .where((front) => front.isNotEmpty)
        .toSet();
    return _localReviewCards
        .where((card) => fronts.contains(card.front))
        .toList();
  }

  List<Map<String, dynamic>> get _questions => _contents
      .expand((content) => content.questions.asMap().entries.map((entry) => {
            ...entry.value,
            '_contentId': content.id,
            '_index': entry.key,
            '_discipline': content.disciplineName ?? 'Sem disciplina',
            '_topic': content.topicName,
            '_material': content.materialTitle ?? 'Material',
          }))
      .toList();

  List<Map<String, dynamic>> get _filteredQuestions =>
      _questions.where((question) {
        final disciplineMatches = _questionDisciplineFilter.isEmpty ||
            question['_discipline'] == _questionDisciplineFilter;
        final topicMatches = _questionTopicFilter.isEmpty ||
            question['_topic'] == _questionTopicFilter;
        final materialMatches = _questionMaterialFilter.isEmpty ||
            question['_material'] == _questionMaterialFilter;
        return disciplineMatches && topicMatches && materialMatches;
      }).toList();

  List<String> get _questionDisciplines => _questions
      .map((question) => question['_discipline'] as String)
      .toSet()
      .toList()
    ..sort();

  List<String> get _questionTopics => _questions
      .map((question) => question['_topic'] as String)
      .toSet()
      .toList()
    ..sort();

  List<String> get _questionMaterials => _questions
      .map((question) => question['_material'] as String)
      .toSet()
      .toList()
    ..sort();

  Widget _flashcardsBody(BuildContext context) {
    if (_loading) return _loadingList();
    final cards = _flashcards;
    if (cards.isEmpty) return _emptyList('Nenhum flashcard disponível.');
    return _flashcardSetup(context, cards);
  }

  Widget _flashcardSetup(
      BuildContext context, List<Map<String, dynamic>> cards) {
    final reviewCards = _reviewCardsFor(cards);
    final dueCount = reviewCards.where(_isDue).length;
    final difficultCount = reviewCards.where(_isDifficult).length;
    final allCount = cards.length;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        Text('Modo de estudo',
            style:
                GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('Escolha como deseja revisar seus flashcards de concursos.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 20),
        _ContestDeckOption(
          icon: Icons.today_rounded,
          title: 'Pendentes',
          subtitle: 'Revisões previstas para agora',
          count: dueCount,
          selected: _flashcardMode == 'due',
          color: AppTheme.primary,
          onTap: () => setState(() => _flashcardMode = 'due'),
        ),
        const SizedBox(height: 10),
        _ContestDeckOption(
          icon: Icons.bolt_rounded,
          title: 'Difíceis',
          subtitle: 'Cartões marcados com dificuldade',
          count: difficultCount,
          selected: _flashcardMode == 'difficult',
          color: AppTheme.error,
          onTap: () => setState(() => _flashcardMode = 'difficult'),
        ),
        const SizedBox(height: 10),
        _ContestDeckOption(
          icon: Icons.style_rounded,
          title: 'Todos',
          subtitle: 'Revisar todos os cartões disponíveis',
          count: allCount,
          selected: _flashcardMode == 'all',
          color: AppTheme.secondary,
          onTap: () => setState(() => _flashcardMode = 'all'),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _selectedFlashcardCount == 0
                ? null
                : () {
                    final subjects = cards
                        .map((card) => card['_discipline'] as String)
                        .toSet();
                    final decks =
                        cards.map((card) => card['_topic'] as String).toSet();
                    final sources = cards
                        .map((card) => card['_material'] as String)
                        .toSet();
                    final query = <String, String>{'mode': _flashcardMode};
                    if (subjects.length == 1) query['subject'] = subjects.first;
                    if (decks.length == 1) query['deck'] = decks.first;
                    if (sources.length == 1) query['source'] = sources.first;
                    context.push(Uri(
                      path: '/concursos/review',
                      queryParameters: query,
                    ).toString());
                  },
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text('Começar estudo ($_selectedFlashcardCount)'),
          ),
        ),
      ],
    );
  }

  String _flashcardMode = 'due';

  int get _selectedFlashcardCount {
    final reviewCards = _reviewCardsFor(_flashcards);
    switch (_flashcardMode) {
      case 'all':
        return _flashcards.length;
      case 'difficult':
        return reviewCards.where(_isDifficult).length;
      default:
        return reviewCards.where(_isDue).length;
    }
  }

  bool _isDue(ContestCard card) =>
      card.nextReviewAt == null || !card.nextReviewAt!.isAfter(DateTime.now());

  bool _isDifficult(ContestCard card) => card.easeFactor < 2.5;

  Widget _questionsBody(BuildContext context) {
    if (_loading) return _loadingList();
    final questions = _filteredQuestions;
    if (questions.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _questionFilters(context),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: Center(child: Text('Nenhuma pergunta disponível.')),
          ),
        ],
      );
    }
    final question = questions[_studyIndex.clamp(0, questions.length - 1)];
    final options = (question['options'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((option) => Map<String, dynamic>.from(option))
        .toList();
    final normalizedOptions = options.isEmpty
        ? [
            {'key': 'Certo', 'label': 'Certo'},
            {'key': 'Errado', 'label': 'Errado'},
          ]
        : options;
    final answer = (question['answer'] as String? ?? '').trim();
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 18),
      children: [
        _questionFilters(context),
        const SizedBox(height: 14),
        Text('Questão ${_studyIndex + 1} de ${questions.length}',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TÓPICO · ${question['_topic']}',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .4)),
                    const SizedBox(height: 4),
                    Text('Material · ${question['_material']}',
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('ENUNCIADO',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1)),
              const SizedBox(height: 6),
              Text(
                  MarkdownText.plain(
                      question['question'] as String? ?? 'Questão'),
                  textAlign: TextAlign.justify,
                  style: GoogleFonts.nunito(
                      fontSize: 18, fontWeight: FontWeight.w800, height: 1.3)),
              const SizedBox(height: 14),
              ...normalizedOptions.map((option) {
                final key = option['key'] as String? ?? '';
                final isSelected = _selectedAnswer == key;
                final isCorrect = _questionAnswered &&
                    _isCorrectQuestionOption(option, answer);
                final isWrong = _questionAnswered && isSelected && !isCorrect;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? Colors.green.withValues(alpha: .14)
                        : isWrong
                            ? Colors.red.withValues(alpha: .14)
                            : isSelected
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: .12)
                                : null,
                    border: Border.all(
                        color: isCorrect
                            ? Colors.green
                            : isWrong
                                ? Colors.red
                                : isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outline),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: RadioListTile<String>(
                    value: key,
                    groupValue: _selectedAnswer,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    visualDensity: VisualDensity.compact,
                    onChanged: _questionAnswered
                        ? null
                        : (value) => setState(() => _selectedAnswer = value),
                    title: Text(
                      '${key.isEmpty ? '' : '$key) '}${MarkdownText.plain(option['label'] as String? ?? '')}',
                      textAlign: TextAlign.justify,
                      style: const TextStyle(fontSize: 15, height: 1.25),
                    ),
                  ),
                );
              }),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _selectedAnswer == null || _questionAnswered
                      ? null
                      : () async {
                          question['_selectedAnswer'] = _selectedAnswer;
                          final result = await _recordQuestionAnswer(question);
                          if (!context.mounted) return;
                          if (result == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Resposta salva. O gabarito será exibido após sincronizar.'),
                              ),
                            );
                            return;
                          }
                          question['answer'] = result.answer;
                          question['explanation'] = result.explanation;
                          question['_isCorrect'] = result.isCorrect;
                          setState(() => _questionAnswered = true);
                        },
                  child: const Text('Responder'),
                ),
              ),
              if (_questionAnswered) ...[
                const SizedBox(height: 14),
                Text(
                    question['_isCorrect'] == true
                        ? 'Resposta correta! Gabarito: $answer'
                        : 'Resposta incorreta. Gabarito: $answer',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: question['_isCorrect'] == true
                            ? Colors.green
                            : Colors.red)),
                if ((question['explanation'] as String? ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                        MarkdownText.plain(question['explanation'] as String)),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _addToNotebook(
                    type: 'question',
                    prompt: MarkdownText.plain(
                        question['question'] as String? ?? ''),
                    answer: answer,
                    explanation: MarkdownText.plain(
                        question['explanation'] as String? ?? ''),
                  ),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Adicionar ao caderno com IA'),
                ),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          OutlinedButton.icon(
              onPressed: _studyIndex == 0 ? null : _previousQuestion,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Anterior')),
          if (_studyIndex == questions.length - 1)
            FilledButton.icon(
                onPressed: _questionAnswered ? _finishQuestions : null,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Concluir'))
          else
            FilledButton.icon(
                onPressed: _nextQuestion,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Próxima')),
        ]),
      ],
    );
  }

  Widget _questionFilters(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        title: Row(children: [
          Icon(Icons.filter_list_rounded,
              size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Filtros', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: _questionDisciplineFilter,
                  decoration: const InputDecoration(labelText: 'Disciplina'),
                  items: [
                    const DropdownMenuItem(
                        value: '', child: Text('Todas as disciplinas')),
                    ..._questionDisciplines.map((discipline) =>
                        DropdownMenuItem(
                            value: discipline,
                            child: Text(discipline,
                                overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (value) => setState(() {
                    _questionDisciplineFilter = value ?? '';
                    _studyIndex = 0;
                    _selectedAnswer = null;
                    _questionAnswered = false;
                    _questionAnswerRecorded = false;
                  }),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _questionTopicFilter,
                  decoration: const InputDecoration(labelText: 'Tópico'),
                  items: [
                    const DropdownMenuItem(
                        value: '', child: Text('Todos os tópicos')),
                    ..._questionTopics.map((topic) => DropdownMenuItem(
                        value: topic,
                        child: Text(topic, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (value) => setState(() {
                    _questionTopicFilter = value ?? '';
                    _studyIndex = 0;
                    _selectedAnswer = null;
                    _questionAnswered = false;
                    _questionAnswerRecorded = false;
                  }),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _questionMaterialFilter,
                  decoration: const InputDecoration(labelText: 'Material'),
                  items: [
                    const DropdownMenuItem(
                        value: '', child: Text('Todos os materiais')),
                    ..._questionMaterials.map((material) => DropdownMenuItem(
                        value: material,
                        child:
                            Text(material, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (value) => setState(() {
                    _questionMaterialFilter = value ?? '';
                    _studyIndex = 0;
                    _selectedAnswer = null;
                    _questionAnswered = false;
                    _questionAnswerRecorded = false;
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingList() => ListView(children: const [
        SizedBox(height: 280, child: Center(child: CircularProgressIndicator()))
      ]);

  Widget _emptyList(String message) => ListView(
        children: [
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 100),
              child: Center(child: Text(message))),
        ],
      );

  void _nextQuestion() => setState(() {
        _studyIndex++;
        _selectedAnswer = null;
        _questionAnswered = false;
        _questionAnswerRecorded = false;
      });

  void _previousQuestion() => setState(() {
        _studyIndex--;
        _selectedAnswer = null;
        _questionAnswered = false;
        _questionAnswerRecorded = false;
      });

  void _finishQuestions() {
    if (!_questionAnswered || !context.canPop()) return;
    // O pop preserva a origem: sessão de estudos, área de questões ou concursos.
    context.pop(true);
  }

  Widget _topicCard(
      BuildContext context, String topic, List<StudyContent> contents) {
    final flashcardCount =
        contents.fold<int>(0, (total, item) => total + item.flashcards.length);
    final children = <Widget>[];
    for (final content in contents) {
      if (widget.type != 'flashcards' &&
          widget.type != 'questions' &&
          content.summary != null &&
          content.summary!.trim().isNotEmpty) {
        children.add(ExpansionTile(
          title: const Text('Resumo'),
          subtitle: Text(content.materialTitle ?? 'Material'),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(MarkdownText.plain(content.summary!),
                    textAlign: TextAlign.justify,
                    style: const TextStyle(height: 1.65)),
              ),
            ),
          ],
        ));
      }
      for (final flashcard
          in widget.type == 'summaries' ? const [] : content.flashcards) {
        children.add(ExpansionTile(
          title: Text(MarkdownText.plain(
              flashcard['question'] as String? ?? 'Flashcard')),
          subtitle: Text(content.materialTitle ?? 'Material'),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    MarkdownText.plain(flashcard['answer'] as String? ?? '')),
              ),
            ),
          ],
        ));
      }
      for (final question
          in widget.type == 'flashcards' || widget.type == 'summaries'
              ? const []
              : content.questions) {
        children.add(ExpansionTile(
          title: Text(
              MarkdownText.plain(question['question'] as String? ?? 'Questão')),
          subtitle: Text(content.materialTitle ?? 'Material'),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Gabarito: ${MarkdownText.plain(question['answer'] as String? ?? '')}\n\n${MarkdownText.plain(question['explanation'] as String? ?? '')}',
                ),
              ),
            ),
          ],
        ));
      }
    }

    return Card(
      margin: const EdgeInsets.only(top: 14),
      child: ExpansionTile(
        title:
            Text(topic, style: GoogleFonts.nunito(fontWeight: FontWeight.w900)),
        subtitle: Text('$flashcardCount flashcards'),
        children: children,
      ),
    );
  }
}

class _ContestDeckOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ContestDeckOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: selected ? color.withValues(alpha: .12) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
            color: selected ? color : Theme.of(context).colorScheme.outline,
            width: selected ? 2 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: .16),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w900)),
                  Text(subtitle,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13)),
                ],
              ),
            ),
            Text('$count',
                style: GoogleFonts.nunito(
                    fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          ]),
        ),
      ),
    );
  }
}
