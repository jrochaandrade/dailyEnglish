import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/phrase_provider.dart';
import '../../models/phrase.dart';
import '../../core/theme/app_theme.dart';

Color _statusColor(String s) =>
    s == 'learned' ? AppTheme.primary : s == 'difficult' ? AppTheme.error : AppTheme.secondary;

String _statusLabel(String s) =>
    s == 'learning' ? 'Learning' : s == 'learned' ? 'Learned' : 'Difficult';

class PhrasesScreen extends ConsumerStatefulWidget {
  const PhrasesScreen({super.key});

  @override
  ConsumerState<PhrasesScreen> createState() => _PhrasesScreenState();
}

class _PhrasesScreenState extends ConsumerState<PhrasesScreen> {
  final _searchController = TextEditingController();
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(phraseListProvider.notifier).setSearch('');
      ref.read(phraseListProvider.notifier).setFilter();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onStatusTap(String status) {
    final next = _selectedStatus == status ? null : status;
    setState(() {
      _selectedStatus = next;
      _searchController.clear();
    });
    ref.read(phraseListProvider.notifier).setFilter(status: next);
  }

  @override
  Widget build(BuildContext context) {
    final pvAsync = ref.watch(phraseListProvider);

    const statusColors = {
      'learned': AppTheme.primary,
      'difficult': AppTheme.error,
      'learning': AppTheme.secondary,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Phrases'),
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/phrases/new'),
        backgroundColor: AppTheme.secondary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (q) {
                ref.read(phraseListProvider.notifier).setSearch(q);
                setState(() => _selectedStatus = null);
              },
              decoration: const InputDecoration(
                hintText: 'Search phrases...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: _selectedStatus == null,
                    onSelected: (_) {
                      setState(() {
                        _selectedStatus = null;
                        _searchController.clear();
                      });
                      ref.read(phraseListProvider.notifier).setFilter();
                    },
                  ),
                ),
                ...['learning', 'learned', 'difficult'].map((s) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(_statusLabel(s)),
                        selected: _selectedStatus == s,
                        selectedColor: statusColors[s]!.withValues(alpha: 0.15),
                        checkmarkColor: statusColors[s],
                        labelStyle: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _selectedStatus == s
                              ? statusColors[s]
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        onSelected: (_) => _onStatusTap(s),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: pvAsync.when(
              data: (phrases) {
                if (phrases.isEmpty) {
                  return _EmptyState(onAdd: () => context.push('/phrases/new'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: phrases.length,
                  itemBuilder: (_, i) => _PhraseCard(phrase: phrases[i]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const Center(child: Text('Erro ao carregar frases.')),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhraseCard extends StatelessWidget {
  final Phrase phrase;
  const _PhraseCard({required this.phrase});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(phrase.status);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          phrase.phrase,
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          phrase.translation,
          style: GoogleFonts.nunito(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _statusLabel(phrase.status),
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        onTap: () => context.push('/phrases/${phrase.id}'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.format_quote_rounded, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No phrases yet.',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first daily phrase!',
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add Phrase'),
          ),
        ],
      ),
    );
  }
}
