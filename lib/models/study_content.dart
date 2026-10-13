class StudyContent {
  final int id;
  final String status;
  final bool studyEnabled;
  final int studyInterval;
  final int studyRepetitions;
  final DateTime? studyNextReviewAt;
  final String? title;
  final String? materialTitle;
  final String? disciplineName;
  final String topicName;
  final String? summary;
  final List<Map<String, dynamic>> flashcards;
  final List<Map<String, dynamic>> questions;

  const StudyContent({
    required this.id,
    required this.status,
    this.studyEnabled = true,
    this.studyInterval = 0,
    this.studyRepetitions = 0,
    this.studyNextReviewAt,
    this.title,
    this.materialTitle,
    this.disciplineName,
    required this.topicName,
    this.summary,
    this.flashcards = const [],
    this.questions = const [],
  });

  factory StudyContent.fromJson(Map<String, dynamic> json) {
    final material = json['material'] as Map<String, dynamic>? ?? {};
    final topic = material['topic'] as Map<String, dynamic>? ?? {};
    final discipline = material['discipline'] as Map<String, dynamic>? ?? {};

    return StudyContent(
      id: json['id'] as int,
      status: json['status'] as String? ?? 'draft',
      studyEnabled: json['study_enabled'] as bool? ?? true,
      studyInterval: (json['study_interval'] as num?)?.toInt() ?? 0,
      studyRepetitions: (json['study_repetitions'] as num?)?.toInt() ?? 0,
      studyNextReviewAt:
          DateTime.tryParse(json['study_next_review_at'] as String? ?? ''),
      title: json['title'] as String?,
      materialTitle: material['title'] as String? ??
          material['original_filename'] as String?,
      disciplineName: discipline['name'] as String?,
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
