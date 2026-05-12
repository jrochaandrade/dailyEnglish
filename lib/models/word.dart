class Word {
  final int? id;
  final String word;
  final String translation;
  final String? translation2;
  final String? translation3;
  final String? meaning;
  final String? meaningPt;
  final String? example1;
  final String? exampleTranslation1;
  final String? example2;
  final String? exampleTranslation2;
  final String? example3;
  final String? exampleTranslation3;
  final String? synonyms;
  final String? opposite;
  final String? category;
  final int difficulty;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  // SM-2 spaced repetition fields
  final DateTime? nextReviewAt;
  final double easeFactor;
  final int srRepetitions;
  final int srInterval;

  const Word({
    this.id,
    required this.word,
    required this.translation,
    this.translation2,
    this.translation3,
    this.meaning,
    this.meaningPt,
    this.example1,
    this.exampleTranslation1,
    this.example2,
    this.exampleTranslation2,
    this.example3,
    this.exampleTranslation3,
    this.synonyms,
    this.opposite,
    this.category,
    this.difficulty = 1,
    this.status = 'learning',
    required this.createdAt,
    required this.updatedAt,
    this.nextReviewAt,
    this.easeFactor = 2.5,
    this.srRepetitions = 0,
    this.srInterval = 0,
  });

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'] as int?,
      word: map['word'] as String,
      translation: map['translation'] as String,
      translation2: map['translation_2'] as String?,
      translation3: map['translation_3'] as String?,
      meaning: map['meaning'] as String?,
      meaningPt: map['meaning_pt'] as String?,
      example1: map['example_1'] as String?,
      exampleTranslation1: map['example_translation_1'] as String?,
      example2: map['example_2'] as String?,
      exampleTranslation2: map['example_translation_2'] as String?,
      example3: map['example_3'] as String?,
      exampleTranslation3: map['example_translation_3'] as String?,
      synonyms: map['synonyms'] as String?,
      opposite: map['opposite'] as String?,
      category: map['category'] as String?,
      difficulty: map['difficulty'] as int? ?? 1,
      status: map['status'] as String? ?? 'learning',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      nextReviewAt: map['next_review_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['next_review_at'] as int)
          : null,
      easeFactor: (map['ease_factor'] as num?)?.toDouble() ?? 2.5,
      srRepetitions: map['sr_repetitions'] as int? ?? 0,
      srInterval: map['sr_interval'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'word': word,
      'translation': translation,
      'translation_2': translation2,
      'translation_3': translation3,
      'meaning': meaning,
      'meaning_pt': meaningPt,
      'example_1': example1,
      'example_translation_1': exampleTranslation1,
      'example_2': example2,
      'example_translation_2': exampleTranslation2,
      'example_3': example3,
      'example_translation_3': exampleTranslation3,
      'synonyms': synonyms,
      'opposite': opposite,
      'category': category,
      'difficulty': difficulty,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'next_review_at': nextReviewAt?.millisecondsSinceEpoch,
      'ease_factor': easeFactor,
      'sr_repetitions': srRepetitions,
      'sr_interval': srInterval,
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
          translation2 == other.translation2 &&
          translation3 == other.translation3 &&
          meaning == other.meaning &&
          meaningPt == other.meaningPt &&
          example1 == other.example1 &&
          exampleTranslation1 == other.exampleTranslation1 &&
          example2 == other.example2 &&
          exampleTranslation2 == other.exampleTranslation2 &&
          example3 == other.example3 &&
          exampleTranslation3 == other.exampleTranslation3 &&
          synonyms == other.synonyms &&
          opposite == other.opposite &&
          category == other.category &&
          difficulty == other.difficulty &&
          status == other.status &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          nextReviewAt == other.nextReviewAt &&
          easeFactor == other.easeFactor &&
          srRepetitions == other.srRepetitions &&
          srInterval == other.srInterval;

  @override
  int get hashCode => Object.hashAll([
        id, word, translation, translation2, translation3, meaning, meaningPt,
        example1, exampleTranslation1, example2, exampleTranslation2,
        example3, exampleTranslation3, synonyms, opposite, category,
        difficulty, status, createdAt, updatedAt,
        nextReviewAt, easeFactor, srRepetitions, srInterval,
      ]);

  Word copyWith({
    int? id,
    String? word,
    String? translation,
    String? translation2,
    String? translation3,
    String? meaning,
    String? meaningPt,
    String? example1,
    String? exampleTranslation1,
    String? example2,
    String? exampleTranslation2,
    String? example3,
    String? exampleTranslation3,
    String? synonyms,
    String? opposite,
    String? category,
    int? difficulty,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? nextReviewAt,
    double? easeFactor,
    int? srRepetitions,
    int? srInterval,
  }) {
    return Word(
      id: id ?? this.id,
      word: word ?? this.word,
      translation: translation ?? this.translation,
      translation2: translation2 ?? this.translation2,
      translation3: translation3 ?? this.translation3,
      meaning: meaning ?? this.meaning,
      meaningPt: meaningPt ?? this.meaningPt,
      example1: example1 ?? this.example1,
      exampleTranslation1: exampleTranslation1 ?? this.exampleTranslation1,
      example2: example2 ?? this.example2,
      exampleTranslation2: exampleTranslation2 ?? this.exampleTranslation2,
      example3: example3 ?? this.example3,
      exampleTranslation3: exampleTranslation3 ?? this.exampleTranslation3,
      synonyms: synonyms ?? this.synonyms,
      opposite: opposite ?? this.opposite,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      easeFactor: easeFactor ?? this.easeFactor,
      srRepetitions: srRepetitions ?? this.srRepetitions,
      srInterval: srInterval ?? this.srInterval,
    );
  }
}
