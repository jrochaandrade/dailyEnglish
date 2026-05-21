import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/study_session.dart';
import '../../providers/study_session_provider.dart';
import '../../core/theme/app_theme.dart';
import 'study_session_form.dart';

class StudyLogScreen extends ConsumerWidget {
  const StudyLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(studySessionListProvider);
    final stats = ref.watch(studyStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Log'),
        leading: BackButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (_) => const StudySessionForm(),
        ),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Error loading sessions.')),
        data: (sessions) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _StatsHeader(stats: stats)),
            if (sessions.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.school_rounded,
                          size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('No study sessions yet.',
                          style: GoogleFonts.nunito(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      const SizedBox(height: 8),
                      Text("Tap + to register your first session.",
                          style: GoogleFonts.nunito(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final session = sessions[index];
                    return _SessionTile(session: session);
                  },
                  childCount: sessions.length,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  final StudyStats stats;
  const _StatsHeader({required this.stats});

  String _fmt(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Study Time',
                          style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      Text(_fmt(stats.totalMinutes),
                          style: GoogleFonts.nunito(
                              fontSize: 28, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    stats.estimatedLevel,
                    style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _SkillStat(label: 'Listening', minutes: stats.listeningMinutes, color: AppTheme.primary),
                const SizedBox(width: 12),
                _SkillStat(label: 'Reading', minutes: stats.readingMinutes, color: AppTheme.secondary),
                const SizedBox(width: 12),
                _SkillStat(label: 'Writing', minutes: stats.writingMinutes, color: AppTheme.tertiary),
                const SizedBox(width: 12),
                _SkillStat(label: 'Speaking', minutes: stats.speakingMinutes, color: Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillStat extends StatelessWidget {
  final String label;
  final int minutes;
  final Color color;
  const _SkillStat({required this.label, required this.minutes, required this.color});

  String _fmt(int m) {
    final h = m ~/ 60;
    final min = m % 60;
    if (h == 0) return '${min}m';
    if (min == 0) return '${h}h';
    return '${h}h${min}m';
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(_fmt(minutes),
              style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: color)),
          Text(label,
              style: GoogleFonts.nunito(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _SessionTile extends ConsumerWidget {
  final StudySession session;
  const _SessionTile({required this.session});

  static const _typeIcons = {
    StudyType.listening: Icons.headphones_rounded,
    StudyType.reading: Icons.menu_book_rounded,
    StudyType.writing: Icons.edit_rounded,
    StudyType.speaking: Icons.record_voice_over_rounded,
  };

  static const _typeColors = {
    StudyType.listening: AppTheme.primary,
    StudyType.reading: AppTheme.secondary,
    StudyType.writing: AppTheme.tertiary,
    StudyType.speaking: Colors.orange,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _typeColors[session.type] ?? AppTheme.primary;
    final icon = _typeIcons[session.type] ?? Icons.school_rounded;
    final h = session.durationMinutes ~/ 60;
    final m = session.durationMinutes % 60;
    final durationStr = h > 0 ? '${h}h ${m}m' : '${m}m';

    return Dismissible(
      key: ValueKey(session.id!),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) {
        final messenger = ScaffoldMessenger.of(context);
        ref
            .read(studySessionListProvider.notifier)
            .deleteSession(session.id!);
        messenger.showSnackBar(
          const SnackBar(content: Text('Session deleted.')),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(
            '${session.type.label} · $durationStr',
            style: GoogleFonts.nunito(
                fontSize: 15, fontWeight: FontWeight.w800),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (session.activity != null)
                Text(session.activity!,
                    style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              Text(session.date,
                  style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
