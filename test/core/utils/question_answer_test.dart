import 'package:flutter_test/flutter_test.dart';
import 'package:daily_english/core/utils/question_answer.dart';

void main() {
  final options = [
    {'key': 'A', 'label': 'Mandado judicial'},
    {'key': 'B', 'label': 'Representação do ofendido'},
    {'key': 'C', 'label': 'Comunicação policial'},
  ];

  for (final answer in [
    'B',
    ' B ',
    'B)',
    'B. Representação do ofendido',
    'B Representação do ofendido',
    'Representação do ofendido'
  ]) {
    test('selected green option and feedback agree for $answer', () {
      final question = {'answer': answer, 'options': options};
      expect(QuestionAnswer.matchesOption(options[1], answer), isTrue);
      expect(QuestionAnswer.isCorrect(question, 'B'), isTrue);
      expect(QuestionAnswer.isCorrect(question, 'A'), isFalse);
    });
  }

  test('missing answer cannot produce a correct response', () {
    expect(QuestionAnswer.isCorrect({'answer': ''}, ''), isFalse);
  });

  test('true/false responses work without options', () {
    expect(QuestionAnswer.isCorrect({'answer': 'Certo'}, 'certo'), isTrue);
    expect(QuestionAnswer.isCorrect({'answer': 'Certo'}, 'Errado'), isFalse);
  });
}
