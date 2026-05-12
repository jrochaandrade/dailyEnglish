import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/phrasal_verb_provider.dart';
import '../../models/phrasal_verb.dart';
import '../../core/theme/app_theme.dart';

Color _pvStatusColor(String s) =>
    s == 'learned' ? AppTheme.primary : s == 'difficult' ? AppTheme.error : AppTheme.secondary;

String _pvStatusLabel(String s) =>
    s == 'learning' ? 'Learning' : s == 'learned' ? 'Learned' : 'Difficult';

class PhrasalVerbsScreen extends ConsumerStatefulWidget {
  const PhrasalVerbsScreen({super.key});

  @override
  ConsumerState<PhrasalVerbsScreen> createState() => _PhrasalVerbsScreenState();
}

class _PhrasalVerbsScreenState extends ConsumerState<PhrasalVerbsScreen> {
  final _searchController = TextEditingController();
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(phrasalVerbListProvider.notifier).setSearch('');
      ref.read(phrasalVerbListProvider.notifier).setFilter();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    ref.read(phrasalVerbListProvider.notifier).setSearch(query);
    setState(() {
      _selectedStatus = null;
    });
  }

  void _onStatusTap(String status) {
    final next = _selectedStatus == status ? null : status;
    setState(() {
      _selectedStatus = next;
      _searchController.clear();
    });
    ref.read(phrasalVerbListProvider.notifier).setFilter(status: next);
  }

  @override
  Widget build(BuildContext context) {
    final pvAsync = ref.watch(phrasalVerbListProvider);

    const statusLabels = {
      'learning': 'Learning',
      'learned': 'Learned',
      'difficult': 'Difficult',
    };
    const statusColors = {
      'learned': AppTheme.primary,
      'difficult': AppTheme.error,
      'learning': AppTheme.secondary,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phrasal Verbs'),
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/phrasal-verbs/new'),
        backgroundColor: AppTheme.tertiary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search phrasal verbs...',
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
                      ref.read(phrasalVerbListProvider.notifier).setFilter();
                    },
                  ),
                ),
                ...['learning', 'learned', 'difficult'].map((s) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(statusLabels[s]!),
                        selected: _selectedStatus == s,
                        selectedColor:
                            statusColors[s]!.withValues(alpha: 0.15),
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
              data: (pvList) {
                if (pvList.isEmpty) {
                  return _EmptyState(
                    onAdd: () => context.push('/phrasal-verbs/new'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: pvList.length,
                  itemBuilder: (_, i) => _PhrasalVerbCard(pv: pvList[i]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  const Center(child: Text('Erro ao carregar phrasal verbs.')),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhrasalVerbCard extends StatelessWidget {
  final PhrasalVerb pv;
  const _PhrasalVerbCard({required this.pv});

  @override
  Widget build(BuildContext context) {
    final color = _pvStatusColor(pv.status);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          pv.verb,
          style: GoogleFonts.nunito(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          pv.meaning,
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
            _pvStatusLabel(pv.status),
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        onTap: () => context.push('/phrasal-verbs/${pv.id}'),
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
          const Icon(Icons.auto_stories_rounded, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No phrasal verbs yet.',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first phrasal verb!',
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add Phrasal Verb'),
          ),
        ],
      ),
    );
  }
}
