import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/word_provider.dart';
import '../../core/theme/app_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordsAsync = ref.watch(wordListProvider);
    final wordCount = wordsAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
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
                style: GoogleFonts.nunito(fontSize: 16, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 32),
              _StatsCard(wordCount: wordCount),
              const SizedBox(height: 24),
              _MenuButton(
                label: 'My Words',
                icon: Icons.menu_book_rounded,
                color: AppTheme.secondary,
                onTap: () => context.go('/words'),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                label: 'Add Word',
                icon: Icons.add_circle_outline_rounded,
                color: AppTheme.primary,
                onTap: () => context.go('/words/new'),
              ),
              const SizedBox(height: 12),
              const _MenuButton(
                label: 'Phrasal Verbs',
                icon: Icons.auto_stories_rounded,
                color: AppTheme.tertiary,
                onTap: null,
                comingSoon: true,
              ),
              const SizedBox(height: 12),
              const _MenuButton(
                label: 'Flashcards',
                icon: Icons.style_rounded,
                color: AppTheme.warning,
                onTap: null,
                comingSoon: true,
              ),
              const SizedBox(height: 12),
              const _MenuButton(
                label: 'My Diary',
                icon: Icons.edit_note_rounded,
                color: AppTheme.secondary,
                onTap: null,
                comingSoon: true,
              ),
            ],
          ),
        ),
      ),
    );
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
                  style: GoogleFonts.nunito(fontSize: 14, color: AppTheme.textSecondary),
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
  final bool comingSoon;

  const _MenuButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.comingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: comingSoon ? 0.45 : 1.0,
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(icon, color: color, size: 28),
          title: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          trailing: comingSoon
              ? Text(
                  'Em breve',
                  style: GoogleFonts.nunito(fontSize: 12, color: AppTheme.textSecondary),
                )
              : const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}
