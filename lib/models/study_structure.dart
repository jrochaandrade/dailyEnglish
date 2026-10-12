class StudyStructure {
  final int id;
  final String name;
  final int materialsCount;
  final List<StudyTopic> topics;

  const StudyStructure({
    required this.id,
    required this.name,
    required this.materialsCount,
    required this.topics,
  });

  factory StudyStructure.fromJson(Map<String, dynamic> json) {
    final topics = (json['topics'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((topic) => StudyTopic.fromJson(Map<String, dynamic>.from(topic)))
        .toList();
    return StudyStructure(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Sem nome',
      materialsCount: json['materials_count'] as int? ?? 0,
      topics: topics,
    );
  }
}

class StudyTopic {
  final int id;
  final String name;

  const StudyTopic({required this.id, required this.name});

  factory StudyTopic.fromJson(Map<String, dynamic> json) => StudyTopic(
        id: json['id'] as int,
        name: json['name'] as String? ?? 'Sem nome',
      );
}
