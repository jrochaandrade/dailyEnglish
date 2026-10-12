import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../providers/word_provider.dart';
import '../../providers/diary_provider.dart';
import '../../providers/phrasal_verb_provider.dart';
import '../../providers/phrase_provider.dart';
import '../../providers/player_stats_provider.dart';

// Bridges google_sign_in auth headers into the googleapis HTTP client.
class _AuthClient extends http.BaseClient {
  _AuthClient(this._headers);
  final Map<String, String> _headers;
  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

class GoogleDriveService {
  GoogleDriveService(this._ref);
  final Ref _ref;

  static const _driveScopes = ['https://www.googleapis.com/auth/drive'];

  final _signIn = GoogleSignIn(
    // drive.file cannot list files created by an older app installation. The
    // full Drive scope is needed to recover legacy Daily English backups.
    scopes: _driveScopes,
  );

  static const _folderName = 'Daily English Backups';

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<GoogleSignInAccount?> signIn() async {
    final account = _signIn.currentUser ??
        await _signIn.signInSilently() ??
        await _signIn.signIn();
    if (account == null) return null;

    // Ask again when this installation has an older drive.file grant.
    final granted = await _signIn.requestScopes(_driveScopes);
    return granted ? account : null;
  }

  Future<void> signOut() => _signIn.signOut();

  GoogleSignInAccount? get currentUser => _signIn.currentUser;

  Future<_AuthClient?> _authClient() async {
    final account = await signIn();
    if (account == null) return null;
    return _AuthClient(await account.authHeaders);
  }

  // ── Drive helpers ─────────────────────────────────────────────────────────

  Future<String> _ensureFolder(drive.DriveApi api) async {
    final res = await api.files.list(
      q: "name='$_folderName' and "
          "mimeType='application/vnd.google-apps.folder' and "
          "trashed=false",
      spaces: 'drive',
      $fields: 'files(id)',
    );
    if (res.files?.isNotEmpty == true) return res.files!.first.id!;
    final folder = await api.files.create(
      drive.File()
        ..name = _folderName
        ..mimeType = 'application/vnd.google-apps.folder',
    );
    return folder.id!;
  }

  Future<List<drive.File>> _listBackupFiles(
      drive.DriveApi api, String folderId) async {
    final byId = <String, drive.File>{};
    final queries = [
      "'$folderId' in parents and name contains 'daily_english_backup_' and trashed=false",
      "name contains 'daily_english_backup_' and trashed=false",
    ];
    for (final query in queries) {
      final response = await api.files.list(
        q: query,
        orderBy: 'modifiedTime desc',
        $fields: 'files(id,name,modifiedTime,size,mimeType,parents)',
        spaces: 'drive',
      );
      for (final file in response.files ?? <drive.File>[]) {
        if (file.id != null) byId[file.id!] = file;
      }
    }
    final files = byId.values.toList()
      ..sort((a, b) => (b.modifiedTime ?? DateTime(1970))
          .compareTo(a.modifiedTime ?? DateTime(1970)));
    return files;
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  static String _formatDate(DateTime dt) =>
      '${_pad(dt.day)}/${_pad(dt.month)}/${dt.year} '
      '${_pad(dt.hour)}:${_pad(dt.minute)}';

  // ── Backup to Drive ───────────────────────────────────────────────────────

  static const _maxBackups = 5;

  Future<void> backupToDrive(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
      content: Row(children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
        SizedBox(width: 12),
        Text('Enviando para o Google Drive…'),
      ]),
      duration: Duration(minutes: 2),
    ));

    try {
      final dbPath = await getDatabasesPath();
      final dbFile = File(join(dbPath, 'daily_english.db'));
      if (!await dbFile.exists()) {
        throw Exception('Banco de dados não encontrado');
      }

      final client = await _authClient();
      if (client == null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Login cancelado.')));
        return;
      }

      final api = drive.DriveApi(client);
      final folderId = await _ensureFolder(api);

      final now = DateTime.now();
      final ts = '${now.year}-${_pad(now.month)}-${_pad(now.day)}'
          '_${_pad(now.hour)}-${_pad(now.minute)}';

      await api.files.create(
        drive.File()
          ..name = 'daily_english_backup_$ts.db'
          ..parents = [folderId],
        uploadMedia: drive.Media(dbFile.openRead(), await dbFile.length()),
      );

      // Delete oldest backups if over the limit
      final res = await api.files.list(
        q: "'$folderId' in parents and trashed=false",
        orderBy: 'createdTime asc',
        $fields: 'files(id,name)',
        spaces: 'drive',
      );
      final all = res.files ?? [];
      if (all.length > _maxBackups) {
        final toDelete = all.sublist(0, all.length - _maxBackups);
        for (final f in toDelete) {
          await api.files.delete(f.id!);
        }
      }

      client.close();

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('✅ Backup salvo no Google Drive!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ));
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Erro no backup: $e')));
    }
  }

  // ── Restore from Drive ────────────────────────────────────────────────────

  Future<void> restoreFromDrive(BuildContext context) async {
    try {
      final client = await _authClient();
      if (client == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Login cancelado.')));
        return;
      }

      final api = drive.DriveApi(client);
      final folderId = await _ensureFolder(api);

      final files = await _listBackupFiles(api, folderId);
      if (files.isEmpty) {
        client.close();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Nenhum backup encontrado no Google Drive.')),
        );
        return;
      }

      // Pick backup
      if (!context.mounted) {
        client.close();
        return;
      }
      final selected = await showDialog<drive.File>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Escolher backup'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: files.length,
              itemBuilder: (_, i) {
                final f = files[i];
                final label = f.modifiedTime != null
                    ? _formatDate(f.modifiedTime!.toLocal())
                    : f.name ?? 'Backup';
                return ListTile(
                  leading: const Icon(Icons.cloud_download_rounded),
                  title: Text(
                    f.name ?? 'Backup',
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(label),
                  onTap: () => Navigator.pop(ctx, f),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );

      if (selected == null) {
        client.close();
        return;
      }

      // Confirm overwrite
      if (!context.mounted) {
        client.close();
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmar restauração'),
          content: Text(
            '⚠️ Os dados atuais serão substituídos pelo backup:\n\n'
            '"${selected.name}"',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restaurar'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        client.close();
        return;
      }

      if (!context.mounted) {
        client.close();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Row(children: [
          SizedBox(
            width: 18,
            height: 18,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          SizedBox(width: 12),
          Text('Baixando backup…'),
        ]),
        duration: Duration(minutes: 2),
      ));

      // Download to temp file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(join(tempDir.path, 'restore_tmp.db'));
      final media = await api.files.get(
        selected.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final sink = tempFile.openWrite();
      await media.stream.pipe(sink);
      await sink.flush();
      await sink.close();
      client.close();

      // Replace the live database
      final dbPath = await getDatabasesPath();
      final db = _ref.read(databaseProvider);
      await db.close();
      await tempFile.copy(join(dbPath, 'daily_english.db'));

      _ref.invalidate(databaseProvider);
      _ref.invalidate(wordListProvider);
      _ref.invalidate(diaryListProvider);
      _ref.invalidate(phrasalVerbListProvider);
      _ref.invalidate(phraseListProvider);
      _ref.invalidate(playerStatsProvider);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('✅ Backup restaurado com sucesso!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Erro na restauração: $e')));
    }
  }
}

final googleDriveServiceProvider =
    Provider<GoogleDriveService>((ref) => GoogleDriveService(ref));
