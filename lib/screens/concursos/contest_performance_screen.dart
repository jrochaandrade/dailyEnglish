import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/study_content_api_service.dart';
import '../../models/contest_card.dart';
import '../../models/study_content.dart';
import '../../providers/contest_card_provider.dart';

class ContestPerformanceScreen extends ConsumerStatefulWidget {
  const ContestPerformanceScreen({super.key});

  @override
  ConsumerState<ContestPerformanceScreen> createState() =>
      _ContestPerformanceScreenState();
}

class _ContestPerformanceScreenState
    extends ConsumerState<ContestPerformanceScreen> {
  late final Future<List<StudyContent>> _contentsFuture =
      StudyContentApiService().list();
  late final Future<List<Map<String, dynamic>>> _questionAnswersFuture =
      _loadQuestionAnswers();

  Future<List<Map<String, dynamic>>> _loadQuestionAnswers() async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList('question-performance-v1') ?? [])
        .map((item) => jsonDecode(item))
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(contestCardListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Desempenho · Concursos')),
      body: cards.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Não foi possível carregar: $error')),
        data: (items) => FutureBuilder<List<StudyContent>>(
          future: _contentsFuture,
          builder: (context, snapshot) =>
              FutureBuilder<List<Map<String, dynamic>>>(
            future: _questionAnswersFuture,
            builder: (context, answersSnapshot) => _PerformanceBody(
              cards: items,
              questionCount: snapshot.data?.fold<int>(0,
                      (total, content) => total + content.questions.length) ??
                  0,
              questionAnswers: answersSnapshot.data ?? const [],
            ),
          ),
        ),
      ),
    );
  }
}

class _PerformanceBody extends StatelessWidget {
  final List<ContestCard> cards;
  final int questionCount;
  final List<Map<String, dynamic>> questionAnswers;
  const _PerformanceBody({
    required this.cards,
    required this.questionCount,
    required this.questionAnswers,
  });

  @override
  Widget build(BuildContext context) {
    final reviewed = cards.where((card) => card.repetitions > 0).length;
    final difficult = cards.where((card) => card.easeFactor < 2.5).length;
    final due = cards
        .where((card) =>
            card.nextReviewAt == null ||
            !card.nextReviewAt!.isAfter(DateTime.now()))
        .length;
    final streak = _streak(cards);
    final answeredQuestions = questionAnswers.length;
    final correctQuestions =
        questionAnswers.where((item) => item['correct'] == true).length;
    final incorrectQuestions = answeredQuestions - correctQuestions;
    final questionAccuracy = answeredQuestions == 0
        ? 0
        : ((correctQuestions / answeredQuestions) * 100).round();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Sua evolução',
            style:
                GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('Acompanhe seus cartões e questões de concurso.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 22),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: [
            _Metric(
                label: 'Cartões',
                value: '${cards.length}',
                icon: Icons.style_rounded),
            _Metric(
                label: 'Questões',
                value: '$answeredQuestions',
                icon: Icons.quiz_outlined),
            _Metric(
                label: 'Acertos',
                value: '$correctQuestions',
                icon: Icons.check_circle_outline_rounded),
            _Metric(
                label: 'Erros',
                value: '$incorrectQuestions',
                icon: Icons.cancel_outlined),
            _Metric(
                label: 'Aproveitamento',
                value: '$questionAccuracy%',
                icon: Icons.insights_rounded),
            _Metric(
                label: 'Revisados',
                value: '$reviewed',
                icon: Icons.check_circle_outline_rounded),
            _Metric(
                label: 'Pendentes',
                value: '$due',
                icon: Icons.schedule_rounded),
            _Metric(
                label: 'Difíceis',
                value: '$difficult',
                icon: Icons.warning_amber_rounded),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const CircleAvatar(
                child: Icon(Icons.local_fire_department_rounded,
                    color: AppTheme.secondary)),
            title: Text('Ofensiva de estudos',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w900)),
            subtitle: Text(
                '$streak ${streak == 1 ? 'dia' : 'dias'} consecutivos com revisão'),
          ),
        ),
        const SizedBox(height: 16),
        _QuestionPerformance(
          answers: questionAnswers,
          generatedCount: questionCount,
        ),
      ],
    );
  }

  int _streak(List<ContestCard> cards) {
    final dates = cards
        .map((card) => card.lastReviewAt)
        .whereType<DateTime>()
        .map((date) =>
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}')
        .toSet();
    var cursor = DateTime.now();
    var count = 0;
    while (dates.contains(
        '${cursor.year.toString().padLeft(4, '0')}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}')) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Metric({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: AppTheme.secondary),
                Text(value,
                    style: GoogleFonts.nunito(
                        fontSize: 24, fontWeight: FontWeight.w900)),
                Text(label,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
        ),
      );
}

