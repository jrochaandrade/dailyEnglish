import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/study_content_api_service.dart';
import '../../models/study_content.dart';

class StudyContentScreen extends StatefulWidget {
  const StudyContentScreen({super.key});

  @override
  State<StudyContentScreen> createState() => _StudyContentScreenState();
}

class _StudyContentScreenState extends State<StudyContentScreen> {
  final _api = StudyContentApiService();
  List<StudyContent> _contents = [];
  String? _message;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final contents = await _api.list();
      if (!mounted) return;
      setState(() {
        _contents = contents;
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

  Map<String, List<StudyContent>> _groupByTopic() {
    final groups = <String, List<StudyContent>>{};
    for (final content in _contents) {
      groups.putIfAbsent(content.topicName, () => []).add(content);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupByTopic();
    return Scaffold(
      appBar: AppBar(title: const Text('Conteúdos de estudo')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(children: const [
                SizedBox(
                    height: 280,
                    child: Center(child: CircularProgressIndicator()))
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
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                  if (_message != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(_message!)),
                  if (!_loading && _message == null && groups.isEmpty)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child:
                            Center(child: Text('Nenhum conteúdo disponível.'))),
                  ...groups.entries.map(
                      (entry) => _topicCard(context, entry.key, entry.value)),
                ],
              ),
      ),
    );
  }

  Widget _topicCard(
      BuildContext context, String topic, List<StudyContent> contents) {
    final flashcardCount =
        contents.fold<int>(0, (total, item) => total + item.flashcards.length);
    final children = <Widget>[];
    for (final content in contents) {
      if (content.summary != null && content.summary!.trim().isNotEmpty) {
        children.add(ExpansionTile(
          title: const Text('Resumo'),
          subtitle: Text(content.materialTitle ?? 'Material'),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(content.summary!),
              ),
            ),
          ],
        ));
      }
      for (final flashcard in content.flashcards) {
        children.add(ExpansionTile(
          title: Text(flashcard['question'] as String? ?? 'Flashcard'),
          subtitle: Text(content.materialTitle ?? 'Material'),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(flashcard['answer'] as String? ?? ''),
              ),
            ),
          ],
        ));
      }
      for (final question in content.questions) {
        children.add(ExpansionTile(
          title: Text(question['question'] as String? ?? 'Questão'),
          subtitle: Text(content.materialTitle ?? 'Material'),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Gabarito: ${question['answer'] as String? ?? ''}\n\n${question['explanation'] as String? ?? ''}',
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
