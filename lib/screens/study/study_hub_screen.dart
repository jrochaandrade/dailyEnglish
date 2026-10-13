import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/study_content_api_service.dart';
import '../../models/study_content.dart';

class StudyHubScreen extends StatefulWidget {
  const StudyHubScreen({super.key});

  @override
  State<StudyHubScreen> createState() => _StudyHubScreenState();
}

class _StudyHubScreenState extends State<StudyHubScreen> {
  final _api = StudyContentApiService();
  List<StudyContent> _contents = [];
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
      if (mounted) setState(() => _contents = contents);
    } on StudyContentApiException catch (error) {
      if (mounted) setState(() => _error = error.code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _summaryCount => _contents
      .where((item) => item.summary?.trim().isNotEmpty ?? false)
      .length;
  int get _flashcardCount =>
      _contents.fold(0, (sum, item) => sum + item.flashcards.length);
  int get _questionCount =>
      _contents.fold(0, (sum, item) => sum + item.questions.length);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estudar'),
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
                            const Icon(Icons.play_circle_fill_rounded,
                                size: 42),
                            const SizedBox(height: 10),
                            const Text('Revisões disponíveis',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 5),
                            Text('Escolha o tipo de conteúdo para começar.',
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                            const SizedBox(height: 16),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              _studyButton(context, 'Resumos', _summaryCount,
                                  Icons.notes_rounded, 'summaries'),
                              _studyButton(
                                  context,
                                  'Flashcards',
                                  _flashcardCount,
                                  Icons.style_rounded,
                                  'flashcards'),
                              _studyButton(context, 'Questões', _questionCount,
                                  Icons.quiz_rounded, 'questions'),
                            ]),
                          ]),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('Conteúdos por material',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  ..._contents.map((content) => _ContentTile(content: content)),
                ],
              ),
      ),
    );
  }

  Widget _studyButton(BuildContext context, String label, int count,
          IconData icon, String type) =>
      FilledButton.icon(
        onPressed: count == 0
            ? null
            : () => context.push(type == 'flashcards' || type == 'questions'
                ? '/study-content?type=$type'
                : '/study/session?type=$type'),
        icon: Icon(icon),
        label: Text('$label ($count)'),
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
