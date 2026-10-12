import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
          builder: (context, snapshot) => _PerformanceBody(
            cards: items,
            questionCount: snapshot.data?.fold<int>(
                    0, (total, content) => total + content.questions.length) ??
                0,
          ),
        ),
      ),
    );
  }
}

class _PerformanceBody extends StatelessWidget {
  final List<ContestCard> cards;
  final int questionCount;
  const _PerformanceBody({required this.cards, required this.questionCount});

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
                value: '$questionCount',
                icon: Icons.quiz_outlined),
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
