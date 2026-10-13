import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/english_sync_api_service.dart';
import '../../core/theme/app_theme.dart';

class SyncScreen extends StatefulWidget {
  final String title;
  final bool contestsOnly;

  const SyncScreen(
      {super.key, this.title = 'Sincronização', this.contestsOnly = false});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _api = EnglishSyncApiService();
  Map<String, dynamic>? _local;
  Map<String, dynamic>? _remote;
  bool _loading = true;
  bool _working = false;
  String? _error;

  Set<String> get _tables => widget.contestsOnly
      ? {'contest_cards'}
      : EnglishSyncApiService.tables
          .where((table) => table != 'contest_cards')
          .toSet();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.localSnapshot(onlyTables: _tables),
        _api.downloadSnapshot(),
      ]);
      if (!mounted) return;
      setState(() {
        _local = results[0];
        _remote = results[1];
        _loading = false;
      });
    } on EnglishSyncException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Não foi possível conferir a sincronização: $error';
          _loading = false;
        });
      }
    }
  }

  Future<void> _upload() async {
    await _run('enviar', () => _api.syncLocalDatabase(onlyTables: _tables));
  }

  Future<void> _download() async {
    await _run('receber', () => _api.downloadAndMerge(onlyTables: _tables));
  }

  Future<void> _run(String action, Future<Object> Function() operation) async {
    setState(() => _working = true);
    try {
      final result = await operation();
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dados $action com sucesso: $result.')),
      );
    } on EnglishSyncException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao $action dados: $error')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
              onPressed: _working ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded))
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _refresh)
              : _safeContent(),
    );
  }

  Widget _safeContent() {
    try {
      return _content();
    } catch (error) {
      return _ErrorState(
        message: 'Não foi possível exibir a comparação: $error',
        onRetry: _refresh,
      );
    }
  }

  Widget _content() {
    final rows = _comparison();
    final upload = rows.fold<int>(0, (sum, row) => sum + row.toUpload);
    final receive = rows.fold<int>(0, (sum, row) => sum + row.toReceive);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Conferir dados',
            style:
                GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(
            'Compare o que está neste aparelho com o que foi salvo na retaguarda.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
              child: _SummaryCard(
                  label: 'Para enviar',
                  value: '$upload',
                  color: AppTheme.warning,
                  icon: Icons.cloud_upload_rounded)),
          const SizedBox(width: 12),
          Expanded(
              child: _SummaryCard(
                  label: 'Para receber',
                  value: '$receive',
                  color: AppTheme.primary,
                  icon: Icons.cloud_download_rounded)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: OutlinedButton.icon(
                  onPressed: _working ? null : _upload,
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: const Text('Enviar'))),
          const SizedBox(width: 10),
          Expanded(
              child: FilledButton.icon(
                  onPressed: _working ? null : _download,
                  icon: const Icon(Icons.cloud_download_rounded),
                  label: const Text('Receber'))),
        ]),
        const SizedBox(height: 10),
        SizedBox(
            width: double.infinity,
            child: TextButton.icon(
                onPressed: _working
                    ? null
                    : () async {
                        await _upload();
                        if (mounted && _error == null) await _download();
                      },
                icon: const Icon(Icons.sync_rounded),
                label: const Text('Sincronizar tudo'))),
        const SizedBox(height: 18),
        Card(child: Column(children: rows.map(_row).toList())),
        const SizedBox(height: 12),
        Text(
            'Enviar grava o banco local no servidor. Receber mescla os dados disponíveis na retaguarda neste aparelho.',
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  List<_TableComparison> _comparison() {
    final local = _tableMap(_local?['tables']);
    final remote = _tableMap(_remote?['tables']);
    return _tables
        .map((table) {
          final localRows = _rows(local[table]);
          final remoteRows = _rows(remote[table]);
          final remoteById = {for (final row in remoteRows) _key(row): row};
          final localById = {for (final row in localRows) _key(row): row};
          final toUpload = localRows.where((row) {
            final other = remoteById[_key(row)];
            return other == null || _updated(row) > _updated(other);
          }).length;
          final toReceive = remoteRows.where((row) {
            final other = localById[_key(row)];
            return other == null || _updated(row) > _updated(other);
          }).length;
          return _TableComparison(
              table, localRows.length, remoteRows.length, toUpload, toReceive);
        })
        .where((row) => row.local > 0 || row.remote > 0)
        .toList();
  }

  Map<String, dynamic> _tableMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  List<Map<String, dynamic>> _rows(dynamic value) =>
      (value is List ? value : const <dynamic>[])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
  String _key(Map<String, dynamic> row) =>
      '${row['id'] ?? row['name'] ?? row['word'] ?? row['phrase'] ?? row['created_at']}';
  int _updated(Map<String, dynamic> row) =>
      DateTime.tryParse('${row['updated_at'] ?? row['created_at'] ?? ''}')
          ?.millisecondsSinceEpoch ??
      0;

  Widget _row(_TableComparison row) => ListTile(
        leading: const Icon(Icons.table_rows_outlined),
        title: Text(_label(row.table),
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        subtitle: Text('Local: ${row.local} · Servidor: ${row.remote}'),
        trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('↑ ${row.toUpload}',
                  style: TextStyle(
                      color: row.toUpload > 0 ? AppTheme.warning : null)),
              Text('↓ ${row.toReceive}',
                  style: TextStyle(
                      color: row.toReceive > 0 ? AppTheme.primary : null))
            ]),
      );

  String _label(String table) => switch (table) {
        'words' => 'Palavras',
        'phrases' => 'Frases',
        'phrasal_verbs' => 'Phrasal verbs',
        'player_stats' => 'Estatísticas',
        'study_sessions' => 'Sessões de estudo',
        'contest_cards' => 'Cartões de concurso',
        'diary_entries' => 'Diário',
        'mock_tests' => 'Simulados',
        'categories' => 'Categorias',
        _ => table
      };
}

class _TableComparison {
  final String table;
  final int local;
  final int remote;
  final int toUpload;
  final int toReceive;
  const _TableComparison(
      this.table, this.local, this.remote, this.toUpload, this.toReceive);
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _SummaryCard(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color),
            const SizedBox(height: 10),
            Text(value,
                style: GoogleFonts.nunito(
                    fontSize: 26, fontWeight: FontWeight.w900)),
            Text(label,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant))
          ])));
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, size: 52),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'))
          ])));
}
