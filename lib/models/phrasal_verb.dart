class PhrasalVerb {
  final int? id;
  final String baseVerb;
  final String particle;
  final String meaning;
  final String? meaningPt;
  final String? meaningEn;
  final String? example1;
  final String? exampleTranslation1;
  final String? example2;
  final String? exampleTranslation2;
  final String? example3;
  final String? exampleTranslation3;
  final int difficulty;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? nextReviewAt;
  final double easeFactor;
  final int srRepetitions;
  final int srInterval;

  const PhrasalVerb({
    this.id,
    required this.baseVerb,
    required this.particle,
    required this.meaning,
    this.meaningPt,
    this.meaningEn,
    this.example1,
    this.exampleTranslation1,
    this.example2,
    this.exampleTranslation2,
    this.example3,
    this.exampleTranslation3,
    this.difficulty = 1,
    this.status = 'learning',
    required this.createdAt,
    required this.updatedAt,
    this.nextReviewAt,
    this.easeFactor = 2.5,
    this.srRepetitions = 0,
    this.srInterval = 0,
  });

  String get verb => '$baseVerb $particle';

  factory PhrasalVerb.fromMap(Map<String, dynamic> map) {
    return PhrasalVerb(
      id: map['id'] as int?,
      baseVerb: map['base_verb'] as String,
      particle: map['particle'] as String,
      meaning: map['meaning'] as String,
      meaningPt: map['meaning_pt'] as String?,
      meaningEn: map['meaning_en'] as String?,
      example1: map['example_1'] as String?,
      exampleTranslation1: map['example_translation_1'] as String?,
      example2: map['example_2'] as String?,
      exampleTranslation2: map['example_translation_2'] as String?,
      example3: map['example_3'] as String?,
      exampleTranslation3: map['example_translation_3'] as String?,
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
      'base_verb': baseVerb,
      'particle': particle,
      'meaning': meaning,
      'meaning_pt': meaningPt,
      'meaning_en': meaningEn,
      'example_1': example1,
      'example_translation_1': exampleTranslation1,
      'example_2': example2,
      'example_translation_2': exampleTranslation2,
      'example_3': example3,
      'example_translation_3': exampleTranslation3,
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
      other is PhrasalVerb &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          baseVerb == other.baseVerb &&
          particle == other.particle &&
          meaning == other.meaning &&
          meaningPt == other.meaningPt &&
          meaningEn == other.meaningEn &&
          example1 == other.example1 &&
          exampleTranslation1 == other.exampleTranslation1 &&
          example2 == other.example2 &&
          exampleTranslation2 == other.exampleTranslation2 &&
          example3 == other.example3 &&
          exampleTranslation3 == other.exampleTranslation3 &&
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
        id,
        baseVerb,
        particle,
        meaning,
        meaningPt,
        meaningEn,
        example1,
        exampleTranslation1,
        example2,
        exampleTranslation2,
        example3,
        exampleTranslation3,
        difficulty,
        status,
        createdAt,
        updatedAt,
        nextReviewAt,
        easeFactor,
        srRepetitions,
        srInterval,
      ]);

  PhrasalVerb copyWith({
    int? id,
    String? baseVerb,
    String? particle,
    String? meaning,
    String? meaningPt,
    String? meaningEn,
    String? example1,
    String? exampleTranslation1,
    String? example2,
    String? exampleTranslation2,
    String? example3,
    String? exampleTranslation3,
    int? difficulty,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? nextReviewAt,
    double? easeFactor,
    int? srRepetitions,
    int? srInterval,
  }) {
    return PhrasalVerb(
      id: id ?? this.id,
      baseVerb: baseVerb ?? this.baseVerb,
      particle: particle ?? this.particle,
      meaning: meaning ?? this.meaning,
      meaningPt: meaningPt ?? this.meaningPt,
      meaningEn: meaningEn ?? this.meaningEn,
      example1: example1 ?? this.example1,
      exampleTranslation1: exampleTranslation1 ?? this.exampleTranslation1,
      example2: example2 ?? this.example2,
      exampleTranslation2: exampleTranslation2 ?? this.exampleTranslation2,
      example3: example3 ?? this.example3,
      exampleTranslation3: exampleTranslation3 ?? this.exampleTranslation3,
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
