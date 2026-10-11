class StudyContent {
  final int id;
  final String status;
  final String? title;
  final String? materialTitle;
  final String topicName;
  final String? summary;
  final List<Map<String, dynamic>> flashcards;
  final List<Map<String, dynamic>> questions;

  const StudyContent({
    required this.id,
    required this.status,
    this.title,
    this.materialTitle,
    required this.topicName,
    this.summary,
    this.flashcards = const [],
    this.questions = const [],
  });

  factory StudyContent.fromJson(Map<String, dynamic> json) {
    final material = json['material'] as Map<String, dynamic>? ?? {};
    final topic = material['topic'] as Map<String, dynamic>? ?? {};

    return StudyContent(
      id: json['id'] as int,
      status: json['status'] as String? ?? 'draft',
      title: json['title'] as String?,
      materialTitle: material['title'] as String? ??
          material['original_filename'] as String?,
      topicName: topic['name'] as String? ?? 'Sem tópico',
      summary: json['summary'] as String?,
      flashcards: _mapList(json['flashcards']),
      questions: _mapList(json['questions']),
    );
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
