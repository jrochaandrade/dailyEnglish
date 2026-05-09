import 'package:flutter/material.dart';
class WordDetailScreen extends StatelessWidget {
  final int wordId;
  const WordDetailScreen({super.key, required this.wordId});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Detail')));
}
