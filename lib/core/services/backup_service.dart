import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/word_provider.dart';
import '../../providers/diary_provider.dart';
import '../../providers/phrasal_verb_provider.dart';
import '../../providers/phrase_provider.dart';
import '../../providers/player_stats_provider.dart';

class BackupService {
  final Ref ref;
  BackupService(this.ref);

  Future<void> exportBackup(BuildContext context) async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'daily_english.db');

      final file = File(path);
      if (!await file.exists()) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum banco de dados encontrado.')),
        );
        return;
      }

      final date = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')[0];
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          join(tempDir.path, 'daily_english_backup_$date.db');
      final tempFile = await file.copy(tempPath);

      if (!context.mounted) return;

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path)],
          text: 'Backup do Dicionário - Daily English',
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao exportar: $e')),
      );
    }
  }

  Future<void> importBackup(BuildContext context) async {
    try {
      // Confirm before overwriting
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore Backup'),
          content: const Text(
            'Selecione um arquivo de backup (.db).\n\n'
            '⚠️ Os dados atuais serão substituídos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Selecionar Arquivo'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Open file picker
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) return;

      final pickedPath = result.files.single.path!;

      final backupFile = File(pickedPath);
      final dbPath = await getDatabasesPath();
      final currentDbPath = join(dbPath, 'daily_english.db');

      final currentDb = ref.read(databaseProvider);
      await currentDb.close();

      await backupFile.copy(currentDbPath);

      ref.invalidate(databaseProvider);
      ref.invalidate(wordListProvider);
      ref.invalidate(diaryListProvider);
      ref.invalidate(phrasalVerbListProvider);
      ref.invalidate(phraseListProvider);
      ref.invalidate(playerStatsProvider);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup restaurado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao importar: $e')),
      );
    }
  }
}

final backupServiceProvider = Provider((ref) => BackupService(ref));
