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

enum _HomeMenuItem { categories, exportBackup, importBackup }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime? _lastPressedAt;

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
                        case _HomeMenuItem.exportBackup:
                          ref.read(backupServiceProvider).exportBackup(context);
                        case _HomeMenuItem.importBackup:
                          ref.read(backupServiceProvider).importBackup(context);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _HomeMenuItem.categories,
                        child: const Text('Categories'),
                      ),
                      PopupMenuItem(
                        value: _HomeMenuItem.exportBackup,
                        child: const Text('Export Backup'),
                      ),
                      PopupMenuItem(
                        value: _HomeMenuItem.importBackup,
                        child: const Text('Restore Backup'),
                      ),
                    ],
                  ),
                ],
              ),
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
                label: 'English Quest',
                subtitle: 'Level up your vocabulary hero',
                icon: Icons.shield_rounded,
                color: AppTheme.warning,
                onTap: () => context.push('/games/quest'),
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
