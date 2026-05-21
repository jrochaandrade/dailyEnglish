class MockTest {
  final int? id;
  final String date; // YYYY-MM-DD
  final double listeningScore;
  final double readingScore;
  final double writingScore;
  final double speakingScore;
  final bool reachedTarget;
  final DateTime createdAt;

  const MockTest({
    this.id,
    required this.date,
    required this.listeningScore,
    required this.readingScore,
    required this.writingScore,
    required this.speakingScore,
    required this.reachedTarget,
    required this.createdAt,
  });

  factory MockTest.fromMap(Map<String, dynamic> map) {
    return MockTest(
      id: map['id'] as int?,
      date: map['date'] as String,
      listeningScore: (map['listening_score'] as num?)?.toDouble() ?? 0.0,
      readingScore: (map['reading_score'] as num?)?.toDouble() ?? 0.0,
      writingScore: (map['writing_score'] as num?)?.toDouble() ?? 0.0,
      speakingScore: (map['speaking_score'] as num?)?.toDouble() ?? 0.0,
      reachedTarget: (map['reached_target'] as int) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'listening_score': listeningScore,
      'reading_score': readingScore,
      'writing_score': writingScore,
      'speaking_score': speakingScore,
      'reached_target': reachedTarget ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
