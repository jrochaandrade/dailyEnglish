import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.school_rounded,
                      size: 52, color: AppTheme.primary),
                ),
                const SizedBox(height: 20),
                Text(
                  'O que você vai estudar?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Escolha uma área para continuar',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                _StudyAreaCard(
                  icon: Icons.translate_rounded,
                  title: 'Inglês',
                  description: 'Palavras, frases, diário, jogos e flashcards',
                  color: AppTheme.primary,
                  onTap: () => context.go('/ingles'),
                ),
                const SizedBox(height: 16),
                _StudyAreaCard(
                  icon: Icons.menu_book_rounded,
                  title: 'Concursos',
                  description: 'Flashcards organizados por matéria e assunto',
                  color: AppTheme.secondary,
                  onTap: () => context.go('/concursos'),
                ),
                const SizedBox(height: 16),
                _StudyAreaCard(
                  icon: Icons.picture_as_pdf_rounded,
                  title: 'Materiais',
                  description: 'PDFs para preparar resumos e revisões',
                  color: AppTheme.tertiary,
                  onTap: () => context.go('/materials'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => context.go('/login'),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Entrar ou criar conta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StudyAreaCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _StudyAreaCard({
    required this.icon,
    required this.title,
    required this.description,
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
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.nunito(
                            fontSize: 19, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(description,
                        style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
