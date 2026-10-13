import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/study_content.dart';
import 'study_content_api_service.dart';

class MindMapViewer {
  static const _fileChannel = MethodChannel('com.devrocha.daily_english/files');

  static Future<void> open(
    BuildContext context,
    StudyContent content,
  ) async {
    final materialId = content.materialId;
    if (!content.hasMindMap || materialId == null) return;

    var loadingVisible = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final file = await StudyContentApiService().downloadMindMap(materialId);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      loadingVisible = false;

      final mimeType = file.mimeType ?? content.mindMapMimeType ?? '';
      if (mimeType.startsWith('image/')) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => Dialog.fullscreen(
            child: Scaffold(
              appBar: AppBar(
                title: Text(content.mindMapFilename ?? 'Mapa mental'),
                leading: CloseButton(
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ),
              body: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: Center(child: Image.memory(file.bytes)),
              ),
            ),
          ),
        );
        return;
      }

      final directory = await getTemporaryDirectory();
      final filename = _safeFilename(
        content.mindMapFilename ?? 'mapa-mental.pdf',
      );
      final localFile = File(path.join(directory.path, filename));
      await localFile.writeAsBytes(file.bytes, flush: true);

      if (Platform.isAndroid) {
        try {
          await _fileChannel.invokeMethod<void>('openFile', {
            'path': localFile.path,
            'mimeType': mimeType.isEmpty ? 'application/pdf' : mimeType,
          });
          return;
        } on PlatformException {
          // O compartilhamento também permite escolher um leitor disponível.
        }
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(localFile.path, mimeType: mimeType)],
          text: content.mindMapFilename ?? 'Mapa mental',
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      final navigator = Navigator.of(context, rootNavigator: true);
      if (loadingVisible && navigator.canPop()) navigator.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o mapa mental.')),
      );
    }
  }

  static String _safeFilename(String filename) {
    final basename = path.basename(filename).replaceAll(
          RegExp(r'[^a-zA-Z0-9._-]'),
          '_',
        );
    return basename.isEmpty ? 'mapa-mental.pdf' : basename;
  }
}
