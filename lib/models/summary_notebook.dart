class SummaryNotebook {
  final int id;
  final String name;
  final String? disciplineName;
  final List<int> sourceContentIds;
  final String? content;
  final String? visual;
  final bool includeVisual;
  final DateTime? generatedAt;

  const SummaryNotebook({
    required this.id,
    required this.name,
    this.disciplineName,
    this.sourceContentIds = const [],
    this.content,
    this.visual,
    this.includeVisual = false,
    this.generatedAt,
  });

  factory SummaryNotebook.fromJson(Map<String, dynamic> json) {
    final discipline = json['discipline'] as Map<String, dynamic>?;
    return SummaryNotebook(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Caderno',
      disciplineName: discipline?['name'] as String?,
      sourceContentIds: (json['source_content_ids'] as List<dynamic>? ?? [])
          .whereType<num>()
          .map((id) => id.toInt())
          .toList(),
      content: json['content'] as String?,
      visual: json['visual'] as String?,
      includeVisual: json['include_visual'] as bool? ?? false,
      generatedAt: json['generated_at'] == null
          ? null
          : DateTime.tryParse(json['generated_at'] as String),
    );
  }
}
