import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/material_api_service.dart';
import '../../core/services/study_structure_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/material.dart';
import '../../models/study_structure.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  final _titleController = TextEditingController();
  final _api = MaterialApiService();
  final _structureApi = StudyStructureApiService();
  final _materials = <StudyMaterial>[];
  List<StudyStructure> _structure = [];
  File? _selectedFile;
  bool _loading = false;
  bool _loadingStructure = false;
  int? _selectedDisciplineId;
  int? _selectedTopicId;
  String? _message;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadMaterials() async {
    try {
      final materials = await _api.list();
      if (!mounted) return;
      setState(() {
        _materials
          ..clear()
          ..addAll(materials);
        _message = null;
      });
    } on MaterialApiException catch (error) {
      if (!mounted) return;
      setState(() => _message = _messageFor(error.code));
    }
  }

  Future<void> _loadStructure() async {
    setState(() => _loadingStructure = true);
    try {
      final structure = await _structureApi.list();
      if (!mounted) return;
      setState(() {
        _structure = structure;
        if (_selectedDisciplineId != null &&
            !structure.any((item) => item.id == _selectedDisciplineId)) {
          _selectedDisciplineId = null;
          _selectedTopicId = null;
        }
      });
    } on StudyStructureApiException catch (error) {
      if (mounted) setState(() => _message = _messageFor(error.code));
    } finally {
      if (mounted) setState(() => _loadingStructure = false);
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadStructure(), _loadMaterials()]);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() {
      _selectedFile = File(path);
      if (_titleController.text.trim().isEmpty) {
        _titleController.text = result!.files.single.name.replaceFirst(
          RegExp(r'\.pdf$', caseSensitive: false),
          '',
        );
      }
    });
  }

  Future<void> _upload() async {
    final file = _selectedFile;
    if (file == null) {
      setState(() => _message = 'Selecione um PDF antes de enviar.');
      return;
    }
    setState(() => _loading = true);
    try {
      final material = await _api.upload(
        file: file,
        title: _titleController.text,
        disciplineId: _selectedDisciplineId,
        topicId: _selectedTopicId,
      );
      if (!mounted) return;
      setState(() {
        _materials.insert(0, material);
        _selectedFile = null;
        _titleController.clear();
        _message = 'Material enviado. Aguardando processamento.';
      });
    } on MaterialApiException catch (error) {
      if (!mounted) return;
      setState(() => _message = _messageFor(error.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pasteContent() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar conteúdo'),
        content: SingleChildScrollView(
          child: Column(children: [
            TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Título')),
            const SizedBox(height: 12),
            TextField(
                controller: contentController,
                minLines: 8,
                maxLines: 14,
                decoration:
                    const InputDecoration(labelText: 'Cole o conteúdo aqui')),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salvar')),
        ],
      ),
    );
    if (confirmed != true || contentController.text.trim().isEmpty) {
      titleController.dispose();
      contentController.dispose();
      return;
    }
    setState(() => _loading = true);
    try {
      final material = await _api.upload(
        sourceType: 'text',
        title: titleController.text.trim().isEmpty
            ? 'Conteúdo colado'
            : titleController.text.trim(),
        content: contentController.text,
        disciplineId: _selectedDisciplineId,
        topicId: _selectedTopicId,
      );
      if (!mounted) return;
      setState(() {
        _materials.insert(0, material);
        _message = 'Conteúdo salvo no servidor.';
      });
    } on MaterialApiException catch (error) {
      if (mounted) setState(() => _message = _messageFor(error.code));
    } finally {
      titleController.dispose();
      contentController.dispose();
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _nameDialog(String title, {String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nome')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Salvar')),
        ],
      ),
    );
    controller.dispose();
    return value?.isEmpty == true ? null : value;
  }

  Future<void> _createDiscipline() async {
    final name = await _nameDialog('Nova disciplina');
    if (name == null) return;
    await _structureApi.createDiscipline(name);
    await _loadStructure();
  }

  Future<void> _createTopic() async {
    final disciplineId = _selectedDisciplineId;
    if (disciplineId == null) return;
    final name = await _nameDialog('Novo tópico');
    if (name == null) return;
    await _structureApi.createTopic(disciplineId, name);
    await _loadStructure();
  }

  Future<void> _editDiscipline(StudyStructure discipline) async {
    final name =
        await _nameDialog('Editar disciplina', initial: discipline.name);
    if (name == null) return;
    await _structureApi.updateDiscipline(discipline.id, name);
    await _loadStructure();
  }

  Future<void> _editTopic(StudyTopic topic) async {
    final name = await _nameDialog('Editar tópico', initial: topic.name);
    if (name == null) return;
    await _structureApi.updateTopic(topic.id, name);
    await _loadStructure();
  }

  Widget _structureSection() {
    final selected = _structure
        .where((item) => item.id == _selectedDisciplineId)
        .firstOrNull;
    final selectedTopic = selected?.topics
        .where((item) => item.id == _selectedTopicId)
        .firstOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (selected != null)
              IconButton(
                  onPressed: () => setState(() {
                        if (_selectedTopicId != null) {
                          _selectedTopicId = null;
                        } else {
                          _selectedDisciplineId = null;
                        }
                      }),
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: _selectedTopicId != null
                      ? 'Voltar aos tópicos'
                      : 'Voltar às disciplinas'),
            Expanded(
                child: Text(
                    selected == null
                        ? 'Disciplinas'
                        : (selectedTopic?.name ?? selected.name),
                    style: GoogleFonts.nunito(
                        fontSize: 18, fontWeight: FontWeight.w900))),
            IconButton(
                onPressed: _loadingStructure ? null : _loadStructure,
                icon: const Icon(Icons.sync_rounded),
                tooltip: 'Atualizar do servidor'),
            if (selected == null)
              IconButton(
                  onPressed: _createDiscipline,
                  icon: const Icon(Icons.create_new_folder_outlined),
                  tooltip: 'Criar disciplina'),
          ]),
          if (_structure.isEmpty)
            const Text('Nenhuma disciplina criada ainda.')
          else if (selected == null)
            _folderWrap(_structure.map((discipline) => _FolderItem(
                  icon: Icons.folder_rounded,
                  label: discipline.name,
                  count: '${discipline.materialsCount} materiais',
                  onTap: () => setState(() {
                    _selectedDisciplineId = discipline.id;
                    _selectedTopicId = null;
                  }),
                  onLongPress: () => _editDiscipline(discipline),
                )))
          else if (_selectedTopicId == null) ...[
            const SizedBox(height: 14),
            Row(children: [
              const Expanded(
                  child: Text('Tópicos da disciplina',
                      style: TextStyle(fontWeight: FontWeight.w700))),
              TextButton.icon(
                  onPressed: _createTopic,
                  icon: const Icon(Icons.add),
                  label: const Text('Novo tópico')),
            ]),
            if (selected.topics.isEmpty)
              const Text('Nenhum tópico criado ainda.')
            else
              _folderWrap(selected.topics.map((topic) => _FolderItem(
                    icon: Icons.folder_rounded,
                    label: topic.name,
                    onTap: () => setState(() => _selectedTopicId = topic.id),
                    onLongPress: () => _editTopic(topic),
                  ))),
          ],
          if (selectedTopic != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                'Conteúdo organizado nesta pasta. Adicione PDFs ou texto abaixo.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _folderWrap(Iterable<_FolderItem> items) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items
            .map((item) => GestureDetector(
                  onTap: item.onTap,
                  onLongPress: item.onLongPress,
                  child: SizedBox(
                    width: 142,
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(item.icon,
                                color: AppTheme.secondary, size: 28),
                            const SizedBox(height: 8),
                            Text(item.label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w900)),
                            if (item.count != null)
                              Text(item.count!,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ))
            .toList(),
      );

  String _messageFor(String code) => code == 'auth_required'
      ? 'Faça login para acessar seus materiais.'
      : 'Não foi possível conectar ao backend.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Materiais'),
        actions: [
          IconButton(
            tooltip: 'Atualizar do servidor',
            onPressed: _refreshAll,
            icon: const Icon(Icons.sync_rounded),
          ),
          IconButton(
            tooltip: 'Conteúdos gerados',
            onPressed: () => context.push('/study-content'),
            icon: const Icon(Icons.auto_awesome_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_selectedTopicId != null) ...[
              Text(
                'Envie o conteúdo que você quer estudar',
                style: GoogleFonts.nunito(
                    fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Comece por PDFs. Depois vamos gerar resumo e flashcards com referência à fonte.',
                style: GoogleFonts.nunito(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
            ],
            _structureSection(),
            if (_selectedTopicId != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Título do material',
                          hintText: 'Ex.: Direito Constitucional',
                        ),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _pickFile,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: Text(_selectedFile == null
                            ? 'Selecionar PDF'
                            : 'Trocar PDF'),
                      ),
                      if (_selectedFile != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _selectedFile!.path
                              .split(Platform.pathSeparator)
                              .last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _upload,
                          icon: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.cloud_upload_outlined),
                          label: const Text('Enviar material'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : _pasteContent,
                          icon: const Icon(Icons.content_paste_rounded),
                          label: const Text('Colar conteúdo de texto'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    _message!,
                    style: GoogleFonts.nunito(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'Seus materiais',
                style: GoogleFonts.nunito(
                    fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              if (_materials.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: Text('Nenhum material enviado ainda.')),
                )
              else
                ..._materials.where((material) {
                  if (_selectedDisciplineId != null &&
                      material.disciplineId != _selectedDisciplineId) {
                    return false;
                  }
                  if (_selectedTopicId != null &&
                      material.topicId != _selectedTopicId) {
                    return false;
                  }
                  return true;
                }).map(
                  (material) => Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: AppTheme.secondary,
                      ),
                      title: Text(material.title ?? material.originalFilename),
                      subtitle: Text(
                        '${material.originalFilename} · ${formatMaterialSize(material.sizeBytes)}',
                      ),
                      trailing: Text(material.status),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FolderItem {
  final IconData icon;
  final String label;
  final String? count;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FolderItem({
    required this.icon,
    required this.label,
    this.count,
    required this.onTap,
    required this.onLongPress,
  });
}
