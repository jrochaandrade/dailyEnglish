import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/study_session.dart';
import '../../models/mock_test.dart';
import '../../providers/study_session_provider.dart';
import '../../providers/mock_test_provider.dart';
import '../../core/theme/app_theme.dart';
import 'study_session_form.dart';
import 'mock_test_form.dart';
import 'mock_targets_sheet.dart';

enum _SessionAction { edit, delete }

class StudyLogScreen extends ConsumerStatefulWidget {
  const StudyLogScreen({super.key});

  @override
  ConsumerState<StudyLogScreen> createState() => _StudyLogScreenState();
}

class _StudyLogScreenState extends ConsumerState<StudyLogScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _addSession() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => const StudySessionForm(),
      );

  void _addMockTest() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => const MockTestForm(),
      );

  void _openTargetsSheet() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => const MockTargetsSheet(),
      );

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(studySessionListProvider);
    final stats = ref.watch(studyStatsProvider);
    final mockStats = ref.watch(mockTestStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Log'),
        leading: BackButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: _openTargetsSheet,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Sessions'),
            Tab(text: 'Mock Tests'),
          ],
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (_, __) => FloatingActionButton(
          onPressed: _tabController.index == 0 ? _addSession : _addMockTest,
          backgroundColor: AppTheme.primary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          _StatsHeader(stats: stats, mockStats: mockStats),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Sessions tab
                sessionsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      const Center(child: Text('Error loading sessions.')),
                  data: (sessions) {
                    final grouped = <StudyType, List<StudySession>>{
                      for (final t in StudyType.values)
                        t: sessions.where((s) => s.type == t).toList(),
                    };
                    DateTime? firstDate;
                    if (sessions.isNotEmpty) {
                      final dates = sessions
                          .map((s) => DateTime.parse(s.date))
                          .toList()
                        ..sort();
                      firstDate = dates.first;
                    }
                    return ListView(
                      children: [
                        for (final type in StudyType.values)
                          _SkillGroup(
                              type: type,
                              sessions: grouped[type]!,
                              firstDate: firstDate),
                        const SizedBox(height: 80),
                      ],
                    );
                  },
                ),
                // Mock Tests tab
                const _MockTestsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  final StudyStats stats;
  final MockTestStats mockStats;
  const _StatsHeader({required this.stats, required this.mockStats});

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
                _SkillStat(
                    label: 'Listening',
                    minutes: stats.listeningMinutes,
                    color: AppTheme.primary),
                const SizedBox(width: 12),
                _SkillStat(
                    label: 'Reading',
                    minutes: stats.readingMinutes,
                    color: AppTheme.secondary),
                const SizedBox(width: 12),
                _SkillStat(
                    label: 'Writing',
                    minutes: stats.writingMinutes,
                    color: AppTheme.tertiary),
                const SizedBox(width: 12),
                _SkillStat(
                    label: 'Speaking',
                    minutes: stats.speakingMinutes,
                    color: Colors.orange),
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
            Row(
              children: [
                _MockStat(label: 'Done', value: '${mockStats.done}'),
                _MockStat(label: 'Positive', value: '${mockStats.positive}'),
                _MockStat(
                    label: 'Rate',
                    value: mockStats.done == 0
                        ? '—'
                        : '${mockStats.rate.toStringAsFixed(0)}%'),
                _MockStat(
                    label: 'Book test?',
                    value: mockStats.done == 0
                        ? '—'
                        : (mockStats.bookTest ? 'Yes' : 'No')),
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

class _MockTestsTab extends ConsumerWidget {
  const _MockTestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mockTestsAsync = ref.watch(mockTestListProvider);
    return mockTestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('Error loading mock tests.')),
      data: (tests) {
        if (tests.isEmpty) {
          return ListView(
            children: const [
              ListTile(title: Text('No mock tests yet.')),
            ],
          );
        }
        return ListView(
          children: [
            for (final test in tests)
              _MockTestTile(key: ValueKey(test.id), test: test),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }
}

class _MockTestTile extends ConsumerWidget {
  final MockTest test;
  const _MockTestTile({super.key, required this.test});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reached = test.reachedTarget;
    return ListTile(
      title: Text(test.date,
          style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800)),
      subtitle: Text(
        'L ${test.listeningScore.toStringAsFixed(1)} · '
        'R ${test.readingScore.toStringAsFixed(1)} · '
        'W ${test.writingScore.toStringAsFixed(1)} · '
        'S ${test.speakingScore.toStringAsFixed(1)}',
        style: GoogleFonts.nunito(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            reached ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: reached ? Colors.green : Colors.red,
          ),
          PopupMenuButton<void>(
            icon: const Icon(Icons.more_vert_rounded),
            itemBuilder: (_) => [
              const PopupMenuItem<void>(
                value: null,
                child: ListTile(
                  leading: Icon(Icons.delete_rounded, color: Colors.red),
                  title:
                      Text('Delete', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            onSelected: (_) async {
              final id = test.id;
              if (id == null) return;
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete this test?'),
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
                    .read(mockTestListProvider.notifier)
                    .deleteTest(id);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _SkillGroup extends StatelessWidget {
  final StudyType type;
  final List<StudySession> sessions;
  final DateTime? firstDate;

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

  const _SkillGroup(
      {required this.type, required this.sessions, this.firstDate});

  String _fmt(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  Map<int, List<StudySession>> _groupByWeek(DateTime first) {
    final result = <int, List<StudySession>>{};
    for (final s in sessions) {
      final d = DateTime.parse(s.date);
      final weekNum = (d.difference(first).inDays ~/ 7) + 1;
      result.putIfAbsent(weekNum, () => []).add(s);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColors[type]!;
    final icon = _typeIcons[type]!;
    final totalMinutes = sessions.fold(0, (sum, s) => sum + s.durationMinutes);
    final first = firstDate;

    List<Widget> children;
    if (sessions.isEmpty) {
      children = [
        ListTile(
          title: Text('No sessions yet.',
              style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      ];
    } else if (first == null) {
      children =
          sessions.map((s) => _SessionTile(key: ValueKey(s.id), session: s)).toList();
    } else {
      final byWeek = _groupByWeek(first);
      final weeks = byWeek.keys.toList()..sort((a, b) => b.compareTo(a));
      children = [
        for (final weekNum in weeks) ...[
          _WeekDivider(
              weekNum: weekNum,
              minutes: byWeek[weekNum]!
                  .fold(0, (sum, s) => sum + s.durationMinutes)),
          ...byWeek[weekNum]!
              .map((s) => _SessionTile(key: ValueKey(s.id), session: s)),
        ],
      ];
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Icon(icon, color: color),
        title: Text(
          '${type.label}  ·  ${_fmt(totalMinutes)}',
          style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        children: children,
      ),
    );
  }
}

class _WeekDivider extends StatelessWidget {
  final int weekNum;
  final int minutes;
  const _WeekDivider({required this.weekNum, required this.minutes});

  String _fmt(int m) {
    final h = m ~/ 60;
    final min = m % 60;
    if (h == 0) return '${min}m';
    if (min == 0) return '${h}h';
    return '${h}h ${min}m';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Row(
        children: [
          Text(
            'WEEK $weekNum',
            style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 1.0),
          ),
          const SizedBox(width: 8),
          Text(
            _fmt(minutes),
            style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                title:
                    Text('Delete', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero),
          ),
        ],
      ),
    );
  }
}
