import 'package:flutter/material.dart';
class WordFormScreen extends StatelessWidget {
  final int? wordId;
  const WordFormScreen({super.key, this.wordId});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Form')));
}
