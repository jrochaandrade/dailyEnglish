class MarkdownText {
  const MarkdownText._();

  static String plain(String value) {
    var text = value.trim();
    if (text.isEmpty) return text;

    text =
        text.replaceAll(RegExp(r'```(?:\w+)?\s*(.*?)```', dotAll: true), r'$1');
    text = text.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]*\)'), r'$1');
    text = text.replaceAll(RegExp(r'^\s*#{1,6}\s*', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '• ');
    text = text.replaceAll('**', '').replaceAll('__', '').replaceAll('`', '');
    text = text.replaceAll('*', '');
    return text.trim();
  }
}
