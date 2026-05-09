class Word {
  final int? id;
  final String word;
  final String translation;
  final String? meaning;
  final String? example1;
  final String? example2;
  final String? example3;
  final String? synonyms;
  final String? opposite;
  final String? category;
  final int difficulty;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Word({
    this.id,
    required this.word,
    required this.translation,
    this.meaning,
    this.example1,
    this.example2,
    this.example3,
    this.synonyms,
    this.opposite,
    this.category,
    this.difficulty = 1,
    this.status = 'learning',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'] as int?,
      word: map['word'] as String,
      translation: map['translation'] as String,
      meaning: map['meaning'] as String?,
      example1: map['example_1'] as String?,
      example2: map['example_2'] as String?,
      example3: map['example_3'] as String?,
      synonyms: map['synonyms'] as String?,
      opposite: map['opposite'] as String?,
      category: map['category'] as String?,
      difficulty: map['difficulty'] as int? ?? 1,
      status: map['status'] as String? ?? 'learning',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'word': word,
      'translation': translation,
      'meaning': meaning,
      'example_1': example1,
      'example_2': example2,
      'example_3': example3,
      'synonyms': synonyms,
      'opposite': opposite,
      'category': category,
      'difficulty': difficulty,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Word &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          word == other.word &&
          translation == other.translation &&
          meaning == other.meaning &&
          example1 == other.example1 &&
          example2 == other.example2 &&
          example3 == other.example3 &&
          synonyms == other.synonyms &&
          opposite == other.opposite &&
          category == other.category &&
          difficulty == other.difficulty &&
          status == other.status &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hashAll([
        id, word, translation, meaning, example1, example2, example3,
        synonyms, opposite, category, difficulty, status, createdAt, updatedAt,
      ]);

  Word copyWith({
    int? id,
    String? word,
    String? translation,
    String? meaning,
    String? example1,
    String? example2,
    String? example3,
    String? synonyms,
    String? opposite,
    String? category,
    int? difficulty,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Word(
      id: id ?? this.id,
      word: word ?? this.word,
      translation: translation ?? this.translation,
      meaning: meaning ?? this.meaning,
      example1: example1 ?? this.example1,
      example2: example2 ?? this.example2,
      example3: example3 ?? this.example3,
      synonyms: synonyms ?? this.synonyms,
      opposite: opposite ?? this.opposite,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
