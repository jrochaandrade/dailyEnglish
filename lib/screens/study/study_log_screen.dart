import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/study_session.dart';
import '../../providers/study_session_provider.dart';
import '../../core/theme/app_theme.dart';
import 'study_session_form.dart';

enum _SessionAction { edit, delete }

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
        data: (sessions) {
          final grouped = <StudyType, List<StudySession>>{
            for (final t in StudyType.values)
              t: sessions.where((s) => s.type == t).toList(),
          };
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _StatsHeader(stats: stats)),
              SliverList(
                delegate: SliverChildListDelegate([
                  for (final type in StudyType.values)
                    _SkillGroup(type: type, sessions: grouped[type]!),
                  const SizedBox(height: 80),
                ]),
              ),
            ],
          );
        },
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
            const Divider(height: 28),
            Text('MOCK TESTS',
                style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 1.2)),
            const SizedBox(height: 8),
            const Row(
              children: [
                _MockStat(label: 'Done', value: '—'),
                _MockStat(label: 'Positive', value: '—'),
                _MockStat(label: 'Rate', value: '—'),
                _MockStat(label: 'Book test?', value: '—'),
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
  const _SkillStat(
      {required this.label, required this.minutes, required this.color});

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
                  fontSize: 14, fontWeight: FontWeight.w900, color: color)),
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

class _MockStat extends StatelessWidget {
  final String label;
  final String value;
  const _MockStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: GoogleFonts.nunito(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
          Text(value,
              style: GoogleFonts.nunito(
                  fontSize: 14, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _SkillGroup extends StatelessWidget {
  final StudyType type;
  final List<StudySession> sessions;

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

  const _SkillGroup({required this.type, required this.sessions});

  String _fmt(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColors[type]!;
    final icon = _typeIcons[type]!;
    final totalMinutes = sessions.fold(0, (sum, s) => sum + s.durationMinutes);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Icon(icon, color: color),
        title: Text(
          '${type.label}  ·  ${_fmt(totalMinutes)}',
          style:
              GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        children: sessions.isEmpty
            ? [
                ListTile(
                  title: Text('No sessions yet.',
                      style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant)),
                ),
              ]
            : sessions.map((s) => _SessionTile(key: ValueKey(s.id), session: s)).toList(),
      ),
    );
  }
}

class _SessionTile extends ConsumerWidget {
  final StudySession session;
  const _SessionTile({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = session.durationMinutes ~/ 60;
    final m = session.durationMinutes % 60;
    final durationStr = h > 0 ? '${h}h ${m}m' : '${m}m';

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        durationStr,
        style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (session.activity != null)
            Text(session.activity!,
                style: GoogleFonts.nunito(
                    fontSize: 13,
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          Text(session.date,
              style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
      trailing: PopupMenuButton<_SessionAction>(
        icon: const Icon(Icons.more_vert_rounded),
        onSelected: (action) async {
          switch (action) {
            case _SessionAction.edit:
              if (!context.mounted) return;
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24))),
                builder: (_) => StudySessionForm(initialSession: session),
              );
            case _SessionAction.delete:
              final id = session.id;
              if (id == null) return;
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete this session?'),
                  content: const Text('This cannot be undone.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete',
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await ref
                    .read(studySessionListProvider.notifier)
                    .deleteSession(id);
              }
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: _SessionAction.edit,
            child: ListTile(
                leading: Icon(Icons.edit_rounded),
                title: Text('Edit'),
                contentPadding: EdgeInsets.zero),
          ),
          PopupMenuItem(
            value: _SessionAction.delete,
            child: ListTile(
                leading: Icon(Icons.delete_rounded, color: Colors.red),
                title: Text('Delete',
                    style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero),
          ),
        ],
      ),
    );
  }
}
