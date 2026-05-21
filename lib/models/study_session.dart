enum StudyType {
  listening,
  reading,
  writing,
  speaking;

  String get label => name[0].toUpperCase() + name.substring(1);

  static StudyType fromString(String value) =>
      StudyType.values.firstWhere((e) => e.name == value);
}

class StudySession {
  final int? id;
  final StudyType type;
  final int durationMinutes;
  final String date; // YYYY-MM-DD
  final String? activity;
  final DateTime createdAt;

  const StudySession({
    this.id,
    required this.type,
    required this.durationMinutes,
    required this.date,
    this.activity,
    required this.createdAt,
  });

  factory StudySession.fromMap(Map<String, dynamic> map) {
    return StudySession(
      id: map['id'] as int?,
      type: StudyType.fromString(map['type'] as String),
      durationMinutes: map['duration_minutes'] as int,
      date: map['date'] as String,
      activity: map['activity'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'type': type.name,
      'duration_minutes': durationMinutes,
      'date': date,
      'activity': activity,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
