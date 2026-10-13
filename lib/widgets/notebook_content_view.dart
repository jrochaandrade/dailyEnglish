import 'package:flutter/material.dart';
import '../core/utils/markdown_text.dart';

class NotebookContentView extends StatelessWidget {
  final String markdown;
  final String? visual;
  const NotebookContentView({super.key, required this.markdown, this.visual});

  @override
  Widget build(BuildContext context) {
    final content = visual != null && visual!.trim().isNotEmpty
        ? _removeVisualSection(markdown)
        : markdown;
    final sections = _sections(content)
        .where((section) =>
            visual == null || section.$1.trim().toLowerCase() != 'visual')
        .toList();
    final List<Widget> children = sections
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
        .toList();
    if (visual != null && visual!.trim().isNotEmpty) {
      children.add(MermaidMindmapView(source: visual!));
    }
    return Column(children: children);
  }

  String _removeVisualSection(String value) => value.replaceAll(
        RegExp(r'(?:^|\n)#{1,3}\s*Visual\s*\n.*?(?=\n#{1,3}\s+|\z)',
            caseSensitive: false),
        '',
      );

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

class MermaidMindmapView extends StatelessWidget {
  final String source;
  const MermaidMindmapView({super.key, required this.source});

  @override
  Widget build(BuildContext context) {
    final nodes = _parseMindmap(source);
    if (nodes.isEmpty) {
      return Card(
        margin: const EdgeInsets.only(top: 12),
        child: ExpansionTile(
          title: const Text('Mapa visual'),
          subtitle: const Text('Não foi possível desenhar este mapa'),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(source),
            ),
          ],
        ),
      );
    }

    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mapa visual',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            ...nodes.map((node) => _MindmapNode(node: node)),
            const SizedBox(height: 4),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title:
                  Text('Ver código Mermaid', style: theme.textTheme.bodySmall),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child:
                      SelectableText(source, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MindmapNodeData {
  final int depth;
  final String label;
  const _MindmapNodeData(this.depth, this.label);
}

class _MindmapNode extends StatelessWidget {
  final _MindmapNodeData node;
  const _MindmapNode({required this.node});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isRoot = node.depth == 0;
    final left = (node.depth * 18).clamp(0, 180).toDouble();
    return Padding(
      padding: EdgeInsets.only(left: left, bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isRoot
              ? colors.primaryContainer
              : colors.surfaceContainerHighest.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isRoot ? colors.primary : colors.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
                isRoot
                    ? Icons.account_tree_rounded
                    : Icons.subdirectory_arrow_right_rounded,
                size: 18,
                color: isRoot ? colors.primary : colors.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(node.label,
                  textAlign: TextAlign.justify,
                  style: TextStyle(
                      fontWeight: isRoot ? FontWeight.w900 : FontWeight.w600,
                      height: 1.35)),
            ),
          ],
        ),
      ),
    );
  }
}

List<_MindmapNodeData> _parseMindmap(String value) {
  var normalized = value.replaceAll('\r', '').trim();
  normalized = normalized.replaceAll(
      RegExp(r'```(?:mermaid)?', caseSensitive: false), '');
  normalized = normalized.replaceAll('```', '').trim();
  final lines = normalized.split('\n');
  final start = lines.indexWhere((line) =>
      RegExp(r'^(?:mermaid\s+)?mindmap(?:\s|$)', caseSensitive: false)
          .hasMatch(line.trim()));
  if (start < 0) return const [];

  final result = <_MindmapNodeData>[];
  final firstRemainder = lines[start].trim().replaceFirst(
      RegExp(r'^(?:mermaid\s+)?mindmap\s*', caseSensitive: false), '');
  final sourceLines = <String>[
    if (firstRemainder.isNotEmpty) '  $firstRemainder',
    ...lines.skip(start + 1),
  ];
  for (final raw in sourceLines) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) continue;
    final indent = raw.length - raw.trimLeft().length;
    final rootMatch = RegExp(
            r'^root\s*(?:\(\((.*?)\)\)|\((.*?)\)|\[(.*?)\])\s*(.*)$',
            caseSensitive: false)
        .firstMatch(trimmed);
    if (rootMatch != null) {
      final rootLabel = [
        rootMatch.group(1),
        rootMatch.group(2),
        rootMatch.group(3)
      ]
          .whereType<String>()
          .firstWhere((item) => item.isNotEmpty, orElse: () => 'Tema')
          .trim();
      result.add(_MindmapNodeData(0, rootLabel));
      final remainder = rootMatch.group(4)?.trim() ?? '';
      if (remainder.isNotEmpty) {
        result.add(_MindmapNodeData(1, remainder));
      }
      continue;
    }
    var label = trimmed;
    label = label.replaceAll(RegExp(r'^\(\(|\)\)$'), '').trim();
    label = label.replaceAll(RegExp(r'^\(|\)$'), '').trim();
    label = label.replaceAll(RegExp(r'^\[|\]$'), '').trim();
    label = label.replaceAll(RegExp(r'^"|"$'), '').trim();
    if (label.isEmpty) continue;
    final depth = result.isEmpty ? 0 : (indent ~/ 2).clamp(1, 8);
    result.add(_MindmapNodeData(depth, label));
  }
  return result;
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
