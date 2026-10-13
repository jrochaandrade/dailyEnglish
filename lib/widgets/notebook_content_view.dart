import 'package:flutter/material.dart';
import '../core/utils/markdown_text.dart';

class NotebookContentView extends StatelessWidget {
  final String markdown;
  const NotebookContentView({super.key, required this.markdown});

  @override
  Widget build(BuildContext context) {
    final sections = _sections(markdown);
    return Column(
      children: sections
          .map((section) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  initiallyExpanded: section.$1 == sections.first.$1,
                  title: Text(section.$1,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: _SectionBody(lines: section.$2),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  List<(String, List<String>)> _sections(String value) {
    final result = <(String, List<String>)>[];
    String? title;
    var lines = <String>[];
    void flush() {
      if (title != null || lines.any((line) => line.trim().isNotEmpty)) {
        result.add((title ?? 'Resumo', List<String>.from(lines)));
      }
      lines = [];
    }

    for (final line in value.split(RegExp(r'\r?\n'))) {
      final match = RegExp(r'^##\s+(.+)$').firstMatch(line.trim());
      if (match != null) {
        flush();
        title = MarkdownText.plain(match.group(1)!);
      } else {
        lines.add(line);
      }
    }
    flush();
    return result.isEmpty
        ? [('Resumo', value.split(RegExp(r'\r?\n')))]
        : result;
  }
}

class _SectionBody extends StatelessWidget {
  final List<String> lines;
  const _SectionBody({required this.lines});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    final bullets = <String>[];
    final table = <List<String>>[];
    void flushBullets() {
      if (bullets.isEmpty) return;
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: bullets
              .map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Text('• ${MarkdownText.plain(item)}',
                        textAlign: TextAlign.justify,
                        style: const TextStyle(height: 1.5)),
                  ))
              .toList(),
        ),
      ));
      bullets.clear();
    }

    void flushTable() {
      if (table.isEmpty) return;
      final rows = table
          .map((row) => TableRow(
                children: row
                    .map((cell) => Padding(
                          padding: const EdgeInsets.all(9),
                          child: Text(MarkdownText.plain(cell),
                              textAlign: TextAlign.justify,
                              style: const TextStyle(height: 1.4)),
                        ))
                    .toList(),
              ))
          .toList();
      children.add(SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(
              color: Theme.of(context).colorScheme.outlineVariant),
          children: rows,
        ),
      ));
      table.clear();
    }

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) {
        flushBullets();
        flushTable();
        continue;
      }
      if (line.startsWith('|') && line.endsWith('|')) {
        flushBullets();
        final cells = line
            .substring(1, line.length - 1)
            .split('|')
            .map((cell) => cell.trim())
            .toList();
        if (cells.isNotEmpty && !RegExp(r'^:?-{3,}:?$').hasMatch(cells.first)) {
          table.add(cells);
        }
        continue;
      }
      flushTable();
      final heading = RegExp(r'^###?\s+(.+)$').firstMatch(line);
      if (heading != null) {
        flushBullets();
        children.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 7),
          child: Text(MarkdownText.plain(heading.group(1)!),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
        ));
        continue;
      }
      final bullet = RegExp(r'^[-*+]\s+(.+)$').firstMatch(line);
      if (bullet != null) {
        bullets.add(bullet.group(1)!);
        continue;
      }
      if (RegExp(r'^---+$').hasMatch(line)) {
        flushBullets();
        children.add(const Divider());
        continue;
      }
      flushBullets();
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Text(MarkdownText.plain(line),
            textAlign: TextAlign.justify, style: const TextStyle(height: 1.6)),
      ));
    }
    flushBullets();
    flushTable();
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}
