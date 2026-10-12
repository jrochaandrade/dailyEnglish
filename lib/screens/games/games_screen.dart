import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import 'game_content.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  GameSource _source = GameSource.words;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mini-Games',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose a source',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: GameSource.values.map((s) {
                  final selected = _source == s;
                  return FilterChip(
                    label: Text(
                      gameSourceLabel(s),
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() => _source = s),
                    selectedColor: AppTheme.primary,
                    backgroundColor: Theme.of(context).cardTheme.color,
                    showCheckmark: false,
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Text(
                'Adventure Mode',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              _GameCard(
                icon: '🛡️',
                title: 'English Quest',
                description: 'Start a mission and use your words to advance.',
                accentColor: AppTheme.warning,
                onPlay: () => context.push('/games/quest'),
              ),
              const SizedBox(height: 24),
              Text(
                'Mini-Games',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              _GameCard(
                icon: '🎯',
                title: 'Multiple Choice',
                description: 'See a term — pick the correct translation.',
                accentColor: AppTheme.primary,
                onPlay: () => context
                    .push('/games/multiple-choice?source=${_source.name}'),
              ),
              const SizedBox(height: 12),
              _GameCard(
                icon: '✏️',
                title: 'Fill in the Blank',
                description:
                    'Complete a sentence with the missing word or verb.',
                accentColor: AppTheme.tertiary,
                onPlay: () =>
                    context.push('/games/fill-blank?source=${_source.name}'),
              ),
              const SizedBox(height: 12),
              _GameCard(
                icon: '🔀',
                title: 'Sentence Scramble',
                description:
                    'Arrange shuffled words into the correct sentence.',
                accentColor: AppTheme.secondary,
                onPlay: () =>
                    context.push('/games/scramble?source=${_source.name}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String icon;
  final String title;
  final String description;
  final Color accentColor;
  final VoidCallback onPlay;

  const _GameCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        leading: Text(icon, style: const TextStyle(fontSize: 32)),
        title: Text(
          title,
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          description,
          style: GoogleFonts.nunito(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: ElevatedButton(
          onPressed: onPlay,
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 40),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: Text('Play',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}
