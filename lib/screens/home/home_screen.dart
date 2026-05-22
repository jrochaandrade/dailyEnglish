import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../../providers/word_provider.dart';
import '../../providers/player_stats_provider.dart';
import '../../models/player_stats.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/google_drive_service.dart';
import 'dart:async';
import '../../providers/global_search_provider.dart';
import '../../providers/study_session_provider.dart';
import '../../providers/mock_test_provider.dart';
import '../../screens/study/study_session_form.dart';

enum _HomeMenuItem { categories, studyLog, exportBackup, importBackup, backupToDrive, restoreFromDrive }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime? _lastPressedAt;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _searchQuery = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final wordCount = ref.watch(totalWordCountProvider).valueOrNull ?? 0;
    final stats = ref.watch(playerStatsProvider).valueOrNull;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastPressedAt == null || now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
          _lastPressedAt = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pressione voltar novamente para sair do app.'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: Theme.of(context).brightness == Brightness.dark
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [const Color(0xFFF0F4FF), const Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily English',
                        style: GoogleFonts.nunito(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                        ),
                      ),
                      Text(
                        'Good morning!',
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  PopupMenuButton<_HomeMenuItem>(
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (item) {
                      switch (item) {
                        case _HomeMenuItem.categories:
                          context.push('/categories');
                        case _HomeMenuItem.studyLog:
                          context.push('/study-log');
                        case _HomeMenuItem.exportBackup:
                          ref.read(backupServiceProvider).exportBackup(context);
                        case _HomeMenuItem.importBackup:
                          ref.read(backupServiceProvider).importBackup(context);
                        case _HomeMenuItem.backupToDrive:
                          ref.read(googleDriveServiceProvider).backupToDrive(context);
                        case _HomeMenuItem.restoreFromDrive:
                          ref.read(googleDriveServiceProvider).restoreFromDrive(context);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: _HomeMenuItem.categories,
                        child: ListTile(
                          leading: Icon(Icons.label_rounded),
                          title: Text('Categories'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: _HomeMenuItem.studyLog,
                        child: ListTile(
                          leading: Icon(Icons.school_rounded),
                          title: Text('Study Log'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: _HomeMenuItem.exportBackup,
                        child: ListTile(
                          leading: Icon(Icons.cloud_upload_rounded),
                          title: Text('Export Backup'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: _HomeMenuItem.importBackup,
                        child: ListTile(
                          leading: Icon(Icons.settings_backup_restore_rounded),
                          title: Text('Restore Backup'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: _HomeMenuItem.backupToDrive,
                        child: ListTile(
                          leading: Icon(Icons.drive_folder_upload_rounded),
                          title: Text('Backup to Google Drive'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: _HomeMenuItem.restoreFromDrive,
                        child: ListTile(
                          leading: Icon(Icons.cloud_download_rounded),
                          title: Text('Restore from Google Drive'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search words, phrasal verbs, phrases…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                _GlobalSearchBody(key: ValueKey(_searchQuery), query: _searchQuery)
              else ...[
                const SizedBox(height: 24),
                _StatsCard(wordCount: wordCount, stats: stats),
                const SizedBox(height: 24),
                Text(
                  'MY LIBRARY',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.9,
                  children: [
                    _GridMenuButton(
                      label: 'Words',
                      description: 'Your dictionary',
                      icon: Icons.menu_book_rounded,
                      color: AppTheme.secondary,
                      onTap: () => context.push('/words'),
                    ),
                    _GridMenuButton(
                      label: 'Phrasal Verbs',
                      description: 'Idioms & verbs',
                      icon: Icons.auto_stories_rounded,
                      color: AppTheme.tertiary,
                      onTap: () => context.push('/phrasal-verbs'),
                    ),
                    _GridMenuButton(
                      label: 'Phrases',
                      description: 'Daily expressions',
                      icon: Icons.format_quote_rounded,
                      color: AppTheme.secondary,
                      onTap: () => context.push('/phrases'),
                    ),
                    _GridMenuButton(
                      label: 'Diary',
                      description: 'Writing practice',
                      icon: Icons.edit_note_rounded,
                      color: AppTheme.primary,
                      onTap: () => context.push('/diary'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'STUDY & PLAY',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                _StudyCard(
                  label: 'Flashcards',
                  subtitle: 'Spaced repetition study',
                  icon: Icons.style_rounded,
                  color: AppTheme.secondary,
                  onTap: () => context.push('/flashcards'),
                ),
                const SizedBox(height: 12),
                _StudyCard(
                  label: 'Mini-Games',
                  subtitle: 'Quick practice sessions',
                  icon: Icons.games_rounded,
                  color: AppTheme.primary,
                  onTap: () => context.push('/games'),
                ),
                const SizedBox(height: 24),
                _StudySummaryCard(),
                const SizedBox(height: 12),
                _StudyCard(
                  label: 'Register Study',
                  subtitle: 'Log a study session',
                  icon: Icons.add_task_rounded,
                  color: AppTheme.primary,
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(24))),
                    builder: (_) => const StudySessionForm(),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    ),
    ));
  }
}

class _StatsCard extends StatelessWidget {
  final int wordCount;
  final PlayerStats? stats;
  const _StatsCard({required this.wordCount, this.stats});

  @override
  Widget build(BuildContext context) {
    final progress = (stats?.xp ?? 0) % 100 / 100;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            SizedBox(
              height: 70,
              width: 70,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    color: AppTheme.primary,
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primary,
                          ),
                        ),
                        Text(
                          'LVL ${stats?.level ?? 1}',
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level Progress',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '$wordCount words',
                    style: GoogleFonts.nunito(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Goals achieved!',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (stats != null)
              Column(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 24)),
                  Text(
                    '${stats!.streak}',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'streak',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _GridMenuButton extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _GridMenuButton({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const Spacer(),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                description,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudyCard extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StudyCard({
    required this.label,
    this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: subtitle != null ? Text(
          subtitle!,
          style: GoogleFonts.nunito(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ) : null,
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _GlobalSearchBody extends ConsumerWidget {
  final String query;
  const _GlobalSearchBody({super.key, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(globalSearchProvider(query));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(child: Text('Error: $e')),
      ),
      data: (results) {
        if (results.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text(
                'No results found',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            if (results.words.isNotEmpty) ...[
              _SearchSectionHeader(label: 'Words'),
              ...results.words.map((w) => _SearchResultTile(
                    title: w.word,
                    subtitle: w.translation,
                    typeLabel: 'Word',
                    typeColor: AppTheme.secondary,
                    onTap: () => context.push('/words/${w.id!}'),
                  )),
              const SizedBox(height: 16),
            ],
            if (results.phrasalVerbs.isNotEmpty) ...[
              _SearchSectionHeader(label: 'Phrasal Verbs'),
              ...results.phrasalVerbs.map((pv) => _SearchResultTile(
                    title: pv.verb,
                    subtitle: pv.meaningPt ?? pv.meaning,
                    typeLabel: 'Phrasal Verb',
                    typeColor: AppTheme.tertiary,
                    onTap: () => context.push('/phrasal-verbs/${pv.id!}'),
                  )),
              const SizedBox(height: 16),
            ],
            if (results.phrases.isNotEmpty) ...[
              _SearchSectionHeader(label: 'Phrases'),
              ...results.phrases.map((p) => _SearchResultTile(
                    title: p.phrase,
                    subtitle: p.translation,
                    typeLabel: 'Phrase',
                    typeColor: AppTheme.primary,
                    onTap: () => context.push('/phrases/${p.id!}'),
                  )),
              const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }
}

class _SearchSectionHeader extends StatelessWidget {
  final String label;
  const _SearchSectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String typeLabel;
  final Color typeColor;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.title,
    required this.subtitle,
    required this.typeLabel,
    required this.typeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          title,
          style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.nunito(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: typeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            typeLabel,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: typeColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _StudySummaryCard extends ConsumerWidget {
  const _StudySummaryCard();

  String _fmt(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(studyStatsProvider);
    final mockStats = ref.watch(mockTestStatsProvider);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Study Progress',
                          style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      Text(_fmt(stats.totalMinutes),
                          style: GoogleFonts.nunito(
                              fontSize: 22,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(stats.estimatedLevel,
                      style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'L ${_fmt(stats.listeningMinutes)}  ·  R ${_fmt(stats.readingMinutes)}  ·  W ${_fmt(stats.writingMinutes)}  ·  S ${_fmt(stats.speakingMinutes)}',
              style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700),
            ),
            Text(
              'Mock tests: ${mockStats.done == 0 ? '—' : '${mockStats.positive}/${mockStats.done} (${mockStats.rate.toStringAsFixed(0)}%)'}',
              style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
