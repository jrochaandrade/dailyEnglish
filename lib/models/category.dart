class Category {
  final int? id;
  final String name;
  final DateTime createdAt;

  const Category({this.id, required this.name, required this.createdAt});

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] as int?,
        name: map['name'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'created_at': createdAt.toIso8601String(),
      };

  Category copyWith({int? id, String? name}) => Category(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt,
      );
}
