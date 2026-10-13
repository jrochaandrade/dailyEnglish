import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/study_content_api_service.dart';
import '../../core/services/summary_notebook_api_service.dart';
import '../../models/summary_notebook.dart';
import '../../widgets/notebook_content_view.dart';

class SummaryNotebooksScreen extends StatefulWidget {
  const SummaryNotebooksScreen({super.key});

  @override
  State<SummaryNotebooksScreen> createState() => _SummaryNotebooksScreenState();
}

class _SummaryNotebooksScreenState extends State<SummaryNotebooksScreen> {
  final _api = SummaryNotebookApiService();
  List<SummaryNotebook> _notebooks = [];
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
      final notebooks = await _api.list();
      if (mounted) setState(() => _notebooks = notebooks);
    } on SummaryNotebookApiException catch (error) {
      if (mounted) setState(() => _error = error.code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadernos de revisão')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(children: const [
                SizedBox(
                    height: 280,
                    child: Center(child: CircularProgressIndicator()))
              ])
            : _error != null
                ? ListView(children: [
                    Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                            child: Text('Não foi possível carregar: $_error')))
                  ])
                : _notebooks.isEmpty
                    ? ListView(children: const [
                        Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                                child: Text(
                                    'Você ainda não criou um caderno de revisão.')))
                      ])
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 25,
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    child: Icon(Icons.auto_stories_rounded,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer),
                                  ),
                                  const SizedBox(width: 14),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Revisão inteligente',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 17)),
                                        SizedBox(height: 4),
                                        Text(
                                            'Regras, pontos essenciais e pegadinhas organizados para sua revisão.'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          ..._notebooks.map((notebook) => _NotebookCard(
                                notebook: notebook,
                                onTap: () => _openNotebook(notebook),
                              )),
                        ],
                      ),
      ),
    );
  }

  Future<void> _openNotebook(SummaryNotebook notebook) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _NotebookDetailScreen(notebook: notebook, api: _api),
    ));
    _load();
  }
}

class _NotebookCard extends StatelessWidget {
  final SummaryNotebook notebook;
  final VoidCallback onTap;
  const _NotebookCard({required this.notebook, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          onTap: onTap,
          leading: const CircleAvatar(child: Icon(Icons.menu_book_rounded)),
          title: Text(notebook.name,
              style: GoogleFonts.nunito(fontWeight: FontWeight.w900)),
          subtitle: Text(
              '${notebook.disciplineName ?? 'Todas as disciplinas'} · ${notebook.sourceContentIds.length} resumo(s)'),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      );
}

class _NotebookDetailScreen extends StatefulWidget {
  final SummaryNotebook notebook;
  final SummaryNotebookApiService api;
  const _NotebookDetailScreen({required this.notebook, required this.api});

  @override
  State<_NotebookDetailScreen> createState() => _NotebookDetailScreenState();
}

class _NotebookDetailScreenState extends State<_NotebookDetailScreen> {
  late SummaryNotebook _notebook = widget.notebook;
  bool _saving = false;

  Future<void> _addSummaries() async {
    final contents = await StudyContentApiService().list();
    if (!mounted) return;
    final available = contents
        .where((content) => content.summary?.trim().isNotEmpty ?? false)
        .toList();
    final selected = {..._notebook.sourceContentIds};
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Adicionar resumos'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: available
                  .map((content) => CheckboxListTile(
                        value: selected.contains(content.id),
                        title: Text(content.materialTitle ?? 'Resumo'),
                        subtitle:
                            Text(content.disciplineName ?? 'Sem disciplina'),
                        onChanged: (value) => setDialogState(() {
                          value == true
                              ? selected.add(content.id)
                              : selected.remove(content.id);
                        }),
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Salvar e melhorar')),
          ],
        ),
      ),
    );
    if (result != true || !mounted || selected.isEmpty) return;
    setState(() => _saving = true);
    try {
      _notebook = await widget.api.update(_notebook.id,
          sourceContentIds: selected.toList(), regenerate: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Caderno atualizado pela IA.')));
        setState(() {});
      }
    } on SummaryNotebookApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Falha: ${error.code}')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_notebook.name),
        actions: [
          IconButton(
              tooltip: 'Adicionar resumos',
              onPressed: _saving ? null : _addSummaries,
              icon: const Icon(Icons.add_rounded)),
        ],
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Text(
                    '${_notebook.sourceContentIds.length} resumo(s) selecionado(s)',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 16),
                if ((_notebook.content ?? '').isEmpty)
                  const Text('O caderno ainda não possui conteúdo gerado.')
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: NotebookContentView(markdown: _notebook.content!),
                    ),
                  ),
                if ((_notebook.visual ?? '').isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Card(
                    child: ExpansionTile(
                      title: const Text('Mapa visual'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: SelectableText(_notebook.visual!),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
