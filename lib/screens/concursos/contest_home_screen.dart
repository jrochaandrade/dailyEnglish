import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/auth_api_service.dart';
import '../../providers/contest_card_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ContestHomeScreen extends ConsumerStatefulWidget {
  const ContestHomeScreen({super.key});

  @override
  ConsumerState<ContestHomeScreen> createState() => _ContestHomeScreenState();
}

class _ContestHomeScreenState extends ConsumerState<ContestHomeScreen> {
  Future<void> _logout() async {
    await AuthApiService().logout();
    if (mounted) context.go('/login');
  }

  Future<void> _openSync() async {
    await context.push('/sync?area=concursos');
    ref.invalidate(contestCardListProvider);
    ref.invalidate(contestSubjectsProvider);
    ref.invalidate(contestDueCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Concursos'),
        leading: IconButton(
          tooltip: 'Áreas de estudo',
          onPressed: () => context.go('/areas'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Sincronizar concursos',
            onPressed: _openSync,
            icon: const Icon(Icons.sync_rounded),
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
          IconButton(
            tooltip: 'Configurar revisões',
            onPressed: () => context.push('/review-settings'),
            icon: const Icon(Icons.notifications_active_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Área de estudos',
              style: GoogleFonts.nunito(
                  fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('Acesse seus materiais e conteúdos gerados pela IA.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          _AreaCard(
            icon: Icons.picture_as_pdf_rounded,
            title: 'Materiais',
            description: 'Inclua e acompanhe os PDFs enviados.',
            onTap: () => context.push('/materials'),
          ),
          _AreaCard(
            icon: Icons.style_rounded,
            title: 'Flashcards',
            description: 'Revise os cartões organizados por tópico.',
            onTap: () => context.push('/study-content?type=flashcards'),
          ),
          _AreaCard(
            icon: Icons.quiz_rounded,
            title: 'Perguntas',
            description: 'Responda questões e confira o gabarito.',
            onTap: () => context.push('/study-content?type=questions'),
          ),
          _AreaCard(
            icon: Icons.article_rounded,
            title: 'Resumos',
            description: 'Consulte os resumos gerados a partir dos materiais.',
            onTap: () => context.push('/study-content?type=summaries'),
          ),
          _AreaCard(
            icon: Icons.insights_rounded,
            title: 'Desempenho',
            description: 'Veja sua ofensiva, revisões e cartões difíceis.',
            onTap: () => context.push('/concursos/performance'),
          ),
          _AreaCard(
            icon: Icons.calendar_today_rounded,
            title: 'Plano de revisão',
            description: 'Veja o que precisa ser revisado hoje.',
            onTap: () => context.push('/review-plan'),
          ),
          _AreaCard(
            icon: Icons.sync_rounded,
            title: 'Sincronização',
            description: 'Confira e receba os cartões da retaguarda.',
            onTap: _openSync,
          ),
        ],
      ),
    );
  }
}

class _AreaCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _AreaCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: .12),
          child: Icon(icon, color: AppTheme.primary),
        ),
        title:
            Text(title, style: GoogleFonts.nunito(fontWeight: FontWeight.w900)),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
