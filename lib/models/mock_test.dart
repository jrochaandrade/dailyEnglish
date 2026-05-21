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
      listeningScore: (map['listening_score'] as num).toDouble(),
      readingScore: (map['reading_score'] as num).toDouble(),
      writingScore: (map['writing_score'] as num).toDouble(),
      speakingScore: (map['speaking_score'] as num).toDouble(),
      reachedTarget: (map['reached_target'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
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
