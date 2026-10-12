class ContestCard {
  final int? id;
  final String subject;
  final String deck;
  final String front;
  final String back;
  final String? note;
  final String? source;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? nextReviewAt;
  final double easeFactor;
  final int repetitions;
  final int interval;
  final DateTime? lastReviewAt;

  const ContestCard({
    this.id,
    required this.subject,
    required this.deck,
    required this.front,
    required this.back,
    this.note,
    this.source,
    required this.createdAt,
    required this.updatedAt,
    this.nextReviewAt,
    this.easeFactor = 2.5,
    this.repetitions = 0,
    this.interval = 0,
    this.lastReviewAt,
  });

  factory ContestCard.fromMap(Map<String, dynamic> map) => ContestCard(
        id: map['id'] as int?,
        subject: map['subject'] as String,
        deck: map['deck'] as String,
        front: map['front'] as String,
        back: map['back'] as String,
        note: map['note'] as String?,
        source: map['source'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        nextReviewAt: map['next_review_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['next_review_at'] as int),
        easeFactor: (map['ease_factor'] as num?)?.toDouble() ?? 2.5,
        repetitions: map['repetitions'] as int? ?? 0,
        interval: map['review_interval'] as int? ?? 0,
        lastReviewAt: map['last_review_at'] == null
            ? null
            : DateTime.tryParse(map['last_review_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'subject': subject,
        'deck': deck,
        'front': front,
        'back': back,
        'note': note,
        'source': source,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'next_review_at': nextReviewAt?.millisecondsSinceEpoch,
        'ease_factor': easeFactor,
        'repetitions': repetitions,
        'review_interval': interval,
        'last_review_at': lastReviewAt?.toIso8601String(),
      };

  ContestCard copyWith({
    int? id,
    String? subject,
    String? deck,
    String? front,
    String? back,
    String? note,
    String? source,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? nextReviewAt,
    double? easeFactor,
    int? repetitions,
    int? interval,
    DateTime? lastReviewAt,
  }) =>
      ContestCard(
        id: id ?? this.id,
        subject: subject ?? this.subject,
        deck: deck ?? this.deck,
        front: front ?? this.front,
        back: back ?? this.back,
        note: note ?? this.note,
        source: source ?? this.source,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        nextReviewAt: nextReviewAt ?? this.nextReviewAt,
        easeFactor: easeFactor ?? this.easeFactor,
        repetitions: repetitions ?? this.repetitions,
        interval: interval ?? this.interval,
        lastReviewAt: lastReviewAt ?? this.lastReviewAt,
      );
}
