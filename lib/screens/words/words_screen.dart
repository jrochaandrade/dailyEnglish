import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/word_provider.dart';
import '../../providers/category_provider.dart';
import '../../models/word.dart';
import '../../core/theme/app_theme.dart';

Color _wordStatusColor(String s) => s == 'learned'
    ? AppTheme.primary
    : s == 'difficult'
        ? AppTheme.error
        : AppTheme.secondary;

String _wordStatusLabel(String s) => s == 'learning'
    ? 'Learning'
    : s == 'learned'
        ? 'Learned'
        : 'Difficult';

class WordsScreen extends ConsumerStatefulWidget {
  const WordsScreen({super.key});

  @override
  ConsumerState<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends ConsumerState<WordsScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String? _selectedCategory;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(wordListProvider.notifier).setSearch('');
      ref.read(wordListProvider.notifier).setFilter();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    ref.read(wordListProvider.notifier).setSearch(query);
    setState(() {
      _selectedCategory = null;
    });
  }

  void _onCategoryTap(String category) {
    final next = _selectedCategory == category ? null : category;
    setState(() {
      _selectedCategory = next;
      _searchController.clear();
    });
    ref.read(wordListProvider.notifier).setFilter(category: next);
  }

  @override
  Widget build(BuildContext context) {
    final wordsAsync = ref.watch(wordListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Words'),
        leading: BackButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/')),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Learning'),
            Tab(text: 'Learned'),
          ],
          labelColor: AppTheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          indicatorColor: AppTheme.primary,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/words/new'),
        backgroundColor: AppTheme.primary,
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
                hintText: 'Search in English or Portuguese...',
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
                    selected: _selectedCategory == null,
                    onSelected: (_) {
                      setState(() {
                        _selectedCategory = null;
                        _searchController.clear();
                      });
                      ref.read(wordListProvider.notifier).setFilter();
                    },
                  ),
                ),
                ...(ref.watch(categoryListProvider).valueOrNull ?? [])
                    .map((cat) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(cat.name),
                            selected: _selectedCategory == cat.name,
                            onSelected: (_) => _onCategoryTap(cat.name),
                          ),
                        )),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(wordsAsync, false),
                _buildList(wordsAsync, true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(AsyncValue<List<Word>> wordsAsync, bool showLearned) {
    return wordsAsync.when(
      data: (allWords) {
        final words = allWords
            .where((w) =>
                showLearned ? w.status == 'learned' : w.status != 'learned')
            .toList();
        if (words.isEmpty) {
          return _EmptyState(onAdd: () => context.push('/words/new'));
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: words.length,
          itemBuilder: (_, i) => _WordCard(word: words[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('Erro ao carregar palavras.')),
    );
  }
}

class _WordCard extends StatelessWidget {
  final Word word;
  const _WordCard({required this.word});

  @override
  Widget build(BuildContext context) {
    final color = _wordStatusColor(word.status);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          word.word,
          style: GoogleFonts.nunito(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          word.translation,
          style: GoogleFonts.nunito(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _wordStatusLabel(word.status),
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        onTap: () => context.push('/words/${word.id}'),
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
          const Icon(Icons.menu_book_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No words yet.',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first word!',
            style: GoogleFonts.nunito(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add Word'),
          ),
        ],
      ),
    );
  }
}
