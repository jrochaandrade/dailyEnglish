import 'package:flutter_test/flutter_test.dart';
import 'package:daily_english/models/word.dart';

void main() {
  final now = DateTime(2026, 1, 1, 12, 0, 0);

  final sampleMap = {
    'id': 1,
    'word': 'improve',
    'translation': 'melhorar',
    'meaning': 'To make something better',
    'example_1': 'I want to improve my English.',
    'example_2': null,
    'example_3': null,
    'synonyms': 'enhance, develop',
    'opposite': 'worsen',
    'category': 'Verbs',
    'difficulty': 2,
    'status': 'learning',
    'created_at': now.toIso8601String(),
    'updated_at': now.toIso8601String(),
  };

  group('Word.fromMap', () {
    test('creates Word with all fields', () {
      final word = Word.fromMap(sampleMap);
      expect(word.id, 1);
      expect(word.word, 'improve');
      expect(word.translation, 'melhorar');
      expect(word.meaning, 'To make something better');
      expect(word.example1, 'I want to improve my English.');
      expect(word.example2, null);
      expect(word.synonyms, 'enhance, develop');
      expect(word.opposite, 'worsen');
      expect(word.category, 'Verbs');
      expect(word.difficulty, 2);
      expect(word.status, 'learning');
      expect(word.createdAt, now);
    });

    test('uses defaults for missing optional fields', () {
      final minimal = {
        'id': 1,
        'word': 'run',
        'translation': 'correr',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };
      final word = Word.fromMap(minimal);
      expect(word.difficulty, 1);
      expect(word.status, 'learning');
      expect(word.meaning, null);
      expect(word.category, null);
    });
  });

  group('Word.toMap', () {
    test('produces correct map with id', () {
      final word = Word.fromMap(sampleMap);
      final map = word.toMap();
      expect(map['id'], 1);
      expect(map['word'], 'improve');
      expect(map['translation'], 'melhorar');
      expect(map['difficulty'], 2);
      expect(map['status'], 'learning');
      expect(map['created_at'], now.toIso8601String());
    });

    test('omits id when null', () {
      final word = Word(
        word: 'run',
        translation: 'correr',
        difficulty: 1,
        status: 'learning',
        createdAt: now,
        updatedAt: now,
      );
      final map = word.toMap();
      expect(map.containsKey('id'), false);
    });
  });

  group('Word.copyWith', () {
    test('updates only specified fields', () {
      final word = Word.fromMap(sampleMap);
      final updated = word.copyWith(status: 'learned');
      expect(updated.status, 'learned');
      expect(updated.word, 'improve');
      expect(updated.id, 1);
    });

    test('updates updatedAt independently', () {
      final word = Word.fromMap(sampleMap);
      final later = DateTime(2026, 6, 1);
      final updated = word.copyWith(updatedAt: later);
      expect(updated.updatedAt, later);
      expect(updated.createdAt, now);
    });
  });
}
