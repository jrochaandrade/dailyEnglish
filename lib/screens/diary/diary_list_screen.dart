import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/diary_provider.dart';
import '../../models/diary_entry.dart';
import '../../core/theme/app_theme.dart';

class DiaryListScreen extends ConsumerWidget {
  const DiaryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(diaryListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Diary'),
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/diary/new'),
        backgroundColor: AppTheme.secondary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: entriesAsync.when(
        data: (entries) => entries.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.edit_note_rounded, size: 80, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'No entries yet.',
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Write about your day in English!',
                      style: GoogleFonts.nunito(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 80, top: 16),
                itemCount: entries.length,
                itemBuilder: (_, i) => _DiaryCard(entry: entries[i]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Erro ao carregar o diário.')),
      ),
    );
  }
}

class _DiaryCard extends StatelessWidget {
  final DiaryEntry entry;
  const _DiaryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dateStr = "${entry.createdAt.day.toString().padLeft(2, '0')}/${entry.createdAt.month.toString().padLeft(2, '0')}/${entry.createdAt.year}";
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          entry.title,
          style: GoogleFonts.nunito(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              entry.content,
              style: GoogleFonts.nunito(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              dateStr,
              style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.secondary),
            ),
          ],
        ),
        trailing: entry.mood != null
            ? Text(entry.mood!, style: const TextStyle(fontSize: 24))
            : null,
        onTap: () => context.push('/diary/${entry.id}'),
      ),
    );
  }
}
