import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../../providers/word_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/backup_service.dart';

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                'Daily English',
                style: GoogleFonts.nunito(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primary,
                ),
              ),
              Text(
                'Your personal English dictionary',
                style: GoogleFonts.nunito(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              _StatsCard(wordCount: wordCount),
              const SizedBox(height: 24),
              _MenuButton(
                label: 'My Words',
                icon: Icons.menu_book_rounded,
                color: AppTheme.secondary,
                onTap: () => context.push('/words'),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                label: 'Phrasal Verbs',
                icon: Icons.auto_stories_rounded,
                color: AppTheme.tertiary,
                onTap: () => context.push('/phrasal-verbs'),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                label: 'Flashcards',
                icon: Icons.style_rounded,
                color: AppTheme.warning,
                onTap: () => context.push('/flashcards'),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                label: 'Mini-Games',
                icon: Icons.games_rounded,
                color: AppTheme.primary,
                onTap: () => context.push('/games'),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                label: 'Daily Phrases',
                icon: Icons.format_quote_rounded,
                color: AppTheme.secondary,
                onTap: () => context.push('/phrases'),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                label: 'My Diary',
                icon: Icons.edit_note_rounded,
                color: AppTheme.secondary,
                onTap: () => context.push('/diary'),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                label: 'Categories',
                icon: Icons.label_rounded,
                color: AppTheme.tertiary,
                onTap: () => context.push('/categories'),
              ),
              const SizedBox(height: 24),
              Text(
                'Data Management',
                style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              _MenuButton(
                label: 'Export Backup',
                icon: Icons.cloud_upload_rounded,
                color: Colors.blueGrey,
                onTap: () => ref.read(backupServiceProvider).exportBackup(context),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                label: 'Restore Backup',
                icon: Icons.settings_backup_restore_rounded,
                color: Colors.blueGrey,
                onTap: () => ref.read(backupServiceProvider).importBackup(context),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ));
  }
}

class _StatsCard extends StatelessWidget {
  final int wordCount;
  const _StatsCard({required this.wordCount});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.menu_book_rounded, size: 48, color: AppTheme.secondary),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$wordCount',
                  style: GoogleFonts.nunito(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary,
                  ),
                ),
                Text(
                  'words in your dictionary',
                  style: GoogleFonts.nunito(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _MenuButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: color, size: 28),
        title: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
