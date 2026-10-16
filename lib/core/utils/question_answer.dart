class QuestionAnswer {
  static String _normalize(Object? value) =>
      (value ?? '').toString().trim().toLowerCase();

  static bool matchesOption(Map option, String answer) {
    final given = _normalize(answer);
    final key = _normalize(option['key']);
    final label = _normalize(option['label']);
    if (given.isEmpty) return false;
    return (label.isNotEmpty && given == label) ||
        (key.isNotEmpty &&
            (given == key ||
                RegExp('^${RegExp.escape(key)}(?:\\)|\\.|\\s|:)')
                    .hasMatch(given)));
  }

  static bool isCorrect(Map<String, dynamic> question, String answer) {
    final expected = _normalize(question['answer']);
    if (expected.isEmpty || answer.trim().isEmpty) return false;
    if (expected == _normalize(answer)) return true;
    for (final option
        in (question['options'] as List? ?? []).whereType<Map>()) {
      if (matchesOption(option, answer)) {
        return matchesOption(option, expected);
      }
    }
    return false;
  }
}
