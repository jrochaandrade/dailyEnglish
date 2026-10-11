import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/material_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/material.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  final _titleController = TextEditingController();
  final _api = MaterialApiService();
  final _materials = <StudyMaterial>[];
  File? _selectedFile;
  bool _loading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
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
            tooltip: 'Conteúdos gerados',
            onPressed: () => context.push('/study-content'),
            icon: const Icon(Icons.auto_awesome_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMaterials,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Envie o conteúdo que você quer estudar',
              style:
                  GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Comece por PDFs. Depois vamos gerar resumo e flashcards com referência à fonte.',
              style: GoogleFonts.nunito(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
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
                        _selectedFile!.path.split(Platform.pathSeparator).last,
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
              style:
                  GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            if (_materials.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: Text('Nenhum material enviado ainda.')),
              )
            else
              ..._materials.map(
                (material) => Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: AppTheme.secondary,
                    ),
                    title: Text(material.title ?? material.originalFilename),
                    subtitle: Text(
                      '\${material.originalFilename} · \${formatMaterialSize(material.sizeBytes)}',
                    ),
                    trailing: Text(material.status),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
