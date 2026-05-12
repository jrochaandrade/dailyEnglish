class DiaryEntry {
  final int? id;
  final String title;
  final String content;
  final String? correctedContent;
  final String? comments;
  final String? mood;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DiaryEntry({
    this.id,
    required this.title,
    required this.content,
    this.correctedContent,
    this.comments,
    this.mood,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DiaryEntry.fromMap(Map<String, dynamic> map) {
    return DiaryEntry(
      id: map['id'] as int?,
      title: map['title'] as String,
      content: map['content'] as String,
      correctedContent: map['corrected_content'] as String?,
      comments: map['comments'] as String?,
      mood: map['mood'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'content': content,
      'corrected_content': correctedContent,
      'comments': comments,
      'mood': mood,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  DiaryEntry copyWith({
    int? id,
    String? title,
    String? content,
    String? correctedContent,
    String? comments,
    String? mood,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiaryEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      correctedContent: correctedContent ?? this.correctedContent,
      comments: comments ?? this.comments,
      mood: mood ?? this.mood,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
