import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/study_content_api_service.dart';
import '../../core/database/app_database.dart';
import '../../models/study_content.dart';
import '../../models/contest_card.dart';
import '../../repositories/contest_card_repository.dart';
import '../../core/utils/markdown_text.dart';
import '../../core/theme/app_theme.dart';

class StudyContentScreen extends StatefulWidget {
  final String? type;

  const StudyContentScreen({super.key, this.type});

  @override
  State<StudyContentScreen> createState() => _StudyContentScreenState();
}

class _StudyContentScreenState extends State<StudyContentScreen> {
  final _api = StudyContentApiService();
  List<StudyContent> _contents = [];
  List<ContestCard> _localReviewCards = [];
  String? _message;
  bool _loading = true;
  int _studyIndex = 0;
  String? _selectedAnswer;
  bool _questionAnswered = false;
  String _questionTopicFilter = '';
  String _questionDisciplineFilter = '';
  String _questionMaterialFilter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final contents = await _api.list();
      await _syncFlashcardsForReview(contents);
      final localCards =
          await ContestCardRepository(AppDatabase().database).getAll();
      if (!mounted) return;
      setState(() {
        _contents = contents;
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
        'questions' => 'Perguntas',
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
              if (_message != null)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(_message!)),
              if (!_loading && _message == null && groups.isEmpty)
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('Nenhum conteúdo disponível.'))),
              ...groups.entries
                  .map((entry) => _topicCard(context, entry.key, entry.value)),
            ],
          );
  }

  List<Map<String, dynamic>> get _flashcards => _contents
      .expand((content) => content.flashcards.map((card) => {
            ...card,
            '_topic': content.topicName,
            '_material': content.materialTitle ?? 'Material',
          }))
      .toList();

  List<Map<String, dynamic>> get _questions => _contents
      .expand((content) => content.questions.map((question) => {
            ...question,
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
    final dueCount = _localReviewCards.where(_isDue).length;
    final difficultCount = _localReviewCards.where(_isDifficult).length;
    final allCount = cards.length;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        Text('Study Mode',
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
                : () => context.push('/concursos/review?mode=$_flashcardMode'),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text('Começar estudo ($_selectedFlashcardCount)'),
          ),
        ),
      ],
    );
  }

  String _flashcardMode = 'due';

  int get _selectedFlashcardCount {
    switch (_flashcardMode) {
      case 'all':
        return _flashcards.length;
      case 'difficult':
        return _localReviewCards.where(_isDifficult).length;
      default:
        return _localReviewCards.where(_isDue).length;
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
      padding: const EdgeInsets.all(18),
      children: [
        _questionFilters(context),
        const SizedBox(height: 14),
        Text('Pergunta ${_studyIndex + 1} de ${questions.length}',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Tópico: ${question['_topic']}',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Material: ${question['_material']}',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13)),
              const SizedBox(height: 14),
              Text(
                  MarkdownText.plain(
                      question['question'] as String? ?? 'Pergunta'),
                  style: GoogleFonts.nunito(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              ...normalizedOptions.map((option) {
                final key = option['key'] as String? ?? '';
                final isSelected = _selectedAnswer == key;
                final isCorrect = _questionAnswered &&
                    key.toLowerCase() == answer.toLowerCase();
                final isWrong = _questionAnswered && isSelected && !isCorrect;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? Colors.green.withValues(alpha: .14)
                        : isWrong
                            ? Colors.red.withValues(alpha: .14)
                            : null,
                    border: Border.all(
                        color: isCorrect
                            ? Colors.green
                            : isWrong
                                ? Colors.red
                                : Theme.of(context).colorScheme.outline),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: RadioListTile<String>(
                    value: key,
                    groupValue: _selectedAnswer,
                    onChanged: _questionAnswered
                        ? null
                        : (value) => setState(() => _selectedAnswer = value),
                    title: Text(
                        '${key.isEmpty ? '' : '$key) '}${MarkdownText.plain(option['label'] as String? ?? '')}'),
                  ),
                );
              }),
              FilledButton(
                onPressed: _selectedAnswer == null || _questionAnswered
                    ? null
                    : () => setState(() => _questionAnswered = true),
                child: const Text('Responder'),
              ),
              if (_questionAnswered) ...[
                const SizedBox(height: 14),
                Text(
                    _selectedAnswer?.toLowerCase() == answer.toLowerCase()
                        ? 'Resposta correta!'
                        : 'Resposta incorreta. Gabarito: $answer',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _selectedAnswer?.toLowerCase() ==
                                answer.toLowerCase()
                            ? Colors.green
                            : Colors.red)),
                if ((question['explanation'] as String? ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                        MarkdownText.plain(question['explanation'] as String)),
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
          FilledButton.icon(
              onPressed:
                  _studyIndex == questions.length - 1 ? null : _nextQuestion,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Próxima')),
        ]),
      ],
    );
  }

  Widget _questionFilters(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.filter_list_rounded,
                  size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Text('Filtros',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _questionDisciplineFilter,
              decoration: const InputDecoration(labelText: 'Disciplina'),
              items: [
                const DropdownMenuItem(
                    value: '', child: Text('Todas as disciplinas')),
                ..._questionDisciplines.map((discipline) => DropdownMenuItem(
                    value: discipline,
                    child: Text(discipline, overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (value) => setState(() {
                _questionDisciplineFilter = value ?? '';
                _studyIndex = 0;
                _selectedAnswer = null;
                _questionAnswered = false;
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
                    child: Text(material, overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (value) => setState(() {
                _questionMaterialFilter = value ?? '';
                _studyIndex = 0;
                _selectedAnswer = null;
                _questionAnswered = false;
              }),
            ),
          ],
        ),
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
      });

  void _previousQuestion() => setState(() {
        _studyIndex--;
        _selectedAnswer = null;
        _questionAnswered = false;
      });

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
                child: Text(MarkdownText.plain(content.summary!)),
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