class _QuestionPerformance extends StatelessWidget {
  final List<Map<String, dynamic>> answers;
  final int generatedCount;

  const _QuestionPerformance(
      {required this.answers, required this.generatedCount});

  DateTime? _date(Map<String, dynamic> item) =>
      DateTime.tryParse(item['answered_at'] as String? ?? '')?.toLocal();

  List<Map<String, int>> _daily() {
    final now = DateTime.now();
    return List.generate(14, (index) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 13 - index));
      final items = answers.where((item) {
        final date = _date(item);
        return date != null &&
            date.year == day.year &&
            date.month == day.month &&
            date.day == day.day;
      });
      final correct = items.where((item) => item['correct'] == true).length;
      return {
        'total': items.length,
        'correct': correct,
        'incorrect': items.length - correct
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daily = _daily();
    final maxTotal = daily.fold<int>(
        1, (max, item) => item['total']! > max ? item['total']! : max);
    final total = answers.length;
    final correct = answers.where((item) => item['correct'] == true).length;
    List<Map<String, dynamic>> since(Duration duration) =>
        answers.where((item) {
          final date = _date(item);
          return date != null && date.isAfter(now.subtract(duration));
        }).toList();

    final today = answers.where((item) {
      final date = _date(item);
      return date != null &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Desempenho das questões',
              style: GoogleFonts.nunito(
                  fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
              generatedCount == 0
                  ? 'Respostas registradas neste dispositivo.'
                  : '$total de $generatedCount questões respondidas',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (final period in daily)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: period['total']! / maxTotal,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  alignment: Alignment.bottomCenter,
                                  child: period['incorrect']! == 0
                                      ? null
                                      : FractionallySizedBox(
                                          heightFactor: period['incorrect']! /
                                              period['total']!,
                                          child: Container(
                                              color: Colors.redAccent
                                                  .withValues(alpha: .9)),
                                        ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('${period['total']}',
                              style: const TextStyle(fontSize: 10)),
                        ]),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 18, children: const [
            _Legend(color: AppTheme.secondary, label: 'Acertos'),
            _Legend(color: Colors.redAccent, label: 'Erros'),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _PeriodMetric(label: 'Hoje', items: today)),
            const SizedBox(width: 8),
            Expanded(
                child: _PeriodMetric(
                    label: '7 dias', items: since(const Duration(days: 7)))),
            const SizedBox(width: 8),
            Expanded(
                child: _PeriodMetric(
                    label: '30 dias', items: since(const Duration(days: 30)))),
          ]),
          const SizedBox(height: 12),
          Text(
              total == 0
                  ? 'Responda questões para acompanhar sua evolução.'
                  : 'Aproveitamento geral: ${((correct / total) * 100).round()}%',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

class _PeriodMetric extends StatelessWidget {
  final String label;
  final List<Map<String, dynamic>> items;

  const _PeriodMetric({required this.label, required this.items});

  @override
  Widget build(BuildContext context) {
    final correct = items.where((item) => item['correct'] == true).length;
    final accuracy =
        items.isEmpty ? 0 : ((correct / items.length) * 100).round();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12)),
        const SizedBox(height: 4),
        Text('${items.length}',
            style:
                GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900)),
        Text('$accuracy% acertos', style: const TextStyle(fontSize: 11)),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12)),
      ]);
}
