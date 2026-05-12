import 'package:flutter/material.dart';
import 'game_content.dart';

class FillBlankScreen extends StatelessWidget {
  final GameSource source;
  const FillBlankScreen({super.key, required this.source});

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Coming soon')));
}
